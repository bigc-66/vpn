import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_models.dart';
import '../models/vpn_status.dart';
import 'vpn_service.dart';

/// 基于 Platform Channel 的真实 VPN 服务实现。
/// 通道名称 `com.vpnclient/vpn` 与各平台原生插件对应。
class PlatformVpnService implements VpnService {
  static const _channel = MethodChannel('com.vpnclient/vpn');
  static const _secureStorage = FlutterSecureStorage();
  static const _privateKeyStorageKey = 'wg_client_private_key';

  late final StreamController<VpnStatus> _statusController;
  Timer? _statusPollTimer;
  VpnStatus? _lastPolledStatus;
  bool _statusPollingInFlight = false;

  /// 缓存的 WireGuard 客户端私钥（连接时传给原生层）
  String? _clientPrivateKey;

  final Future<String?> Function(
    String host,
    List<String> dohUrls,
    List<String> dnsServers,
  ) _wireGuardHostResolver;

  PlatformVpnService({
    Future<String?> Function(
      String host,
      List<String> dohUrls,
      List<String> dnsServers,
    )? wireGuardHostResolver,
  }) : _wireGuardHostResolver =
            wireGuardHostResolver ?? _defaultWireGuardHostResolver {
    _statusController = StreamController<VpnStatus>.broadcast();
    _restorePrivateKey();
    _startStatusPolling();
  }

  @override
  Stream<VpnStatus> get statusStream => _statusController.stream;

  @override
  Future<VpnStatus> getStatus() async {
    final raw = await _channel.invokeMethod<String>('getStatus');
    return _parseStatus((raw ?? 'disconnected').toString());
  }

  @override
  Future<void> connect({
    required LiNode node,
    required VpnProtocol protocol,
    required String username,
    required String password,
    List<String> routes = const [],
    bool splitRouting = true,
  }) async {
    final endpoint = _normalizeEndpoint(node.url, node.port);
    final isWireGuard = protocol == VpnProtocol.wireguard;
    final resolvedServer = isWireGuard
        ? await _resolveWireGuardServer(endpoint.server, node)
        : endpoint.server;
    final privateKey = node.clientPrivateKey.isNotEmpty
        ? node.clientPrivateKey
        : (_clientPrivateKey ?? '');

    // SSL VPN (Cisco AnyConnect/CSTP): 先通过 Web 表单认证获取会话 Cookie
    String sessionCookie = '';
    if (!isWireGuard) {
      final cookie = await _cstpAuthenticate(
        host: endpoint.server,
        port: endpoint.port,
        groupPath: endpoint.path,
        username: username,
        password: password,
      );
      if (cookie == null || cookie.isEmpty) {
        throw PlatformException(
          code: 'CSTP_AUTH_FAILED',
          message: 'VPN gateway authentication failed',
        );
      }
      sessionCookie = cookie;
      dev.log('CSTP auth success, cookie obtained', name: 'PlatformVpnService');
    }

    final params = <String, dynamic>{
      'server': resolvedServer,
      'port': endpoint.port,
      'protocol': protocol == VpnProtocol.ssl ? 'ssl' : 'wireguard',
      'username': username,
      'password': password,
      'serverPublicKey': node.publicKey,
      'clientPrivateKey': privateKey,
      'clientIpAddress': node.clientIpAddress,
      'dnsServers': node.dnsServers,
      'doh': node.doh,
      'dnsFallback': node.dnsServers,
      'dnsStrategy': isWireGuard ? 'doh_first' : 'system',
      'sessionCookie': sessionCookie,
      'routes': routes,
      'splitRouting': splitRouting,
    };
    dev.log(
      'connect params: server=$resolvedServer port=${endpoint.port} '
      'protocol=${params['protocol']} '
      'dnsServers=${params['dnsServers']} '
      'doh=${params['doh']} '
      'dnsStrategy=${params['dnsStrategy']} '
      'dnsFallback=${params['dnsFallback']} '
      'routes=${(params['routes'] as List).length}条=${params['routes']} '
      'splitRouting=${params['splitRouting']} '
      'publicKey=${node.publicKey.length > 8 ? '${node.publicKey.substring(0, 8)}...(${node.publicKey.length})' : node.publicKey} '
      'privateKey=${privateKey.length > 8 ? '${privateKey.substring(0, 8)}...(${privateKey.length})' : '(empty=${privateKey.isEmpty})'} '
      'clientIp=${node.clientIpAddress} '
      'nodeUrl=${node.url} nodeName=${node.name} nodePort=${node.port}',
      name: 'PlatformVpnService',
    );
    await _channel.invokeMethod('connect', params);
  }

  /// Cisco AnyConnect/ASA Web 表单认证。
  /// 返回会话 Cookie 字符串（用于 CSTP CONNECT 请求），失败返回 null。
  Future<String?> _cstpAuthenticate({
    required String host,
    required int port,
    required String groupPath,
    required String username,
    required String password,
  }) async {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final baseUrl = 'https://$host:$port';

      // 第一步: GET 登录页面，提取 csrf_token
      final loginUrl = Uri.parse('$baseUrl/+CSCOE+/logon.html');
      final getReq = await client.getUrl(loginUrl);
      getReq.headers.set('User-Agent', 'AnyConnect');
      getReq.followRedirects = false;
      final getResp = await getReq.close().timeout(const Duration(seconds: 10));
      final html = await utf8.decodeStream(getResp);

      // 收集响应 Cookie
      final allCookies = <String, String>{};
      void collectCookies(HttpClientResponse resp) {
        final headers = resp.headers[HttpHeaders.setCookieHeader];
        if (headers != null) {
          for (final raw in headers) {
            final kv = raw.split(';').first.trim();
            final eq = kv.indexOf('=');
            if (eq > 0) {
              allCookies[kv.substring(0, eq)] = kv;
            }
          }
        }
      }
      collectCookies(getResp);

      // 提取 csrf_token
      final csrfMatch = RegExp(
        r'name="csrf_token"\s+[^>]*value="([^"]*)"',
      ).firstMatch(html);
      final csrf = csrfMatch?.group(1) ?? '';

      // 模拟页面 JavaScript 设置的 Cookie
      allCookies['webvpnlogin'] = 'webvpnlogin=1';
      if (csrf.isNotEmpty) {
        allCookies['CSRFtoken'] = 'CSRFtoken=$csrf';
      }

      dev.log(
        'CSTP login page: csrf=${csrf.isNotEmpty ? "found" : "missing"}, '
        'cookies=${allCookies.keys.join(",")}',
        name: 'PlatformVpnService',
      );

      // 第二步: POST 登录凭据（与 HTML 表单完全一致）
      final postUrl = Uri.parse('$baseUrl/+webvpn+/index.html');
      final postReq = await client.postUrl(postUrl);
      postReq.headers
          .set('Content-Type', 'application/x-www-form-urlencoded');
      postReq.headers.set('User-Agent', 'AnyConnect');
      postReq.followRedirects = false;
      postReq.headers.set('Cookie', allCookies.values.join('; '));

      final formData = {
        'tgroup': '',
        'next': '',
        'tgcookieset': '',
        'csrf_token': csrf,
        'username': username,
        'password': password,
        'Login': 'Login',
      };
      final body = formData.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      postReq.add(utf8.encode(body));

      final postResp =
          await postReq.close().timeout(const Duration(seconds: 10));
      final respBody = await utf8.decodeStream(postResp);
      collectCookies(postResp);

      dev.log(
        'CSTP login response: status=${postResp.statusCode}, '
        'cookies=${allCookies.keys.join(",")}',
        name: 'PlatformVpnService',
      );

      // 检查 webvpn 会话 Cookie（非空值的 webvpn= 才是有效 session）
      final webvpnSession = allCookies['webvpn'];
      if (webvpnSession != null && !webvpnSession.endsWith('=')) {
        return allCookies.values.join('; ');
      }

      // 登录失败检查
      if (respBody.contains('a0=114') || respBody.contains('Login denied')) {
        dev.log('CSTP auth: Login denied (a0=114)',
            name: 'PlatformVpnService');
      }

      return null;
    } catch (e) {
      dev.log('CSTP auth failed: $e', name: 'PlatformVpnService');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _resolveWireGuardServer(String host, LiNode node) async {
    final resolved =
        await _wireGuardHostResolver(host, node.doh, node.dnsServers);
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved.trim();
    }
    return host;
  }

  static Future<String?> _defaultWireGuardHostResolver(
    String host,
    List<String> dohUrls,
    List<String> dnsServers,
  ) async {
    if (_isIpLiteral(host)) return host;

    final dohResolved = await _resolveHostViaDoh(host, dohUrls);
    if (dohResolved != null) return dohResolved;

    final apiDnsResolved = await _resolveHostViaApiDns(host, dnsServers);
    if (apiDnsResolved != null) return apiDnsResolved;

    try {
      final systemResults = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(seconds: 3));
      if (systemResults.isNotEmpty) {
        return systemResults.first.address;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static bool _isIpLiteral(String host) {
    return InternetAddress.tryParse(host) != null;
  }

  static Future<String?> _resolveHostViaDoh(
    String host,
    List<String> dohUrls,
  ) async {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      for (final rawUrl in dohUrls) {
        final uri = Uri.tryParse(rawUrl);
        if (uri == null || uri.host.isEmpty) continue;
        try {
          final query = Map<String, String>.from(uri.queryParameters);
          query['name'] = host;
          query['type'] = 'A';
          final requestUri = uri.replace(queryParameters: query);

          final req = await httpClient
              .getUrl(requestUri)
              .timeout(const Duration(seconds: 4));
          req.headers.set(HttpHeaders.acceptHeader,
              'application/dns-json, application/json');
          final resp = await req.close().timeout(const Duration(seconds: 4));
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            continue;
          }
          final bodyText = await utf8.decodeStream(resp);
          final body = jsonDecode(bodyText);
          if (body is! Map<String, dynamic>) {
            continue;
          }
          final answers = body['Answer'];
          if (answers is! List) {
            continue;
          }
          for (final answer in answers) {
            if (answer is! Map<String, dynamic>) continue;
            final type = (answer['type'] as num?)?.toInt();
            final data = answer['data']?.toString() ?? '';
            if (type == 1 && InternetAddress.tryParse(data) != null) {
              return data;
            }
          }
        } catch (_) {
          // 尝试下一个 DoH 地址
        }
      }
      return null;
    } finally {
      httpClient.close(force: true);
    }
  }

  static Future<String?> _resolveHostViaApiDns(
    String host,
    List<String> dnsServers,
  ) async {
    for (final dnsServer in dnsServers) {
      final resolved = await _queryARecordFromDnsServer(host, dnsServer);
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }

  static Future<String?> _queryARecordFromDnsServer(
    String host,
    String dnsServer,
  ) async {
    final dnsIp = InternetAddress.tryParse(dnsServer);
    if (dnsIp == null) return null;

    final random = Random();
    final transactionId = random.nextInt(0x10000);
    final query = _buildDnsQuery(host, transactionId);

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.send(query, dnsIp, 53);

      final completer = Completer<String?>();
      late final StreamSubscription<RawSocketEvent> subscription;
      subscription = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram == null) return;
          final resolved = _parseDnsAResponse(
            datagram.data,
            expectedTransactionId: transactionId,
          );
          if (!completer.isCompleted) {
            completer.complete(resolved);
          }
        }
      });

      final result = await completer.future
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      await subscription.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      socket.close();
    }
  }

  static List<int> _buildDnsQuery(String host, int transactionId) {
    final bytes = BytesBuilder();
    bytes.add([
      (transactionId >> 8) & 0xFF,
      transactionId & 0xFF,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);

    final labels = host.split('.');
    for (final label in labels) {
      final encoded = utf8.encode(label);
      bytes.add([encoded.length]);
      bytes.add(encoded);
    }
    bytes.add([0x00]);
    bytes.add([0x00, 0x01]);
    bytes.add([0x00, 0x01]);
    return bytes.toBytes();
  }

  static String? _parseDnsAResponse(
    List<int> payload, {
    required int expectedTransactionId,
  }) {
    if (payload.length < 12) return null;
    final responseId = (payload[0] << 8) | payload[1];
    if (responseId != expectedTransactionId) return null;

    final questionCount = (payload[4] << 8) | payload[5];
    final answerCount = (payload[6] << 8) | payload[7];
    int offset = 12;

    for (int questionIndex = 0;
        questionIndex < questionCount;
        questionIndex++) {
      offset = _skipDnsName(payload, offset);
      if (offset < 0 || offset + 4 > payload.length) return null;
      offset += 4;
    }

    for (int answerIndex = 0; answerIndex < answerCount; answerIndex++) {
      offset = _skipDnsName(payload, offset);
      if (offset < 0 || offset + 10 > payload.length) return null;

      final type = (payload[offset] << 8) | payload[offset + 1];
      final dnsClass = (payload[offset + 2] << 8) | payload[offset + 3];
      final rdLength = (payload[offset + 8] << 8) | payload[offset + 9];
      offset += 10;

      if (offset + rdLength > payload.length) return null;
      if (type == 1 && dnsClass == 1 && rdLength == 4) {
        return '${payload[offset]}.${payload[offset + 1]}.${payload[offset + 2]}.${payload[offset + 3]}';
      }
      offset += rdLength;
    }
    return null;
  }

  static int _skipDnsName(List<int> payload, int startOffset) {
    int offset = startOffset;
    while (offset < payload.length) {
      final length = payload[offset];
      if (length == 0) {
        return offset + 1;
      }
      if ((length & 0xC0) == 0xC0) {
        if (offset + 1 >= payload.length) return -1;
        return offset + 2;
      }
      offset += 1 + length;
    }
    return -1;
  }

  ({String server, int port, String path}) _normalizeEndpoint(
      String rawUrl, int fallbackPort) {
    final uri = Uri.tryParse(rawUrl);
    if (uri != null && uri.host.isNotEmpty) {
      final normalizedPort = uri.hasPort ? uri.port : fallbackPort;
      return (server: uri.host, port: normalizedPort, path: uri.path);
    }
    return (server: rawUrl, port: fallbackPort, path: '');
  }

  @override
  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
  }

  @override
  Future<String?> getLastError() async {
    final raw = await _channel.invokeMethod('getLastError');
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  /// 连接成功后调用：写入网络配置（DNS + 路由表）
  Future<void> applyNetworkConfig(NetworkConfig config) async {
    await _channel.invokeMethod('applyNetworkConfig', <String, dynamic>{
      'dnsServers': config.dnsServers,
      'routes': config.routes,
      'mtu': config.mtu ?? 1380,
    });
  }

  /// 仅写入指定路由（用于两阶段路由策略第二阶段）
  Future<void> applyDefaultRoute() async {
    await _channel.invokeMethod('applyDefaultRoute');
  }

  /// 获取当前隧道统计（字节数等）
  Future<Map<String, dynamic>> getTunnelStats() async {
    final result = await _channel.invokeMethod('getTunnelStats');
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return <String, dynamic>{};
  }

  /// 生成 WireGuard 密钥对，返回 {privateKey, publicKey}（Base64）。
  /// 私钥自动缓存，后续 connect 调用会携带。
  Future<Map<String, String>> generateKeyPair() async {
    final result = await _channel.invokeMethod('generateKeyPair');
    final map = Map<String, String>.from(result as Map);
    _clientPrivateKey = map['privateKey'];
    if (_clientPrivateKey != null && _clientPrivateKey!.isNotEmpty) {
      await _secureStorage.write(
        key: _privateKeyStorageKey,
        value: _clientPrivateKey!,
      );
    }
    return map;
  }

  Future<void> _restorePrivateKey() async {
    try {
      final key = await _secureStorage.read(key: _privateKeyStorageKey);
      if (key != null && key.isNotEmpty) {
        _clientPrivateKey = key;
      }
    } catch (e) {
      dev.log('restorePrivateKey failed: $e', name: 'PlatformVpnService');
    }
  }

  /// 手动设置 WireGuard 客户端私钥（如从安全存储恢复）
  void setClientPrivateKey(String privateKey) {
    _clientPrivateKey = privateKey;
  }

  /// 对 VPN 网关发送 ping 探测，确认隧道连通性
  Future<bool> pingGateway(String gatewayIp) async {
    final result = await _channel.invokeMethod('pingGateway', <String, dynamic>{
      'gatewayIp': gatewayIp,
    });
    return result == true;
  }

  @override
  Future<bool> isElevated() async {
    final result = await _channel.invokeMethod('isElevated');
    return result == true;
  }

  @override
  Future<bool> restartElevated() async {
    final result = await _channel.invokeMethod('restartElevated');
    return result == true;
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _statusController.close();
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_statusPollingInFlight) return;
      _statusPollingInFlight = true;
      try {
        final raw = await _channel
            .invokeMethod<String>('getStatus')
            .timeout(const Duration(seconds: 2), onTimeout: () => 'connecting');
        final status = _parseStatus((raw ?? 'disconnected').toString());
        if (_lastPolledStatus != status) {
          _lastPolledStatus = status;
          _statusController.add(status);
        }
      } catch (_) {
        if (_lastPolledStatus != VpnStatus.error) {
          _lastPolledStatus = VpnStatus.error;
          _statusController.add(VpnStatus.error);
        }
      } finally {
        _statusPollingInFlight = false;
      }
    });
  }

  static VpnStatus _parseStatus(String raw) {
    return switch (raw) {
      'connected' => VpnStatus.connected,
      'connecting' => VpnStatus.connecting,
      'disconnected' => VpnStatus.disconnected,
      'disconnecting' => VpnStatus.disconnecting,
      _ => VpnStatus.error,
    };
  }
}

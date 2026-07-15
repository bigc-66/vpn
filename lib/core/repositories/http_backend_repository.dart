import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/auth_models.dart';
import 'backend_repository.dart';

const _uuid = Uuid();

/// 真实后端实现，字段名已根据 2026-03-10 接口文档确认。
class HttpBackendRepository implements BackendRepository {
  HttpBackendRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  void bindApiBase(String liUrl) {
    _apiClient.setBaseUrl(liUrl);
  }

  // 仅验证服务地址（两步添加第一步）
  // 直接向用户输入的地址发请求，验证其可达性和有效性

  @override
  Future<LiInfo?> fetchLiInfo({required String liUrl}) async {
    try {
      // 规范化地址：补 https 前缀
      String normalizedUrl = liUrl.trim();
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }
      // 去掉末尾斜杠
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      final uri = Uri.parse('$normalizedUrl/api/v1/li/info');
      final response = await http.Client()
          .get(uri, headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = response.body.trim();
      if (body.isEmpty) return null;
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final raw = decoded;

      // 服务端可能用 {code, msg, data} 包裹
      if (raw.containsKey('code')) {
        final code = (raw['code'] as num?)?.toInt();
        if (code != null && code != 200) return null;
        final data = raw['data'];
        if (data is Map<String, dynamic>) {
          return _parseLiInfo(liUrl, data);
        }
        return null;
      }

      // 验证返回数据的有效性（必须有 license_key 或 nodes）
      final licenseKey = raw['license_key']?.toString() ?? '';
      final nodes = (raw['nodes'] as List?) ?? [];
      if (licenseKey.isEmpty && nodes.isEmpty) return null;

      return _parseLiInfo(liUrl, raw);
    } catch (_) {
      return null;
    }
  }

  //  获取 Li 信息 + 用户认证

  @override
  Future<LoginSession> loginAndCreateSession({
    required String liUrl,
    required String username,
    required String password,
  }) async {
    // Step 1: 拉取 Li 信息（直接响应，无 code/data 包裹）
    final liRes = await _apiClient.getJson(
      '/api/v1/li/info',
      headers: <String, String>{'X-Li-Domain': liUrl},
    );
    final liInfo = _parseLiInfo(liUrl, liRes);

    // Step 2: 用户认证（响应包裹在 {code, msg, data}）
    final rawLogin = await _apiClient.postJson(
      '/api/v1/auth/login',
      body: <String, dynamic>{
        'username': username,
        'password': password,
        'client_nonce': _uuid.v4(),
      },
    );
    final loginData = _unwrapData(rawLogin, '用户认证');
    final accessToken =
      (loginData['access_token'] ?? loginData['token'] ?? '').toString();
    final userId =
      (loginData['user_id'] ?? loginData['username'] ?? username).toString();
    final expireRaw = loginData['expire'];
    final expireAt = expireRaw != null
        ? DateTime.fromMillisecondsSinceEpoch((expireRaw as num).toInt() * 1000)
        : null;
    final sessionId =
      (loginData['session_id']?.toString().isNotEmpty == true)
        ? loginData['session_id'].toString()
        : _uuid.v4();

    // Step 3: 用户配置（可选，服务端出错时使用默认值不阻断登录）
    UserConfig userConfig;
    try {
      final rawUc = await _apiClient.getJson(
        '/api/v1/user/config',
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      );
      final ucData = _unwrapData(rawUc, '用户配置');
      userConfig = _parseUserConfig(userId, ucData);
    } catch (_) {
      userConfig = UserConfig(
        userId: userId,
        subscription: '',
        expiryTime: DateTime.now().add(const Duration(days: 365)),
        lastLoginAt: DateTime.now(),
      );
    }

    return LoginSession(
      accessToken: accessToken,
      userId: userId,
      sessionId: sessionId,
      liInfo: liInfo,
      userConfig: userConfig,
      expireAt: expireAt,
    );
  }

  //  刷新 Li

  @override
  Future<LiInfo> refreshLiInfo({
    required String liUrl,
    required String accessToken,
  }) async {
    final liRes = await _apiClient.getJson(
      '/api/v1/li/info',
      headers: <String, String>{
        'X-Li-Domain': liUrl,
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _parseLiInfo(liUrl, liRes);
  }

  //  网络配置

  @override
  Future<NetworkConfig> fetchNetworkConfig({
    required String accessToken,
    required String sessionId,
    required String nodeUrl,
  }) async {
    final raw = await _apiClient.getJson(
      '/api/v1/vpn/network-config',
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    final res = raw.containsKey('code') ? _unwrapData(raw, '网络配置') : raw;
    final rawNodes = (res['nodes'] as List?) ?? const [];
    final nodes =
        rawNodes.whereType<Map<String, dynamic>>().map(_parseNode).toList();
    final routesRaw = res['routes'];
    // routes 可能是 CIDR 列表，也可能是路由表下载 URL
    String? routeTableUrl;
    List<String> routes;
    if (routesRaw is List) {
      routes = _toStringList(routesRaw);
    } else if (routesRaw is String && routesRaw.startsWith('http')) {
      routeTableUrl = routesRaw;
      routes = const <String>[];
    } else {
      routes = const <String>[];
    }

    return NetworkConfig(
      dnsServers: _toStringList(res['dns_servers']),
      routes: routes,
      nodes: nodes,
      mtu: (res['mtu'] as num?)?.toInt(),
      routeTableUrl: routeTableUrl,
    );
  }

  //  心跳

  @override
  Future<HeartbeatResponse> sendHeartbeat({
    required String accessToken,
    required String sessionId,
    required String deviceInfo,
  }) async {
    final raw = await _apiClient.postJson(
      '/api/v1/vpn/heartbeat',
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        'session_id': sessionId,
        'device_info': deviceInfo,
      },
    );
    final res = raw.containsKey('code') ? _unwrapData(raw, '心跳') : raw;

    // 调试：记录心跳原始响应
    dev.log('heartbeat raw keys: ${raw.keys}', name: 'Heartbeat');
    dev.log('heartbeat res keys: ${res.keys}, res=$res', name: 'Heartbeat');

    // 兼容两种服务端格式：
    // 1) action: "force_disconnect"（标准字段）
    // 2) force_disconnect: 1 / force_disconnect: true（直接字段）
    // 3) force_disconnect: "1" / "true"（字符串格式）
    final actionStr = res['action']?.toString() ?? '';
    final forceDisconnectRaw = res['force_disconnect'];
    dev.log('heartbeat action=$actionStr force_disconnect=$forceDisconnectRaw type=${forceDisconnectRaw.runtimeType}',
        name: 'Heartbeat');
    final isForceDisconnect = actionStr == 'force_disconnect' ||
        forceDisconnectRaw == true ||
        forceDisconnectRaw == 1 ||
        forceDisconnectRaw?.toString() == '1' ||
        forceDisconnectRaw?.toString() == 'true';

    final type = isForceDisconnect
        ? HeartbeatReturnType.forceDisconnect
        : switch (actionStr) {
            'notify' => HeartbeatReturnType.notification,
            'li_update' => HeartbeatReturnType.liUpdate,
            _ => HeartbeatReturnType.confirm,
          };

    PushMessage? msg;
    if (type == HeartbeatReturnType.notification &&
        res['notification'] != null) {
      final n = res['notification'] as Map<String, dynamic>;
      final hasUrl = n['url'] != null && n['url'].toString().isNotEmpty;
      msg = PushMessage(
        id: n['id']?.toString() ?? _uuid.v4(),
        type: hasUrl ? PushMessageType.textWithUrl : PushMessageType.textOnly,
        text: n['text']?.toString() ?? '',
        url: hasUrl ? n['url'].toString() : null,
        carryCredentials: n['carry_credentials'] == true,
        receivedAt: DateTime.now(),
      );
    }
    return HeartbeatResponse(type: type, message: msg);
  }

  //  路由表下载

  @override
  Future<List<String>> downloadRouteTable({
    required String url,
    required String accessToken,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);

    // 使用流式 HTTP 获取真实下载进度
    final uri =
        Uri.parse(url.startsWith('http') ? url : '${_apiClient.baseUrl}$url');
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['Accept'] = 'application/json';

    final streamedResponse = await _apiClient
        .sendStreaming(request)
        .timeout(const Duration(seconds: 30));
    final totalBytes = streamedResponse.contentLength ?? 0;
    final chunks = <int>[];
    var receivedBytes = 0;

    await for (final chunk in streamedResponse.stream) {
      chunks.addAll(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call((receivedBytes / totalBytes).clamp(0.0, 1.0));
      } else {
        onProgress?.call(0.5);
      }
    }

    onProgress?.call(1.0);

    final body = _decodeResponseBody(chunks);
    return _parseRouteList(body);
  }

  //  合规回传

  @override
  Future<bool> reportCompliance({
    required String licenseKey,
    required String userId,
    required String deviceInfo,
    required String localIp,
  }) async {
    final raw = await _apiClient.postJson(
      '/api/v1/compliance/report',
      body: <String, dynamic>{
        'license_key': licenseKey,
        'user_id': userId,
        'device_info': deviceInfo,
        'local_ip': localIp,
      },
    );
    final res = raw.containsKey('code') ? _unwrapData(raw, '合规回传') : raw;
    return res['passed'] == true;
  }

  //  版本检查

  @override
  Future<VersionInfo?> checkVersion({required String currentVersion}) async {
    final appsType = _detectPlatformType();
    final raw = await _apiClient.getJson(
      '/api/v1/client/version/check?version=$currentVersion&apps_type=$appsType',
    );
    // 服务端可能只支持部分 apps_type（如 ios/android），桌面端返回 null 表示无更新
    final code = (raw['code'] as num?)?.toInt();
    if (code != null && code == 400) return null;
    final res = raw.containsKey('code') ? _unwrapData(raw, '版本检查') : raw;
    final latest = res['latest_version']?.toString() ?? '';
    if (latest.isEmpty || latest == currentVersion) return null;
    final updateTimeRaw = res['update_time'];
    final rawRequired = res['is_required'];
    final isRequired = rawRequired == true ||
        rawRequired?.toString() == '1' ||
        rawRequired?.toString().toLowerCase() == 'true';
    return VersionInfo(
      version: latest,
      downloadUrl: res['download_url']?.toString() ?? '',
      isRequired: isRequired,
      description: res['description']?.toString(),
      updateTime: updateTimeRaw != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (updateTimeRaw as num).toInt() * 1000)
          : null,
    );
  }

  static String _detectPlatformType() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  //  私有工具

  LiInfo _parseLiInfo(String liUrl, Map<String, dynamic> raw) {
    final heartbeatRaw = raw['heartbeat_interval'];
    final heartbeat = heartbeatRaw is num
        ? heartbeatRaw.toInt()
        : int.tryParse(heartbeatRaw?.toString() ?? '') ?? 30;

    final rawNodes = (raw['nodes'] as List?) ?? [];
    final nodes =
        rawNodes.whereType<Map<String, dynamic>>().map(_parseNode).toList();

    return LiInfo(
      primaryDomain: liUrl,
      serverName:
          (raw['service_name'] ?? raw['server_name'] ?? liUrl).toString(),
      licenseKey: raw['license_key']?.toString() ?? '',
      nodes: nodes,
      heartbeatIntervalSeconds: heartbeat.clamp(30, 3600),
      webWhitelist: _toStringList(raw['web_whitelist']),
      backupDomains: _toStringList(raw['backup_domains']),
      routeTableUrl: raw['route_table_url']?.toString(),
      customServiceUrl: raw['custom_service_url']?.toString(),
      fLinkUrl: raw['f_link_url']?.toString(),
      serviceUrl: raw['service_url']?.toString(),
      aboutDescription: raw['about_description']?.toString(),
      aboutTeam: raw['about_team']?.toString(),
      aboutEmail: raw['about_email']?.toString(),
      aboutWebsite: raw['about_website']?.toString(),
    );
  }

  UserConfig _parseUserConfig(
      String fallbackUserId, Map<String, dynamic> data) {
    final expiryRaw = data['expiry_time']?.toString() ?? '';
    final lastLoginRaw = data['last_login_at']?.toString() ?? '';
    final wgRaw = data['wireguard'];
    final wireguard = wgRaw is Map<String, dynamic>
        ? WireGuardUserConfig(
            privateKey: wgRaw['privatekey']?.toString() ?? '',
            ipAddress: wgRaw['ipaddress']?.toString() ?? '',
          )
        : null;
    return UserConfig(
      userId: data['username']?.toString() ?? fallbackUserId,
      subscription: data['subscription']?.toString() ?? '',
      expiryTime: DateTime.tryParse(expiryRaw) ??
          DateTime.now().add(const Duration(days: 365)),
      lastLoginAt: DateTime.tryParse(lastLoginRaw) ?? DateTime.now(),
      forcedNodeUrl: data['forced_node_url']?.toString(),
      forcedRouteTableUrl: data['forced_route_table_url']?.toString(),
      splitMode: data['split_mode']?.toString(),
      speedLimit: data['speed_limit']?.toString(),
      wireguard: (wireguard == null ||
              (wireguard.privateKey.isEmpty && wireguard.ipAddress.isEmpty))
          ? null
          : wireguard,
    );
  }

  /// 解包 {code, msg, data} 包裹结构，code != 200 时抛出 ApiException
  Map<String, dynamic> _unwrapData(Map<String, dynamic> raw, String context) {
    final code = (raw['code'] as num?)?.toInt();
    if (code != null && code != 200) {
      throw ApiException('$context 失败: ${raw['msg'] ?? code}',
          statusCode: code);
    }
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  //  日志上报

  @override
  Future<void> uploadLog({
    required String accessToken,
    required String username,
    required String logContent,
    String liUrl = '',
  }) async {
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
    };
    if (liUrl.isNotEmpty) {
      headers['X-Li-Domain'] = liUrl;
    }
    try {
      await _apiClient.postJson(
        '/api/v1/client/log/upload',
        headers: headers,
        body: <String, dynamic>{
          'username': username,
          'log': logContent,
        },
      );
    } on ApiException catch (e) {
      // 服务端尚未实现此端点时(404)，视为提交成功（日志已采集）
      if (e.statusCode == 404) return;
      rethrow;
    }
  }

  static List<String> _toStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) return [raw];
    return [];
  }

  static String _decodeResponseBody(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  List<String> _parseRouteList(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return _extractCidrs(body);
    }

    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }

    if (decoded is Map<String, dynamic>) {
      final data =
          decoded.containsKey('code') ? _unwrapData(decoded, '路由表') : decoded;
      return _coerceRouteField(data['routes']);
    }

    if (decoded is String) {
      return _coerceRouteField(decoded);
    }

    return [];
  }

  List<String> _coerceRouteField(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String) {
      if (raw.trim().isEmpty) return [];
      try {
        final inner = jsonDecode(raw);
        if (inner is List) {
          return inner.map((e) => e.toString()).toList();
        }
        if (inner is Map<String, dynamic>) {
          final nestedRoutes = inner['routes'];
          if (nestedRoutes is List) {
            return nestedRoutes.map((e) => e.toString()).toList();
          }
        }
      } catch (_) {
        return _extractCidrs(raw);
      }
      return _extractCidrs(raw);
    }
    return [];
  }

  static List<String> _extractCidrs(String text) {
    final matches = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}\b')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (matches.isEmpty) return [];
    return matches.toSet().toList();
  }

  static LiNode _parseNode(Map<String, dynamic> raw) {
    dev.log('_parseNode raw: $raw', name: 'HttpBackendRepository');
    // 写入诊断文件
    try {
      final exePath = Platform.resolvedExecutable;
      final dir = exePath.substring(0, exePath.lastIndexOf(Platform.pathSeparator));
      final logFile = File('$dir${Platform.pathSeparator}dart_debug.log');
      logFile.writeAsStringSync(
        '[${DateTime.now()}] _parseNode raw: $raw\n',
        mode: FileMode.append,
      );
    } catch (_) {}
    final protoValue = raw['protocol']?.toString().toLowerCase();
    final proto = switch (protoValue) {
      'wireguard' => VpnProtocol.wireguard,
      'ssl' => VpnProtocol.ssl,
      _ => VpnProtocol.auto,
    };

    final userInfo =
        raw['userinfo'] is Map<String, dynamic> ? raw['userinfo'] as Map<String, dynamic> : null;
    final wireguardList = userInfo?['wireguard'];
    final firstWg = (wireguardList is List && wireguardList.isNotEmpty &&
            wireguardList.first is Map<String, dynamic>)
        ? wireguardList.first as Map<String, dynamic>
        : null;

    final portRaw = raw['port'];
    final parsedPort = portRaw is num
        ? portRaw.toInt()
        : int.tryParse(portRaw?.toString() ?? '');

    return LiNode(
      id: (raw['id'] as num?)?.toInt() ?? 0,
      name: raw['name']?.toString() ?? '',
      url: raw['url']?.toString() ?? '',
      protocol: proto,
      port: parsedPort ?? 443,
      publicKey: (raw['public_key'] ?? raw['server_public_key'] ?? '').toString(),
      dnsServers: _toStringList(raw['dns_servers'] ?? raw['dns']),
      doh: _toStringList(raw['doh']),
      clientPrivateKey: (firstWg?['privatekey'] ?? raw['client_private_key'] ?? '').toString(),
      clientIpAddress: (firstWg?['ipaddress'] ?? raw['client_ip_address'] ?? '').toString(),
    );
  }
}

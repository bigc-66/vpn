import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_exception.dart';
import '../i18n/app_strings.dart';
import '../models/auth_models.dart';
import '../models/vpn_status.dart';
import '../repositories/backend_repository.dart';
import '../services/vpn_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required VpnService vpnService,
    required BackendRepository backendRepository,
  })  : _vpnService = vpnService,
        _backendRepository = backendRepository {
    _statusSub = _vpnService.statusStream.listen((status) {
      vpnStatus = status;
      if (status == VpnStatus.connecting || status == VpnStatus.disconnecting) {
        _armConnectWatchdog();
      } else {
        _cancelConnectWatchdog();
      }
      if (status == VpnStatus.connected) {
        _onConnected();
      }
      if (status == VpnStatus.disconnected) {
        _onDisconnected();
      }
      notifyListeners();
    });
    // 后台预加载黑名单，避免 connect() 中阻塞
    _loadBlocklistIfNeeded();
    _loadServices();
    _loadToggles();
  }

  final VpnService _vpnService;
  final BackendRepository _backendRepository;
  StreamSubscription<VpnStatus>? _statusSub;
  Timer? _heartbeatTimer;
  Timer? _connectWatchdogTimer;
  int _heartbeatFailCount = 0;
  static const int _heartbeatMaxFails = 3;
  static const Duration _connectWatchdogTimeout = Duration(seconds: 35);
  bool _reconnecting = false;

  /// 业务层用的文案（无 BuildContext，默认中文）。
  /// 设置 locale 后可切换。
  AppLocale _locale = AppLocale.zh;
  AppStrings get _s => AppStrings.forLocale(_locale);

  void setLocale(AppLocale locale) {
    _locale = locale;
  }

  // --- 登录态 ---
  String liUrl = '';
  String username = '';
  String token = '';
  String sessionId = '';
  String _passwordInMemory = '';
  LiInfo? liInfo;
  UserConfig? userConfig;

  // --- 连接态 ---
  LiNode? selectedNode;
  VpnProtocol selectedProtocol = VpnProtocol.auto;
  NetworkConfig? networkConfig;
  double routeDownloadProgress = 0.0;
  VpnStatus vpnStatus = VpnStatus.disconnected;

  // --- 推送消息 ---
  final List<PushMessage> messages = [];

  // --- 分流路由 ---
  final List<SplitRoute> splitRoutes = [];

  String? lastError;
  bool isBusy = false;

  /// 跳过 connect() 中的网络可用性检查（测试时设为 true）
  @visibleForTesting
  bool skipNetworkCheck = false;

  // --- 日志上传 ---
  bool isLogUploading = false;
  String? logUploadResult; // 'success' | 'fail' | null

  // --- 多服务管理 ---
  final List<ServiceEntry> services = [];
  static const _servicesKey = 'saved_services';

  // --- 分流全局开关 ---
  bool splitRoutingEnabled = true;
  static const _splitToggleKey = 'split_routing_enabled';

  // --- 外部控制开关 ---
  bool externalControlEnabled = false;
  static const _externalControlKey = 'external_control_enabled';

  // --- 合规上报去重 ---
  bool _complianceReported = false;

  // --- 非法密钥黑名单 ---
  final Set<String> _blockedLicenseKeys = {};
  bool _blocklistLoaded = false;
  static const _secureStorage = FlutterSecureStorage();
  static const _blocklistKey = 'blocked_license_keys';

  bool get loggedIn => token.isNotEmpty;

  List<LiNode> get availableNodes {
    final postLoginNodes = networkConfig?.nodes ?? const <LiNode>[];
    if (postLoginNodes.isNotEmpty) return postLoginNodes;
    return liInfo?.nodes ?? const <LiNode>[];
  }

  // URL Scheme 预填 Li URL（无登录凭证时）
  String pendingLiUrl = '';
  void setPendingLiUrl(String url) {
    pendingLiUrl = url.trim();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // 验证服务地址（两步添加的第一步）
  // ─────────────────────────────────────────────────────────────────

  /// 仅验证服务地址可达性，成功返回 null，失败返回错误信息。
  Future<String?> resolveServiceAddress(String address) async {
    if (address.trim().isEmpty) return _s.errFieldEmpty;

    // 先检查网络可用性
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 5));
      if (result.isEmpty || result.first.rawAddress.isEmpty) {
        return _s.errNetworkUnavailable;
      }
    } on SocketException {
      return _s.errNetworkUnavailable;
    } on TimeoutException {
      return _s.errNetworkUnavailable;
    } catch (_) {
      // 查询失败，视为网络不可用
      return _s.errNetworkUnavailable;
    }

    // 网络可用，再验证服务地址
    try {
      final info = await _backendRepository.fetchLiInfo(liUrl: address.trim());
      if (info == null) return _s.errServiceNotFound;
      // 有效服务必须有 licenseKey 或至少一个节点
      if (info.licenseKey.isEmpty && info.nodes.isEmpty) {
        return _s.errServiceNotFound;
      }
      return null; // 成功
    } on ApiException catch (e) {
      if (e.message.contains('disabled') || e.message.contains('禁用')) {
        return _s.errServiceDisabled;
      }
      return _s.errServiceNotFound;
    } catch (e) {
      return _s.errServiceNotFound;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 登录
  // ─────────────────────────────────────────────────────────────────

  Future<void> login({
    required String liUrlInput,
    required String usernameInput,
    required String password,
  }) async {
    if (isBusy) return;
    isBusy = true;
    lastError = null;
    notifyListeners();
    try {
      if (liUrlInput.trim().isEmpty ||
          usernameInput.trim().isEmpty ||
          password.isEmpty) {
        lastError = _s.errFieldEmpty;
        return;
      }

      liUrl = liUrlInput.trim();
      username = usernameInput.trim();
      _passwordInMemory = password;

      final session = await _backendRepository.loginAndCreateSession(
        liUrl: liUrl,
        username: username,
        password: password,
      );
      _applySession(session);
      await _loadPostLoginNetworkConfig();
      await saveCurrentAsService();
    } on ApiException catch (e) {
      lastError = '${_s.errLoginFailed}: ${e.message}';
    } catch (e) {
      lastError = '${_s.errLoginFailed}: $e';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void logout() {
    disconnect();
    liUrl = '';
    username = '';
    token = '';
    sessionId = '';
    _passwordInMemory = '';
    liInfo = null;
    userConfig = null;
    selectedNode = null;
    selectedProtocol = VpnProtocol.auto;
    networkConfig = null;
    routeDownloadProgress = 0.0;
    _complianceReported = false;
    messages.clear();
    splitRoutes.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // 连接流程: 检查禁用 -> 检查网络 -> 验证节点 -> 下载路由表 -> VPN 建立
  // ─────────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (isBusy) return;

    final node = selectedNode ??
        (availableNodes.isNotEmpty ? availableNodes.first : null);
    if (node == null) {
      lastError = _s.errNoNode;
      notifyListeners();
      return;
    }

    // 检测该接入服务是否已经被禁用（黑名单）
    final licenseKey = liInfo?.licenseKey ?? '';
    if (licenseKey.isNotEmpty && _blockedLicenseKeys.contains(licenseKey)) {
      lastError = _s.errServiceDisabled;
      notifyListeners();
      return;
    }

    // 节点地址为空时拒绝连接
    if (node.url.trim().isEmpty) {
      lastError = '${_s.errConnectFailed}: 节点地址为空';
      notifyListeners();
      return;
    }

    // WireGuard 需要有效的客户端配置
    final protocol = _resolveProtocol(node);
    if (protocol == VpnProtocol.wireguard) {
      final wg = userConfig?.wireguard;
      if (wg == null || wg.privateKey.isEmpty || wg.ipAddress.isEmpty) {
        lastError = '${_s.errConnectFailed}: WireGuard 客户端配置缺失（私钥或地址为空）';
        notifyListeners();
        return;
      }
    }

    if (Platform.isWindows) {
      try {
        final elevated = await _vpnService.isElevated();
        if (!elevated) {
          lastError =
              '${_s.errConnectFailed}: 请以管理员身份运行客户端（右键程序图标→以管理员身份运行）';
          notifyListeners();
          return;
        }
      } catch (e) {
        lastError = '${_s.errConnectFailed}: 权限检查失败: $e';
        notifyListeners();
        return;
      }
    }

    isBusy = true;
    lastError = null;
    vpnStatus = VpnStatus.connecting;
    routeDownloadProgress = 0.0;
    notifyListeners();

    // 本地网络连接检查（设置 isBusy 后执行，保持 loading 状态）
    if (!skipNetworkCheck) {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        isBusy = false;
        vpnStatus = VpnStatus.disconnected;
        lastError = _s.errNetworkUnavailable;
        notifyListeners();
        return;
      }
    } on SocketException {
      isBusy = false;
      vpnStatus = VpnStatus.disconnected;
      lastError = _s.errNetworkUnavailable;
      notifyListeners();
      return;
    } on TimeoutException {
      isBusy = false;
      vpnStatus = VpnStatus.disconnected;
      lastError = _s.errNetworkUnavailable;
      notifyListeners();
      return;
    } catch (_) {
      // 无法确定网络状态，继续尝试连接
    }
    }

    try {
      // Step 1: 获取网络配置（容错：异常时使用最小配置）
      try {
        networkConfig = await _backendRepository.fetchNetworkConfig(
          accessToken: token,
          sessionId: sessionId,
          nodeUrl: node.url,
        );
      } catch (e) {
        dev.log('fetchNetworkConfig failed, fallback to minimal config: $e',
            name: 'AppController');
        networkConfig = NetworkConfig(
          dnsServers: node.dnsServers,
          routes: const [],
          nodes: availableNodes,
        );
      }

      // Step 2: 下载路由表（带进度）
      final routeUrl = userConfig?.forcedRouteTableUrl
          ?? liInfo?.routeTableUrl
          ?? networkConfig?.routeTableUrl;
      if (routeUrl != null && routeUrl.isNotEmpty) {
        try {
          final routeList = await _backendRepository.downloadRouteTable(
            url: routeUrl,
            accessToken: token,
            onProgress: (p) {
              routeDownloadProgress = p;
              notifyListeners();
            },
          );
          networkConfig = NetworkConfig(
            dnsServers: networkConfig!.dnsServers,
            routes: routeList,
            nodes: networkConfig!.nodes,
            mtu: networkConfig!.mtu,
          );
        } catch (e) {
          dev.log('downloadRouteTable failed, continue without routes: $e',
              name: 'AppController');
        }
      }

      // Step 3: 建立 VPN 隧道
      final connectNode = _buildConnectNode(node, protocol);

      // 原生状态异常时，最多等待一段时间后强制退场，避免 UI 长时间卡在“连接中”。
      _armConnectWatchdog();

      // 收集所有分流路由：服务端路由表 + 用户自定义分流规则中 mode=tunnel 的目标
      final allRoutes = <String>[
        ...?networkConfig?.routes,
        for (final r in splitRoutes)
          if (r.enabled && r.mode == 'tunnel') r.target,
      ];

      try {
        await _vpnService
            .connect(
              node: connectNode,
              protocol: protocol,
              username: username,
              password: _passwordInMemory,
              routes: allRoutes,
              splitRouting: splitRoutingEnabled,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException('VPN connect timeout'),
            );
      } on FormatException catch (e) {
        dev.log(
            'platform connect response decode failed, continue waiting status: $e',
            name: 'AppController');
      } on PlatformException catch (e) {
        final raw = '${e.code}: ${e.message ?? ''} ${e.details ?? ''}'.trim();
        if (raw.contains('Missing extension byte')) {
          dev.log('platform connect codec issue, continue waiting status: $raw',
              name: 'AppController');
        } else {
          rethrow;
        }
      }

      final finalStatus = await _waitForTerminalStatus();

      if (finalStatus == VpnStatus.error ||
          finalStatus == VpnStatus.disconnected) {
        final detail = await _vpnService.getLastError();
        lastError = detail == null || detail.isEmpty
            ? _s.errConnectFailed
            : '${_s.errConnectFailed}: $detail';
        await _resetStuckConnectingState();
      } else {
        selectedNode = connectNode;
        selectedProtocol = protocol;

        // 写入 DNS + 非默认路由（所有协议通用）
        if (networkConfig != null) {
          final effectiveConfig = _buildEffectiveNetworkConfig(
              protocol, connectNode, networkConfig!);
          dev.log(
            'applyNetworkConfig: protocol=$protocol '
            'dnsServers=${effectiveConfig.dnsServers} '
            'routes=${effectiveConfig.routes.length}条 '
            'mtu=${effectiveConfig.mtu} '
            'splitRoutingEnabled=$splitRoutingEnabled '
            'nodeDns=${connectNode.dnsServers} '
            'nodeDoh=${connectNode.doh}',
            name: 'AppController',
          );
          try {
            await _vpnService.applyNetworkConfig(effectiveConfig);
          } on FormatException catch (e) {
            dev.log('applyNetworkConfig response decode failed, continue: $e',
                name: 'AppController');
          } on PlatformException catch (e) {
            final raw =
                '${e.code}: ${e.message ?? ''} ${e.details ?? ''}'.trim();
            if (raw.contains('Missing extension byte')) {
              dev.log('applyNetworkConfig codec issue, continue: $raw',
                  name: 'AppController');
            } else {
              rethrow;
            }
          }
        }

        // 全局模式（分流关闭）：添加默认路由，所有流量走 VPN
        if (!splitRoutingEnabled) {
          try {
            await _vpnService.applyDefaultRoute();
            dev.log('applyDefaultRoute: default routes added',
                name: 'AppController');
          } on PlatformException catch (e) {
            dev.log('applyDefaultRoute failed: $e', name: 'AppController');
          }
        }
      }
    } on ApiException catch (e) {
      lastError = '${_s.errConnectFailed}: ${e.message}';
      await _resetStuckConnectingState();
    } on TimeoutException {
      lastError = '${_s.errConnectFailed}: 连接超时（原生插件未及时返回）';
      await _resetStuckConnectingState();
    } on PlatformException catch (e) {
      final raw = '${e.code}: ${e.message ?? ''} ${e.details ?? ''}'.trim();
      if (raw.contains('Missing extension byte')) {
        lastError = '${_s.errConnectFailed}: 原生返回编码异常（请检查节点地址/原生插件编码）';
      } else {
        lastError = '${_s.errConnectFailed}: $raw';
      }
      await _resetStuckConnectingState();
    } on FormatException catch (e) {
      lastError =
          '${_s.errConnectFailed}: 接口返回编码异常（请检查服务端/插件返回编码）: ${e.message}';
      await _resetStuckConnectingState();
    } catch (e) {
      lastError = '${_s.errConnectFailed}: $e';
      await _resetStuckConnectingState();
    } finally {
      _cancelConnectWatchdog();
      isBusy = false;
      notifyListeners();
    }
  }

  Future<VpnStatus> _waitForTerminalStatus() async {
    const deadline = Duration(seconds: 30);
    const interval = Duration(milliseconds: 200);
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < deadline) {
      final status = await _vpnService.getStatus().timeout(
            const Duration(seconds: 2),
            onTimeout: () => VpnStatus.connecting,
          );
      if (status == VpnStatus.connected ||
          status == VpnStatus.error ||
          status == VpnStatus.disconnected) {
        return status;
      }
      await Future<void>.delayed(interval);
    }

    return VpnStatus.error;
  }

  void _armConnectWatchdog() {
    _connectWatchdogTimer?.cancel();
    _connectWatchdogTimer = Timer(_connectWatchdogTimeout, () async {
      if (!isBusy) {
        return;
      }
      lastError ??= '${_s.errConnectFailed}: 连接超时（状态回调未返回）';
      await _resetStuckConnectingState();
      if (vpnStatus == VpnStatus.connecting ||
          vpnStatus == VpnStatus.disconnecting ||
          vpnStatus == VpnStatus.disconnected) {
        vpnStatus = VpnStatus.error;
      }
      isBusy = false;
      notifyListeners();
    });
  }

  void _cancelConnectWatchdog() {
    _connectWatchdogTimer?.cancel();
    _connectWatchdogTimer = null;
  }

  Future<void> _resetStuckConnectingState() async {
    if (vpnStatus == VpnStatus.connecting ||
        vpnStatus == VpnStatus.disconnecting) {
      dev.log('_resetStuckConnectingState: status=$vpnStatus, forcing disconnect',
          name: 'AppController');
      try {
        await _vpnService.disconnect().timeout(
              const Duration(seconds: 3),
              onTimeout: () {},
            );
      } catch (_) {
        // ignore disconnect cleanup failures
      }
      if (vpnStatus == VpnStatus.connecting ||
          vpnStatus == VpnStatus.disconnecting) {
        vpnStatus = VpnStatus.error;
      }
    }
  }

  Future<void> disconnect() async {
    dev.log('disconnect() called', name: 'AppController');
    try {
      await _vpnService.disconnect().timeout(
            const Duration(seconds: 3),
            onTimeout: () {},
          );
    } catch (e) {
      dev.log('disconnect() error (ignored): $e', name: 'AppController');
    }
  }

  void selectNode(LiNode node) {
    selectedNode = node;
    notifyListeners();
  }

  void selectProtocol(VpnProtocol protocol) {
    selectedProtocol = protocol;
    notifyListeners();
  }

  /// 当前选中节点支持的协议列表（用于 UI 下拉）。
  /// 节点 protocol = auto → 返回 [ssl, wireguard]（用户自选）；
  /// 节点 protocol = ssl/wireguard → 仅返回该协议（强制）。
  List<VpnProtocol> get availableProtocolsForNode {
    final node = selectedNode ??
        (availableNodes.isNotEmpty ? availableNodes.first : null);
    if (node == null) return [];
    if (node.protocol == VpnProtocol.auto) {
      return [VpnProtocol.ssl, VpnProtocol.wireguard];
    }
    return [node.protocol];
  }

  // ─────────────────────────────────────────────────────────────────
  // 分流路由管理
  // ─────────────────────────────────────────────────────────────────

  String? addSplitRoute(String target, {String name = '', String mode = 'bypass'}) {
    if (!SplitRoute.isValidTarget(target)) {
      return _s.errSplitInvalid;
    }
    if (splitRoutes.any((r) => r.target == target)) {
      return _s.errSplitDuplicate;
    }
    splitRoutes.add(SplitRoute(name: name, target: target, mode: mode));
    notifyListeners();
    return null;
  }

  void removeSplitRoute(String target) {
    splitRoutes.removeWhere((r) => r.target == target);
    notifyListeners();
  }

  void toggleSplitRoute(String target) {
    final idx = splitRoutes.indexWhere((r) => r.target == target);
    if (idx >= 0) {
      splitRoutes[idx] =
          splitRoutes[idx].copyWith(enabled: !splitRoutes[idx].enabled);
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 版本检查
  // ─────────────────────────────────────────────────────────────────

  VersionInfo? latestVersion;
  bool versionChecked = false;

  Future<void> checkVersion(String currentVersion) async {
    if (versionChecked) return;
    versionChecked = true;
    try {
      latestVersion = await _backendRepository.checkVersion(
        currentVersion: currentVersion,
      );
      notifyListeners();
    } catch (e) {
      versionChecked = false;
      dev.log('checkVersion failed: $e', name: 'AppController');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 日志上传
  // ─────────────────────────────────────────────────────────────────

  /// 收集日志并上传到服务端，上传成功后内容自动清除。
  Future<void> uploadLog({String? targetLiUrl}) async {
    if (isLogUploading || token.isEmpty) return;
    isLogUploading = true;
    logUploadResult = null;
    notifyListeners();
    try {
      final logContent = _collectLogContent();
      await _backendRepository.uploadLog(
        accessToken: token,
        username: username,
        logContent: logContent,
        liUrl: targetLiUrl ?? liUrl,
      );
      logUploadResult = 'success';
    } catch (e) {
      dev.log('uploadLog failed: $e', name: 'AppController');
      logUploadResult = 'fail';
    } finally {
      isLogUploading = false;
      notifyListeners();
    }
  }

  String _collectLogContent() {
    final buf = StringBuffer();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    buf.writeln('=== Netsignory 日志 ===');
    buf.writeln('时间: $dateStr');
    buf.writeln('用户: $username');
    buf.writeln('服务器: $liUrl');
    buf.writeln('VPN 状态: ${vpnStatus.name}');
    if (selectedNode != null) {
      buf.writeln(
          '节点: ${selectedNode!.name} (${selectedNode!.url}:${selectedNode!.port})');
    }
    if (lastError != null) buf.writeln('最后错误: $lastError');
    buf.writeln('消息数: ${messages.length}');
    buf.writeln('分流规则数: ${splitRoutes.length}');
    buf.writeln('设备信息: ${_deviceInfo()}');
    return buf.toString();
  }

  /// 供外部调用的日志内容获取。
  String collectLogContentPublic() => _collectLogContent();

  // ─────────────────────────────────────────────────────────────────
  // WEB 调起带凭证 URL 构建（仅对白名单内 URL 携带凭证）
  // ─────────────────────────────────────────────────────────────────

  /// 对白名单 URL 或 f_link_url / service_url 携带凭证；其余原样返回。
  /// 凭证通过 query param 传递（字段名以接口文档为准）。
  String buildAuthUrl(String rawUrl) {
    final needsAuth = (liInfo != null && liInfo!.isUrlInWhitelist(rawUrl)) ||
        _isLiSpecialUrl(rawUrl);
    if (!needsAuth) return rawUrl;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'username': username,
      'token': token,
      'session_id': sessionId,
    }).toString();
  }

  /// f_link_url / service_url 始终需要携带 token。
  bool _isLiSpecialUrl(String url) {
    if (liInfo == null || url.isEmpty) return false;
    final fLink = liInfo!.fLinkUrl ?? '';
    final svc = liInfo!.serviceUrl ?? '';
    return (fLink.isNotEmpty && url.startsWith(fLink)) ||
        (svc.isNotEmpty && url.startsWith(svc));
  }

  // ─────────────────────────────────────────────────────────────────
  // 私有：连接成功/断开
  // ─────────────────────────────────────────────────────────────────

  void _onConnected() {
    _heartbeatFailCount = 0;
    _startHeartbeat();
    _reportCompliance();
  }

  void _onDisconnected() {
    _heartbeatFailCount = 0;
    _complianceReported = false;
    _stopHeartbeat();
  }

  void _applySession(LoginSession session) {
    token = session.accessToken;
    sessionId = session.sessionId;
    liInfo = session.liInfo;
    userConfig = session.userConfig;
    _autoSelectSingleNode();
  }

  Future<void> _loadPostLoginNetworkConfig() async {
    if (token.isEmpty || sessionId.isEmpty) return;
    try {
      final cfg = await _backendRepository.fetchNetworkConfig(
        accessToken: token,
        sessionId: sessionId,
        nodeUrl: selectedNode?.url ?? '',
      );
      networkConfig = cfg;
      // 若 network-config 带了 routeTableUrl 且 liInfo 缺失，则补充
      if (cfg.routeTableUrl != null &&
          cfg.routeTableUrl!.isNotEmpty &&
          (liInfo?.routeTableUrl == null || liInfo!.routeTableUrl!.isEmpty)) {
        liInfo = LiInfo(
          primaryDomain: liInfo!.primaryDomain,
          serverName: liInfo!.serverName,
          licenseKey: liInfo!.licenseKey,
          nodes: liInfo!.nodes,
          heartbeatIntervalSeconds: liInfo!.heartbeatIntervalSeconds,
          webWhitelist: liInfo!.webWhitelist,
          backupDomains: liInfo!.backupDomains,
          routeTableUrl: cfg.routeTableUrl,
          customServiceUrl: liInfo!.customServiceUrl,
          fLinkUrl: liInfo!.fLinkUrl,
          serviceUrl: liInfo!.serviceUrl,
          aboutDescription: liInfo!.aboutDescription,
          aboutTeam: liInfo!.aboutTeam,
          aboutEmail: liInfo!.aboutEmail,
          aboutWebsite: liInfo!.aboutWebsite,
        );
      }
      _autoSelectSingleNode();
    } catch (e) {
      dev.log('post-login network-config failed: $e', name: 'AppController');
    }
  }

  void _autoSelectSingleNode() {
    if (selectedNode != null) return;
    if (availableNodes.length == 1) {
      selectedNode = availableNodes.first;
    }
  }

  VpnProtocol _resolveProtocol(LiNode node) {
    if (node.protocol != VpnProtocol.auto) return node.protocol;
    return selectedProtocol == VpnProtocol.auto
      ? VpnProtocol.ssl
        : selectedProtocol;
  }

  LiNode _buildConnectNode(LiNode base, VpnProtocol protocol) {
    if (protocol != VpnProtocol.wireguard) return base;
    final wg = userConfig?.wireguard;
    if (wg == null) return base;
    return base.copyWith(
      clientPrivateKey:
          wg.privateKey.isNotEmpty ? wg.privateKey : base.clientPrivateKey,
      clientIpAddress:
          wg.ipAddress.isNotEmpty ? wg.ipAddress : base.clientIpAddress,
    );
  }

  NetworkConfig _buildEffectiveNetworkConfig(
    VpnProtocol protocol,
    LiNode node,
    NetworkConfig config,
  ) {
    final rawDns =
        config.dnsServers.isNotEmpty ? config.dnsServers : node.dnsServers;

    // 公共 DNS 放首位，确保 netsh set 设为主 DNS，服务端 DNS（如 100.64.x.x）作为备用
    final safeDns = <String>['8.8.8.8', '1.1.1.1'];
    for (final d in rawDns) {
      if (!safeDns.contains(d)) safeDns.add(d);
    }

    if (protocol == VpnProtocol.wireguard) {
      return NetworkConfig(
        dnsServers: safeDns,
        routes: config.routes,
        nodes: config.nodes,
        mtu: config.mtu,
        routeTableUrl: config.routeTableUrl,
      );
    }

    return NetworkConfig(
      dnsServers: safeDns,
      routes: config.routes,
      nodes: config.nodes,
      mtu: config.mtu,
      routeTableUrl: config.routeTableUrl,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // 心跳
  // ─────────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    final interval = liInfo?.heartbeatIntervalSeconds ?? 30;
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: interval.clamp(30, 3600)),
      (_) => _doHeartbeat(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _doHeartbeat() async {
    if (token.isEmpty || sessionId.isEmpty) return;
    try {
      final resp = await _backendRepository.sendHeartbeat(
        accessToken: token,
        sessionId: sessionId,
        deviceInfo: _deviceInfo(),
      );
      _heartbeatFailCount = 0;
      _handleHeartbeatResponse(resp);
    } catch (e) {
      _heartbeatFailCount++;
      dev.log('heartbeat failed (#$_heartbeatFailCount): $e',
          name: 'AppController');
      // VPN 隧道建立后默认路由可能导致后端不可达，
      // 此时不应断开连接，仅记录日志。
      if (_heartbeatFailCount >= _heartbeatMaxFails) {
        dev.log(
            'heartbeat unreachable after $_heartbeatMaxFails attempts, '
            'keeping connection alive',
            name: 'AppController');
        _heartbeatFailCount = 0;
      }
    }
  }

  void _handleHeartbeatResponse(HeartbeatResponse resp) {
    switch (resp.type) {
      case HeartbeatReturnType.confirm:
        break;
      case HeartbeatReturnType.notification:
        if (resp.message != null) {
          messages.insert(0, resp.message!);
          notifyListeners();
        }
        break;
      case HeartbeatReturnType.liUpdate:
        _refreshLi();
        break;
      case HeartbeatReturnType.forceDisconnect:
        dev.log('heartbeat returned forceDisconnect, disconnecting',
            name: 'AppController');
        lastError = _s.errForceDisconnect;
        disconnect();
        notifyListeners();
        break;
    }
  }

  Future<void> _refreshLi() async {
    // 尝试主域名，失败则逐一尝试备用域名
    final domains = [liUrl, ...liInfo?.backupDomains ?? []];
    for (final domain in domains) {
      try {
        final updated = await _backendRepository.refreshLiInfo(
          liUrl: domain,
          accessToken: token,
        );
        liInfo = updated;
        liUrl = domain; // 切换到可用域名
        notifyListeners();
        return;
      } catch (e) {
        dev.log('refreshLi failed for $domain: $e', name: 'AppController');
        // 尝试下一个域名
      }
    }
    dev.log('all backup domains failed', name: 'AppController');
  }

  /// 测试专用：直接触发备用域名刷新逻辑。
  @visibleForTesting
  Future<void> refreshLiForTest() => _refreshLi();

  // ─────────────────────────────────────────────────────────────────
  // 合规回传（连接成功后一次）
  // ─────────────────────────────────────────────────────────────────

  static const int _complianceMaxRetries = 2;

  Future<void> _reportCompliance() async {
    if (liInfo == null) return;
    if (_complianceReported) return; // 已上报成功，本次连接不再重复
    final localIp = await _getLocalIp();
    for (int attempt = 0; attempt <= _complianceMaxRetries; attempt++) {
      try {
        final ok = await _backendRepository.reportCompliance(
          licenseKey: liInfo!.licenseKey,
          userId: username,
          deviceInfo: _deviceInfo(),
          localIp: localIp,
        );
        if (!ok) {
          // 合规接口返回 passed!=true → 密钥非法，强制断连 + 加黑名单
          dev.log('compliance returned passed!=true, disconnecting',
              name: 'AppController');
          await _addToBlocklist(liInfo!.licenseKey);
          lastError = _s.errComplianceFailed;
          await disconnect();
          notifyListeners();
        } else {
          _complianceReported = true;
        }
        return; // 成功或已处理
      } catch (e) {
        dev.log('reportCompliance attempt $attempt failed: $e',
            name: 'AppController');
        if (attempt < _complianceMaxRetries) {
          await Future<void>.delayed(
            Duration(milliseconds: 500 * (attempt + 1)),
          );
          continue;
        }
        // 所有重试失败 — 合规服务不可达，仅记录警告，不断开连接
        dev.log('compliance check unreachable after all retries, '
            'allowing connection to continue', name: 'AppController');
        _complianceReported = true; // 视为已处理，不再重试
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 非法密钥黑名单（持久化到安全存储）
  // ─────────────────────────────────────────────────────────────────

  Future<void> _loadBlocklistIfNeeded() async {
    if (_blocklistLoaded) return;
    _blocklistLoaded = true;
    try {
      final raw = await _secureStorage.read(key: _blocklistKey);
      if (raw != null && raw.isNotEmpty) {
        _blockedLicenseKeys.addAll(raw.split(','));
      }
    } catch (e) {
      dev.log('loadBlocklist failed: $e', name: 'AppController');
      _blocklistLoaded = false;
    }
  }

  Future<void> _addToBlocklist(String licenseKey) async {
    if (licenseKey.isEmpty) return;
    _blockedLicenseKeys.add(licenseKey);
    try {
      await _secureStorage.write(
        key: _blocklistKey,
        value: _blockedLicenseKeys.join(','),
      );
    } catch (e) {
      dev.log('writeBlocklist failed: $e', name: 'AppController');
    }
  }

  String _deviceInfo() {
    try {
      return '${Platform.operatingSystem}/${Platform.operatingSystemVersion}';
    } catch (e) {
      dev.log('deviceInfo failed: $e', name: 'AppController');
      return 'flutter/unknown';
    }
  }

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      dev.log('getLocalIp failed: $e', name: 'AppController');
    }
    return '0.0.0.0';
  }

  // ─────────────────────────────────────────────────────────────────
  // 多服务管理
  // ─────────────────────────────────────────────────────────────────

  Future<void> _loadServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_servicesKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        services
          ..clear()
          ..addAll(list.map(ServiceEntry.fromJson));
        notifyListeners();
      }
      // 自动登录：找到上次活跃的服务，使用保存的密码自动登录
      await _tryAutoLogin();
    } catch (e) {
      dev.log('loadServices failed: $e', name: 'AppController');
    }
  }

  /// 尝试使用上次活跃服务的保存凭据自动登录。
  Future<void> _tryAutoLogin() async {
    if (loggedIn || services.isEmpty) return;
    // 找活跃服务，或取最近使用的
    final active = services.cast<ServiceEntry?>().firstWhere(
          (s) => s!.isActive,
          orElse: () => null,
        );
    final target = active ?? services.first;
    if (target.liUrl.isEmpty || target.username.isEmpty) return;
    final savedPwd = await getSavedPassword(target.id);
    if (savedPwd == null || savedPwd.isEmpty) return;
    // 静默登录
    await login(
      liUrlInput: target.liUrl,
      usernameInput: target.username,
      password: savedPwd,
    );
  }

  Future<void> _saveServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(services.map((s) => s.toJson()).toList());
      await prefs.setString(_servicesKey, json);
    } catch (e) {
      dev.log('saveServices failed: $e', name: 'AppController');
    }
  }

  /// 登录成功后将当前服务存入列表（去重），并将密码存入安全存储。
  Future<void> saveCurrentAsService() async {
    if (liUrl.isEmpty || username.isEmpty) return;
    final existing = services.indexWhere(
        (s) => s.liUrl == liUrl && s.username == username);
    final id = existing >= 0 ? services[existing].id : const Uuid().v4();
    final entry = ServiceEntry(
      id: id,
      liUrl: liUrl,
      username: username,
      serverName: liInfo?.serverName ?? '',
      lastConnected: DateTime.now(),
      isActive: true,
    );
    // 将其他服务设为非活跃
    for (int i = 0; i < services.length; i++) {
      if (services[i].isActive) {
        services[i] = services[i].copyWith(isActive: false);
      }
    }
    if (existing >= 0) {
      services[existing] = entry;
    } else {
      services.add(entry);
    }
    // 将密码存入安全存储（按 service id 索引）
    if (_passwordInMemory.isNotEmpty) {
      await _saveServicePassword(id, _passwordInMemory);
    }
    await _saveServices();
    notifyListeners();
  }

  /// 将指定服务的密码存入安全存储。
  Future<void> _saveServicePassword(String serviceId, String password) async {
    try {
      await _secureStorage.write(
          key: 'svc_pwd_$serviceId', value: password);
    } catch (e) {
      dev.log('saveServicePassword failed: $e', name: 'AppController');
    }
  }

  /// 读取指定服务的已保存密码。
  Future<String?> getSavedPassword(String serviceId) async {
    try {
      return await _secureStorage.read(key: 'svc_pwd_$serviceId');
    } catch (e) {
      dev.log('getSavedPassword failed: $e', name: 'AppController');
      return null;
    }
  }

  /// 查找匹配 [liUrl] 和 [username] 的已保存服务，返回其 ID。
  String? findServiceId(String liUrl, String username) {
    final idx = services.indexWhere(
        (s) => s.liUrl == liUrl && s.username == username);
    return idx >= 0 ? services[idx].id : null;
  }

  /// 查找匹配 [liUrl] 的最近使用服务。
  ServiceEntry? findServiceByUrl(String url) {
    final matches = services.where((s) => s.liUrl == url).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) =>
        (b.lastConnected ?? DateTime(2000)).compareTo(
            a.lastConnected ?? DateTime(2000)));
    return matches.first;
  }

  Future<void> removeService(String serviceId) async {
    services.removeWhere((s) => s.id == serviceId);
    await _saveServices();
    notifyListeners();
  }

  Future<void> switchService(String serviceId) async {
    if (isBusy) return;
    final target = services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => services.first,
    );

    // 标记活跃服务
    for (int i = 0; i < services.length; i++) {
      services[i] = services[i].copyWith(
        isActive: services[i].id == serviceId,
      );
    }
    await _saveServices();

    // 先断开当前连接
    try {
      await _vpnService.disconnect().timeout(
            const Duration(seconds: 3),
            onTimeout: () {},
          );
    } catch (_) {}

    // 优先用内存密码，其次尝试安全存储中已保存的密码
    String savedPassword = _passwordInMemory;
    if (savedPassword.isEmpty) {
      savedPassword = await getSavedPassword(target.id) ?? '';
    }

    // 有密码时：先登录目标服务，成功后一次性替换状态（不闪登录页）
    if (savedPassword.isNotEmpty &&
        target.liUrl.isNotEmpty &&
        target.username.isNotEmpty) {
      isBusy = true;
      lastError = null;
      notifyListeners();
      try {
        final session = await _backendRepository.loginAndCreateSession(
          liUrl: target.liUrl,
          username: target.username,
          password: savedPassword,
        );
        // 登录成功：一次性切换全部状态
        liUrl = target.liUrl;
        username = target.username;
        _passwordInMemory = savedPassword;
        selectedNode = null;
        selectedProtocol = VpnProtocol.auto;
        networkConfig = null;
        routeDownloadProgress = 0.0;
        messages.clear();
        splitRoutes.clear();
        _applySession(session);
        await _loadPostLoginNetworkConfig();
        await saveCurrentAsService();
      } on ApiException catch (e) {
        lastError = '${_s.errLoginFailed}: ${e.message}';
      } catch (e) {
        lastError = '${_s.errLoginFailed}: $e';
      } finally {
        isBusy = false;
        notifyListeners();
      }
    } else {
      // 无密码：回退到登录页
      token = '';
      sessionId = '';
      _passwordInMemory = '';
      liInfo = null;
      userConfig = null;
      selectedNode = null;
      selectedProtocol = VpnProtocol.auto;
      networkConfig = null;
      routeDownloadProgress = 0.0;
      messages.clear();
      splitRoutes.clear();
      liUrl = target.liUrl;
      username = target.username;
      notifyListeners();
    }
  }

  /// 修改已保存服务的用户名（需要重新登录）。
  Future<void> updateServiceUsername(String serviceId, String newUsername) async {
    final idx = services.indexWhere((s) => s.id == serviceId);
    if (idx < 0) return;
    services[idx] = services[idx].copyWith(username: newUsername);
    await _saveServices();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // 开关持久化
  // ─────────────────────────────────────────────────────────────────

  Future<void> _loadToggles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      splitRoutingEnabled = prefs.getBool(_splitToggleKey) ?? true;
      externalControlEnabled = prefs.getBool(_externalControlKey) ?? false;
      notifyListeners();
    } catch (e) {
      dev.log('loadToggles failed: $e', name: 'AppController');
    }
  }

  Future<void> setSplitRoutingEnabled(bool value) async {
    final changed = splitRoutingEnabled != value;
    splitRoutingEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_splitToggleKey, value);
    } catch (e) {
      dev.log('saveSplitToggle failed: $e', name: 'AppController');
    }

    // 已连接时立即生效，无需重连
    if (changed && vpnStatus == VpnStatus.connected) {
      if (value) {
        // 开启分流：移除默认路由
        dev.log('setSplitRoutingEnabled: split ON, removing default route',
            name: 'AppController');
      } else {
        // 关闭分流 → 全局模式：立即添加默认路由
        dev.log('setSplitRoutingEnabled: split OFF, adding default route',
            name: 'AppController');
        try {
          await _vpnService.applyDefaultRoute();
          dev.log('applyDefaultRoute: OK', name: 'AppController');
        } on Exception catch (e) {
          dev.log('applyDefaultRoute failed: $e', name: 'AppController');
        }
      }
    }
  }

  Future<void> setExternalControlEnabled(bool value) async {
    externalControlEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_externalControlKey, value);
    } catch (e) {
      dev.log('saveExternalControl failed: $e', name: 'AppController');
    }
  }

  /// 清空日志（目前仅清除上传结果状态）。
  void clearLog() {
    logUploadResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectWatchdogTimer?.cancel();
    _heartbeatTimer?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:uuid/uuid.dart';

import '../models/auth_models.dart';
import 'backend_repository.dart';

const _uuid = Uuid();

class MockBackendRepository implements BackendRepository {
  @override
  void bindApiBase(String liUrl) {}

  // 模拟 Li 信息结构（测试用）
  static LiInfo _makeMockLi(String liUrl) => LiInfo(
        primaryDomain: liUrl.isNotEmpty ? liUrl : 'demo.sdwan.local',
        serverName: 'Demo SD-WAN 企业网络',
        licenseKey: 'mock-license-key-demo',
        nodes: [
          LiNode(
            id: 1,
            name: '上海节点',
            url: 'sh01.sdwan.local',
            protocol: VpnProtocol.wireguard,
            port: 8096,
            publicKey: 'mock-wg-pubkey-sh01',
            dnsServers: ['10.10.10.53'],
            doh: ['https://dns.sdwan.local/dns-query'],
          ),
          LiNode(
            id: 2,
            name: '北京节点',
            url: 'bj01.sdwan.local',
            protocol: VpnProtocol.ssl,
            port: 443,
            publicKey: '',
            dnsServers: ['10.10.20.53'],
            doh: [],
          ),
          LiNode(
            id: 3,
            name: '香港节点',
            url: 'hk01.sdwan.local',
            protocol: VpnProtocol.auto,
            port: 8096,
            publicKey: 'mock-wg-pubkey-hk01',
            dnsServers: ['10.10.30.53'],
            doh: ['https://dns-hk.sdwan.local/dns-query'],
          ),
        ],
        webWhitelist: const ['https://demo.sdwan.local/'],
        heartbeatIntervalSeconds: 30,
        customServiceUrl: 'https://portal.sdwan.local/user',
        backupDomains: ['backup.sdwan.local'],
        routeTableUrl: 'https://demo.sdwan.local/routes/default.conf',
      );

  @override
  Future<LiInfo?> fetchLiInfo({required String liUrl}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (liUrl.isEmpty) return null;
    return _makeMockLi(liUrl);
  }

  @override
  Future<LoginSession> loginAndCreateSession({
    required String liUrl,
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (username.isEmpty || password.isEmpty) {
      throw Exception('用户名或密码为空');
    }
    final li = _makeMockLi(liUrl);
    return LoginSession(
      accessToken: 'mock-token-${_uuid.v4()}',
      userId: username,
      sessionId: 'mock-session-${_uuid.v4()}',
      liInfo: li,
      userConfig: UserConfig(
        userId: username,
        subscription: '企业版',
        expiryTime: DateTime.now().add(const Duration(days: 365)),
        lastLoginAt: DateTime.now(),
        splitMode: 'user_defined',
        speedLimit: '100Mbps',
        wireguard: WireGuardUserConfig(
          privateKey: 'mock-user-private-key',
          ipAddress: '10.8.0.2',
        ),
      ),
    );
  }

  @override
  Future<LiInfo> refreshLiInfo({
    required String liUrl,
    required String accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _makeMockLi(liUrl);
  }

  @override
  Future<NetworkConfig> fetchNetworkConfig({
    required String accessToken,
    required String sessionId,
    required String nodeUrl,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final li = _makeMockLi('demo.sdwan.local');
    return NetworkConfig(
      dnsServers: ['10.10.10.53', '10.10.10.54'],
      routes: ['10.0.0.0/8', '172.16.0.0/12', '192.168.100.0/24'],
      nodes: li.nodes,
      mtu: 1380,
    );
  }

  int _heartbeatCount = 0;

  @override
  Future<HeartbeatResponse> sendHeartbeat({
    required String accessToken,
    required String sessionId,
    required String deviceInfo,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _heartbeatCount++;

    // 模拟: 第 3 次心跳推送一条通知消息
    if (_heartbeatCount == 3) {
      return HeartbeatResponse(
        type: HeartbeatReturnType.notification,
        message: PushMessage(
          id: _uuid.v4(),
          type: PushMessageType.textWithUrl,
          text: '您的订阅将在 30 天后到期，点击续费',
          url: 'https://portal.sdwan.local/renew',
          carryCredentials: true,
          receivedAt: DateTime.now(),
        ),
      );
    }
    // 第 6 次心跳推送纯文字通知
    if (_heartbeatCount == 6) {
      return HeartbeatResponse(
        type: HeartbeatReturnType.notification,
        message: PushMessage(
          id: _uuid.v4(),
          type: PushMessageType.textOnly,
          text: '系统将于今晚 23:00 进行例行维护，预计 30 分钟。',
          receivedAt: DateTime.now(),
        ),
      );
    }
    return HeartbeatResponse(type: HeartbeatReturnType.confirm);
  }

  @override
  Future<List<String>> downloadRouteTable({
    required String url,
    required String accessToken,
    void Function(double progress)? onProgress,
  }) async {
    // 模拟分段下载进度
    for (int i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      onProgress?.call(i / 10.0);
    }
    return [
      '10.0.0.0/8',
      '172.16.0.0/12',
      '192.168.100.0/24',
      '192.168.200.0/24',
    ];
  }

  @override
  Future<bool> reportCompliance({
    required String licenseKey,
    required String userId,
    required String deviceInfo,
    required String localIp,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Mock 始终返回合规
    return true;
  }

  @override
  Future<VersionInfo?> checkVersion({required String currentVersion}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Mock: 无新版本
    return null;
  }

  @override
  Future<void> uploadLog({
    required String accessToken,
    required String username,
    required String logContent,
    String liUrl = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Mock: 静默成功
  }
}

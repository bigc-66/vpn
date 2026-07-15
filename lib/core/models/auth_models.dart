enum VpnProtocol { ssl, wireguard, auto }

extension VpnProtocolLabel on VpnProtocol {
  String get label {
    switch (this) {
      case VpnProtocol.ssl:
        return 'SSL VPN';
      case VpnProtocol.wireguard:
        return 'WireGuard';
      case VpnProtocol.auto:
        return '自动';
    }
  }
}

// 节点信息
class LiNode {
  LiNode({
    required this.id,
    required this.name,
    required this.url,
    required this.protocol,
    required this.port,
    this.publicKey = '',
    this.dnsServers = const [],
    this.doh = const [],
    this.clientPrivateKey = '',
    this.clientIpAddress = '',
  });

  /// 节点 ID
  final int id;
  final String name;
  final String url;
  final VpnProtocol protocol;

  /// 连接端口
  final int port;

  /// WireGuard 服务端公钥（SSL 节点为空）
  final String publicKey;

  /// 节点专属 DNS，覆盖全局 DNS
  final List<String> dnsServers;

  /// 节点专属 DNS over HTTPS 地址列表
  final List<String> doh;

  /// WireGuard 客户端私钥（优先使用用户配置下发）
  final String clientPrivateKey;

  /// WireGuard 客户端隧道地址（如 10.8.0.2 或 10.8.0.2/32）
  final String clientIpAddress;

  LiNode copyWith({
    int? id,
    String? name,
    String? url,
    VpnProtocol? protocol,
    int? port,
    String? publicKey,
    List<String>? dnsServers,
    List<String>? doh,
    String? clientPrivateKey,
    String? clientIpAddress,
  }) {
    return LiNode(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      protocol: protocol ?? this.protocol,
      port: port ?? this.port,
      publicKey: publicKey ?? this.publicKey,
      dnsServers: dnsServers ?? this.dnsServers,
      doh: doh ?? this.doh,
      clientPrivateKey: clientPrivateKey ?? this.clientPrivateKey,
      clientIpAddress: clientIpAddress ?? this.clientIpAddress,
    );
  }
}

class WireGuardUserConfig {
  WireGuardUserConfig({
    required this.privateKey,
    required this.ipAddress,
  });

  final String privateKey;
  final String ipAddress;
}

// Li (Link Info) 核心结构 —— 来自服务端主域名
class LiInfo {
  LiInfo({
    required this.primaryDomain,
    required this.serverName,
    required this.licenseKey,
    required this.nodes,
    required this.heartbeatIntervalSeconds,
    this.webWhitelist = const [],
    this.backupDomains = const [],
    this.routeTableUrl,
    this.customServiceUrl,
    this.fLinkUrl,
    this.serviceUrl,
    this.aboutDescription,
    this.aboutTeam,
    this.aboutEmail,
    this.aboutWebsite,
  });

  final String primaryDomain;

  /// 来自接口字段 server_name
  final String serverName;
  final String licenseKey;
  final List<LiNode> nodes;
  // 最小 30 秒
  final int heartbeatIntervalSeconds;
  // WEB 白名单 URL（携带凭证访问的前缀）
  final List<String> webWhitelist;
  final List<String> backupDomains;
  // 路由表下载地址
  final String? routeTableUrl;
  // F 键扩展服务地址（可选，非标准字段）
  final String? customServiceUrl;
  // 菜单栏中间 web 页面 URL（需携带 token）
  final String? fLinkUrl;
  // 登录后首页下方展示 web 页面 URL（需携带 token）
  final String? serviceUrl;
  // 关于页面内容（从 API 获取，可选）
  final String? aboutDescription;
  final String? aboutTeam;
  final String? aboutEmail;
  final String? aboutWebsite;

  bool isUrlInWhitelist(String url) {
    if (webWhitelist.isEmpty) return false;
    for (final prefix in webWhitelist) {
      if (prefix.isNotEmpty && url.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }
}

// 用户配置（认证后从服务端下载）
class UserConfig {
  UserConfig({
    required this.userId,
    required this.subscription,
    required this.expiryTime,
    required this.lastLoginAt,
    this.forcedNodeUrl,
    this.forcedRouteTableUrl,
    this.splitMode,
    this.speedLimit,
    this.wireguard,
  });

  final String userId;
  final String subscription;
  final DateTime expiryTime;
  final DateTime lastLoginAt;
  // 非 null 时强制使用指定节点
  final String? forcedNodeUrl;
  // 非 null 时强制使用指定路由表
  final String? forcedRouteTableUrl;
  // 'full' | 'split' | 'user_defined'
  final String? splitMode;
  // 套餐限速，如 "100Mbps"，来自订阅信息
  final String? speedLimit;
  // 用户专属 WireGuard 信息
  final WireGuardUserConfig? wireguard;
}

class LoginSession {
  LoginSession({
    required this.accessToken,
    required this.userId,
    required this.sessionId,
    required this.liInfo,
    required this.userConfig,
    this.expireAt,
  });

  final String accessToken;
  final String userId;
  final String sessionId;
  final LiInfo liInfo;
  final UserConfig userConfig;

  /// Token 过期时间（来自 expire Unix 时间戳）
  final DateTime? expireAt;
}

class NetworkConfig {
  NetworkConfig({
    required this.dnsServers,
    required this.routes,
    this.nodes = const [],
    this.mtu,
    this.routeTableUrl,
  });

  final List<String> dnsServers;
  final List<String> routes;
  final List<LiNode> nodes;
  final int? mtu;
  /// 当服务端 routes 字段为 URL 时保存于此，供后续下载
  final String? routeTableUrl;
}

// 推送消息
enum PushMessageType { textOnly, textWithUrl }

class PushMessage {
  PushMessage({
    required this.id,
    required this.type,
    required this.text,
    this.url,
    this.carryCredentials = false,
    required this.receivedAt,
  });

  final String id;
  final PushMessageType type;
  final String text;
  final String? url;
  // 是否在白名单内（由 LiInfo.isUrlInWhitelist 决定）
  final bool carryCredentials;
  final DateTime receivedAt;
}

// 心跳响应类型
enum HeartbeatReturnType { confirm, notification, liUpdate, forceDisconnect }

class HeartbeatResponse {
  HeartbeatResponse({required this.type, this.message});
  final HeartbeatReturnType type;
  final PushMessage? message;
}

// 自定义分流规则
class SplitRoute {
  SplitRoute({this.name = '', required this.target, required this.mode, this.enabled = true});

  /// 用户自定义别名，如 "公司内网"
  final String name;

  /// 单 IP: xxx.xxx.xxx.xxx 或 C 段: xxx.xxx.xxx.*
  final String target;

  /// 'bypass' = 不走通道，'tunnel' = 走通道
  final String mode;

  /// 是否启用该条规则
  final bool enabled;

  SplitRoute copyWith({String? name, String? target, String? mode, bool? enabled}) {
    return SplitRoute(
      name: name ?? this.name,
      target: target ?? this.target,
      mode: mode ?? this.mode,
      enabled: enabled ?? this.enabled,
    );
  }

  static bool isValidTarget(String t) {
    final parts = t.split('.');
    if (parts.length != 4) return false;
    for (int i = 0; i < 3; i++) {
      final n = int.tryParse(parts[i]);
      if (n == null || n < 0 || n > 255) return false;
    }
    final last = parts[3];
    if (last == '*') return true;
    final n = int.tryParse(last);
    return n != null && n >= 0 && n <= 255;
  }
}

// 版本信息
class VersionInfo {
  VersionInfo({
    required this.version,
    required this.downloadUrl,
    required this.isRequired,
    this.description,
    this.updateTime,
  });
  final String version;
  final String downloadUrl;

  /// is_required: 服务端返回 int(0/1)
  final bool isRequired;
  final String? description;
  final DateTime? updateTime;
}

// 多服务管理：保存单个服务入口的完整信息
class ServiceEntry {
  ServiceEntry({
    required this.id,
    required this.liUrl,
    required this.username,
    this.serverName = '',
    this.lastConnected,
    this.isActive = false,
  });

  final String id;
  final String liUrl;
  final String username;
  final String serverName;
  final DateTime? lastConnected;
  final bool isActive;

  ServiceEntry copyWith({
    String? id,
    String? liUrl,
    String? username,
    String? serverName,
    DateTime? lastConnected,
    bool? isActive,
  }) {
    return ServiceEntry(
      id: id ?? this.id,
      liUrl: liUrl ?? this.liUrl,
      username: username ?? this.username,
      serverName: serverName ?? this.serverName,
      lastConnected: lastConnected ?? this.lastConnected,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'liUrl': liUrl,
        'username': username,
        'serverName': serverName,
        'lastConnected': lastConnected?.toIso8601String(),
        'isActive': isActive,
      };

  factory ServiceEntry.fromJson(Map<String, dynamic> json) => ServiceEntry(
        id: json['id'] as String? ?? '',
        liUrl: json['liUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        serverName: json['serverName'] as String? ?? '',
        lastConnected: json['lastConnected'] != null
            ? DateTime.tryParse(json['lastConnected'] as String)
            : null,
        isActive: json['isActive'] as bool? ?? false,
      );
}

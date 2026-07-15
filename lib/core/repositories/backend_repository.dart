import '../models/auth_models.dart';

abstract class BackendRepository {
  /// 仅验证服务地址并获取 Li 基本信息（不需要凭证）
  Future<LiInfo?> fetchLiInfo({required String liUrl});

  /// 获取 Li 信息并完成用户认证，返回完整 Session
  Future<LoginSession> loginAndCreateSession({
    required String liUrl,
    required String username,
    required String password,
  });

  /// 重新拉取 Li 信息（心跳触发 Li 更新时使用）
  Future<LiInfo> refreshLiInfo({
    required String liUrl,
    required String accessToken,
  });

  /// 连接成功后获取实际网络配置（DNS、路由）
  Future<NetworkConfig> fetchNetworkConfig({
    required String accessToken,
    required String sessionId,
    required String nodeUrl,
  });

  /// 心跳上报，返回服务端指令
  Future<HeartbeatResponse> sendHeartbeat({
    required String accessToken,
    required String sessionId,
    required String deviceInfo,
  });

  /// 下载路由表；onProgress 回调 0.0~1.0
  Future<List<String>> downloadRouteTable({
    required String url,
    required String accessToken,
    void Function(double progress)? onProgress,
  });

  /// 向 Unify Flow 上报合规信息
  Future<bool> reportCompliance({
    required String licenseKey,
    required String userId,
    required String deviceInfo,
    required String localIp,
  });

  /// 检查客户端版本
  Future<VersionInfo?> checkVersion({required String currentVersion});

  /// 上传用户日志（日志内容由调用方生成）
  Future<void> uploadLog({
    required String accessToken,
    required String username,
    required String logContent,
    String liUrl = '',
  });

  /// 将后续 REST 请求（登录、心跳、网络配置等）指向用户填入的服务域名。
  /// 与 [fetchLiInfo] 使用同一主机，否则请求会打到编译期默认 [AppConfig.baseUrl]，
  /// 自定义部署（如 client.example.com）将收不到任何流量。
  void bindApiBase(String liUrl);
}

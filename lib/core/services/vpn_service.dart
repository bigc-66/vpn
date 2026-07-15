import '../models/auth_models.dart';
import '../models/vpn_status.dart';

abstract class VpnService {
  Stream<VpnStatus> get statusStream;

  /// 读取当前底层状态（用于连接流程的主动轮询）。
  Future<VpnStatus> getStatus() async => VpnStatus.disconnected;

  Future<void> connect({
    required LiNode node,
    required VpnProtocol protocol,
    required String username,
    required String password,
    List<String> routes = const [],
    bool splitRouting = true,
  });

  Future<void> disconnect();

  /// 两阶段路由 — 第一阶段：写入 DNS + 非默认路由
  Future<void> applyNetworkConfig(NetworkConfig config);

  /// 两阶段路由 — 第二阶段：写入默认路由 (0.0.0.0/0)
  Future<void> applyDefaultRoute();

  /// 可选：获取底层最近一次连接错误详情（无详情时返回 null）。
  Future<String?> getLastError() async => null;

  /// 当前进程是否具备管理员权限（仅 Windows 真实实现有意义）。
  Future<bool> isElevated() async => true;

  /// 请求以管理员权限重启当前应用（仅 Windows 真实实现）。
  Future<bool> restartElevated() async => false;

  void dispose();
}

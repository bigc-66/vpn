import 'dart:async';

import '../models/auth_models.dart';
import '../models/vpn_status.dart';
import 'vpn_service.dart';

class MockVpnService implements VpnService {
  final StreamController<VpnStatus> _statusController =
      StreamController<VpnStatus>.broadcast();

  VpnStatus _current = VpnStatus.disconnected;

  @override
  Stream<VpnStatus> get statusStream => _statusController.stream;

  @override
  Future<VpnStatus> getStatus() async => _current;

  @override
  Future<void> connect({
    required LiNode node,
    required VpnProtocol protocol,
    required String username,
    required String password,
    List<String> routes = const [],
    bool splitRouting = true,
  }) async {
    if (_current == VpnStatus.connected || _current == VpnStatus.connecting) {
      return;
    }

    _emit(VpnStatus.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (node.url.trim().isEmpty || username.trim().isEmpty || password.isEmpty) {
      _emit(VpnStatus.error);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _emit(VpnStatus.disconnected);
      return;
    }

    _emit(VpnStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    if (_current == VpnStatus.disconnected ||
        _current == VpnStatus.disconnecting) {
      return;
    }

    _emit(VpnStatus.disconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _emit(VpnStatus.disconnected);
  }

  void _emit(VpnStatus status) {
    _current = status;
    _statusController.add(status);
  }

  @override
  Future<void> applyNetworkConfig(NetworkConfig config) async {}

  @override
  Future<void> applyDefaultRoute() async {}

  @override
  Future<String?> getLastError() async => null;

  @override
  Future<bool> isElevated() async => true;

  @override
  Future<bool> restartElevated() async => false;

  @override
  void dispose() {
    _statusController.close();
  }
}

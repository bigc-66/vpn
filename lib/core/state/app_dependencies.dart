import '../api/api_client.dart';
import '../config/app_config.dart';
import '../repositories/backend_repository.dart';
import '../repositories/http_backend_repository.dart';
import '../services/platform_vpn_service.dart';
import '../services/vpn_service.dart';
import 'package:flutter/foundation.dart';

// Mock 仅在 USE_MOCK_BACKEND=true 时使用（开发模式）。
// 使用延迟导入避免 Release 构建时 tree-shaking 失效。
import '../repositories/mock_backend_repository.dart' deferred as mock_repo;
import '../services/mock_vpn_service.dart' deferred as mock_vpn;

class AppDependencies {
  AppDependencies({
    required this.config,
    required this.vpnService,
    required this.backendRepository,
    this.apiClient,
  });

  final AppConfig config;
  final VpnService vpnService;
  final BackendRepository backendRepository;
  final ApiClient? apiClient;

  static Future<AppDependencies> build() async {
    final config = AppConfig.fromEnv();
    if (config.useMockBackend || kIsWeb) {
      await mock_repo.loadLibrary();
      await mock_vpn.loadLibrary();
      return AppDependencies(
        config: config,
        vpnService: mock_vpn.MockVpnService(),
        backendRepository: mock_repo.MockBackendRepository(),
      );
    }

    final apiClient = ApiClient(baseUrl: config.baseUrl);
    return AppDependencies(
      config: config,
      vpnService: PlatformVpnService(),
      backendRepository: HttpBackendRepository(apiClient),
      apiClient: apiClient,
    );
  }

  void dispose() {
    vpnService.dispose();
    apiClient?.dispose();
  }
}

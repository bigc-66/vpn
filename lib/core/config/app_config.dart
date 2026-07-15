class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.useMockBackend,
  });

  final String baseUrl;
  final bool useMockBackend;

  static AppConfig fromEnv() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://client.gogogofuture.com',
    );
    const useMock = bool.fromEnvironment('USE_MOCK_BACKEND', defaultValue: false);

    return const AppConfig(baseUrl: baseUrl, useMockBackend: useMock);
  }
}

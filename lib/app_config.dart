class AppConfig {
  final String apiBaseUrl;
  final String apiKey;

  const AppConfig({required this.apiBaseUrl, required this.apiKey});

  factory AppConfig.fromEnvironment() {
    final config = tryFromEnvironment();
    if (config != null) return config;
    throw StateError(
      'Missing dart-define values. Pass API_BASE_URL and API_KEY.',
    );
  }

  static AppConfig? tryFromEnvironment() {
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    const key = String.fromEnvironment('API_KEY');
    if (baseUrl.isEmpty || key.isEmpty) {
      return null;
    }
    return const AppConfig(apiBaseUrl: baseUrl, apiKey: key);
  }
}

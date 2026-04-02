class AppConfig {
  final String apiBaseUrl;
  final String apiKey;

  const AppConfig({
    required this.apiBaseUrl,
    required this.apiKey,
  });

  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    const key = String.fromEnvironment('API_KEY');
    if (baseUrl.isEmpty || key.isEmpty) {
      throw StateError(
        'Missing dart-define values. Pass API_BASE_URL and API_KEY.',
      );
    }
    return const AppConfig(apiBaseUrl: baseUrl, apiKey: key);
  }
}

class CollaborationConfig {
  const CollaborationConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'COACHSPLIT_API_BASE_URL',
    defaultValue: '',
  );

  static bool get isConfigured => apiBaseUrl.trim().isNotEmpty;
}

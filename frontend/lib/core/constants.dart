class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const String hiveBox = 'app_box';
}

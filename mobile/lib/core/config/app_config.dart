/// App-wide settings. Change these in one place.
abstract final class AppConfig {
  static const String appName = 'Widgetry';
  static const String siteUrl = 'https://widgetryacademy.in';

  /// Jobs and profile API (Railway). Override for local testing with
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.widgetryacademy.in/api');

  static const String blogFeedUrl = '$siteUrl/blog/feed.json';
  static const String privacyUrl = '$siteUrl/privacy.html';
  static const String termsUrl = '$siteUrl/jobs-terms.html';
  static const String contactUrl = '$siteUrl/contact.html';
  static const String postJobUrl = '$siteUrl/post-job.html';
  static const String whatsappNumber = '918617692683';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}

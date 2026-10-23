/// App-wide settings. Change these in one place.
abstract final class AppConfig {
  static const String appName = 'Widgetry';
  static const String siteUrl = 'https://widgetryacademy.in';

  /// Optional: the OAuth *Web* client ID for native Google sign-in. Usually read automatically from google-services.json.
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Jobs, profile and payments API (Railway). Override for local testing with
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.widgetryacademy.in/api');

  static const String blogFeedUrl = '$siteUrl/blog/feed.json';
  static const String privacyUrl = '$siteUrl/privacy.html';
  static const String termsUrl = '$siteUrl/jobs-terms.html';
  static const String contactUrl = '$siteUrl/contact.html';
  static const String postJobUrl = '$siteUrl/post-job.html';
  static const String refundUrl = '$siteUrl/refund.html';
  static const String whatsappNumber = '918617692683';

  /// Shown on receipts (same as the website's contact and policy pages).
  static const String businessName = 'Widgetry Academy';
  static const String businessOwner = 'Kishan Kumar Sharma';
  static const String businessAddress = 'Kolkata, West Bengal, India';
  static const String businessEmail = 'kishantechdev@gmail.com';
  /// Widgetry Tutor (AI, /tutor). Hidden for now: set true to show it in the Courses tab and Settings.
  static const bool tutorEnabled = false;

  static const String udyam = 'UDYAM-WB-22-0009252';

  /// Setup guide students follow before Day 1.
  static const String flutterInstallUrl = 'https://docs.flutter.dev/get-started/install';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}

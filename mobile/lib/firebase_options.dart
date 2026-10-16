// PLACEHOLDER. Replace this file by running, in the mobile/ folder:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=flutter-in-10-days --platforms=android,ios --android-package-name=in.widgetryacademy.app --ios-bundle-id=in.widgetryacademy.app
//
// It writes the real lib/firebase_options.dart (and google-services.json / GoogleService-Info.plist).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Run `flutterfire configure` first: see mobile/README.md (Firebase setup).');
}

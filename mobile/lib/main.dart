import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:widgetry_academy/app/app.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/notifications/push_service.dart';
import 'package:widgetry_academy/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await configureDependencies();

  // Ask for notification permission and subscribe to topics without delaying the first frame
  unawaited(getIt<PushService>().init());

  runApp(const WidgetryApp());
}

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/firebase_options.dart';

/// Runs when a push arrives while the app is closed. Notification messages are shown by the system,
/// so we only need Firebase ready here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Where a tapped notification should take the user.
class PushTarget {
  const PushTarget({this.route, this.url});
  final String? route;
  final String? url;
}

class ForegroundPush {
  const ForegroundPush(this.title, this.body, this.target);
  final String title;
  final String body;
  final PushTarget target;
}

/// A notification topic the user can switch on or off.
class PushTopic {
  const PushTopic(this.id, this.label, {this.defaultOn = false});
  final String id;
  final String label;
  final bool defaultOn;
}

/// Firebase Cloud Messaging: permission, topics, device registration and taps.
/// Topics: `all` (always), `academy`, `jobs-<category>`. The server sends to these.
@lazySingleton
class PushService {
  PushService(this._fcm, this._api, this._prefs);
  final FirebaseMessaging _fcm;
  final ApiClient _api;
  final SharedPreferences _prefs;

  final _taps = StreamController<PushTarget>.broadcast();
  final _foreground = StreamController<ForegroundPush>.broadcast();
  Stream<PushTarget> get taps => _taps.stream;
  Stream<ForegroundPush> get foreground => _foreground.stream;

  PushTarget? _launchTarget;
  bool _started = false;
  final _ready = Completer<void>();
  String? _registeredFor;

  static const _prefix = 'push_topic_';
  static const defaultTopics = ['academy', 'jobs-flutter'];

  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      // iOS: no system banner while the app is open; the app shows its own banner instead
      await _fcm.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        _foreground.add(ForegroundPush(n.title ?? AppConfig.appName, n.body ?? '', targetFor(m.data)));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(targetFor(m.data)));
      final initial = await _fcm.getInitialMessage();
      if (initial != null) _launchTarget = targetFor(initial.data);
      _fcm.onTokenRefresh.listen((_) {
        final uid = _registeredFor;
        _registeredFor = null;
        if (uid != null) registerDevice(uid);
      });
      if (!_ready.isCompleted) _ready.complete();
      // Topics last: on iOS they fail until the APNs token arrives, which must not stop the listeners above
      await _subscribeDefaults();
    } catch (_) {
      // Push is optional: the app works without it (e.g. emulator without Google Play services).
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// The notification that opened the app from closed, if any. Read once, after [init] finishes.
  Future<PushTarget?> takeLaunchTarget() async {
    await _ready.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    final t = _launchTarget;
    _launchTarget = null;
    return t;
  }

  Future<void> _subscribeDefaults() async {
    if (Platform.isIOS) {
      for (var i = 0; i < 10 && await _fcm.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    for (final t in ['all', ...defaultTopics]) {
      if (t == 'all' || isOn(t)) {
        try {
          await _fcm.subscribeToTopic(t);
        } catch (_) {}
      }
    }
  }

  bool isOn(String topic) => _prefs.getBool('$_prefix$topic') ?? defaultTopics.contains(topic);

  Future<void> setTopic(String topic, bool on) async {
    await _prefs.setBool('$_prefix$topic', on);
    try {
      on ? await _fcm.subscribeToTopic(topic) : await _fcm.unsubscribeFromTopic(topic);
    } catch (_) {}
  }

  /// Links this phone to the signed-in user for personal notifications (job approved, profile verified).
  Future<void> registerDevice(String uid) async {
    if (_registeredFor == uid) return;
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _api.post('/me/devices', body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
      _registeredFor = uid;
    } catch (_) {}
  }

  /// Call before signing out, while the user's token is still valid.
  Future<void> unregisterDevice() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _api.delete('/me/devices', body: {'token': token});
    } catch (_) {}
    _registeredFor = null;
  }

  /// Maps the server's data payload to a screen in the app (or a web link).
  static PushTarget targetFor(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}';
    final link = '${data['link'] ?? ''}';
    switch (type) {
      case 'job':
        final id = '${data['jobId'] ?? ''}';
        if (id.isNotEmpty) return PushTarget(route: '/jobs/$id');
      case 'jobs':
        final cat = '${data['category'] ?? ''}';
        return PushTarget(route: cat.isEmpty ? '/jobs' : '/jobs?cat=$cat');
      case 'profile':
        return const PushTarget(route: '/profile');
    }
    if (link.startsWith(AppConfig.siteUrl)) {
      final path = link.substring(AppConfig.siteUrl.length);
      if (path.contains('#courses') || path.contains('#fees') || path == '/' || path.isEmpty) return const PushTarget(route: '/courses');
      if (path.startsWith('/blog')) return const PushTarget(route: '/blog');
      if (path.startsWith('/jobs')) return const PushTarget(route: '/jobs');
      if (path.startsWith('/my-profile') || path.startsWith('/resume')) return const PushTarget(route: '/profile');
    }
    return link.startsWith('https://') ? PushTarget(url: link) : const PushTarget(route: '/jobs');
  }
}

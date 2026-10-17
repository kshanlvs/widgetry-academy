import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/notifications/push_service.dart';
import 'package:widgetry_academy/core/router/app_router.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';

class WidgetryApp extends StatelessWidget {
  const WidgetryApp({super.key});

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>().router;
    return MultiBlocProvider(
      providers: [
        // App-wide state (singletons)
        BlocProvider<AuthCubit>.value(value: getIt<AuthCubit>()),
        BlocProvider<ProfileCubit>.value(value: getIt<ProfileCubit>()),
        BlocProvider<CoursesCubit>.value(value: getIt<CoursesCubit>()),
      ],
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
        scaffoldMessengerKey: messengerKey,
        builder: (context, child) => _PushBridge(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Connects push notifications to the app: registers the phone after sign-in,
/// opens the right screen when a notification is tapped, and shows a banner for ones that arrive in the foreground.
class _PushBridge extends StatefulWidget {
  const _PushBridge({required this.child});
  final Widget child;
  @override
  State<_PushBridge> createState() => _PushBridgeState();
}

class _PushBridgeState extends State<_PushBridge> {
  final _push = getIt<PushService>();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _subs.add(_push.taps.listen(_open));
    _subs.add(_push.foreground.listen((m) {
      WidgetryApp.messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(m.body.isEmpty ? m.title : '${m.title}\n${m.body}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'View', onPressed: () => _open(m.target)),
        ));
    }));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launch = await _push.takeLaunchTarget();
      if (launch != null && mounted) _open(launch);
    });
    // Already signed in when the app starts: link this phone for personal notifications
    final user = getIt<AuthCubit>().state.user;
    if (user != null) _push.registerDevice(user.uid);
  }

  void _open(PushTarget t) {
    final route = t.route;
    if (route != null) {
      final router = getIt<AppRouter>().router;
      // Tab roots (/jobs, /courses, /blog, /profile) switch tabs; deeper screens open on top
      Uri.parse(route).pathSegments.length <= 1 ? router.go(route) : router.push(route);
    } else if (t.url != null) {
      getIt<LinkLauncher>().openInApp(t.url!);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
        listenWhen: (a, b) => a.user?.uid != b.user?.uid && b.user != null,
        listener: (context, s) => _push.registerDevice(s.user!.uid),
        child: widget.child,
      );
}

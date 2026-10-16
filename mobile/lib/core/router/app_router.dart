import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/auth/presentation/pages/sign_in_page.dart';
import 'package:widgetry_academy/features/blog/presentation/blog_page.dart';
import 'package:widgetry_academy/features/courses/presentation/pages/course_detail_page.dart';
import 'package:widgetry_academy/features/courses/presentation/pages/courses_page.dart';
import 'package:widgetry_academy/features/courses/presentation/pages/registration_page.dart';
import 'package:widgetry_academy/features/jobs/presentation/pages/job_detail_page.dart';
import 'package:widgetry_academy/features/jobs/presentation/pages/jobs_page.dart';
import 'package:widgetry_academy/features/jobs/presentation/pages/saved_jobs_page.dart';
import 'package:widgetry_academy/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:widgetry_academy/features/profile/presentation/pages/profile_page.dart';
import 'package:widgetry_academy/features/profile/presentation/pages/resume_page.dart';
import 'package:widgetry_academy/features/settings/settings_page.dart';

/// All routes in one place. Four tabs (Jobs, Courses, Guides, Profile) keep their own history.
/// Screens that need an account send signed-out users to /sign-in and bring them back after.
@lazySingleton
class AppRouter {
  AppRouter(this._auth);
  final AuthCubit _auth;

  static final rootKey = GlobalKey<NavigatorState>();
  static const _needsAccount = ['/profile/edit', '/profile/resume'];

  late final GoRouter router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/jobs',
    refreshListenable: _StreamListenable(_auth.stream),
    redirect: (context, state) {
      final path = state.uri.path;
      final needs = _needsAccount.contains(path) || RegExp(r'^/courses/[^/]+/register$').hasMatch(path);
      if (needs && _auth.state.status == AuthStatus.signedOut) return '/sign-in?from=${Uri.encodeComponent(state.uri.toString())}';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/jobs',
              builder: (_, s) => JobsPage(key: ValueKey(s.uri.queryParameters['cat']), initialCategory: s.uri.queryParameters['cat']),
              routes: [
                GoRoute(path: 'saved', parentNavigatorKey: rootKey, builder: (_, __) => const SavedJobsPage()),
                GoRoute(path: ':id', parentNavigatorKey: rootKey, builder: (_, s) => JobDetailPage(jobId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/courses',
              builder: (_, __) => const CoursesPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootKey,
                  builder: (_, s) => CourseDetailPage(courseId: s.pathParameters['id']!),
                  routes: [GoRoute(path: 'register', parentNavigatorKey: rootKey, builder: (_, s) => RegistrationPage(courseId: s.pathParameters['id']!))],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/blog', builder: (_, __) => const BlogPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfilePage(),
              routes: [
                GoRoute(path: 'edit', parentNavigatorKey: rootKey, builder: (_, __) => const ProfileEditPage()),
                GoRoute(path: 'resume', parentNavigatorKey: rootKey, builder: (_, __) => const ResumePage()),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(path: '/sign-in', parentNavigatorKey: rootKey, builder: (_, s) => SignInPage(redirectTo: s.uri.queryParameters['from'])),
      GoRoute(path: '/settings', parentNavigatorKey: rootKey, builder: (_, __) => const SettingsPage()),
    ],
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Jobs'),
            NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Courses'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Guides'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
}

/// Lets go_router re-check redirects whenever sign-in state changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

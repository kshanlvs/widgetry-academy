import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/notifications/push_service.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/auth/domain/usecases/auth_usecases.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _push = getIt<PushService>();
  final _links = getIt<LinkLauncher>();
  JobsMeta _meta = JobsMeta.fallback;

  @override
  void initState() {
    super.initState();
    getIt<GetJobsMeta>()(const NoParams()).then((r) {
      if (mounted && r.valueOrNull != null) setState(() => _meta = r.valueOrNull!);
    });
  }

  Widget _topic(String id, String title, String subtitle) => SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: _push.isOn(id),
        onChanged: (v) async {
          tick();
          await _push.setTopic(id, v);
          if (mounted) setState(() {});
        },
      );

  Widget _link(IconData icon, String title, VoidCallback onTap, {bool external = false}) => ListTile(
        leading: Icon(icon, size: 22),
        title: Text(title),
        trailing: Icon(external ? Icons.north_east_rounded : Icons.chevron_right_rounded, size: external ? 18 : 22, color: Palette.of(context).faint),
        onTap: onTap,
      );

  Future<void> _deleteAccount() async {
    final router = GoRouter.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your sign-in, Talent Network profile and resume, jobs you posted, your course registration and saved jobs on this phone. It can\'t be undone.\n\n'
          'If you paid a course fee, we keep the payment record because tax law requires it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.bad),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _deleting = true);
    final r = await getIt<DeleteAccount>()(const NoParams());
    if (!mounted) return;
    setState(() => _deleting = false);
    r.fold(
      (f) => showMessage(context, f.message),
      (msg) {
        showMessage(context, msg);
        router.go('/jobs');
      },
    );
  }

  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), titleSpacing: 0),
      body: ListView(padding: const EdgeInsets.only(bottom: Space.xxxl), children: [
        if (auth.isSignedIn) ...[
          const SectionLabel('Account', padding: EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.sm)),
          Group(children: [
            ListTile(
              leading: Avatar(name: auth.user?.displayName ?? auth.user?.email ?? '?', photo: auth.user?.photoUrl, size: 40),
              title: Text(auth.user?.displayName ?? 'Signed in'),
              subtitle: Text(auth.user?.email ?? ''),
            ),
            _link(Icons.receipt_long_outlined, 'Payments & receipts', () => context.push('/payments')),
            ListTile(
              leading: const Icon(Icons.logout_rounded, size: 22, color: AppColors.bad),
              title: const Text('Sign out', style: TextStyle(color: AppColors.bad)),
              onTap: () async {
                final authCubit = context.read<AuthCubit>();
                final router = GoRouter.of(context);
                await _push.unregisterDevice();
                await authCubit.signOut();
                router.go('/jobs');
              },
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _deleting ? null : _deleteAccount,
                style: TextButton.styleFrom(foregroundColor: Palette.of(context).muted),
                child: BusyLabel(busy: _deleting, label: 'Delete account'),
              ),
            ),
          ),
        ] else ...[
          const SectionLabel('Account', padding: EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.sm)),
          Group(children: [_link(Icons.login_rounded, 'Sign in', () => context.push('/sign-in'))]),
        ],
        const SectionLabel('Notifications'),
        Group(children: [
          _topic('academy', 'Academy updates', 'New batches, offers and class reminders'),
          for (final c in _meta.categories) _topic('jobs-${c.slug}', '${c.name} jobs', 'When new ${c.name} roles go live'),
        ]),
        const SectionLabel('Help'),
        Group(children: [
          _link(Icons.record_voice_over_outlined, 'Mock interviews', () => context.push('/interviews')),
          _link(Icons.chat_bubble_outline_rounded, 'Ask the Widgetry Assistant', () => context.push('/assistant')),
          _link(Icons.chat_rounded, 'WhatsApp us', () => _links.openExternal('https://wa.me/${AppConfig.whatsappNumber}'), external: true),
        ]),
        const SectionLabel('More'),
        Group(children: [
          _link(Icons.business_center_outlined, 'Post a job (employers)', () => _links.openInApp(AppConfig.postJobUrl), external: true),
          _link(Icons.school_outlined, 'Become a mentor or interviewer', () => _links.openInApp('${AppConfig.siteUrl}/pages/apply-mentor.html'), external: true),
          _link(Icons.ios_share_rounded, 'Share the app', () => _links.share('Flutter, Android and iOS jobs, a free ATS resume and live courses: ${AppConfig.siteUrl}')),
          _link(Icons.privacy_tip_outlined, 'Privacy policy', () => _links.openInApp(AppConfig.privacyUrl), external: true),
          _link(Icons.gavel_outlined, 'Terms & posting rules', () => _links.openInApp(AppConfig.termsUrl), external: true),
        ]),
        const SizedBox(height: Space.xxxl),
        const Center(child: Wordmark(suffix: 'Academy', size: 14)),
        const SizedBox(height: Space.sm),
        Center(child: Text('Made in Kolkata', style: t.bodySmall?.copyWith(color: Palette.of(context).faint))),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/notifications/push_service.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
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
          await _push.setTopic(id, v);
          if (mounted) setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        const _Header('Notifications'),
        _topic('academy', 'Academy updates', 'New batches, offers and class reminders'),
        for (final c in _meta.categories) _topic('jobs-${c.slug}', '${c.name} job alerts', 'When new ${c.name} jobs go live'),
        const _Header('Account'),
        if (auth.isSignedIn)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            subtitle: Text(auth.user?.email ?? ''),
            onTap: () async {
              final authCubit = context.read<AuthCubit>();
              final router = GoRouter.of(context);
              await _push.unregisterDevice();
              await authCubit.signOut();
              router.go('/jobs');
            },
          )
        else
          ListTile(leading: const Icon(Icons.login), title: const Text('Sign in'), onTap: () => context.push('/sign-in')),
        const _Header('Widgetry'),
        ListTile(leading: const Icon(Icons.business_center_outlined), title: const Text('Post a job (employers)'), onTap: () => _links.openInApp(AppConfig.postJobUrl)),
        ListTile(leading: const Icon(Icons.chat_outlined), title: const Text('Contact us on WhatsApp'), onTap: () => _links.openExternal('https://wa.me/${AppConfig.whatsappNumber}')),
        ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy policy'), onTap: () => _links.openInApp(AppConfig.privacyUrl)),
        ListTile(leading: const Icon(Icons.gavel_outlined), title: const Text('Terms & posting rules'), onTap: () => _links.openInApp(AppConfig.termsUrl)),
        ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share the app'), onTap: () => _links.share('Find Flutter, Android and iOS jobs and build a free ATS resume: ${AppConfig.siteUrl}')),
        const SizedBox(height: 24),
        Center(child: Text('Widgetry Academy · Kolkata, India', style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
        child: Text(text.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
      );
}

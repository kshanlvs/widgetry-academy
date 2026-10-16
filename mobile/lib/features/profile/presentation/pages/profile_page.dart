import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/services/profile_score.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:widgetry_academy/features/profile/presentation/widgets/photo_picker.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile'), actions: [IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings'))]),
        body: BlocConsumer<ProfileCubit, ProfileState>(
          listenWhen: (a, b) => b.message != null || (b.error != null && b.status != ProfileStatus.failure),
          listener: (context, s) => showMessage(context, s.message ?? s.error!),
          builder: (context, s) => switch (s.status) {
            ProfileStatus.signedOut => EmptyView(
                icon: Icons.badge_outlined,
                title: 'Your profile and resume',
                message: 'Sign in to build an ATS-friendly resume and join the Widgetry Talent Network, where mobile employers find you.',
                action: FilledButton(onPressed: () => context.push('/sign-in?from=/profile'), child: const Text('Sign in')),
              ),
            ProfileStatus.loading => const LoadingView(),
            ProfileStatus.failure => ErrorView(message: s.error ?? 'Could not load your profile.', onRetry: context.read<ProfileCubit>().load),
            ProfileStatus.empty => EmptyView(
                icon: Icons.rocket_launch_outlined,
                title: 'Create your profile',
                message: 'Takes 5 minutes. You get a premium ATS resume and a place in the Talent Network. Private until you say yes.',
                action: FilledButton(onPressed: () => context.push('/profile/edit'), child: const Text('Create my profile')),
              ),
            ProfileStatus.ready => _ProfileView(p: s.profile!, score: s.score!, saving: s.saving),
          },
        ),
      );
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.p, required this.score, required this.saving});
  final Candidate p;
  final ProfileScore score;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<ProfileCubit>();
    const meta = JobsMeta.fallback;

    Future<void> changePhoto() async {
      final bytes = await pickProfilePhoto(context, canRemove: p.photo != null, onRemove: cubit.removePhoto);
      if (bytes != null) await cubit.uploadPhoto(bytes);
    }

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        // Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              GestureDetector(
                onTap: saving ? null : changePhoto,
                child: Stack(children: [
                  Opacity(opacity: saving ? 0.5 : 1, child: Avatar(name: p.fullName, photo: p.photo, size: 104)),
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: CircleAvatar(radius: 17, backgroundColor: Theme.of(context).colorScheme.primary, child: const Icon(Icons.photo_camera, size: 17, color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Text(p.fullName, textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(p.headline, textAlign: TextAlign.center, style: t.titleSmall),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                for (final c in p.categories) CategoryBadge(slug: c, name: meta.categoryName(c)),
                Pill(text: Labels.verification[p.verification] ?? 'Self-declared', color: p.verification == 'self' ? null : AppColors.ok),
                Pill(text: p.openToWork ? '● Open to work' : 'Paused', color: p.openToWork ? AppColors.ok : null),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: () => context.push('/profile/edit'), icon: const Icon(Icons.edit_outlined), label: const Text('Edit'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/profile/resume'), icon: const Icon(Icons.description_outlined), label: const Text('Resume'))),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // Score
        SectionCard(
          title: 'Profile score',
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(child: CircularProgressIndicator(value: score.score / 100, strokeWidth: 9, backgroundColor: AppColors.soft, strokeCap: StrokeCap.round)),
                Text('${score.score}', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(score.level, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (score.tips.isEmpty) const Text('Your profile is complete. Recruiters love this.'),
                for (final tip in score.tips.take(4))
                  InkWell(
                    onTap: tip.action == 'photo' ? changePhoto : (tip.action == 'edit' ? () => context.push('/profile/edit') : null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.radio_button_unchecked, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tip.text, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Card(
          child: SwitchListTile(
            title: const Text('Open to work', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Turn off to pause your profile.'),
            value: p.openToWork,
            onChanged: cubit.setOpenToWork,
          ),
        ),
        const SizedBox(height: 14),
        if ((p.about ?? '').isNotEmpty) ...[SectionCard(title: 'About', child: Text(p.about!)), const SizedBox(height: 14)],
        if (p.skills.isNotEmpty) ...[
          SectionCard(title: 'Skills', child: Wrap(spacing: 6, runSpacing: 6, children: [for (final s in p.skills) Chip(label: Text(s), visualDensity: VisualDensity.compact)])),
          const SizedBox(height: 14),
        ],
        if (p.experience.isNotEmpty) ...[
          SectionCard(
            title: 'Experience',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final w in p.experience)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.role, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${w.company} · ${Fmt.yearMonth(w.start)} – ${Fmt.yearMonth(w.end)}', style: t.bodySmall),
                    for (final b in w.bullets) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $b')),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        if (p.apps.isNotEmpty) ...[
          SectionCard(
            title: 'Apps & projects',
            child: Column(children: [
              for (final a in p.apps)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apps_rounded),
                  title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([a.role, a.about].whereType<String>().where((x) => x.isNotEmpty).join(' · ')),
                ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        if (p.education.isNotEmpty)
          SectionCard(
            title: 'Education',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in p.education)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${e.degree}\n${e.institute}${e.year != null ? ' · ${e.year}' : ''}', style: t.bodyMedium),
                ),
            ]),
          ),
      ]),
    );
  }
}

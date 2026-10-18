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
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')), const SizedBox(width: Space.xs)],
        ),
        body: BlocConsumer<ProfileCubit, ProfileState>(
          listenWhen: (a, b) => b.message != null || (b.error != null && b.status != ProfileStatus.failure),
          listener: (context, s) => showMessage(context, s.message ?? s.error!),
          builder: (context, s) => switch (s.status) {
            ProfileStatus.signedOut => const _Intro(signedIn: false),
            ProfileStatus.loading => const SkeletonList(count: 3, leading: false),
            ProfileStatus.failure => ErrorView(message: s.error ?? 'Could not load your profile.', onRetry: context.read<ProfileCubit>().load),
            ProfileStatus.empty => const _Intro(signedIn: true),
            ProfileStatus.ready => _ProfileView(p: s.profile!, score: s.score!, saving: s.saving),
          },
        ),
      );
}

/// Shown before there is a profile: what you get, then one clear action.
class _Intro extends StatelessWidget {
  const _Intro({required this.signedIn});
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    Widget point(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(icon, size: 20, color: p.accent),
            ),
            const SizedBox(width: Space.md + 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: t.titleSmall), const SizedBox(height: 2), Text(text, style: t.bodySmall)])),
          ]),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxxl), children: [
      Text(signedIn ? 'Create your profile' : 'Your profile and resume', style: t.headlineSmall),
      const SizedBox(height: 6),
      Text('About 5 minutes. Private until you say yes.', style: t.bodyMedium?.copyWith(color: p.muted)),
      const SizedBox(height: Space.xxl),
      point(Icons.description_outlined, 'ATS-friendly resume', 'A clean PDF in three styles, built from your profile. Share or print it any time.'),
      point(Icons.insights_outlined, 'Profile score', 'See exactly what to add to stand out to recruiters.'),
      point(Icons.groups_2_outlined, 'Talent Network', 'Mobile teams find you. We share your profile only with your approval.'),
      const SizedBox(height: Space.md),
      FilledButton(
        onPressed: () => signedIn ? context.push('/profile/edit') : context.push('/sign-in?from=/profile'),
        child: Text(signedIn ? 'Create my profile' : 'Sign in to start'),
      ),
    ]);
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.p, required this.score, required this.saving});
  final Candidate p;
  final ProfileScore score;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pal = Palette.of(context);
    final cubit = context.read<ProfileCubit>();
    const meta = JobsMeta.fallback;

    Future<void> changePhoto() async {
      final bytes = await pickProfilePhoto(context, canRemove: p.photo != null, onRemove: cubit.removePhoto);
      if (bytes != null) await cubit.uploadPhoto(bytes);
    }

    void onTip(ScoreTip tip) => switch (tip.action) {
          'photo' => changePhoto(),
          'edit' => context.push('/profile/edit'),
          _ => null,
        };

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(padding: const EdgeInsets.only(bottom: Space.xxxl), children: [
        // Identity
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, 0),
          child: Row(children: [
            GestureDetector(
              onTap: saving ? null : changePhoto,
              child: Stack(clipBehavior: Clip.none, children: [
                AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: saving ? 0.5 : 1, child: Avatar(name: p.fullName, photo: p.photo, size: 76)),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: pal.surface, shape: BoxShape.circle, border: Border.all(color: pal.line)),
                    child: Icon(Icons.photo_camera_outlined, size: 14, color: pal.ink),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: t.titleLarge),
                const SizedBox(height: 2),
                Text(p.headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: pal.muted)),
                const SizedBox(height: Space.sm),
                Wrap(spacing: Space.md, runSpacing: 4, children: [
                  for (final c in p.categories) CategoryBadge(slug: c, name: meta.categoryName(c)),
                  if (p.verification != 'self')
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, size: 14, color: pal.accent),
                      const SizedBox(width: 4),
                      Text(p.verification == 'verified' ? 'Widgetry verified' : 'Portfolio checked', style: t.bodySmall?.copyWith(color: pal.accent, fontWeight: FontWeight.w600)),
                    ]),
                  if (p.mockInterview != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.record_voice_over_rounded, size: 14, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text('Mock interview ${p.mockInterview!.overall.toStringAsFixed(1)}/5', style: t.bodySmall?.copyWith(color: AppColors.warn, fontWeight: FontWeight.w600)),
                    ]),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: Space.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(children: [
            Expanded(child: FilledButton(onPressed: () => context.push('/profile/resume'), child: const Text('View resume'))),
            const SizedBox(width: Space.sm),
            Expanded(child: OutlinedButton(onPressed: () => context.push('/profile/edit'), child: const Text('Edit profile'))),
          ]),
        ),
        const SizedBox(height: Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Material(
            color: pal.soft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(Radii.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.lg),
              onTap: () => context.push('/interviews'),
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(children: [
                  Icon(Icons.record_voice_over_outlined, color: pal.accent),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Practise with a mock interview', style: t.titleSmall),
                      Text('One-to-one with a working engineer, with a written scorecard', style: t.bodySmall),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: pal.faint),
                ]),
              ),
            ),
          ),
        ),

        // Score
        const SectionLabel('Profile strength'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${score.score}', style: t.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  Padding(padding: const EdgeInsets.only(bottom: 5, left: 2), child: Text('/100', style: t.bodySmall)),
                  const Spacer(),
                  Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(score.level, style: t.bodySmall?.copyWith(color: pal.ink, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: Space.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score.score / 100),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 7, color: score.score >= 65 ? pal.accent : AppColors.gold),
                  ),
                ),
                if (score.tips.isEmpty) ...[
                  const SizedBox(height: Space.md),
                  Text('Your profile is complete. Recruiters notice that.', style: t.bodySmall),
                ] else ...[
                  const SizedBox(height: Space.md),
                  for (final tip in score.tips.take(3))
                    InkWell(
                      onTap: tip.action == 'verify' ? null : () => onTip(tip),
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          Icon(Icons.add_circle_outline_rounded, size: 17, color: pal.accent),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tip.text, style: t.bodyMedium)),
                          if (tip.action != 'verify') Icon(Icons.chevron_right_rounded, size: 20, color: pal.faint),
                        ]),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ),

        // Visibility
        const SectionLabel('Visibility'),
        Group(children: [
          SwitchListTile(
            title: const Text('Open to work'),
            subtitle: Text(p.openToWork ? 'Recruiters can request your profile' : 'Your profile is paused'),
            value: p.openToWork,
            onChanged: saving ? null : cubit.setOpenToWork,
          ),
        ]),

        if ((p.about ?? '').isNotEmpty) ...[
          const SectionLabel('About'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Space.page), child: Text(p.about!, style: t.bodyMedium)),
        ],
        if (p.skills.isNotEmpty) ...[
          const SectionLabel('Skills'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Space.page), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final s in p.skills) Pill(text: s)])),
        ],
        if (p.experience.isNotEmpty) ...[
          const SectionLabel('Experience'),
          Group(children: [
            for (final w in p.experience)
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.role, style: t.titleSmall),
                  Text('${w.company}  ·  ${Fmt.yearMonth(w.start)} – ${Fmt.yearMonth(w.end)}', style: t.bodySmall),
                  for (final b in w.bullets)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: const EdgeInsets.only(top: 8, right: 8), child: Container(width: 4, height: 4, decoration: BoxDecoration(color: pal.faint, shape: BoxShape.circle))),
                        Expanded(child: Text(b, style: t.bodyMedium)),
                      ]),
                    ),
                ]),
              ),
          ]),
        ],
        if (p.apps.isNotEmpty) ...[
          const SectionLabel('Apps & projects'),
          Group(children: [
            for (final a in p.apps)
              ListTile(
                leading: CompanyLogo(name: a.name, size: 38),
                title: Text(a.name),
                subtitle: Text([a.role, a.about].whereType<String>().where((x) => x.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ],
        if (p.education.isNotEmpty) ...[
          const SectionLabel('Education'),
          Group(children: [
            for (final e in p.education)
              ListTile(
                title: Text(e.degree),
                subtitle: Text([e.institute, if (e.year != null) '${e.year}', if ((e.score ?? '').isNotEmpty) e.score!].join(' · ')),
              ),
          ]),
        ],
      ]),
    );
  }
}

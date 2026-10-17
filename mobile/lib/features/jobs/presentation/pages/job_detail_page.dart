import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/presentation/cubit/job_detail_cubit.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/job_card.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/report_sheet.dart';

class JobDetailPage extends StatelessWidget {
  const JobDetailPage({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<JobDetailCubit>()..load(jobId),
        child: BlocConsumer<JobDetailCubit, JobDetailState>(
          listenWhen: (a, b) => b.message != null,
          listener: (context, s) => showMessage(context, s.message!),
          builder: (context, s) {
            final cubit = context.read<JobDetailCubit>();
            final job = s.job;
            final p = Palette.of(context);
            return Scaffold(
              backgroundColor: p.surface,
              appBar: AppBar(
                backgroundColor: p.surface,
                actions: [
                  if (job != null) IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share_rounded, size: 21), onPressed: cubit.share),
                  const SizedBox(width: Space.xs),
                ],
              ),
              body: switch (s.status) {
                DetailStatus.loading => const _DetailSkeleton(),
                DetailStatus.failure => ErrorView(title: 'Job not available', message: s.error ?? 'This job may have been removed.', onRetry: () => cubit.load(jobId)),
                DetailStatus.ready => _Body(job: job!, reported: s.reported),
              },
              bottomNavigationBar: job == null
                  ? null
                  : BottomActionBar(
                      leading: _SaveButton(saved: s.saved, onTap: () {
                        tick();
                        cubit.toggleSave();
                      }),
                      child: job.canApply
                          ? FilledButton(
                              onPressed: cubit.apply,
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text((job.applyUrl ?? '').isNotEmpty ? 'Apply on company site' : 'Apply by email'),
                                const SizedBox(width: 8),
                                const Icon(Icons.north_east_rounded, size: 18),
                              ]),
                            )
                          : FilledButton(onPressed: null, child: Text(job.status == 'filled' ? 'Position filled' : 'Applications closed')),
                    ),
            );
          },
        ),
      );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: 52,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(52, 52)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, key: ValueKey(saved), color: saved ? p.accent : p.ink, semanticLabel: saved ? 'Saved' : 'Save job'),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.job, required this.reported});
  final Job job;
  final bool reported;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final cubit = context.read<JobDetailCubit>();
    final catName = JobsMeta.fallback.categoryName(job.category);
    final salary = job.salary == null ? null : Fmt.salary(min: job.salary!.min, max: job.salary!.max, period: job.salary!.period);

    return ListView(padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxxl), children: [
      Hero(tag: 'logo-${job.id}', child: Align(alignment: Alignment.centerLeft, child: CompanyLogo(name: job.company.name, size: 56))),
      const SizedBox(height: Space.lg),
      Text(job.title, style: t.headlineSmall),
      const SizedBox(height: 6),
      Row(children: [
        Flexible(child: Text(job.company.name, style: t.titleSmall?.copyWith(color: p.muted, fontWeight: FontWeight.w600))),
        if (job.company.verified) ...[
          const SizedBox(width: 5),
          Icon(Icons.verified_rounded, size: 16, color: p.accent),
          const SizedBox(width: 3),
          Text('Verified', style: t.bodySmall?.copyWith(color: p.accent, fontWeight: FontWeight.w600)),
        ],
      ]),
      const SizedBox(height: Space.md),
      Row(children: [
        CategoryBadge(slug: job.category, name: catName),
        if (job.postedAt != null) ...[const SizedBox(width: Space.md), Text('Posted ${Fmt.timeAgo(job.postedAt)}', style: t.bodySmall?.copyWith(color: p.faint))],
        if (job.featured) ...[const SizedBox(width: Space.md), Text('Featured', style: t.bodySmall?.copyWith(color: AppColors.warn, fontWeight: FontWeight.w700))],
      ]),
      if (!job.isOpen) ...[
        const SizedBox(height: Space.lg),
        _Notice(icon: Icons.do_not_disturb_on_outlined, color: AppColors.warn, text: job.status == 'filled' ? 'This position has been filled.' : 'This job is no longer accepting applications.'),
      ],
      const SizedBox(height: Space.xl),
      Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.lg)),
        child: Column(children: [
          Row(children: [
            Expanded(child: Fact(icon: Icons.place_outlined, label: 'Location', value: job.mode == 'remote' ? 'Remote (India)' : JobCard.whereText(job))),
            Expanded(child: Fact(icon: Icons.work_outline_rounded, label: 'Job type', value: Labels.jobType[job.type] ?? job.type)),
          ]),
          const SizedBox(height: Space.lg),
          Row(children: [
            Expanded(child: Fact(icon: Icons.stairs_outlined, label: 'Experience', value: Labels.level[job.level] ?? job.level)),
            Expanded(child: Fact(icon: Icons.payments_outlined, label: 'Salary', value: salary ?? 'Not disclosed')),
          ]),
        ]),
      ),
      if (job.skills.isNotEmpty) ...[
        const SizedBox(height: Space.xxl),
        Text('Skills', style: t.titleSmall),
        const SizedBox(height: Space.sm + 2),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final s in job.skills) Pill(text: s)]),
      ],
      const SizedBox(height: Space.xxl),
      Text('About the role', style: t.titleSmall),
      const SizedBox(height: Space.sm),
      SelectableText(job.description ?? '', style: t.bodyLarge?.copyWith(height: 1.65, color: p.ink.withValues(alpha: 0.88))),
      const SizedBox(height: Space.xxl),
      Divider(color: p.line),
      const SizedBox(height: Space.lg),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.shield_outlined, size: 20, color: p.accent),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Never pay to get a job', style: t.titleSmall),
            const SizedBox(height: 2),
            Text('Widgetry never charges job seekers, and neither should an employer. If anyone asks for money, report it.', style: t.bodySmall),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: reported
                  ? null
                  : () async {
                      final r = await showReportSheet(context);
                      if (r != null) await cubit.report(r.$1, r.$2);
                    },
              child: Text(reported ? 'Reported. Thank you.' : 'Report this job'),
            ),
          ]),
        ),
      ]),
    ]);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: color.withValues(alpha: 0.22))),
        child: Row(children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => const Shimmer(
        child: Padding(
          padding: EdgeInsets.fromLTRB(Space.page, 0, Space.page, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 56, height: 56, radius: 14),
            SizedBox(height: Space.lg),
            SkeletonBox(width: 260, height: 22),
            SizedBox(height: 10),
            SkeletonBox(width: 140, height: 14),
            SizedBox(height: Space.xl),
            SkeletonBox(height: 120, radius: 16),
            SizedBox(height: Space.xxl),
            SkeletonBox(width: 90, height: 14),
            SizedBox(height: 12),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 220, height: 12),
          ]),
        ),
      );
}

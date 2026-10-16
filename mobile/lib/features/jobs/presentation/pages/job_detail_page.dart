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
            return Scaffold(
              appBar: AppBar(actions: [
                if (job != null) ...[
                  IconButton(tooltip: s.saved ? 'Remove from saved' : 'Save job', icon: Icon(s.saved ? Icons.bookmark : Icons.bookmark_outline), onPressed: cubit.toggleSave),
                  IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share), onPressed: cubit.share),
                ],
              ]),
              body: switch (s.status) {
                DetailStatus.loading => const LoadingView(),
                DetailStatus.failure => ErrorView(message: s.error ?? 'This job is not available.', onRetry: () => cubit.load(jobId)),
                DetailStatus.ready => _Body(job: job!, reported: s.reported),
              },
              bottomNavigationBar: job == null
                  ? null
                  : SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: job.canApply
                            ? FilledButton.icon(onPressed: cubit.apply, icon: const Icon(Icons.open_in_new), label: Text((job.applyUrl ?? '').isNotEmpty ? 'Apply on company site' : 'Apply by email'))
                            : FilledButton(onPressed: null, child: Text(job.status == 'filled' ? 'Position filled' : 'No longer accepting applications')),
                      ),
                    ),
            );
          },
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.job, required this.reported});
  final Job job;
  final bool reported;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<JobDetailCubit>();
    final where = job.mode == 'remote' ? 'Remote (India)' : '${job.city ?? ''} · ${Labels.workMode[job.mode] ?? job.mode}';
    final catName = JobsMeta.fallback.categoryName(job.category);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CompanyLogo(name: job.company.name, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job.title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 4),
            Row(children: [
              Flexible(child: Text(job.company.name, style: t.titleMedium)),
              if (job.company.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 18, color: AppColors.ok)),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 6, runSpacing: 6, children: [
        CategoryBadge(slug: job.category, name: catName),
        Pill(text: Labels.jobType[job.type] ?? job.type, icon: Icons.work_outline),
        Pill(text: where, icon: Icons.place_outlined),
        Pill(text: Labels.level[job.level] ?? job.level, icon: Icons.trending_up),
        if (job.postedAt != null) Pill(text: 'Posted ${Fmt.timeAgo(job.postedAt)}', icon: Icons.schedule),
      ]),
      if (job.salary != null) ...[
        const SizedBox(height: 14),
        Text(Fmt.salary(min: job.salary!.min, max: job.salary!.max, period: job.salary!.period), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.green)),
      ],
      if (!job.isOpen) ...[
        const SizedBox(height: 14),
        Card(
          color: AppColors.warn.withValues(alpha: 0.08),
          child: Padding(padding: const EdgeInsets.all(14), child: Text(job.status == 'filled' ? 'This position has been filled.' : 'This job is no longer accepting applications.', style: const TextStyle(fontWeight: FontWeight.w700))),
        ),
      ],
      if (job.skills.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('Skills', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final s in job.skills) Chip(label: Text(s), visualDensity: VisualDensity.compact)]),
      ],
      const SizedBox(height: 18),
      Text('About the role', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      SelectableText(job.description ?? '', style: t.bodyLarge?.copyWith(height: 1.55)),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🛡️ Stay safe', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Never pay anyone to get a job or an interview. Widgetry never charges job seekers.'),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: reported
                  ? null
                  : () async {
                      final r = await showReportSheet(context);
                      if (r != null) await cubit.report(r.$1, r.$2);
                    },
              icon: const Icon(Icons.flag_outlined),
              label: Text(reported ? 'Reported. Thank you.' : 'Report this job'),
            ),
          ]),
        ),
      ),
    ]);
  }
}

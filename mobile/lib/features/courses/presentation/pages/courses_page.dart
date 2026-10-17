import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'ask',
          onPressed: () => context.push('/assistant'),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
          label: const Text('Ask a question'),
        ),
        body: BlocBuilder<CoursesCubit, CoursesState>(
          builder: (context, s) {
            final cubit = context.read<CoursesCubit>();
            final t = Theme.of(context).textTheme;
            final p = Palette.of(context);
            final open = s.courses.where((c) => c.isOpen).toList()..sort((a, b) => (b.flagship ? 1 : 0) - (a.flagship ? 1 : 0));
            final soon = s.courses.where((c) => !c.isOpen).toList();
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: CustomScrollView(slivers: [
                const SliverAppBar(floating: true, snap: true, title: Wordmark(suffix: 'Academy', size: 17)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.xl),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Learn to build real apps', style: t.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Live weekend classes, taught by engineers who ship apps for a living.', style: t.bodyMedium?.copyWith(color: p.muted)),
                    ]),
                  ),
                ),
                if (s.loading && s.courses.isEmpty)
                  const SliverFillRemaining(hasScrollBody: true, child: SkeletonList(count: 2, leading: false))
                else if (s.courses.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: ErrorView(message: s.error ?? 'No courses right now.', onRetry: cubit.load))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 110),
                    sliver: SliverList.list(children: [
                      if (s.registration != null) ...[_RegisteredBanner(reg: s.registration!), const SizedBox(height: Space.lg)],
                      for (final c in open) ...[_FeaturedCourse(course: c, batch: c.showBatch || c.flagship ? s.batch : const BatchInfo()), const SizedBox(height: Space.lg)],
                      if (soon.isNotEmpty) const SectionLabel('Coming soon', padding: EdgeInsets.fromLTRB(4, Space.sm, 4, Space.sm)),
                      for (final c in soon) ...[_CourseRow(course: c), const SizedBox(height: Space.md)],
                    ]),
                  ),
              ]),
            );
          },
        ),
      );
}

class _RegisteredBanner extends StatelessWidget {
  const _RegisteredBanner({required this.reg});
  final Registration reg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: AppColors.ok.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: AppColors.ok.withValues(alpha: 0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 22),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("You're registered for ${reg.course.isEmpty ? 'Flutter in 10 Days' : reg.course}", style: t.titleSmall),
            const SizedBox(height: 2),
            Text(reg.isPaid ? 'Payment received. Batch details come on WhatsApp.' : 'Next step: pay to confirm your seat.', style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

/// Open course: deep green card like the website hero, with batch and price.
class _FeaturedCourse extends StatelessWidget {
  const _FeaturedCourse({required this.course, required this.batch});
  final Course course;
  final BatchInfo batch;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final c = course;
    final when = [batch.days, batch.time, batch.mode].whereType<String>().where((x) => x.isNotEmpty).join(' · ');
    return Material(
      color: p.hero,
      borderRadius: BorderRadius.circular(Radii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/courses/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text((c.badge ?? (c.flagship ? 'Flagship course' : 'Now enrolling')).replaceAll('★', '').trim().toUpperCase(),
                  style: t.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.1)),
              const Spacer(),
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.greenBright, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Enrolling', style: t.bodySmall?.copyWith(color: p.onHeroMuted, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: Space.md),
            Text(c.title, style: AppTheme.display(size: 24, color: Colors.white)),
            if (c.tagline != null) ...[const SizedBox(height: Space.sm), Text(c.tagline!, style: t.bodyMedium?.copyWith(color: p.onHeroMuted))],
            if (c.meta != null) ...[const SizedBox(height: Space.sm), Text(c.meta!, style: t.bodySmall?.copyWith(color: p.onHeroMuted, fontWeight: FontWeight.w600))],
            if (!batch.isEmpty) ...[
              const SizedBox(height: Space.lg),
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                child: Row(children: [
                  const Icon(Icons.event_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(batch.startDate == null ? (batch.name ?? 'Next batch') : 'Next batch starts ${batch.startDate}', style: t.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      if (when.isNotEmpty) Text(when, style: t.bodySmall?.copyWith(color: p.onHeroMuted)),
                    ]),
                  ),
                ]),
              ),
              if (batch.seatsLeft != null) Padding(padding: const EdgeInsets.only(top: Space.sm), child: Text('${batch.seatsLeft} early-bird seats left', style: t.bodySmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700))),
            ],
            const SizedBox(height: Space.lg),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (c.price != null) ...[
                Text(Fmt.rupees(c.price!), style: AppTheme.display(size: 20, color: Colors.white, weight: FontWeight.w600)),
                if (c.mrp != null && c.mrp! > c.price!) ...[
                  const SizedBox(width: Space.sm),
                  Text(Fmt.rupees(c.mrp!), style: t.bodyMedium?.copyWith(color: p.onHeroMuted, decoration: TextDecoration.lineThrough, decorationColor: p.onHeroMuted)),
                ],
              ],
              const Spacer(),
              Text('View course', style: t.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final c = course;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/courses/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: t.titleMedium),
                if (c.tagline != null || c.meta != null) ...[
                  const SizedBox(height: 4),
                  Text(c.tagline ?? c.meta!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ],
              ]),
            ),
            const SizedBox(width: Space.md),
            const Pill(text: 'Coming soon'),
          ]),
        ),
      ),
    );
  }
}

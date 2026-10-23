import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/courses/presentation/widgets/my_course.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'ask',
          onPressed: () => context.push('/tutor'),
          icon: const Icon(Icons.auto_awesome_rounded, size: 20),
          label: const Text('Ask Widgetry Tutor'),
        ),
        body: BlocBuilder<CoursesCubit, CoursesState>(
          builder: (context, s) {
            final cubit = context.read<CoursesCubit>();
            final t = Theme.of(context).textTheme;
            final p = Palette.of(context);
            final mine = s.myCourse;
            final reg = s.registration;
            final shorts = s.myShortCourses;
            final boughtSlugs = {for (final c in shorts) c.slug};
            final learning = mine != null || shorts.isNotEmpty;
            // Once registered or bought, the course's sales card is replaced by "My course"
            final open = s.courses.where((c) => c.isOpen && c.id != mine?.id && !boughtSlugs.contains(c.shortSlug)).toList()..sort((a, b) => (b.flagship ? 1 : 0) - (a.flagship ? 1 : 0));
            final soon = s.courses.where((c) => !c.isOpen).toList();
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: CustomScrollView(slivers: [
                const SliverAppBar(floating: true, snap: true, title: Wordmark(suffix: 'Academy', size: 17)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.xl),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(learning ? 'Your learning' : 'Learn to build real apps', style: t.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        learning ? 'Everything for your courses in one place.' : 'Live weekend classes, taught by engineers who ship apps for a living.',
                        style: t.bodyMedium?.copyWith(color: p.muted),
                      ),
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
                      if (mine != null && reg != null) ...[
                        MyCourseCard(course: mine, reg: reg, batch: s.batch),
                        const SizedBox(height: Space.md),
                        if (stageOf(reg) != EnrolmentStage.registered) ...[StartChecklist(course: mine, reg: reg, batch: s.batch), const SizedBox(height: Space.md)],
                      ],
                      for (final c in shorts) ...[MyShortCourseCard(course: c), const SizedBox(height: Space.md)],
                      if (learning && (open.isNotEmpty || soon.isNotEmpty)) const SectionLabel('Explore more courses', padding: EdgeInsets.fromLTRB(4, Space.lg, 4, Space.sm)),
                      for (final c in open) ...[_FeaturedCourse(course: c, batch: c.usesBatch ? s.batch : const BatchInfo()), const SizedBox(height: Space.lg)],
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

/// The start date on a course card ("Starts Sat 8 Nov…", "Dates coming soon").
class _DateBox extends StatelessWidget {
  const _DateBox({required this.line});
  final String line;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Row(children: [
          const Icon(Icons.event_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: Space.md),
          Expanded(child: Text(line, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      );
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
              Container(width: 7, height: 7, decoration: BoxDecoration(color: c.enrolling ? AppColors.greenBright : AppColors.gold, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(c.enrolling ? 'Enrolling' : (c.live?.tag ?? 'Dates soon'), style: t.bodySmall?.copyWith(color: p.onHeroMuted, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: Space.md),
            Text(c.title, style: AppTheme.display(size: 24, color: Colors.white)),
            if (c.tagline != null) ...[const SizedBox(height: Space.sm), Text(c.tagline!, style: t.bodyMedium?.copyWith(color: p.onHeroMuted))],
            if (c.meta != null) ...[const SizedBox(height: Space.sm), Text(c.meta!, style: t.bodySmall?.copyWith(color: p.onHeroMuted, fontWeight: FontWeight.w600))],
            if (c.dateLine != null) ...[
              const SizedBox(height: Space.lg),
              _DateBox(line: c.dateLine!),
            ] else if (!batch.isEmpty) ...[
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

/// A short course the student paid for: dates, class link and receipts.
class MyShortCourseCard extends StatelessWidget {
  const MyShortCourseCard({super.key, required this.course});
  final EnrolledCourse course;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final c = course;
    final when = c.schedule ?? (c.startsAt == null ? null : 'Starts ${Fmt.date(c.startsAt!)}');
    final countdown = c.startsAt == null ? null : Fmt.countdown(c.startsAt!);
    final path = c.appPath;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          color: p.hero,
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('MY COURSE', style: t.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.ok.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                child: Text(c.status == 'booked' ? 'Seat booked' : 'Enrolled', style: t.bodySmall?.copyWith(color: AppColors.greenBright, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: Space.md),
            Text(c.title, style: AppTheme.display(size: 22, color: Colors.white)),
            if (when != null) ...[
              const SizedBox(height: Space.md),
              Row(children: [
                const Icon(Icons.event_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(when, style: t.bodySmall?.copyWith(color: p.onHeroMuted, height: 1.45))),
                if (countdown != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.sm)),
                    child: Text(countdown, style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
          child: Column(children: [
            if (c.meetingLink != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => getIt<LinkLauncher>().openExternal(c.meetingLink!),
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: const Text('Join class'),
                ),
              )
            else if (path != null)
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.push(path), child: const Text('Open course'))),
            const SizedBox(height: Space.xs),
            Row(children: [
              if (c.meetingLink != null && path != null) Expanded(child: TextButton.icon(onPressed: () => context.push(path), icon: const Icon(Icons.info_outline_rounded, size: 18), label: const Text('Course details'))),
              Expanded(child: TextButton.icon(onPressed: () => context.push('/payments'), icon: const Icon(Icons.receipt_long_outlined, size: 18), label: const Text('Receipts'))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

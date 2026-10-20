import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/courses/presentation/widgets/my_course.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/job_card.dart';

/// Course banners on the home screen. A registered student sees their own course
/// (what to do next); everyone else sees the open courses, swipeable.
class CourseBanners extends StatefulWidget {
  const CourseBanners({super.key});
  @override
  State<CourseBanners> createState() => _CourseBannersState();
}

class _CourseBannersState extends State<CourseBanners> {
  final _page = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CoursesCubit, CoursesState>(
        builder: (context, s) {
          final mine = s.myCourse, reg = s.registration;
          if (mine != null && reg != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
              child: _MyCourseBanner(course: mine, reg: reg, batch: s.batch),
            );
          }
          final open = s.courses.where((c) => c.isOpen).toList()..sort((a, b) => (b.flagship ? 1 : 0) - (a.flagship ? 1 : 0));
          if (open.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: Column(children: [
              SizedBox(
                height: 176,
                child: PageView.builder(
                  controller: _page,
                  padEnds: open.length == 1,
                  itemCount: open.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Padding(
                    padding: EdgeInsets.only(left: i == 0 && open.length > 1 ? Space.lg - 6 : 6, right: 6),
                    child: _CourseBanner(course: open[i], batch: open[i].usesBatch ? s.batch : const BatchInfo()),
                  ),
                ),
              ),
              if (open.length > 1) ...[
                const SizedBox(height: Space.sm),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < open.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(color: i == _index ? Palette.of(context).accent : Palette.of(context).line, borderRadius: BorderRadius.circular(3)),
                    ),
                ]),
              ],
            ]),
          );
        },
      );
}

class _CourseBanner extends StatelessWidget {
  const _CourseBanner({required this.course, required this.batch});
  final Course course;
  final BatchInfo batch;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final c = course;
    final line = [
      if (c.dateLine != null) c.dateLine! else if (batch.startDate != null) 'Next batch ${batch.startDate}' else if (c.meta != null) c.meta!,
      if (c.price != null) Fmt.rupees(c.price!),
    ].join('  ·  ');
    return Material(
      color: p.hero,
      borderRadius: BorderRadius.circular(Radii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/courses/${c.id}'),
        child: Stack(children: [
          // Brand mark, large and faint, so the banner doesn't look like a plain box
          const Positioned(right: -18, bottom: -18, child: Opacity(opacity: 0.12, child: BrandMark(size: 120, onDark: true))),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((c.badge ?? (c.flagship ? 'Flagship course' : 'Now enrolling')).replaceAll('★', '').trim().toUpperCase(),
                  style: t.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.1)),
              const SizedBox(height: Space.sm),
              Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(size: 21, color: Colors.white)),
              if (c.tagline != null) ...[
                const SizedBox(height: 4),
                Text(c.tagline!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: p.onHeroMuted, height: 1.4)),
              ],
              const Spacer(),
              Row(children: [
                Expanded(child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
                if (batch.seatsLeft != null && batch.seatsLeft! > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                    child: Text('${batch.seatsLeft} seats left', style: t.bodySmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// For a registered student: their course and the one thing to do next.
class _MyCourseBanner extends StatelessWidget {
  const _MyCourseBanner({required this.course, required this.reg, required this.batch});
  final Course course;
  final Registration reg;
  final BatchInfo batch;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final stage = stageOf(reg);
    final start = Fmt.looseDate(batch.startDate);
    final countdown = start == null ? null : Fmt.countdown(start);
    final (status, action, route) = switch (stage) {
      EnrolmentStage.enrolled => (countdown == null ? 'Seat confirmed' : 'Seat confirmed · $countdown', 'Open', '/courses/${course.id}'),
      EnrolmentStage.booked => ('Seat booked · balance due', 'Pay balance', '/courses/${course.id}/pay'),
      EnrolmentStage.registered => ('Payment pending', 'Pay now', '/courses/${course.id}/pay'),
    };
    return Material(
      color: p.hero,
      borderRadius: BorderRadius.circular(Radii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => stage == EnrolmentStage.enrolled ? context.go(route) : context.push(route),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
          child: Row(children: [
            const BrandMark(size: 34, onDark: true),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MY COURSE', style: t.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.1)),
                const SizedBox(height: 2),
                Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(color: Colors.white)),
                Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: stage == EnrolmentStage.enrolled ? AppColors.greenBright : AppColors.gold, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: Space.sm),
            FilledButton(
              onPressed: () => stage == EnrolmentStage.enrolled ? context.go(route) : context.push(route),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.deep, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 14)),
              child: Text(action),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Featured jobs as a horizontal row of compact cards.
class FeaturedJobsRow extends StatelessWidget {
  const FeaturedJobsRow({super.key, required this.jobs, required this.categoryName});
  final List<Job> jobs;
  final String Function(String slug) categoryName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, Space.sm),
        child: Row(children: [
          const Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
          const SizedBox(width: 6),
          Text('Featured jobs', style: t.titleSmall),
          const Spacer(),
          Text('${jobs.length}', style: t.bodySmall?.copyWith(color: p.faint)),
        ]),
      ),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(width: Space.md),
          itemBuilder: (context, i) => _FeaturedCard(job: jobs[i], categoryName: categoryName(jobs[i].category)),
        ),
      ),
    ]);
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.job, required this.categoryName});
  final Job job;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final salary = job.salary == null ? '' : Fmt.salary(min: job.salary!.min, max: job.salary!.max, period: job.salary!.period, short: true);
    return SizedBox(
      width: 268,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: AppColors.gold.withValues(alpha: 0.7), width: 1.3)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/jobs/${job.id}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CompanyLogo(name: job.company.name, size: 36),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Row(children: [
                    Flexible(child: Text(job.company.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: p.muted, fontWeight: FontWeight.w600))),
                    if (job.company.verified) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 14, color: p.accent)),
                  ]),
                ),
              ]),
              const SizedBox(height: Space.md),
              Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(height: 1.3)),
              const Spacer(),
              Row(children: [
                CategoryBadge(slug: job.category, name: categoryName),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    salary.isNotEmpty ? salary : JobCard.whereText(job),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: t.bodySmall?.copyWith(color: p.ink, fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Mock interview with a working engineer" on the home screen.
class MockInterviewTile extends StatelessWidget {
  const MockInterviewTile({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/interviews'),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.md)),
                child: const Icon(Icons.record_voice_over_rounded, color: AppColors.warn, size: 22),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mock interview with a working engineer', style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text('One-to-one video call and a written scorecard', style: t.bodySmall),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: p.faint),
            ]),
          ),
        ),
      ),
    );
  }
}

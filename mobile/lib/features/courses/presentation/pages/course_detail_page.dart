import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/workshops/presentation/workshop_page.dart' show shortCourseSlug;

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({super.key, required this.courseId});
  final String courseId;

  /// Where to pay: the course's own payment link if it has one, otherwise the fees section on the website.
  static String paymentLink(Course c) {
    final l = c.ctaLink ?? '';
    if (l.startsWith('https://')) return l;
    if (RegExp(r'^[\w./-]+\.html(#[\w-]+)?$').hasMatch(l)) return '${AppConfig.siteUrl}/$l';
    return '${AppConfig.siteUrl}/#fees';
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CoursesCubit, CoursesState>(
        builder: (context, s) {
          final c = s.byId(courseId);
          if (c == null) return Scaffold(appBar: AppBar(), body: s.loading ? const LoadingView() : const ErrorView(title: 'Course not found', message: 'This course is not available any more.'));
          final t = Theme.of(context).textTheme;
          final p = Palette.of(context);
          final links = getIt<LinkLauncher>();
          final registered = s.registration != null && s.myCourse?.id == c.id;
          final showBatch = c.usesBatch && !s.batch.isEmpty;
          final when = [s.batch.days, s.batch.time, s.batch.mode].whereType<String>().where((x) => x.isNotEmpty).join(' · ');

          return Scaffold(
            backgroundColor: p.surface,
            body: CustomScrollView(slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: p.hero,
                foregroundColor: Colors.white,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                actions: [
                  IconButton(tooltip: 'Ask a question', icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21), onPressed: () => context.push('/assistant')),
                  IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share_rounded, size: 21), onPressed: () => links.share('${c.title} at Widgetry Academy\n${AppConfig.siteUrl}/#courses')),
                  const SizedBox(width: Space.xs),
                ],
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: p.hero,
                  padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.xxl),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      (c.isOpen ? (c.badge ?? 'Now enrolling') : 'Coming soon').replaceAll('★', '').trim().toUpperCase(),
                      style: t.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: Space.md),
                    Text(c.title, style: AppTheme.display(size: 28, color: Colors.white)),
                    if (c.tagline != null) ...[const SizedBox(height: Space.md), Text(c.tagline!, style: t.bodyLarge?.copyWith(color: p.onHeroMuted, height: 1.5))],
                    if (c.meta != null) ...[const SizedBox(height: Space.md), Text(c.meta!, style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))],
                    if (c.tags.isNotEmpty) ...[
                      const SizedBox(height: Space.lg),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final tag in c.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                            child: Text(tag, style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                      ]),
                    ],
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, Space.xxxl),
                sliver: SliverList.list(children: [
                  if (registered) ...[
                    _Note(
                        icon: s.registration!.isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                        color: s.registration!.isPaid ? AppColors.ok : AppColors.warn,
                        title: s.registration!.isPaid ? "You're enrolled" : s.registration!.isPartPaid ? 'Seat booked' : "You're registered",
                        text: s.registration!.isPaid
                            ? 'Payment received. See you in class.'
                            : s.registration!.isPartPaid
                                ? 'Seat booked with ${Fmt.rupees(s.registration!.amountPaid)}. Pay the balance before the course starts.'
                                : 'Pay to confirm your seat. Seats are held for a short time.'),
                    const SizedBox(height: Space.xl),
                  ],
                  if (c.dateLine != null) ...[
                    Container(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.lg)),
                      child: Fact(icon: Icons.event_rounded, label: c.enrolling ? 'Next batch' : (c.live?.tag ?? 'Next batch'), value: c.dateLine!),
                    ),
                    const SizedBox(height: Space.xxl),
                  ] else if (showBatch) ...[
                    Container(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.lg)),
                      child: Column(children: [
                        Fact(icon: Icons.event_rounded, label: s.batch.name ?? 'Next batch', value: s.batch.startDate == null ? 'Dates announced soon' : 'Starts ${s.batch.startDate}'),
                        if (when.isNotEmpty) ...[const SizedBox(height: Space.md), Fact(icon: Icons.schedule_rounded, label: 'Schedule', value: when)],
                        if (s.batch.demo != null) ...[const SizedBox(height: Space.md), Fact(icon: Icons.play_circle_outline_rounded, label: 'Free demo', value: s.batch.demo!)],
                        if (s.batch.seatsLeft != null) ...[const SizedBox(height: Space.md), Fact(icon: Icons.event_seat_outlined, label: 'Early-bird seats', value: '${s.batch.seatsLeft} left')],
                      ]),
                    ),
                    const SizedBox(height: Space.xxl),
                  ],
                  if (c.steps.isNotEmpty) ...[
                    Text("What you'll learn", style: t.titleLarge),
                    const SizedBox(height: Space.lg),
                    for (final (i, st) in c.steps.indexed) _Step(index: i + 1, step: st, last: i == c.steps.length - 1),
                    const SizedBox(height: Space.lg),
                  ],
                  if (c.outcome != null) ...[
                    _Note(icon: Icons.flag_outlined, color: p.accent, title: 'You finish with', text: c.outcome!),
                    const SizedBox(height: Space.xxl),
                  ],
                  if (c.mentorName != null) ...[
                    Text('Your mentor', style: t.titleLarge),
                    const SizedBox(height: Space.md),
                    Row(children: [
                      Avatar(name: c.mentorName!, size: 52),
                      const SizedBox(width: Space.md + 2),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.mentorName!, style: t.titleMedium),
                          if (c.mentorLine != null) Text(c.mentorLine!, style: t.bodySmall),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: Space.xxl),
                  ],
                  Divider(color: p.line),
                  const SizedBox(height: Space.sm),
                  if (c.brochureUrl(AppConfig.siteUrl) case final String pdf)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.picture_as_pdf_outlined, color: p.accent),
                      title: const Text('Download syllabus'),
                      subtitle: const Text('Full syllabus and brochure (PDF)'),
                      trailing: Icon(Icons.download_rounded, size: 20, color: p.faint),
                      onTap: () => links.openExternal(pdf),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat_rounded, color: AppColors.whatsapp),
                    title: const Text('Talk to us on WhatsApp'),
                    subtitle: const Text('Usually replies within a few hours'),
                    trailing: Icon(Icons.north_east_rounded, size: 18, color: p.faint),
                    onTap: () => links.openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I have a question about ${c.title}')}'),
                  ),
                ]),
              ),
            ]),
            bottomNavigationBar: !c.isOpen
                ? null
                : BottomActionBar(
                    leading: c.price == null || registered
                        ? null
                        : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(Fmt.rupees(c.price!), style: t.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                            if (c.mrp != null && c.mrp! > c.price!)
                              Text(Fmt.rupees(c.mrp!), style: t.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: p.faint))
                            else if (c.priceNote != null)
                              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: Text(c.priceNote!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall)),
                          ]),
                    child: shortCourseSlug(c.ctaLink) != null
                        ? FilledButton(
                            onPressed: () => context.push('/short-courses/${shortCourseSlug(c.ctaLink)}'),
                            child: Text(s.myShortCourses.any((m) => m.slug == shortCourseSlug(c.ctaLink)) ? "You're enrolled · Open course" : 'See dates & enrol'),
                          )
                        : registered
                        ? (s.registration!.isPaid || s.registration!.isClosed
                            ? OutlinedButton.icon(
                                onPressed: () => context.push('/payments'),
                                icon: const Icon(Icons.receipt_long_outlined, size: 19),
                                label: const Text('Orders & receipts'),
                              )
                            : FilledButton(
                                onPressed: () => context.push('/courses/${c.id}/pay'),
                                child: Text(s.registration!.isPartPaid ? 'Pay the balance' : 'Pay & confirm seat'),
                              ))
                        : FilledButton(
                            onPressed: () => s.signedIn ? context.push('/courses/${c.id}/register') : context.push('/sign-in?from=${Uri.encodeComponent('/courses/${c.id}/register')}'),
                            child: const Text('Reserve my seat'),
                          ),
                  ),
          );
        },
      );
}

/// Numbered timeline row for the curriculum.
class _Step extends StatelessWidget {
  const _Step({required this.index, required this.step, required this.last});
  final int index;
  final CourseStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 30,
          child: Column(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
              child: Text('$index', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            if (!last) Expanded(child: Container(width: 1.5, margin: const EdgeInsets.symmetric(vertical: 4), color: p.line)),
          ]),
        ),
        const SizedBox(width: Space.md + 2),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: last ? 0 : Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.title, style: t.titleSmall),
              if (step.detail.isNotEmpty) ...[const SizedBox(height: 3), Text(step.detail, style: t.bodyMedium?.copyWith(color: p.muted))],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.title, required this.text});
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 21, color: color),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall),
            const SizedBox(height: 2),
            Text(text, style: t.bodyMedium),
          ]),
        ),
      ]),
    );
  }
}

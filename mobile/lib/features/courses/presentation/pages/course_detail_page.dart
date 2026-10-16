import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';

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
          if (c == null) return Scaffold(appBar: AppBar(), body: s.loading ? const LoadingView() : const ErrorView(message: 'This course is not available.'));
          final t = Theme.of(context).textTheme;
          final links = getIt<LinkLauncher>();
          final registered = s.registration != null;
          return Scaffold(
            appBar: AppBar(actions: [IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share), onPressed: () => links.share('${c.title} at Widgetry Academy\n${AppConfig.siteUrl}/#courses'))]),
            body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
              if (c.isOpen) Text(c.badge ?? '★ Enrolling now', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(c.title, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              if (c.meta != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.meta!, style: t.titleSmall)),
              if (c.tagline != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(c.tagline!, style: t.bodyLarge)),
              if (c.showBatch && !s.batch.isEmpty) ...[
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_rounded),
                    title: Text(s.batch.startDate == null ? 'Next batch' : 'Starts ${s.batch.startDate}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([s.batch.days, s.batch.time, s.batch.mode].whereType<String>().join(' · ')),
                  ),
                ),
              ],
              if (c.tags.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in c.tags) Pill(text: tag)])],
              if (c.steps.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text("What you'll learn", style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final (i, st) in c.steps.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 15, backgroundColor: AppColors.green, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    title: Text(st.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: st.detail.isEmpty ? null : Text(st.detail),
                  ),
              ],
              if (c.outcome != null) ...[
                const SizedBox(height: 16),
                SectionCard(title: 'You finish with', child: Text(c.outcome!)),
              ],
              if (c.mentorName != null) ...[
                const SizedBox(height: 14),
                Card(child: ListTile(leading: Avatar(name: c.mentorName!, size: 44), title: Text(c.mentorName!, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: c.mentorLine == null ? null : Text(c.mentorLine!))),
              ],
              if (c.price != null && c.isOpen) ...[
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.rupees(c.price!), style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  if (c.mrp != null) Padding(padding: const EdgeInsets.only(left: 10, bottom: 4), child: Text(Fmt.rupees(c.mrp!), style: const TextStyle(decoration: TextDecoration.lineThrough))),
                ]),
                if (c.priceNote != null) Text(c.priceNote!, style: t.bodySmall),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => links.openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I have a question about ${c.title}')}'),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Ask a question on WhatsApp'),
              ),
            ]),
            bottomNavigationBar: !c.isOpen
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: registered
                          ? FilledButton.icon(onPressed: () => links.openInApp(paymentLink(c)), icon: const Icon(Icons.lock_outline), label: const Text('Pay & confirm my seat'))
                          : FilledButton(
                              onPressed: () => s.signedIn ? context.push('/courses/${c.id}/register') : context.push('/sign-in?from=${Uri.encodeComponent('/courses/${c.id}/register')}'),
                              child: const Text('Reserve my seat'),
                            ),
                    ),
                  ),
          );
        },
      );
}

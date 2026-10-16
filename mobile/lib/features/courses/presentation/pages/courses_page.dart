import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Courses')),
        body: BlocBuilder<CoursesCubit, CoursesState>(
          builder: (context, s) {
            if (s.loading && s.courses.isEmpty) return const LoadingView();
            if (s.courses.isEmpty) return ErrorView(message: s.error ?? 'No courses right now.', onRetry: context.read<CoursesCubit>().load);
            return RefreshIndicator(
              onRefresh: context.read<CoursesCubit>().load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
                if (s.registration != null) ...[_RegisteredCard(reg: s.registration!), const SizedBox(height: 14)],
                if (!s.batch.isEmpty) ...[_BatchCard(batch: s.batch), const SizedBox(height: 14)],
                for (final c in s.courses) ...[CourseCard(course: c), const SizedBox(height: 14)],
              ]),
            );
          },
        ),
      );
}

class _RegisteredCard extends StatelessWidget {
  const _RegisteredCard({required this.reg});
  final Registration reg;
  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.ok.withValues(alpha: 0.08),
        child: ListTile(
          leading: const Icon(Icons.verified_rounded, color: AppColors.ok),
          title: Text("You're registered for ${reg.course.isEmpty ? 'Flutter in 10 Days' : reg.course}", style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(reg.isPaid ? 'Payment received. See you in class!' : 'Next step: pay to confirm your seat.'),
        ),
      );
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch});
  final BatchInfo batch;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.deep, AppColors.deep2]), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((batch.name ?? 'Next batch').toUpperCase(), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          if (batch.startDate != null) Text('Starts ${batch.startDate}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text([batch.days, batch.time, batch.mode].whereType<String>().join(' · '), style: const TextStyle(color: Color(0xFFA8C2B6))),
          if (batch.seatsLeft != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Only ${batch.seatsLeft} early-bird seats left', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700))),
          if (batch.demo != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(batch.demo!, style: const TextStyle(color: Colors.white))),
        ]),
      );
}

class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = course;
    return Card(
      shape: c.flagship || c.isOpen ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.green, width: 1.6)) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/courses/${c.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (c.isOpen)
            Container(
              width: double.infinity,
              color: AppColors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text(c.badge ?? (c.flagship ? '★ Flagship course' : '★ New course'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Spacer(),
                const Text('● Enrolling now', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!c.isOpen) const Pill(text: '◷ Coming soon'),
              if (c.meta != null) Text(c.meta!, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(c.title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              if (c.tagline != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.tagline!)),
              if (c.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in c.tags) Pill(text: tag)])),
              if (c.price != null && c.isOpen) ...[
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.rupees(c.price!), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  if (c.mrp != null) Padding(padding: const EdgeInsets.only(left: 8, bottom: 3), child: Text(Fmt.rupees(c.mrp!), style: const TextStyle(decoration: TextDecoration.lineThrough))),
                ]),
              ],
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: Text(c.isOpen ? 'View details →' : 'Learn more →', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800))),
            ]),
          ),
        ]),
      ),
    );
  }
}

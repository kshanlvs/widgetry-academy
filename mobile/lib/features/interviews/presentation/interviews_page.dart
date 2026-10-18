import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';
import 'package:widgetry_academy/features/interviews/presentation/interviews_cubits.dart';
import 'package:widgetry_academy/features/interviews/presentation/widgets.dart';

/// Mock interviews with working engineers: what you get, prices, and your bookings.
class InterviewsPage extends StatelessWidget {
  const InterviewsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<InterviewsCubit>()..load(),
        child: BlocBuilder<InterviewsCubit, InterviewsState>(
          builder: (context, s) {
            final cubit = context.read<InterviewsCubit>();
            final signedIn = context.watch<AuthCubit>().state.isSignedIn;
            void book() => context.push(signedIn ? '/interviews/book' : '/sign-in?from=/interviews/book').then((_) => cubit.load());
            return Scaffold(
              appBar: AppBar(title: const Text('Mock interviews'), titleSpacing: 0),
              body: s.loading
                  ? const SkeletonList(count: 3, leading: false)
                  : s.options == null
                      ? ErrorView(message: s.error ?? 'Could not load mock interviews.', onRetry: cubit.load)
                      : RefreshIndicator(onRefresh: cubit.load, child: _Body(s: s, onBook: book)),
              bottomNavigationBar: s.options == null
                  ? null
                  : BottomActionBar(
                      child: FilledButton(
                        onPressed: s.options!.enabled ? book : null,
                        child: Text(s.options!.enabled ? 'Book a mock interview' : 'Booking opens soon'),
                      ),
                    ),
            );
          },
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.s, required this.onBook});
  final InterviewsState s;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final o = s.options!;
    Widget step(int n, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
              child: Text('$n', style: t.labelLarge?.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: t.titleSmall), const SizedBox(height: 2), Text(text, style: t.bodySmall)])),
          ]),
        );

    return ListView(padding: const EdgeInsets.only(bottom: Space.xxxl), children: [
      // Hero
      Container(
        margin: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(Radii.xl)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PRACTISE WITH A PRO', style: t.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.1)),
          const SizedBox(height: Space.sm),
          Text('A real interview, before the real one', style: AppTheme.display(size: 22, color: Colors.white)),
          const SizedBox(height: Space.sm),
          Text('One-to-one video interview with an engineer who ships ${o.tracks.map((t) => t.name).join(', ')} apps at work. Honest feedback the same day.',
              style: t.bodyMedium?.copyWith(color: p.onHeroMuted, height: 1.45)),
          const SizedBox(height: Space.lg),
          Text('From ${Fmt.rupees(o.lowestPrice)}', style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),

      // My bookings
      if (s.upcoming.isNotEmpty) ...[
        const SectionLabel('Upcoming'),
        Group(children: [for (final b in s.upcoming) _BookingRow(b: b)]),
      ],

      const SectionLabel('Pick your level'),
      Group(children: [
        for (final l in o.levels)
          ListTile(
            title: Text(l.name),
            subtitle: Text(l.note),
            trailing: Text(Fmt.rupees(l.price ?? 0), style: t.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            onTap: onBook,
          ),
      ]),

      const SectionLabel('How it works'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.page),
        child: Column(children: [
          step(1, 'Choose the round', o.formats.map((f) => f.name).join(', ')),
          step(2, 'Pick a time that suits you', 'Engineers open evening and weekend slots. Your seat is held while you pay.'),
          step(3, 'Join the video call', 'The link appears in the app once you pay. We remind you an hour before.'),
          step(4, 'Get a written scorecard', 'Scores on five skills, what went well, what to fix, and a hire / no-hire call. Show it on your profile if you like.'),
        ]),
      ),

      if (s.past.isNotEmpty) ...[
        const SectionLabel('Past interviews'),
        Group(children: [for (final b in s.past) _BookingRow(b: b)]),
      ],

      if (s.isInterviewer) ...[
        const SectionLabel('For interviewers'),
        Group(children: [
          ListTile(
            leading: const Icon(Icons.event_available_outlined, size: 22),
            title: const Text('Interviewer dashboard'),
            subtitle: const Text('Your free slots, bookings and feedback'),
            trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
            onTap: () => context.push('/interviewer'),
          ),
        ]),
      ],

      Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, 0),
        child: Text('Cancel up to ${o.cancelHours} hours before for a full refund. Payments by Razorpay: UPI, cards, net banking.', style: t.bodySmall?.copyWith(color: p.faint)),
      ),
    ]);
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.b});
  final MockBooking b;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (label, color) = bookingStatus(context, b);
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.md)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${b.startsAt.day}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.ink, height: 1.1)),
          Text(['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][b.startsAt.month - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.accent)),
        ]),
      ),
      title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${timeLabel(b.startsAt)}${b.interviewer == null ? '' : ' · ${b.interviewer!.name}'}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Pill(text: label, color: color),
      onTap: () => context.push('/interviews/${b.id}'),
    );
  }
}

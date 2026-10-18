import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';
import 'package:widgetry_academy/features/interviews/presentation/interviews_cubits.dart';
import 'package:widgetry_academy/features/interviews/presentation/widgets.dart';

/// One mock interview. The candidate sees time, joining link and feedback;
/// the interviewer sees the candidate and sends the scorecard.
class InterviewDetailPage extends StatelessWidget {
  const InterviewDetailPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<BookingCubit>()..load(id),
        child: BlocConsumer<BookingCubit, BookingState>(
          listenWhen: (a, b) => b.message != null && b.message != a.message,
          listener: (context, s) => showMessage(context, s.message!),
          builder: (context, s) {
            final cubit = context.read<BookingCubit>();
            final b = s.booking;
            return Scaffold(
              appBar: AppBar(title: const Text('Mock interview'), titleSpacing: 0),
              body: s.loading
                  ? const LoadingView()
                  : b == null
                      ? ErrorView(message: s.error ?? 'Could not load this booking.', onRetry: cubit.refresh)
                      : RefreshIndicator(onRefresh: cubit.refresh, child: _Body(b: b, s: s)),
              bottomNavigationBar: b == null ? null : _Actions(b: b, busy: s.busy),
            );
          },
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.b, required this.s});
  final MockBooking b;
  final BookingState s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final o = s.options;
    final cubit = context.read<BookingCubit>();
    final interviewerView = b.asInterviewer;
    final (label, color) = bookingStatus(context, b);
    final links = getIt<LinkLauncher>();

    return ListView(padding: const EdgeInsets.fromLTRB(0, Space.sm, 0, Space.xxxl), children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.page),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Pill(text: label, color: color), const Spacer(), if (b.isUpcoming) Text(startsIn(b.startsAt), style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: p.accent))]),
          const SizedBox(height: Space.md),
          Text(b.title, style: t.headlineSmall),
          const SizedBox(height: 4),
          Text(whenLabel(b.startsAt, b.durationMin), style: t.bodyLarge?.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
          Text(o == null ? b.format : o.formatName(b.format), style: t.bodyMedium?.copyWith(color: p.muted)),
        ]),
      ),

      if (b.status == 'confirmed' && b.meetingLink != null) ...[
        const SizedBox(height: Space.lg),
        _JoinCard(b: b),
      ],

      if (b.status == 'refund_due')
        _Note(icon: Icons.replay_rounded, text: 'Your full refund of ${Fmt.rupees(b.amount)} is on its way. It reaches your account in 5–7 working days after we process it.'),
      if (b.status == 'no_show')
        _Note(icon: Icons.info_outline_rounded, text: 'This interview was marked as missed. If something went wrong, message us and we\'ll try to help.'),

      // Interviewer
      if (!interviewerView && b.interviewer != null) ...[
        const SectionLabel('Your interviewer'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: Space.page), child: InterviewerTile(info: b.interviewer!)),
        if (b.interviewer!.linkedinUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.page, 0),
            child: TextButton.icon(onPressed: () => links.openExternal(b.interviewer!.linkedinUrl!), icon: const Icon(Icons.north_east_rounded, size: 16), label: const Text('LinkedIn')),
          ),
      ],

      // Candidate (interviewer view)
      if (interviewerView) ...[
        const SectionLabel('Candidate'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: Space.page), child: _CandidateCard(b: b)),
      ],

      if ((b.focus ?? '').isNotEmpty) ...[
        SectionLabel(interviewerView ? 'They want to focus on' : 'You asked to focus on'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: Space.page), child: Text(b.focus!, style: t.bodyMedium)),
      ],

      // Feedback
      if (b.scorecard != null) ...[
        const SectionLabel('Feedback'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ScoreBars(card: b.scorecard!, areaName: (id) => o?.areaName(id) ?? id),
                const SizedBox(height: Space.sm),
                Text('What went well', style: t.titleSmall),
                const SizedBox(height: 4),
                Text(b.scorecard!.strengths, style: t.bodyMedium),
                const SizedBox(height: Space.lg),
                Text('What to work on', style: t.titleSmall),
                const SizedBox(height: 4),
                Text(b.scorecard!.improve, style: t.bodyMedium),
              ]),
            ),
          ),
        ),
        if (!interviewerView)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, 0),
            child: SwitchListTile(
              value: b.scorecard!.shared,
              onChanged: cubit.share,
              title: const Text('Show on my profile'),
              subtitle: Text('Adds "Mock interview ${b.scorecard!.overall.toStringAsFixed(1)}/5" to your Talent Network profile. Written feedback stays private.'),
            ),
          ),
      ] else if (!interviewerView && b.status == 'confirmed' && b.endsAt.isBefore(DateTime.now()))
        const _Note(icon: Icons.edit_note_rounded, text: 'Your interviewer is writing your feedback. You\'ll get a notification when it\'s ready, usually the same day.'),

      // Payment
      if (!interviewerView && b.paymentId != null) ...[
        const SectionLabel('Payment'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Column(children: [
            Fact(label: 'Amount', value: Fmt.rupees(b.amount)),
            const SizedBox(height: Space.md),
            Fact(label: 'Payment ID', value: b.paymentId!),
          ]),
        ),
      ],

      if (!interviewerView)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.xl, Space.sm, 0),
          child: ListTile(
            leading: const Icon(Icons.support_agent_rounded, size: 22),
            title: const Text('Need help with this booking?'),
            trailing: Icon(Icons.north_east_rounded, size: 18, color: p.faint),
            onTap: () => links.openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I need help with my mock interview booking #${b.id} on ${whenLabel(b.startsAt, b.durationMin)}.')}'),
          ),
        ),
    ]);
  }
}

/// Join button that becomes active 10 minutes before the start.
class _JoinCard extends StatefulWidget {
  const _JoinCard({required this.b});
  final MockBooking b;
  @override
  State<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends State<_JoinCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final b = widget.b;
    final open = b.canJoin(DateTime.now());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.lg),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: p.soft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.videocam_outlined, color: p.accent),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(open ? 'Your interview is starting' : 'Video call link', style: t.titleSmall)),
        ]),
        const SizedBox(height: 4),
        Text(open ? 'Join from a laptop if you can, with a working mic and camera.' : 'The join button opens 10 minutes before the start.', style: t.bodySmall),
        const SizedBox(height: Space.md),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: open ? () => getIt<LinkLauncher>().openExternal(b.meetingLink!) : null, icon: const Icon(Icons.login_rounded, size: 18), label: const Text('Join call'))),
          const SizedBox(width: Space.sm),
          OutlinedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: b.meetingLink!));
              showMessage(context, 'Link copied');
            },
            child: const Text('Copy link'),
          ),
        ]),
      ]),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.b});
  final MockBooking b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final c = b.candidate;
    final links = getIt<LinkLauncher>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Avatar(name: c?.name ?? b.candidateName ?? '?', size: 44),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c?.name ?? b.candidateName ?? 'Candidate', style: t.titleMedium),
            if (c?.headline != null) Text(c!.headline!, style: t.bodySmall?.copyWith(color: p.muted)),
            if (c == null && b.candidateEmail != null) Text(b.candidateEmail!, style: t.bodySmall?.copyWith(color: p.muted)),
          ]),
        ),
      ]),
      if (c == null)
        Padding(padding: const EdgeInsets.only(top: Space.sm), child: Text('The candidate chose not to share their profile, or hasn\'t made one yet.', style: t.bodySmall)),
      if (c != null) ...[
        if (c.skills.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final s in c.skills.take(12)) Pill(text: s)]),
        ],
        if ((c.about ?? '').isNotEmpty) ...[const SizedBox(height: Space.md), Text(c.about!, maxLines: 6, overflow: TextOverflow.ellipsis, style: t.bodySmall)],
        if (c.links.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Wrap(spacing: 4, children: [
            for (final e in c.links.entries) TextButton.icon(onPressed: () => links.openExternal(e.value), icon: const Icon(Icons.north_east_rounded, size: 15), label: Text(e.key)),
          ]),
        ],
      ],
    ]);
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: AppColors.warn),
        const SizedBox(width: Space.md),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.ink))),
      ]),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.b, required this.busy});
  final MockBooking b;
  final bool busy;

  Future<void> _confirmCancel(BuildContext context) async {
    final cubit = context.read<BookingCubit>();
    final paid = b.status == 'confirmed';
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this interview?'),
        content: Text(paid ? 'You get a full refund of ${Fmt.rupees(b.amount)} in 5–7 working days. The slot opens for others.' : 'Your held slot is released. No money was taken.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.bad), child: const Text('Cancel interview')),
        ],
      ),
    );
    if (yes == true) await cubit.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final interviewerView = b.asInterviewer;
    final cubit = context.read<BookingCubit>();
    if (interviewerView) {
      if (b.canScore) {
        return BottomActionBar(
          child: Row(children: [
            if (b.canMarkNoShow) ...[OutlinedButton(onPressed: busy ? null : cubit.markNoShow, child: const Text('No-show')), const SizedBox(width: Space.sm)],
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : () => context.push('/interviewer/score/${b.id}', extra: cubit).then((_) => cubit.refresh()),
                child: const Text('Write feedback'),
              ),
            ),
          ]),
        );
      }
      return const SizedBox.shrink();
    }
    if (b.canCancel && b.status == 'confirmed') {
      return BottomActionBar(child: OutlinedButton(onPressed: busy ? null : () => _confirmCancel(context), child: BusyLabel(busy: busy, label: 'Cancel and get a refund')));
    }
    if (b.status == 'created') {
      return BottomActionBar(child: OutlinedButton(onPressed: busy ? null : () => _confirmCancel(context), child: BusyLabel(busy: busy, label: 'Release this slot')));
    }
    return const SizedBox.shrink();
  }
}

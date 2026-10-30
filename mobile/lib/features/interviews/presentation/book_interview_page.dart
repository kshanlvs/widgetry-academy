import 'package:flutter/material.dart';
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
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';
import 'package:widgetry_academy/features/interviews/presentation/interviews_cubits.dart';
import 'package:widgetry_academy/features/interviews/presentation/widgets.dart';

/// Book a mock interview in three steps: what kind → when → confirm and pay.
class BookInterviewPage extends StatelessWidget {
  const BookInterviewPage({super.key, this.track, this.level});
  final String? track;
  final String? level;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<BookInterviewCubit>()..load(track: track, level: level),
        child: BlocConsumer<BookInterviewCubit, BookState>(
          listenWhen: (a, b) => b.message != null && b.message != a.message,
          listener: (context, s) => showMessage(context, s.message!),
          builder: (context, s) {
            final cubit = context.read<BookInterviewCubit>();
            final p = Palette.of(context);
            final Widget body;
            if (s.loading) {
              body = const LoadingView();
            } else if (s.options == null) {
              body = ErrorView(message: s.error ?? 'Could not load mock interviews.', onRetry: () => cubit.load(track: track, level: level));
            } else if (s.outcome != null) {
              body = _Done(outcome: s.outcome!, slot: s.slot);
            } else {
              body = switch (s.step) {
                BookStep.choose => _Choose(s: s),
                BookStep.slot => _Slots(s: s),
                BookStep.confirm => _Confirm(s: s),
              };
            }
            final Widget? bar = s.options == null || s.outcome != null
                ? null
                : switch (s.step) {
                    BookStep.choose => BottomActionBar(
                        child: FilledButton(onPressed: s.level == null ? null : cubit.toSlots, child: Text(s.level == null ? 'Choose your level' : 'See available times')),
                      ),
                    BookStep.slot => null,
                    BookStep.confirm => BottomActionBar(
                        child: FilledButton(onPressed: s.paying ? null : cubit.pay, child: BusyLabel(busy: s.paying, label: 'Pay ${Fmt.rupees(s.price ?? 0)} and book')),
                      ),
                  };
            return PopScope(
              canPop: s.step == BookStep.choose || s.outcome != null,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) cubit.back();
              },
              child: Scaffold(
                backgroundColor: p.surface,
                appBar: AppBar(
                  backgroundColor: p.surface,
                  titleSpacing: 0,
                  title: Text(s.outcome != null ? '' : switch (s.step) { BookStep.choose => 'Book a mock interview', BookStep.slot => 'Pick a time', BookStep.confirm => 'Confirm and pay' }),
                  automaticallyImplyLeading: !s.paying,
                ),
                body: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey('${s.step}${s.outcome != null}'), child: body)),
                bottomNavigationBar: bar,
              ),
            );
          },
        ),
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.title, required this.note, required this.selected, required this.onTap, this.trailing});
  final String title;
  final String note;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Material(
        color: selected ? p.soft.withValues(alpha: 0.55) : p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: selected ? p.accent : p.line, width: selected ? 1.6 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            tick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(top: 2),
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? p.accent : p.faint, width: selected ? 6 : 1.6)),
              ),
              const SizedBox(width: Space.md + 2),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: t.titleSmall), if (note.isNotEmpty) ...[const SizedBox(height: 2), Text(note, style: t.bodySmall)]])),
              if (trailing != null) Text(trailing!, style: t.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Choose extends StatelessWidget {
  const _Choose({required this.s});
  final BookState s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final o = s.options!;
    final cubit = context.read<BookInterviewCubit>();
    return ListView(padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxl), children: [
      // One track (Flutter for now): nothing to choose
      if (o.tracks.length > 1) ...[
        Text('Track', style: t.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tr in o.tracks) ChoiceChip(label: Text(tr.name), selected: s.track == tr.id, onSelected: (_) => cubit.setTrack(tr.id)),
        ]),
        const SizedBox(height: Space.xl),
      ],
      Text('Your level', style: t.titleSmall),
      const SizedBox(height: Space.sm),
      for (final l in o.levels) _OptionCard(title: l.name, note: l.note, trailing: Fmt.rupees(l.price ?? 0), selected: s.level == l.id, onTap: () => cubit.setLevel(l.id)),
      const SizedBox(height: Space.lg),
      Text('Round', style: t.titleSmall),
      const SizedBox(height: Space.sm),
      for (final f in o.formats) _OptionCard(title: f.name, note: f.note, selected: s.format == f.id, onTap: () => cubit.setFormat(f.id)),
    ]);
  }
}

class _Slots extends StatelessWidget {
  const _Slots({required this.s});
  final BookState s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final cubit = context.read<BookInterviewCubit>();
    if (s.slotsLoading) return const SkeletonList(count: 3, leading: false);
    final days = s.days;
    if (days.isEmpty) {
      return EmptyView(
        icon: Icons.event_busy_outlined,
        title: 'No open times right now',
        message: 'Our engineers add new evening and weekend slots every week. Message us and we\'ll find you a time.',
        action: Column(children: [
          OutlinedButton(onPressed: cubit.refreshSlots, child: const Text('Check again')),
          TextButton(
            onPressed: () => getIt<LinkLauncher>().openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I want to book a ${s.options!.trackName(s.track)} mock interview (${s.options!.levelName(s.level ?? '')}). When are slots available?')}'),
            child: const Text('Ask on WhatsApp'),
          ),
        ]),
      );
    }
    final day = s.day ?? days.first;
    final list = s.slotsOn(day);
    return RefreshIndicator(
      onRefresh: cubit.refreshSlots,
      child: ListView(padding: const EdgeInsets.only(bottom: Space.xxxl), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.md),
          child: Text('${s.options!.trackName(s.track)} · ${s.options!.levelName(s.level ?? '')} · ${s.options!.formatName(s.format)}', style: t.bodySmall),
        ),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final d = days[i];
              final on = d == day;
              return Material(
                color: on ? p.accent : p.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: on ? p.accent : p.line)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () {
                    tick();
                    cubit.pickDay(d);
                  },
                  child: SizedBox(
                    width: 64,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][d.weekday - 1], style: t.labelSmall?.copyWith(color: on ? p.onAccent : p.muted, letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text('${d.day}', style: t.titleMedium?.copyWith(color: on ? p.onAccent : p.ink, fontWeight: FontWeight.w700)),
                      Text('${s.slotsOn(d).length} open', style: t.bodySmall?.copyWith(fontSize: 10.5, color: on ? p.onAccent : p.faint)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, Space.sm), child: Text(dayLabel(day), style: t.titleSmall)),
        for (final slot in list)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Material(
              color: p.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  tick();
                  cubit.pickSlot(slot);
                },
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.schedule_rounded, size: 18, color: p.accent),
                      const SizedBox(width: Space.sm),
                      Text('${timeLabel(slot.startsAt)} – ${timeLabel(slot.endsAt)}', style: t.titleSmall),
                      const Spacer(),
                      Text('${slot.durationMin} min', style: t.bodySmall),
                    ]),
                    if (slot.interviewer != null) ...[const SizedBox(height: Space.md), InterviewerTile(info: slot.interviewer!, dense: true)],
                  ]),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, 0),
          child: Text('Times are in your phone\'s time zone.', style: t.bodySmall?.copyWith(color: p.faint)),
        ),
      ]),
    );
  }
}

class _Confirm extends StatefulWidget {
  const _Confirm({required this.s});
  final BookState s;
  @override
  State<_Confirm> createState() => _ConfirmState();
}

class _ConfirmState extends State<_Confirm> {
  late final _focus = TextEditingController(text: widget.s.focus);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final s = widget.s;
    final o = s.options!;
    final slot = s.slot!;
    final cubit = context.read<BookInterviewCubit>();
    return ListView(padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxl), children: [
      Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.trackName(s.track)} · ${o.formatName(s.format)}', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(whenLabel(slot.startsAt, slot.durationMin), style: t.bodyMedium?.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
          if (slot.interviewer != null) ...[const SizedBox(height: Space.lg), InterviewerTile(info: slot.interviewer!)],
          const SizedBox(height: Space.lg),
          Row(children: [
            Expanded(child: Text('${o.levelName(s.level ?? '')} · ${slot.durationMin} min', style: t.bodySmall)),
            Text(Fmt.rupees(s.price ?? 0), style: t.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: s.paying ? null : cubit.back, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Change time'))),
        ]),
      ),
      const SizedBox(height: Space.xl),
      TextField(
        controller: _focus,
        maxLines: 3,
        maxLength: 500,
        enabled: !s.paying,
        onChanged: cubit.setFocus,
        decoration: const InputDecoration(labelText: 'Anything to focus on? (optional)', hintText: 'e.g. Bloc, my upcoming interview at a fintech, live coding nerves'),
      ),
      CheckboxListTile(
        value: s.shareProfile,
        onChanged: s.paying ? null : (v) => cubit.setShareProfile(v ?? true),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Share my Widgetry profile and resume with the interviewer'),
        subtitle: const Text('So they can ask about your own projects. Only this interviewer sees it.'),
      ),
      const SizedBox(height: Space.md),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: p.accent),
        const SizedBox(width: Space.md),
        Expanded(child: Text('Your slot is held for ${o.holdMinutes} minutes while you pay. Secure payment by Razorpay: UPI, cards, net banking.', style: t.bodySmall)),
      ]),
      const SizedBox(height: Space.md),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.replay_rounded, size: 18, color: p.accent),
        const SizedBox(width: Space.md),
        Expanded(child: Text('Full refund if you cancel at least ${o.cancelHours} hours before.', style: t.bodySmall)),
      ]),
      const SizedBox(height: Space.md),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 18, color: p.accent),
        const SizedBox(width: Space.md),
        Expanded(child: Text('This is a practice interview, not a real hiring interview. It helps you prepare but can\'t guarantee you clear any interview or get a job.', style: t.bodySmall)),
      ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => getIt<LinkLauncher>().openInApp('${AppConfig.siteUrl}/terms.html#mock'),
          child: const Text('Mock interview terms'),
        ),
      ),
    ]);
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.outcome, required this.slot});
  final BookingOutcome outcome;
  final InterviewSlot? slot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final (icon, color, title, text) = switch (outcome.kind) {
      BookingOutcomeKind.confirmed => (Icons.check_rounded, AppColors.ok, 'You\'re booked', 'We\'ve told your interviewer. The joining link is on the booking, and we remind you an hour before.'),
      BookingOutcomeKind.slotLost => (Icons.info_outline_rounded, AppColors.warn, 'That time was just taken', 'Your payment came through after someone else booked this slot. We\'ll refund you in full within 3 working days, or message us to pick another time.'),
      _ => (Icons.hourglass_top_rounded, AppColors.warn, 'Confirming your payment', 'Your bank is confirming the payment. This usually takes a minute and the booking updates by itself. Please don\'t pay again.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page + 4, Space.xxl, Space.page + 4, Space.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 34)),
        const SizedBox(height: Space.xl),
        Text(title, style: AppTheme.display(size: 24, color: p.ink)),
        const SizedBox(height: Space.sm),
        Text(text, style: t.bodyLarge?.copyWith(color: p.muted)),
        if (slot != null && outcome.kind != BookingOutcomeKind.slotLost) ...[
          const SizedBox(height: Space.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Fact(label: 'When', value: whenLabel(slot!.startsAt, slot!.durationMin)),
              if (slot!.interviewer != null) ...[const SizedBox(height: Space.md), Fact(label: 'Interviewer', value: slot!.interviewer!.name)],
              if (outcome.paymentId != null) ...[const SizedBox(height: Space.md), Fact(label: 'Payment ID', value: outcome.paymentId!)],
            ]),
          ),
        ],
        const Spacer(),
        if (outcome.bookingId != null)
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.pushReplacement('/interviews/${outcome.bookingId}'), child: const Text('View booking'))),
        const SizedBox(height: Space.sm),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Done'))),
      ]),
    );
  }
}

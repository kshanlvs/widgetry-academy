import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/utils/validators.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';
import 'package:widgetry_academy/features/interviews/presentation/interviews_cubits.dart';
import 'package:widgetry_academy/features/interviews/presentation/widgets.dart';

/// For Widgetry interviewers: availability, bookings and feedback to write.
class InterviewerPage extends StatelessWidget {
  const InterviewerPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<InterviewerCubit>()..load(),
        child: BlocConsumer<InterviewerCubit, InterviewerState>(
          listenWhen: (a, b) => b.message != null && b.message != a.message,
          listener: (context, s) => showMessage(context, s.message!),
          builder: (context, s) {
            final cubit = context.read<InterviewerCubit>();
            final d = s.dashboard;
            return Scaffold(
              appBar: AppBar(title: const Text('Interviewer'), titleSpacing: 0),
              body: s.loading
                  ? const SkeletonList(count: 3, leading: false)
                  : s.error == 'notInterviewer'
                      ? EmptyView(
                          icon: Icons.record_voice_over_outlined,
                          title: 'For Widgetry interviewers',
                          message: 'Working engineers take mock interviews with us and get paid per session. Apply as a mentor and we\'ll get in touch.',
                          action: FilledButton(onPressed: () => getIt<LinkLauncher>().openInApp('${AppConfig.siteUrl}/mentor.html'), child: const Text('Apply as a mentor')),
                        )
                      : d == null
                          ? ErrorView(message: s.error ?? 'Could not load your dashboard.', onRetry: cubit.load)
                          : RefreshIndicator(onRefresh: cubit.load, child: _Body(d: d, s: s)),
              floatingActionButton: d == null || d.me.meetingLink == null
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: s.busy ? null : () => _addSlots(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add free slots'),
                    ),
            );
          },
        ),
      );

  static Future<void> _addSlots(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => BlocProvider.value(value: context.read<InterviewerCubit>(), child: const _AddSlotsSheet()),
      );

  static Future<void> editProfile(BuildContext context, InterviewerProfile me, MockOptions? o) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => BlocProvider.value(value: context.read<InterviewerCubit>(), child: _ProfileSheet(me: me, options: o)),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.d, required this.s});
  final InterviewerDashboard d;
  final InterviewerState s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final now = DateTime.now();
    final needsFeedback = d.bookings.where((b) => b.status == 'confirmed' && b.startsAt.isBefore(now)).toList();
    final upcoming = d.bookings.where((b) => b.status == 'confirmed' && !b.startsAt.isBefore(now)).toList();
    final past = d.bookings.where((b) => b.status != 'confirmed').toList().reversed.toList();
    final openSlots = d.slots.where((x) => x.status != 'booked').toList();
    final days = <DateTime, List<InterviewSlot>>{};
    for (final x in openSlots) {
      days.putIfAbsent(DateTime(x.startsAt.year, x.startsAt.month, x.startsAt.day), () => []).add(x);
    }
    final cubit = context.read<InterviewerCubit>();

    return ListView(padding: const EdgeInsets.only(bottom: 120), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InterviewerTile(info: InterviewerInfo(name: d.me.name, title: d.me.title, company: d.me.company, years: d.me.years, tracks: d.me.tracks, bio: d.me.bio)),
              const SizedBox(height: Space.md),
              Row(children: [
                Icon(d.me.meetingLink == null ? Icons.warning_amber_rounded : Icons.videocam_outlined, size: 18, color: d.me.meetingLink == null ? AppColors.warn : p.accent),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(d.me.meetingLink ?? 'Add your Google Meet or Zoom link to start taking bookings',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: d.me.meetingLink == null ? AppColors.warn : p.muted, fontWeight: FontWeight.w600)),
                ),
                TextButton(onPressed: () => InterviewerPage.editProfile(context, d.me, s.options), child: const Text('Edit')),
              ]),
            ]),
          ),
        ),
      ),

      if (needsFeedback.isNotEmpty) ...[
        const SectionLabel('Feedback to write'),
        Group(children: [for (final b in needsFeedback) _BookingTile(b: b, highlight: true)]),
      ],
      if (upcoming.isNotEmpty) ...[
        const SectionLabel('Upcoming interviews'),
        Group(children: [for (final b in upcoming) _BookingTile(b: b)]),
      ],

      SectionLabel('Your free slots', trailing: Text('${openSlots.length}', style: t.bodySmall)),
      if (openSlots.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Text(d.me.meetingLink == null ? 'Add your meeting link first, then add slots.' : 'No free slots. Add a few evening or weekend times so candidates can book you.', style: t.bodyMedium?.copyWith(color: p.muted)),
        )
      else
        for (final e in days.entries)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dayLabel(e.key), style: t.titleSmall),
              const SizedBox(height: Space.sm),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final x in e.value)
                  InputChip(
                    label: Text('${timeLabel(x.startsAt)} · ${x.durationMin}m${x.status == 'held' ? ' · being paid' : ''}'),
                    onDeleted: x.status == 'open' ? () => cubit.deleteSlot(x) : null,
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  ),
              ]),
            ]),
          ),

      if (past.isNotEmpty) ...[
        const SectionLabel('Past'),
        Group(children: [for (final b in past.take(20)) _BookingTile(b: b)]),
      ],
    ]);
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.b, this.highlight = false});
  final MockBooking b;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (label, color) = switch (b.status) {
      'completed' => ('Feedback sent', AppColors.ok),
      'no_show' => ('No-show', p.muted),
      _ => highlight ? ('Write feedback', AppColors.warn) : ('Booked', AppColors.ok),
    };
    return ListTile(
      title: Text(b.candidateName ?? 'Candidate'),
      subtitle: Text('${b.title.replaceFirst('Mock interview · ', '')}\n${whenLabel(b.startsAt, b.durationMin)}'),
      isThreeLine: true,
      trailing: Pill(text: label, color: color),
      onTap: () => context.push('/interviews/${b.id}').then((_) {
        if (context.mounted) context.read<InterviewerCubit>().load();
      }),
    );
  }
}

class _AddSlotsSheet extends StatefulWidget {
  const _AddSlotsSheet();
  @override
  State<_AddSlotsSheet> createState() => _AddSlotsSheetState();
}

class _AddSlotsSheetState extends State<_AddSlotsSheet> {
  late DateTime _day = _days.first;
  final Set<int> _minutes = {}; // minutes after midnight
  int _duration = 60;

  static List<DateTime> get _days {
    final n = DateTime.now();
    return [for (var i = 0; i < 21; i++) DateTime(n.year, n.month, n.day + i)];
  }

  /// 7:00 AM to 10:30 PM every 30 minutes, minus times less than 2 hours away.
  List<int> get _times {
    final now = DateTime.now();
    return [
      for (var m = 7 * 60; m <= 22 * 60 + 30; m += 30)
        if (_day.add(Duration(minutes: m)).isAfter(now.add(const Duration(hours: 2)))) m,
    ];
  }

  String _label(int m) => timeLabel(_day.add(Duration(minutes: m)));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final busy = context.select<InterviewerCubit, bool>((c) => c.state.busy);
    final times = _times;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.md), child: Text('Add free slots', style: t.titleLarge)),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
            itemBuilder: (_, i) {
              final d = _days[i];
              final on = d == _day;
              return ChoiceChip(
                label: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1], style: const TextStyle(fontSize: 11)),
                  Text('${d.day}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                selected: on,
                onSelected: (_) => setState(() {
                  _day = d;
                  _minutes.clear();
                }),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.sm),
          child: Row(children: [
            Expanded(child: Text('${dayLabel(_day)}: pick start times', style: t.titleSmall)),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 45, label: Text('45 min')), ButtonSegment(value: 60, label: Text('60 min'))],
              selected: {_duration},
              onSelectionChanged: (v) => setState(() => _duration = v.first),
            ),
          ]),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            child: times.isEmpty
                ? Text('No times left today. Pick another day.', style: t.bodyMedium?.copyWith(color: p.muted))
                : Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in times)
                      FilterChip(
                        label: Text(_label(m)),
                        selected: _minutes.contains(m),
                        onSelected: (on) => setState(() => on ? _minutes.add(m) : _minutes.remove(m)),
                      ),
                  ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Slots that overlap ones you already have are skipped. Candidates see times in their own time zone.', style: t.bodySmall),
            const SizedBox(height: Space.md),
            FilledButton(
              onPressed: busy || _minutes.isEmpty
                  ? null
                  : () async {
                      final starts = (_minutes.toList()..sort()).map((m) => _day.add(Duration(minutes: m))).toList();
                      final ok = await context.read<InterviewerCubit>().addSlots(starts, _duration);
                      if (ok && context.mounted) Navigator.pop(context);
                    },
              child: BusyLabel(busy: busy, label: _minutes.isEmpty ? 'Pick at least one time' : 'Add ${_minutes.length} ${_minutes.length == 1 ? 'slot' : 'slots'}'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.me, required this.options});
  final InterviewerProfile me;
  final MockOptions? options;
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.me.title);
  late final _company = TextEditingController(text: widget.me.company ?? '');
  late final _years = TextEditingController(text: '${widget.me.years}');
  late final _bio = TextEditingController(text: widget.me.bio ?? '');
  late final _linkedin = TextEditingController(text: widget.me.linkedinUrl ?? '');
  late final _meeting = TextEditingController(text: widget.me.meetingLink ?? '');
  late List<String> _tracks = [...widget.me.tracks];

  @override
  void dispose() {
    for (final c in [_title, _company, _years, _bio, _linkedin, _meeting]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_tracks.isEmpty) {
      showMessage(context, 'Choose at least one track.');
      return;
    }
    String? url(TextEditingController c) => Validators.normalizeUrl(c.text).isEmpty ? null : Validators.normalizeUrl(c.text);
    final ok = await context.read<InterviewerCubit>().saveProfile(InterviewerProfile(
          name: widget.me.name,
          email: widget.me.email,
          title: _title.text.trim(),
          company: _company.text.trim().isEmpty ? null : _company.text.trim(),
          years: int.tryParse(_years.text.trim()) ?? 0,
          tracks: _tracks,
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          linkedinUrl: url(_linkedin),
          meetingLink: url(_meeting),
        ));
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final busy = context.select<InterviewerCubit, bool>((c) => c.state.busy);
    final tracks = widget.options?.tracks ?? const [MockOption(id: 'flutter', name: 'Flutter'), MockOption(id: 'android', name: 'Android'), MockOption(id: 'ios', name: 'iOS')];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl), children: [
          Text('Interviewer profile', style: t.titleLarge),
          const SizedBox(height: Space.lg),
          TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title', hintText: 'Senior Flutter Engineer'), validator: (v) => (v ?? '').trim().length < 2 ? 'Required' : null),
          const SizedBox(height: Space.md),
          Row(children: [
            Expanded(flex: 3, child: TextFormField(controller: _company, decoration: const InputDecoration(labelText: 'Company (optional)'))),
            const SizedBox(width: Space.md),
            Expanded(flex: 2, child: TextFormField(controller: _years, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years'), validator: (v) => (int.tryParse((v ?? '').trim()) ?? -1) < 0 ? 'Number' : null)),
          ]),
          const SizedBox(height: Space.lg),
          Text('I interview for', style: t.titleSmall),
          const SizedBox(height: Space.sm),
          Wrap(spacing: 8, children: [
            for (final tr in tracks)
              FilterChip(label: Text(tr.name), selected: _tracks.contains(tr.id), onSelected: (on) => setState(() => _tracks = on ? [..._tracks, tr.id] : _tracks.where((x) => x != tr.id).toList())),
          ]),
          const SizedBox(height: Space.lg),
          TextFormField(
            controller: _meeting,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Your meeting link', hintText: 'meet.google.com/abc-defg-hij', helperText: 'A Google Meet or Zoom room you use for every interview. Only booked candidates see it.'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Needed so candidates can join' : Validators.optionalHttpsUrl(v),
          ),
          const SizedBox(height: Space.md),
          TextFormField(controller: _linkedin, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'LinkedIn (optional)'), validator: Validators.optionalHttpsUrl),
          const SizedBox(height: Space.md),
          TextFormField(controller: _bio, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Short bio (optional)', hintText: 'What you build and what you look for in candidates')),
          const SizedBox(height: Space.md),
          FilledButton(onPressed: busy ? null : _save, child: BusyLabel(busy: busy, label: 'Save')),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';
import 'package:widgetry_academy/features/interviews/presentation/interviews_cubits.dart';
import 'package:widgetry_academy/features/interviews/presentation/widgets.dart';

/// The interviewer's scorecard: five skills scored 1–5, what went well, what to improve, and a call.
class ScorecardFormPage extends StatelessWidget {
  const ScorecardFormPage({super.key, required this.id, this.cubit});
  final int id;
  /// Shared from the booking screen when opened from there.
  final BookingCubit? cubit;

  @override
  Widget build(BuildContext context) {
    const child = _Form();
    return cubit != null ? BlocProvider.value(value: cubit!, child: child) : BlocProvider(create: (_) => getIt<BookingCubit>()..load(id), child: child);
  }
}

class _Form extends StatefulWidget {
  const _Form();
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _form = GlobalKey<FormState>();
  final _strengths = TextEditingController();
  final _improve = TextEditingController();
  final Map<String, int> _scores = {};
  String? _recommendation;
  bool _submitted = false;

  static const _scale = {1: 'Weak', 2: 'Below bar', 3: 'At bar', 4: 'Strong', 5: 'Excellent'};

  @override
  void dispose() {
    _strengths.dispose();
    _improve.dispose();
    super.dispose();
  }

  Future<void> _send(MockOptions o) async {
    setState(() => _submitted = true);
    final missing = o.areas.where((a) => !_scores.containsKey(a.id)).map((a) => a.name).toList();
    if (missing.isNotEmpty) {
      showMessage(context, 'Score ${missing.first} too.');
      return;
    }
    if (_recommendation == null) {
      showMessage(context, 'Choose your overall call.');
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await context.read<BookingCubit>().sendScorecard(ScorecardInput(scores: _scores, strengths: _strengths.text, improve: _improve.text, recommendation: _recommendation!));
    if (ok && mounted) context.pop();
  }

  String? _minWords(String? v) => (v ?? '').trim().length < 20 ? 'Write at least a couple of sentences' : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return BlocConsumer<BookingCubit, BookingState>(
      listenWhen: (a, b) => b.message != null && b.message != a.message && !b.message!.startsWith('Feedback sent'),
      listener: (context, s) => showMessage(context, s.message!),
      builder: (context, s) {
        final o = s.options, b = s.booking;
        return Scaffold(
          appBar: AppBar(title: const Text('Interview feedback'), titleSpacing: 0),
          body: s.loading
              ? const LoadingView()
              : o == null || b == null
                  ? ErrorView(message: s.error ?? 'Could not load this booking.', onRetry: context.read<BookingCubit>().refresh)
                  : Form(
                      key: _form,
                      autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                      child: ListView(padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxxl), children: [
                        Text(b.candidate?.name ?? b.candidateName ?? 'Candidate', style: t.titleLarge),
                        Text('${b.title} · ${whenLabel(b.startsAt, b.durationMin)}', style: t.bodySmall),
                        const SizedBox(height: Space.sm),
                        Text('The candidate sees everything on this page. Be specific and kind: what they did, and what would make the next interview go better.', style: t.bodySmall?.copyWith(color: p.muted)),
                        const SizedBox(height: Space.xl),
                        for (final a in o.areas) ...[
                          Row(children: [
                            Expanded(child: Text(a.name, style: t.titleSmall)),
                            if (_scores[a.id] != null) Text(_scale[_scores[a.id]]!, style: t.bodySmall?.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: Space.sm),
                          SegmentedButton<int>(
                            showSelectedIcon: false,
                            emptySelectionAllowed: true,
                            segments: [for (var i = 1; i <= 5; i++) ButtonSegment(value: i, label: Text('$i'))],
                            selected: {if (_scores[a.id] != null) _scores[a.id]!},
                            onSelectionChanged: (v) => setState(() {
                              if (v.isEmpty) {
                                _scores.remove(a.id);
                              } else {
                                _scores[a.id] = v.first;
                              }
                            }),
                          ),
                          if (_submitted && _scores[a.id] == null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Required', style: t.bodySmall?.copyWith(color: AppColors.bad))),
                          const SizedBox(height: Space.lg),
                        ],
                        const SizedBox(height: Space.sm),
                        TextFormField(
                          controller: _strengths,
                          maxLines: 5,
                          minLines: 3,
                          maxLength: 1500,
                          validator: _minWords,
                          decoration: const InputDecoration(labelText: 'What went well', hintText: 'e.g. Explained Bloc events and states clearly; wrote a clean widget test without help.'),
                        ),
                        const SizedBox(height: Space.md),
                        TextFormField(
                          controller: _improve,
                          maxLines: 5,
                          minLines: 3,
                          maxLength: 1500,
                          validator: _minWords,
                          decoration: const InputDecoration(labelText: 'What to work on', hintText: 'e.g. Talk through the approach before coding; practise list and map problems; read about isolates.'),
                        ),
                        const SizedBox(height: Space.lg),
                        Text('If this were a real interview', style: t.titleSmall),
                        const SizedBox(height: Space.sm),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final e in Scorecard.recommendations.entries)
                            ChoiceChip(label: Text(e.value), selected: _recommendation == e.key, onSelected: (_) => setState(() => _recommendation = e.key)),
                        ]),
                        if (_submitted && _recommendation == null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Required', style: t.bodySmall?.copyWith(color: AppColors.bad))),
                      ]),
                    ),
          bottomNavigationBar: o == null || b == null
              ? null
              : BottomActionBar(child: FilledButton(onPressed: s.busy ? null : () => _send(o), child: BusyLabel(busy: s.busy, label: 'Send feedback'))),
        );
      },
    );
  }
}

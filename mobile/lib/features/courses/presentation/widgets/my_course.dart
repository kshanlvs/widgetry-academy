import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';

/// Where the student stands: registered (not paid), seat booked (balance due) or enrolled.
enum EnrolmentStage { registered, booked, enrolled }

EnrolmentStage stageOf(Registration r) => r.isPaid ? EnrolmentStage.enrolled : r.isPartPaid ? EnrolmentStage.booked : EnrolmentStage.registered;

String whenText(BatchInfo b) => [b.days, b.time, b.mode].whereType<String>().where((x) => x.isNotEmpty).join(' · ');

/// Replaces the course's sales card once the student has registered.
class MyCourseCard extends StatelessWidget {
  const MyCourseCard({super.key, required this.course, required this.reg, required this.batch});
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
    final (label, color) = switch (stage) {
      EnrolmentStage.enrolled => ('Seat confirmed', AppColors.ok),
      EnrolmentStage.booked => ('Seat booked · balance due', AppColors.warn),
      EnrolmentStage.registered => ('Payment pending', AppColors.warn),
    };

    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
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
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: t.bodySmall?.copyWith(color: stage == EnrolmentStage.enrolled ? AppColors.greenBright : AppColors.gold, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: Space.md),
            Text(course.title, style: AppTheme.display(size: 22, color: Colors.white)),
            if (!batch.isEmpty) ...[
              const SizedBox(height: Space.md),
              Row(children: [
                const Icon(Icons.event_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    [if (batch.startDate != null) 'Starts ${batch.startDate}', whenText(batch)].where((x) => x.isNotEmpty).join('\n'),
                    style: t.bodySmall?.copyWith(color: p.onHeroMuted, height: 1.45),
                  ),
                ),
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
        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (stage != EnrolmentStage.enrolled) ...[
              Text(
                stage == EnrolmentStage.booked
                    ? 'Your seat is held. Pay the balance before the course starts to keep it.'
                    : "You're registered. Pay to confirm your seat; seats are limited.",
                style: t.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: Space.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/courses/${course.id}/pay'),
                  child: Text(stage == EnrolmentStage.booked ? 'Pay the balance' : 'Pay & confirm seat'),
                ),
              ),
            ] else
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.push('/courses/${course.id}'), child: const Text('Open course'))),
            const SizedBox(height: Space.xs),
            Row(children: [
              Expanded(child: TextButton.icon(onPressed: () => context.push('/payments'), icon: const Icon(Icons.receipt_long_outlined, size: 18), label: const Text('Receipts'))),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => getIt<LinkLauncher>().openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I\'m enrolled in ${course.title} (${reg.email}). ')}'),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Message us'),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// "Before Day 1" steps for booked or enrolled students. Ticks are saved on the phone.
class StartChecklist extends StatefulWidget {
  const StartChecklist({super.key, required this.course, required this.reg, required this.batch});
  final Course course;
  final Registration reg;
  final BatchInfo batch;
  @override
  State<StartChecklist> createState() => _StartChecklistState();
}

class _StartChecklistState extends State<StartChecklist> {
  final _prefs = getIt<SharedPreferences>();
  String _key(String id) => 'start_${widget.course.id}_$id';
  bool _done(String id) => _prefs.getBool(_key(id)) ?? false;
  Future<void> _toggle(String id) async {
    tick();
    await _prefs.setBool(_key(id), !_done(id));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final links = getIt<LinkLauncher>();
    final stage = stageOf(widget.reg);
    final b = widget.batch;
    final items = <_Item>[
      _Item('seat', stage == EnrolmentStage.enrolled ? 'Seat confirmed' : 'Seat booked', stage == EnrolmentStage.enrolled ? 'Payment received. You\'re in.' : 'Pay the balance before the course starts.', auto: true),
      if (stage == EnrolmentStage.booked)
        _Item('balance', 'Pay the balance', 'Keeps your seat. Takes a minute.', auto: false, done: false, action: ('Pay', () => context.push('/courses/${widget.course.id}/pay'))),
      _Item('group', 'Join the batch WhatsApp group', 'We add you within 24 hours of payment. Not added yet? Message us.',
          action: ('Message', () => links.openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, please add me to the ${widget.course.title} batch group. My email: ${widget.reg.email}')}'))),
      _Item('setup', 'Set up Flutter on your laptop', 'About 30 minutes. Stuck? We help you on Day 1.', action: ('Guide', () => links.openInApp(AppConfig.flutterInstallUrl))),
      _Item('day1', 'Join Day 1 on time', [if (b.startDate != null) b.startDate!, whenText(b)].where((x) => x.isNotEmpty).join(' · ').ifEmpty('Batch dates come on WhatsApp.')),
    ];
    final doneCount = items.where((i) => i.auto || (i.done ?? _done(i.id))).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.sm, Space.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: Row(children: [
              Expanded(child: Text('Before Day 1', style: t.titleSmall)),
              Text('$doneCount of ${items.length}', style: t.bodySmall),
            ]),
          ),
          const SizedBox(height: Space.sm),
          for (final i in items)
            Builder(builder: (context) {
              final done = i.auto || (i.done ?? _done(i.id));
              final canTick = !i.auto && i.done == null;
              return InkWell(
                onTap: canTick ? () => _toggle(i.id) : null,
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(color: done ? p.accent : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: done ? p.accent : p.faint, width: 1.6)),
                      child: done ? Icon(Icons.check_rounded, size: 15, color: p.onAccent) : null,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i.title, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: done ? p.muted : p.ink, decoration: done && canTick ? TextDecoration.lineThrough : null)),
                        Text(i.text, style: t.bodySmall),
                      ]),
                    ),
                    if (i.action != null) TextButton(onPressed: i.action!.$2, style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(i.action!.$1)),
                  ]),
                ),
              );
            }),
        ]),
      ),
    );
  }
}

class _Item {
  _Item(this.id, this.title, this.text, {this.auto = false, this.done, this.action});
  final String id;
  final String title;
  final String text;
  /// Done by the system (e.g. payment), not by the student.
  final bool auto;
  /// Fixed state; null means the student ticks it.
  final bool? done;
  final (String, VoidCallback)? action;
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

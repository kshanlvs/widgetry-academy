import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';

/// "Today", "Tomorrow", or "Sat, 25 Oct".
String dayLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return DateFormat('EEE, d MMM').format(d);
}

/// "6:00 PM"
String timeLabel(DateTime d) => DateFormat('h:mm a').format(d);

/// "Sat, 25 Oct · 6:00 – 7:00 PM"
String whenLabel(DateTime start, int minutes) {
  final end = start.add(Duration(minutes: minutes));
  final sameHalf = DateFormat('a').format(start) == DateFormat('a').format(end);
  return '${dayLabel(start)} · ${sameHalf ? DateFormat('h:mm').format(start) : timeLabel(start)} – ${timeLabel(end)}';
}

/// "in 3 days", "in 2 hours", "in 15 minutes"
String startsIn(DateTime start, {DateTime? now}) {
  final d = start.difference(now ?? DateTime.now());
  if (d.isNegative) return 'now';
  if (d.inDays >= 1) return 'in ${d.inDays} ${d.inDays == 1 ? 'day' : 'days'}';
  if (d.inHours >= 1) return 'in ${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'}';
  final m = d.inMinutes < 1 ? 1 : d.inMinutes;
  return 'in $m ${m == 1 ? 'minute' : 'minutes'}';
}

(String, Color) bookingStatus(BuildContext context, MockBooking b) {
  final p = Palette.of(context);
  return switch (b.status) {
    'created' => ('Payment pending', AppColors.warn),
    'confirmed' => b.endsAt.isBefore(DateTime.now()) ? ('Awaiting feedback', AppColors.warn) : ('Booked', AppColors.ok),
    'completed' => ('Feedback ready', AppColors.ok),
    'refund_due' => ('Refund in progress', AppColors.warn),
    'no_show' => ('Missed', p.muted),
    'cancelled' => ('Cancelled', p.muted),
    _ => (b.status, p.muted),
  };
}

class InterviewerTile extends StatelessWidget {
  const InterviewerTile({super.key, required this.info, this.dense = false});
  final InterviewerInfo info;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Avatar(name: info.name, size: dense ? 36 : 44),
      const SizedBox(width: Space.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(info.name, style: dense ? t.titleSmall : t.titleMedium),
          Text(info.line, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: p.muted)),
          if (!dense && (info.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text(info.bio!, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodySmall),
          ],
        ]),
      ),
    ]);
  }
}

/// The interviewer's scores as bars, plus the overall.
class ScoreBars extends StatelessWidget {
  const ScoreBars({super.key, required this.card, required this.areaName});
  final Scorecard card;
  final String Function(String id) areaName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final good = card.recommendation == 'strong_hire' || card.recommendation == 'hire';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(card.overall.toStringAsFixed(1), style: t.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: p.ink, height: 1)),
        Padding(padding: const EdgeInsets.only(left: 6, bottom: 4), child: Text('out of 5', style: t.bodySmall)),
        const Spacer(),
        Pill(text: card.recommendationLabel, color: good ? AppColors.ok : AppColors.warn),
      ]),
      const SizedBox(height: Space.lg),
      for (final e in card.scores.entries) ...[
        Row(children: [
          Expanded(child: Text(areaName(e.key), style: t.bodyMedium)),
          Text('${e.value}/5', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: p.ink, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: e.value / 5, minHeight: 6, color: e.value >= 4 ? AppColors.ok : e.value == 3 ? AppColors.gold : AppColors.warn),
        ),
        const SizedBox(height: Space.md),
      ],
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';

/// Asks why a job is being reported. Returns (reason, details) or null.
Future<(String, String?)?> showReportSheet(BuildContext context) => showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _ReportSheet(),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String _reason = 'asks_fees';
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Report this job', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Reports are private. Jobs reported by several people are taken down for review.'),
          const SizedBox(height: 8),
          // Simple chips instead of radio buttons: works the same on every Flutter version
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in Labels.report.entries)
              ChoiceChip(label: Text(e.value), selected: _reason == e.key, onSelected: (_) => setState(() => _reason = e.key)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _details, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'Details (optional)')),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, (_reason, _details.text)), child: const Text('Send report'))),
        ]),
      );
}

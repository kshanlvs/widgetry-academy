import 'package:flutter/material.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';

/// Bottom sheet for job type, work mode, experience, city and skill. Returns the new filter or null.
Future<JobFilter?> showJobFilters(BuildContext context, {required JobFilter filter, required JobsMeta meta}) {
  return showModalBottomSheet<JobFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _FiltersSheet(filter: filter, meta: meta),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.filter, required this.meta});
  final JobFilter filter;
  final JobsMeta meta;
  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late JobFilter f = widget.filter;

  Widget _group(String title, Map<String, String> options, String? selected, void Function(String?) onPick) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in options.entries)
              ChoiceChip(label: Text(e.value), selected: selected == e.key, onSelected: (on) => setState(() => onPick(on ? e.key : null))),
          ]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final cat = widget.meta.categories.where((c) => c.slug == f.category).firstOrNull;
    final skills = {...(cat?.suggestedSkills ?? widget.meta.skills).take(14), if (f.skill != null) f.skill!};
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
            Row(children: [
              Expanded(child: Text('Filters', style: Theme.of(context).textTheme.titleLarge)),
              if (f.activeCount > 0) TextButton(onPressed: () => setState(() => f = f.clearedFilters()), child: const Text('Reset')),
            ]),
            _group('Job type', Labels.jobType, f.type, (v) => f = f.copyWith(type: () => v)),
            _group('Work mode', Labels.workMode, f.mode, (v) => f = f.copyWith(mode: () => v)),
            _group('Experience', Labels.level, f.level, (v) => f = f.copyWith(level: () => v)),
            if (widget.meta.cities.isNotEmpty) _group('City', {for (final c in widget.meta.cities) c: c}, f.city, (v) => f = f.copyWith(city: () => v)),
            if (skills.isNotEmpty) _group('Skill', {for (final s in skills) s: s}, f.skill, (v) => f = f.copyWith(skill: () => v)),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, f), child: Text(f.activeCount == 0 ? 'Show all jobs' : 'Show jobs (${f.activeCount} ${f.activeCount == 1 ? 'filter' : 'filters'})'))),
            ]),
          ),
        ),
      ]),
    );
  }
}

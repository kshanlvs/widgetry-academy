import 'package:flutter/material.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';

/// One job in a list: logo, title, company, a single line of facts, salary and age.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.categoryName, required this.onTap, this.trailing});
  final Job job;
  final String categoryName;
  final VoidCallback onTap;
  final Widget? trailing;

  static String whereText(Job j) => j.mode == 'remote' ? 'Remote' : [if ((j.city ?? '').isNotEmpty) j.city!, Labels.workMode[j.mode] ?? j.mode].join(' · ');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final salary = job.salary == null ? '' : Fmt.salary(min: job.salary!.min, max: job.salary!.max, period: job.salary!.period, short: true);
    final facts = [whereText(job), Labels.jobType[job.type] ?? job.type, (Labels.level[job.level] ?? job.level).split(' (').first].join('  ·  ');

    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: job.featured ? AppColors.gold.withValues(alpha: 0.7) : p.line, width: job.featured ? 1.3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hero(tag: 'logo-${job.id}', child: CompanyLogo(name: job.company.name, size: 44)),
            const SizedBox(width: Space.md + 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(height: 1.28))),
                  if (trailing != null) trailing!,
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Flexible(child: Text(job.company.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: p.muted, fontWeight: FontWeight.w500))),
                  if (job.company.verified) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 15, color: p.accent)),
                ]),
                const SizedBox(height: Space.sm + 2),
                Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: p.ink.withValues(alpha: 0.72), fontWeight: FontWeight.w500)),
                const SizedBox(height: Space.md),
                Row(children: [
                  CategoryBadge(slug: job.category, name: categoryName),
                  if (salary.isNotEmpty) ...[
                    _dot(p),
                    Flexible(child: Text(salary, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: p.ink, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]))),
                  ],
                  const Spacer(),
                  if (job.featured) ...[
                    Text('Featured', style: t.bodySmall?.copyWith(color: AppColors.warn, fontWeight: FontWeight.w700)),
                    _dot(p),
                  ],
                  Text(Fmt.timeAgo(job.postedAt), style: t.bodySmall?.copyWith(color: p.faint)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static Widget _dot(Palette p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(width: 3, height: 3, decoration: BoxDecoration(color: p.faint, shape: BoxShape.circle)),
      );
}

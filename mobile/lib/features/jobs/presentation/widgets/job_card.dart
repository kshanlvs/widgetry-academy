import 'package:flutter/material.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.categoryName, required this.onTap, this.trailing});
  final Job job;
  final String categoryName;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final where = job.mode == 'remote' ? 'Remote' : '${job.city ?? ''} · ${Labels.workMode[job.mode] ?? job.mode}';
    final salary = job.salary == null ? '' : Fmt.salary(min: job.salary!.min, max: job.salary!.max, period: job.salary!.period, short: true);
    return Card(
      shape: job.featured
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.gold, width: 1.6))
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CompanyLogo(name: job.company.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(job.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25))),
                  if (trailing != null) trailing!,
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Flexible(child: Text(job.company.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  if (job.company.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 16, color: AppColors.ok)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  CategoryBadge(slug: job.category, name: categoryName),
                  Pill(text: Labels.jobType[job.type] ?? job.type, icon: Icons.work_outline),
                  Pill(text: where, icon: Icons.place_outlined),
                  Pill(text: Labels.level[job.level] ?? job.level, icon: Icons.trending_up),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  if (salary.isNotEmpty) Text(salary, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.green)),
                  const Spacer(),
                  if (job.featured) const Padding(padding: EdgeInsets.only(right: 8), child: Text('★ Featured', style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w700, fontSize: 12))),
                  Text(Fmt.timeAgo(job.postedAt), style: t.bodySmall),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

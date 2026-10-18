import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/features/workshops/domain/workshops.dart';
import 'package:widgetry_academy/features/workshops/presentation/workshops_cubits.dart';

/// Home screen: one tile per short live course (e.g. the Bloc crash course). Shows nothing when there are none.
class ShortCourseTiles extends StatelessWidget {
  const ShortCourseTiles({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<WorkshopsListCubit>()..load(),
        child: BlocBuilder<WorkshopsListCubit, WorkshopsListState>(
          builder: (context, s) => s.items.isEmpty
              ? const SizedBox.shrink()
              : Column(children: [for (final w in s.items) _Tile(w: w)]),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.w});
  final Workshop w;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final sub = w.datesComingSoon
        ? 'Live crash course · dates coming soon'
        : [w.schedule ?? (w.startsAt == null ? null : Fmt.date(w.startsAt!)), w.isFull ? 'Full' : Fmt.rupees(w.payNow)].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/short-courses/${w.slug}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(Icons.bolt_rounded, color: p.accent, size: 24),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(w.title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (w.isOpen && w.earlyPrice != null) ...[
                      const SizedBox(width: Space.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(4)),
                        child: Text('EARLY BIRD', style: t.labelSmall?.copyWith(color: AppColors.warn, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(sub, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: p.faint),
            ]),
          ),
        ),
      ),
    );
  }
}

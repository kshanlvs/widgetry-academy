import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/presentation/bloc/jobs_bloc.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/filters_sheet.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/home_highlights.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/job_card.dart';

class JobsPage extends StatelessWidget {
  const JobsPage({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<JobsBloc>()..add(JobsStarted(category: initialCategory)),
        child: const _JobsView(),
      );
}

class _JobsView extends StatefulWidget {
  const _JobsView();
  @override
  State<_JobsView> createState() => _JobsViewState();
}

class _JobsViewState extends State<_JobsView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) context.read<JobsBloc>().add(const JobsNextPageRequested());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh(JobsBloc bloc) {
    final done = Completer<void>();
    bloc.add(JobsRefreshed(done: done));
    return done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: BlocBuilder<JobsBloc, JobsState>(
        builder: (context, s) {
          final bloc = context.read<JobsBloc>();
          final live = s.meta.liveJobs > 0 ? s.meta.liveJobs : s.meta.categories.fold<int>(0, (a, c) => a + c.liveJobs);
          // Browsing (not searching or filtering): show the course banners and the featured row
          final browsing = s.filter.query.isEmpty && s.filter.activeCount == 0;
          final featured = browsing ? s.jobs.where((j) => j.featured).toList() : const <Job>[];
          final listed = featured.isEmpty ? s.jobs : s.jobs.where((j) => !j.featured).toList();
          return RefreshIndicator(
            onRefresh: () => _refresh(bloc),
            edgeOffset: 120,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  toolbarHeight: 60,
                  title: const Wordmark(suffix: 'Jobs', size: 17),
                  actions: [
                    IconButton(tooltip: 'Saved jobs', icon: const Icon(Icons.bookmark_border_rounded), onPressed: () => context.push('/jobs/saved')),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (_) => getIt<LinkLauncher>().openInApp(AppConfig.postJobUrl),
                      itemBuilder: (_) => const [PopupMenuItem(value: 'post', child: Text('Post a job (employers)'))],
                    ),
                    const SizedBox(width: Space.xs),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.lg),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mobile developer jobs', style: t.headlineSmall),
                      const SizedBox(height: 4),
                      Text(live > 0 ? '$live open roles in India · every post checked by an engineer' : 'Every post checked by an engineer before it goes live', style: t.bodyMedium?.copyWith(color: p.muted)),
                    ]),
                  ),
                ),
                if (browsing) const SliverToBoxAdapter(child: CourseBanners()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchHeader(
                    background: p.bg,
                    line: p.line,
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 0),
                        child: Row(children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: TextField(
                                controller: _search,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Role, skill or company',
                                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                                  contentPadding: EdgeInsets.zero,
                                  suffixIcon: s.filter.query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          icon: const Icon(Icons.close_rounded, size: 19),
                                          onPressed: () {
                                            _search.clear();
                                            bloc.add(const JobsSearchSubmitted(''));
                                          },
                                        ),
                                ),
                                onSubmitted: (q) => bloc.add(JobsSearchSubmitted(q)),
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          _FilterButton(
                            count: s.filter.activeCount,
                            onTap: () async {
                              final f = await showJobFilters(context, filter: s.filter, meta: s.meta);
                              if (f != null) bloc.add(JobsFiltersApplied(f));
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: Space.sm),
                      _CategoryTabs(meta: s.meta, selected: s.filter.category, total: live, onSelect: (slug) => bloc.add(JobsCategorySelected(slug))),
                    ]),
                  ),
                ),
                if (s.status == JobsStatus.loading || s.status == JobsStatus.initial)
                  const SliverSkeletonList()
                else if (s.status == JobsStatus.failure)
                  SliverFillRemaining(hasScrollBody: false, child: ErrorView(message: s.error ?? 'Could not load jobs.', onRetry: () => bloc.add(JobsFiltersApplied(s.filter))))
                else if (s.jobs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.search_off_rounded,
                      title: s.filter.query.isEmpty && s.filter.activeCount == 0 ? 'No openings here yet' : 'No jobs match',
                      message: s.filter.query.isEmpty && s.filter.activeCount == 0 ? 'New roles are added every week. Turn on job alerts in Settings to hear first.' : 'Try fewer filters or a different search.',
                      action: s.filter.activeCount > 0 ? OutlinedButton(onPressed: () => bloc.add(JobsFiltersApplied(s.filter.clearedFilters())), child: const Text('Clear filters')) : null,
                    ),
                  )
                else ...[
                  if (featured.isNotEmpty) SliverToBoxAdapter(child: FeaturedJobsRow(jobs: featured, categoryName: s.meta.categoryName)),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(Space.page, featured.isNotEmpty ? Space.xl : Space.md, Space.page, Space.sm),
                    sliver: SliverToBoxAdapter(
                      child: featured.isNotEmpty
                          ? Row(children: [
                              Text('Latest jobs', style: t.titleSmall),
                              const Spacer(),
                              Text('${s.total} ${s.total == 1 ? 'job' : 'jobs'}', style: t.bodySmall?.copyWith(color: p.faint)),
                            ])
                          : Text(
                              '${s.total} ${s.total == 1 ? 'job' : 'jobs'}${s.filter.query.isEmpty ? '' : ' for “${s.filter.query}”'}',
                              style: t.bodySmall?.copyWith(color: p.faint),
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxxl),
                    sliver: SliverList.separated(
                      itemCount: listed.length + (s.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: Space.md),
                      itemBuilder: (context, i) {
                        if (i >= listed.length) return const Padding(padding: EdgeInsets.all(Space.lg), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))));
                        final j = listed[i];
                        return JobCard(job: j, categoryName: s.meta.categoryName(j.category), onTap: () => context.push('/jobs/${j.id}'));
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  _SearchHeader({required this.child, required this.background, required this.line});
  final Widget child;
  final Color background;
  final Color line;
  static const _h = 108.0;

  @override
  double get minExtent => _h;
  @override
  double get maxExtent => _h;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        decoration: BoxDecoration(color: background, border: Border(bottom: BorderSide(color: overlapsContent || shrinkOffset > 0 ? line : Colors.transparent))),
        padding: const EdgeInsets.only(top: Space.xs),
        child: child,
      );

  @override
  bool shouldRebuild(_SearchHeader old) => true;
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final on = count > 0;
    return Material(
      color: on ? p.ink : p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: on ? p.ink : p.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 19, color: on ? p.bg : p.ink),
              if (on) ...[const SizedBox(width: 6), Text('$count', style: TextStyle(color: p.bg, fontWeight: FontWeight.w700))],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Underlined category tabs with live counts: All · Flutter · Android · iOS.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.meta, required this.selected, required this.total, required this.onSelect});
  final JobsMeta meta;
  final String? selected;
  final int total;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <(String?, String, int)>[
      (null, 'All', total),
      for (final c in meta.categories) (c.slug, c.name, c.liveJobs),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.page - 4),
        children: [for (final (slug, name, n) in items) _Tab(label: name, count: n, selected: selected == slug, onTap: () => onSelect(slug))],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.count, required this.selected, required this.onTap});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InkWell(
      onTap: selected
          ? null
          : () {
              tick();
              onTap();
            },
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? p.accent : Colors.transparent, width: 2.2))),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? p.ink : p.muted)),
              if (count > 0) TextSpan(text: '  $count', style: TextStyle(fontWeight: FontWeight.w600, color: selected ? p.accent : p.faint, fontSize: 12.5)),
            ]),
            style: const TextStyle(fontSize: 14.5),
          ),
        ),
      ),
    );
  }
}

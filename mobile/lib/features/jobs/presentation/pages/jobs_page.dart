import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/jobs/presentation/bloc/jobs_bloc.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/filters_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          IconButton(tooltip: 'Saved jobs', icon: const Icon(Icons.bookmark_outline), onPressed: () => context.push('/jobs/saved')),
          PopupMenuButton<String>(
            onSelected: (v) => getIt<LinkLauncher>().openInApp(AppConfig.postJobUrl),
            itemBuilder: (_) => const [PopupMenuItem(value: 'post', child: Text('Post a job (employers)'))],
          ),
        ],
      ),
      body: BlocBuilder<JobsBloc, JobsState>(
        builder: (context, s) {
          final bloc = context.read<JobsBloc>();
          return RefreshIndicator(
            onRefresh: () {
              final done = Completer<void>();
              bloc.add(JobsRefreshed(done: done));
              return done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search: Flutter intern, Kotlin, SwiftUI…',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: s.filter.query.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); bloc.add(const JobsSearchSubmitted('')); }),
                          ),
                          onSubmitted: (q) => bloc.add(JobsSearchSubmitted(q)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: s.filter.activeCount > 0,
                        label: Text('${s.filter.activeCount}'),
                        child: IconButton.filledTonal(
                          tooltip: 'Filters',
                          icon: const Icon(Icons.tune),
                          onPressed: () async {
                            final f = await showJobFilters(context, filter: s.filter, meta: s.meta);
                            if (f != null) bloc.add(JobsFiltersApplied(f));
                          },
                        ),
                      ),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 46,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                      _tab(context, null, 'All', s.meta.categories.fold<int>(0, (a, c) => a + c.liveJobs), s.filter.category == null),
                      for (final c in s.meta.categories) _tab(context, c.slug, c.name, c.liveJobs, s.filter.category == c.slug),
                    ]),
                  ),
                ),
                if (s.status == JobsStatus.loading || s.status == JobsStatus.initial)
                  const SliverFillRemaining(child: LoadingView())
                else if (s.status == JobsStatus.failure)
                  SliverFillRemaining(child: ErrorView(message: s.error ?? 'Could not load jobs.', onRetry: () => bloc.add(JobsFiltersApplied(s.filter))))
                else if (s.jobs.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyView(icon: Icons.work_off_outlined, title: 'No jobs match yet', message: 'Try fewer filters or another category. New jobs are added every week.'),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    sliver: SliverToBoxAdapter(child: Text('${s.total} job${s.total == 1 ? '' : 's'}${s.filter.query.isEmpty ? '' : ' for “${s.filter.query}”'}', style: Theme.of(context).textTheme.bodySmall)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: s.jobs.length + (s.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i >= s.jobs.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                        final j = s.jobs[i];
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

  Widget _tab(BuildContext context, String? slug, String label, int count, bool selected) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label  $count'),
          selected: selected,
          onSelected: (_) => context.read<JobsBloc>().add(JobsCategorySelected(slug)),
        ),
      );
}

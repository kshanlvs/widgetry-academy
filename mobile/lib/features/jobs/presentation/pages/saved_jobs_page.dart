import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/presentation/cubit/saved_jobs_cubit.dart';
import 'package:widgetry_academy/features/jobs/presentation/widgets/job_card.dart';

class SavedJobsPage extends StatelessWidget {
  const SavedJobsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<SavedJobsCubit>()..load(),
        child: Scaffold(
          appBar: AppBar(title: const Text('Saved jobs')),
          body: BlocBuilder<SavedJobsCubit, SavedJobsState>(
            builder: (context, s) {
              if (s.loading) return const SkeletonList(count: 3);
              if (s.error != null) return ErrorView(message: s.error!);
              if (s.jobs.isEmpty) {
                return const EmptyView(icon: Icons.bookmark_border_rounded, title: 'Nothing saved yet', message: 'Tap the bookmark on a job to keep it here. Saved jobs stay on this phone.');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: s.jobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final j = s.jobs[i];
                  return JobCard(
                    job: j,
                    categoryName: JobsMeta.fallback.categoryName(j.category),
                    onTap: () async {
                      await context.push('/jobs/${j.id}');
                      if (context.mounted) await context.read<SavedJobsCubit>().load();
                    },
                    trailing: IconButton(tooltip: 'Remove from saved', visualDensity: VisualDensity.compact, icon: const Icon(Icons.bookmark_rounded), onPressed: () => context.read<SavedJobsCubit>().remove(j)),
                  );
                },
              );
            },
          ),
        ),
      );
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';

class SavedJobsState extends Equatable {
  const SavedJobsState({this.loading = true, this.jobs = const [], this.error});
  final bool loading;
  final List<Job> jobs;
  final String? error;
  @override
  List<Object?> get props => [loading, jobs, error];
}

@injectable
class SavedJobsCubit extends Cubit<SavedJobsState> {
  SavedJobsCubit(this._get, this._toggle) : super(const SavedJobsState());
  final GetSavedJobs _get;
  final ToggleSavedJob _toggle;

  Future<void> load() async {
    final r = await _get(const NoParams());
    emit(r.fold((f) => SavedJobsState(loading: false, error: f.message), (jobs) => SavedJobsState(loading: false, jobs: jobs)));
  }

  Future<void> remove(Job job) async {
    await _toggle(job);
    await load();
  }
}

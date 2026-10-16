import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';

enum DetailStatus { loading, ready, failure }

class JobDetailState extends Equatable {
  const JobDetailState({this.status = DetailStatus.loading, this.job, this.saved = false, this.error, this.message, this.reported = false});
  final DetailStatus status;
  final Job? job;
  final bool saved;
  final String? error;
  final String? message;
  final bool reported;

  JobDetailState copyWith({DetailStatus? status, Job? job, bool? saved, String? error, String? message, bool? reported}) => JobDetailState(
        status: status ?? this.status,
        job: job ?? this.job,
        saved: saved ?? this.saved,
        error: error,
        message: message,
        reported: reported ?? this.reported,
      );

  @override
  List<Object?> get props => [status, job, saved, error, message, reported];
}

@injectable
class JobDetailCubit extends Cubit<JobDetailState> {
  JobDetailCubit(this._get, this._isSaved, this._toggle, this._report, this._links) : super(const JobDetailState());
  final GetJobDetail _get;
  final IsJobSaved _isSaved;
  final ToggleSavedJob _toggle;
  final ReportJob _report;
  final LinkLauncher _links;

  Future<void> load(String id) async {
    if (state.status != DetailStatus.loading) emit(state.copyWith(status: DetailStatus.loading));
    final saved = (await _isSaved(id)).valueOrNull ?? false;
    final r = await _get(id);
    r.fold(
      (f) => emit(state.copyWith(status: DetailStatus.failure, error: f.message)),
      (job) => emit(state.copyWith(status: DetailStatus.ready, job: job, saved: saved)),
    );
  }

  Future<void> toggleSave() async {
    final job = state.job;
    if (job == null) return;
    final r = await _toggle(job);
    r.fold((f) => emit(state.copyWith(message: f.message)), (saved) => emit(state.copyWith(saved: saved, message: saved ? 'Saved to your jobs' : 'Removed from saved jobs')));
  }

  /// Opens the employer's own careers page, or an email to them.
  Future<void> apply() async {
    final job = state.job;
    if (job == null || !job.canApply) return;
    final ok = (job.applyUrl ?? '').isNotEmpty
        ? await _links.openInApp(job.applyUrl!)
        : await _links.email(job.applyEmail!, subject: 'Application: ${job.title} (via Widgetry Jobs)');
    if (!ok) emit(state.copyWith(message: "Couldn't open the application link."));
  }

  Future<void> share() async {
    final job = state.job;
    if (job == null) return;
    await _links.share('${job.title} at ${job.company.name}\n${job.shareUrl}', subject: job.title);
  }

  Future<void> report(String reason, String? details) async {
    final job = state.job;
    if (job == null) return;
    final r = await _report(ReportJobParams(jobId: job.id, reason: reason, details: details));
    r.fold((f) => emit(state.copyWith(message: f.message)), (_) => emit(state.copyWith(reported: true, message: "Thanks. We'll review this job.")));
  }
}

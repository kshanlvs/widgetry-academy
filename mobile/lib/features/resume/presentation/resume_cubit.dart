import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:widgetry_academy/features/resume/domain/resume.dart';

class ResumeState extends Equatable {
  const ResumeState({
    this.premium = const ResumePremium(),
    this.versions = const [],
    this.versionId,
    this.look = const ResumeSettings(),
    this.pdf,
    this.building = false,
    this.pdfError,
    this.ats,
    this.atsLoading = false,
    this.job,
    this.ai = const {},
    this.aiBusy,
    this.buying = false,
    this.message,
    this.error,
  });

  final ResumePremium premium;
  final List<ResumeVersion> versions;
  /// The saved copy on screen, or null for the main resume.
  final int? versionId;
  /// How it looks right now (saved to the account a moment after each change).
  final ResumeSettings look;
  final ResumeFile? pdf;
  final bool building;
  final String? pdfError;
  final AtsResult? ats;
  final bool atsLoading;
  final TargetJob? job;
  final Map<AiAction, AiResult> ai;
  final AiAction? aiBusy;
  final bool buying;
  final String? message;
  final String? error;

  ResumeVersion? get version => versions.where((v) => v.id == versionId).firstOrNull;
  /// A Premium template without Premium: watermarked preview, no download.
  bool get locked => !premium.canUse(look.template);
  /// Pro features (colour, photo, fit to one page, Key highlights) apply: with Premium, or while previewing a Pro template.
  bool get fullLook => premium.active || proTemplates.contains(look.template);

  ResumeState copyWith({
    ResumePremium? premium,
    List<ResumeVersion>? versions,
    int? versionId,
    bool clearVersion = false,
    ResumeSettings? look,
    ResumeFile? pdf,
    bool? building,
    String? pdfError,
    AtsResult? ats,
    bool? atsLoading,
    TargetJob? job,
    bool clearJob = false,
    Map<AiAction, AiResult>? ai,
    AiAction? aiBusy,
    bool clearAiBusy = false,
    bool? buying,
    String? message,
    String? error,
  }) =>
      ResumeState(
        premium: premium ?? this.premium,
        versions: versions ?? this.versions,
        versionId: clearVersion ? null : (versionId ?? this.versionId),
        look: look ?? this.look,
        pdf: pdf ?? this.pdf,
        building: building ?? this.building,
        pdfError: pdfError,
        ats: ats ?? this.ats,
        atsLoading: atsLoading ?? this.atsLoading,
        job: clearJob ? null : (job ?? this.job),
        ai: ai ?? this.ai,
        aiBusy: clearAiBusy ? null : (aiBusy ?? this.aiBusy),
        buying: buying ?? this.buying,
        message: message,
        error: error,
      );

  @override
  List<Object?> get props => [premium, versions, versionId, look, pdf, building, pdfError, ats, atsLoading, job, ai, aiBusy, buying, message, error];
}

/// The resume screen: live PDF preview, ATS check, AI writer, design and saved copies.
@injectable
class ResumeCubit extends Cubit<ResumeState> {
  ResumeCubit(this._profile, this._premium, this._pdf, this._word, this._ats, this._versions, this._ai, this._repo, this._buy, this._recover)
      : super(ResumeState(look: _profile.state.profile?.resumeSettings ?? const ResumeSettings()));

  final ProfileCubit _profile;
  final GetResumePremium _premium;
  final MakeResumePdf _pdf;
  final MakeResumeWord _word;
  final CheckResumeAts _ats;
  final GetResumeVersions _versions;
  final RunResumeAi _ai;
  final ResumeRepository _repo;
  final BuyResumePremium _buy;
  final RecoverResumePurchases _recover;
  Timer? _debounce;
  int _pdfRequest = 0;

  Future<void> start() async {
    await Future.wait([_loadPremium(), _loadVersions(), _buildPdf(), _check()]);
  }

  Future<void> _loadPremium() async {
    final r = await _premium(const NoParams());
    final p = r.valueOrNull;
    if (p == null || isClosed) return;
    emit(state.copyWith(premium: p));
    // A Google Play purchase that never got confirmed (app closed mid-way): confirm it now
    if (!p.active && p.android != null && await _recover(p.android!) > 0) await _loadPremium();
  }

  Future<void> _loadVersions() async {
    final r = await _versions(const NoParams());
    if (!isClosed && r.valueOrNull != null) emit(state.copyWith(versions: r.valueOrNull));
  }

  Future<void> _buildPdf() async {
    final n = ++_pdfRequest;
    emit(state.copyWith(building: true));
    final r = await _pdf(ResumeLook(state.look, versionId: state.versionId));
    if (isClosed || n != _pdfRequest) return; // a newer change is on its way
    r.fold((f) => emit(state.copyWith(building: false, pdfError: f.message)), (file) => emit(state.copyWith(building: false, pdf: file)));
  }

  Future<void> _check() async {
    emit(state.copyWith(atsLoading: true));
    final r = await _ats(AtsParams(versionId: state.versionId, job: state.job));
    if (isClosed) return;
    r.fold((f) => emit(state.copyWith(atsLoading: false, error: f.message)), (a) => emit(state.copyWith(atsLoading: false, ats: a)));
  }

  /// Template, colour, size, sections or title changed: preview again and save.
  void setLook(ResumeSettings look) {
    emit(state.copyWith(look: look));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _buildPdf();
      // Premium templates are only saved with Premium; the preview still shows them
      if (state.premium.canUse(look.template)) _profile.saveResumeSettings(look);
    });
  }

  Future<void> refreshPreview() => _buildPdf();

  void openVersion(int? id) {
    emit(id == null ? state.copyWith(clearVersion: true, ai: const {}) : state.copyWith(versionId: id, ai: const {}));
    _buildPdf();
    _check();
  }

  Future<void> setJob(TargetJob? job) async {
    emit(job == null ? state.copyWith(clearJob: true) : state.copyWith(job: job));
    await _check();
  }

  Future<ResumeFile?> download({required bool word}) async {
    final r = await (word ? _word : _pdf)(ResumeLook(state.look, versionId: state.versionId));
    return r.fold((f) {
      emit(state.copyWith(error: f.message));
      return null;
    }, (f) => f);
  }

  Future<void> runAi(AiAction action, {int? experienceIndex}) async {
    if (state.aiBusy != null) return;
    emit(state.copyWith(aiBusy: action, ai: {...state.ai}..remove(action)));
    final r = await _ai(AiRequest(action, job: state.job, experienceIndex: experienceIndex));
    if (isClosed) return;
    r.fold(
      (f) {
        final ended = f.message.contains('Premium');
        emit(state.copyWith(clearAiBusy: true, error: f.message, premium: ended ? state.premium.copyWith(active: false) : null));
      },
      (reply) => emit(state.copyWith(clearAiBusy: true, ai: {...state.ai, action: reply.result}, premium: state.premium.copyWith(aiLeftToday: reply.aiLeftToday))),
    );
  }

  /// Puts an AI suggestion into the resume on screen: the saved copy if one is open, else the main resume.
  Future<void> applyAi(AiAction action) async {
    final res = state.ai[action];
    if (res == null) return;
    final p = _profile.state.profile;
    String? about;
    var points = <int, String>{};
    var addSkills = <String>[];
    switch (res) {
      case SummaryResult(:final summary):
        about = summary;
      case BulletsResult(:final index, points: final list):
        points = {index: list.join('\n')};
      case TailorResult(:final summary, :final jobs, addSkills: final add):
        about = summary;
        points = {for (final e in jobs.entries) e.key: e.value.join('\n')};
        addSkills = add;
      case CoverResult():
        return;
    }
    final before = state.ats?.score;
    final v = state.version;
    if (v != null) {
      final skills = addSkills.isEmpty ? null : {...(v.skills ?? p?.skills ?? const <String>[]), ...addSkills}.take(15).toList();
      final r = await _repo.updateVersion(v.id, about: about, skills: skills, points: points.isEmpty ? null : {...v.points, ...points});
      if (isClosed) return;
      r.fold((f) => emit(state.copyWith(error: f.message)), (nv) => emit(state.copyWith(versions: [for (final x in state.versions) x.id == nv.id ? nv : x], ai: {...state.ai}..remove(action))));
    } else {
      final r = await _repo.applyToMain(about: about, points: points, addSkills: addSkills);
      if (isClosed) return;
      r.fold((f) => emit(state.copyWith(error: f.message)), (profile) {
        _profile.replaceProfile(profile);
        emit(state.copyWith(ai: {...state.ai}..remove(action)));
      });
    }
    await Future.wait([_buildPdf(), _check()]);
    if (!isClosed && before != null && state.ats != null) emit(state.copyWith(message: 'Saved · ATS score $before → ${state.ats!.score}'));
  }

  /// Tailored for a job and kept as its own copy, so the main resume stays as it is.
  Future<void> saveAsCopy(String name) async {
    final res = state.ai[AiAction.tailor];
    if (res is! TailorResult) return;
    final p = _profile.state.profile;
    final job = state.job;
    final r = await _repo.createVersion(VersionDraft(
      name: name,
      jobId: job?.id,
      jobTitle: job?.title,
      company: job?.company,
      title: job?.title,
      about: res.summary,
      skills: {...?p?.skills, ...res.addSkills}.take(15).toList(),
      points: {for (final e in res.jobs.entries) e.key: e.value.join('\n')},
    ));
    if (isClosed) return;
    await r.fold((f) async => emit(state.copyWith(error: f.message)), (v) async {
      emit(state.copyWith(versions: [v, ...state.versions], versionId: v.id, ai: {...state.ai}..remove(AiAction.tailor), message: 'Saved "$name". Your main resume is unchanged.'));
      await Future.wait([_buildPdf(), _check()]);
    });
  }

  Future<void> renameVersion(int id, String name) async {
    final r = await _repo.updateVersion(id, name: name);
    if (!isClosed) r.fold((f) => emit(state.copyWith(error: f.message)), (nv) => emit(state.copyWith(versions: [for (final x in state.versions) x.id == id ? nv : x])));
  }

  Future<void> deleteVersion(int id) async {
    final r = await _repo.deleteVersion(id);
    if (isClosed) return;
    r.fold((f) => emit(state.copyWith(error: f.message)), (_) {
      final wasOpen = state.versionId == id;
      emit(state.copyWith(versions: state.versions.where((v) => v.id != id).toList(), clearVersion: wasOpen, message: 'Copy deleted'));
      if (wasOpen) {
        _buildPdf();
        _check();
      }
    });
  }

  /// [taxState]: the person's state, needed when Google's choice screen is used.
  Future<void> buy({String? taxState}) async {
    if (state.buying) return;
    emit(state.copyWith(buying: true));
    final r = await _buy(BuyPremiumRequest(state.premium, state: taxState));
    if (isClosed) return;
    await r.fold((f) async => emit(state.copyWith(buying: false, error: f.message)), (o) async {
      emit(state.copyWith(buying: false, message: switch (o) {
        BuyOutcome.active => 'Resume Premium is on ✨',
        BuyOutcome.pending => 'Payment received. Premium switches on in a few minutes.',
        BuyOutcome.cancelled => null,
      }));
      if (o != BuyOutcome.cancelled) {
        await _loadPremium();
        if (state.premium.active) {
          _profile.saveResumeSettings(state.look);
          await _buildPdf();
        }
      }
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

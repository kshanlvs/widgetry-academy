import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';

// The resume is made by the same engine as the website (on the server): 6 templates, the ATS check,
// resume import, AI writing help and saved copies per job. The app shows and controls it.

/// Templates, in the order shown. The last three need Resume Premium (a watermarked preview otherwise).
const resumeTemplates = {'modern': 'Modern', 'classic': 'Classic', 'compact': 'Compact', 'executive': 'Executive', 'minimal': 'Minimal', 'elegant': 'Elegant'};
const proTemplates = {'executive', 'minimal', 'elegant'};
const resumeDensities = {'normal': 'Normal', 'compact': 'Snug', 'tight': 'Fit more'};
const resumeParts = {
  'photo': 'Photo', 'phone': 'Phone', 'email': 'Email', 'city': 'City', 'summary': 'Summary', 'projects': 'Projects',
  'achievements': 'Achievements', 'education': 'Education', 'certifications': 'Certifications', 'languages': 'Languages',
};

/// Resume Premium: price and whether this person has it.
class ResumePremium extends Equatable {
  const ResumePremium({
    this.active = false,
    this.expiresAt,
    this.price = 299,
    this.days = 30,
    this.aiLeftToday,
    this.paymentsEnabled = true,
    this.playProductId,
    this.android,
    this.maxVersions = 5,
  });
  final bool active;
  final DateTime? expiresAt;
  final int price;
  final int days;
  final int? aiLeftToday;
  final bool paymentsEnabled;
  /// One-time product in Google Play ("resume_premium_299"), when Google's choice screen is used.
  final String? playProductId;
  final AndroidBilling? android;
  final int maxVersions;

  /// Bought before and now over.
  bool get ended => !active && expiresAt != null;
  bool get endsSoon => active && expiresAt != null && expiresAt!.difference(DateTime.now()).inDays < 5;
  bool canUse(String template) => active || !proTemplates.contains(template);

  ResumePremium copyWith({int? aiLeftToday, bool? active, DateTime? expiresAt}) => ResumePremium(
        active: active ?? this.active, expiresAt: expiresAt ?? this.expiresAt, price: price, days: days, aiLeftToday: aiLeftToday ?? this.aiLeftToday,
        paymentsEnabled: paymentsEnabled, playProductId: playProductId, android: android, maxVersions: maxVersions);

  @override
  List<Object?> get props => [active, expiresAt, price, days, aiLeftToday, paymentsEnabled, playProductId, android, maxVersions];
}

/// A saved copy of the resume for one job: only what differs from the main resume.
class ResumeVersion extends Equatable {
  const ResumeVersion({required this.id, required this.name, this.jobTitle, this.company, this.title, this.about, this.skills, this.points = const {}});
  final int id;
  final String name;
  final String? jobTitle;
  final String? company;
  /// Shown under the name instead of the headline.
  final String? title;
  final String? about;
  final List<String>? skills;
  /// Job index → its points (one per line).
  final Map<int, String> points;

  String get subtitle => [jobTitle, company].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  @override
  List<Object?> get props => [id, name, jobTitle, company, title, about, skills, points];
}

/// What to put in a saved copy.
class VersionDraft extends Equatable {
  const VersionDraft({required this.name, this.jobId, this.jobTitle, this.company, this.title, this.about, this.skills, this.points = const {}});
  final String name;
  final String? jobId;
  final String? jobTitle;
  final String? company;
  final String? title;
  final String? about;
  final List<String>? skills;
  final Map<int, String> points;
  @override
  List<Object?> get props => [name, jobId, jobTitle, company, title, about, skills, points];
}

/// The job a resume is checked or tailored against: a Widgetry job or a pasted description.
class TargetJob extends Equatable {
  const TargetJob({this.id, required this.title, this.company, this.text});
  final String? id;
  final String title;
  final String? company;
  /// Pasted description (null for a Widgetry job: the server reads it).
  final String? text;
  @override
  List<Object?> get props => [id, title, company, text];
}

class AtsCategory extends Equatable {
  const AtsCategory({required this.label, required this.score, required this.max, required this.status, required this.detail, this.tips = const []});
  final String label;
  final int score;
  final int max;
  /// "good", "ok" or "bad"
  final String status;
  final String detail;
  final List<String> tips;
  @override
  List<Object?> get props => [label, score, max, status, detail, tips];
}

class AtsResult extends Equatable {
  const AtsResult({required this.score, required this.grade, required this.mode, this.categories = const [], this.matched = const [], this.missing = const [], this.key = const [], this.job});
  final int score;
  final String grade;
  /// "job" (checked against a job) or "role" (against what recruiters expect for the role)
  final String mode;
  final List<AtsCategory> categories;
  final List<String> matched;
  final List<String> missing;
  /// Missing keywords that matter most for the job.
  final List<String> key;
  final TargetJob? job;
  @override
  List<Object?> get props => [score, grade, mode, categories, matched, missing, key, job];
}

/// A resume file read by the server, as profile fields to put in the form.
class ImportedResume extends Equatable {
  const ImportedResume({required this.profile, this.found = const [], this.ai = false, this.message});
  /// null when nothing readable was found (e.g. a scanned image).
  final Candidate? profile;
  /// "your name", "2 jobs"… what was filled in.
  final List<String> found;
  final bool ai;
  final String? message;
  @override
  List<Object?> get props => [profile, found, ai, message];
}

class ResumeFile extends Equatable {
  const ResumeFile({required this.bytes, required this.fileName, this.pages = 1, this.watermark = false});
  final Uint8List bytes;
  final String fileName;
  final int pages;
  final bool watermark;
  @override
  List<Object?> get props => [bytes.length, fileName, pages, watermark];
}

// ---------- AI writing help (Resume Premium) ----------
enum AiAction { tailor, summary, bullets, cover }

sealed class AiResult extends Equatable {
  const AiResult();
}

final class SummaryResult extends AiResult {
  const SummaryResult(this.summary);
  final String summary;
  @override
  List<Object?> get props => [summary];
}

final class BulletsResult extends AiResult {
  const BulletsResult({required this.index, required this.points, this.note});
  final int index;
  final List<String> points;
  final String? note;
  @override
  List<Object?> get props => [index, points, note];
}

final class TailorResult extends AiResult {
  const TailorResult({required this.summary, this.jobs = const {}, this.addSkills = const [], this.gaps = const [], this.tips = const []});
  final String summary;
  /// Job index → rewritten points
  final Map<int, List<String>> jobs;
  final List<String> addSkills;
  final List<String> gaps;
  final List<String> tips;
  @override
  List<Object?> get props => [summary, jobs, addSkills, gaps, tips];
}

final class CoverResult extends AiResult {
  const CoverResult(this.letter);
  final String letter;
  @override
  List<Object?> get props => [letter];
}

class AiRequest extends Equatable {
  const AiRequest(this.action, {this.job, this.experienceIndex});
  final AiAction action;
  final TargetJob? job;
  final int? experienceIndex;
  @override
  List<Object?> get props => [action, job, experienceIndex];
}

class AiReply extends Equatable {
  const AiReply(this.result, {this.aiLeftToday});
  final AiResult result;
  final int? aiLeftToday;
  @override
  List<Object?> get props => [result, aiLeftToday];
}

/// The look sent with a download (unsaved changes from the screen are fine).
class ResumeLook extends Equatable {
  const ResumeLook(this.settings, {this.versionId});
  final ResumeSettings settings;
  final int? versionId;
  @override
  List<Object?> get props => [settings, versionId];
}

abstract interface class ResumeRepository {
  Future<Result<ResumePremium>> premium();
  /// Before signing in: a preview of a resume that isn't saved (nothing is stored on the server).
  Future<Result<ResumeFile>> guestPdf(Candidate profile, ResumeSettings look);
  Future<Result<AtsResult>> guestAts(Candidate profile, {TargetJob? job});
  Future<Result<ResumeFile>> pdf(ResumeLook look);
  Future<Result<ResumeFile>> docx(ResumeLook look);
  Future<Result<AtsResult>> ats({int? versionId, TargetJob? job});
  Future<Result<ImportedResume>> importFile(Uint8List bytes, {required String fileName, bool ai = false});
  Future<Result<List<ResumeVersion>>> versions();
  Future<Result<ResumeVersion>> createVersion(VersionDraft d);
  Future<Result<ResumeVersion>> updateVersion(int id, {String? name, String? about, List<String>? skills, Map<int, String>? points});
  Future<Result<Unit>> deleteVersion(int id);
  Future<Result<AiReply>> ai(AiRequest r);
  /// Saves AI suggestions into the main resume; returns the updated profile.
  Future<Result<Candidate>> applyToMain({String? about, Map<int, String> points = const {}, List<String> addSkills = const []});
  // Buying Resume Premium
  Future<Result<String>> startPlayPurchase();
  Future<Result<CheckoutOrder>> createOrder({String? externalToken, String? state});
  Future<Result<ResumePremium>> verify({required String orderId, required String paymentId, required String signature});
  /// "paid" or "pending"
  Future<Result<String>> verifyStorePurchase({required String productId, required String token});
}

// ---------- Use cases ----------
@injectable
class GetResumePremium implements UseCase<ResumePremium, NoParams> {
  const GetResumePremium(this._repo);
  final ResumeRepository _repo;
  @override
  Future<Result<ResumePremium>> call(NoParams p) => _repo.premium();
}

@injectable
class MakeResumePdf implements UseCase<ResumeFile, ResumeLook> {
  const MakeResumePdf(this._repo);
  final ResumeRepository _repo;
  @override
  Future<Result<ResumeFile>> call(ResumeLook l) => _repo.pdf(l);
}

@injectable
class MakeResumeWord implements UseCase<ResumeFile, ResumeLook> {
  const MakeResumeWord(this._repo);
  final ResumeRepository _repo;
  @override
  Future<Result<ResumeFile>> call(ResumeLook l) => _repo.docx(l);
}

class AtsParams extends Equatable {
  const AtsParams({this.versionId, this.job});
  final int? versionId;
  final TargetJob? job;
  @override
  List<Object?> get props => [versionId, job];
}

@injectable
class CheckResumeAts implements UseCase<AtsResult, AtsParams> {
  const CheckResumeAts(this._repo);
  final ResumeRepository _repo;
  @override
  Future<Result<AtsResult>> call(AtsParams p) {
    if (p.job?.text != null && p.job!.text!.trim().length < 80) return Future.value(const Err(ValidationFailure('Paste the full job description (at least a few lines).')));
    return _repo.ats(versionId: p.versionId, job: p.job);
  }
}

class ImportParams extends Equatable {
  const ImportParams(this.bytes, {required this.fileName, this.ai = false});
  final Uint8List bytes;
  final String fileName;
  final bool ai;
  @override
  List<Object?> get props => [bytes.length, fileName, ai];
}

/// Reads an existing resume (PDF or Word) into profile fields.
@injectable
class ImportResume implements UseCase<ImportedResume, ImportParams> {
  const ImportResume(this._repo);
  final ResumeRepository _repo;
  static const maxBytes = 5 * 1024 * 1024;
  @override
  Future<Result<ImportedResume>> call(ImportParams p) {
    final name = p.fileName.toLowerCase();
    if (name.endsWith('.doc')) return Future.value(const Err(ValidationFailure('Old .doc files can\'t be read. Save it as .docx or PDF and try again.')));
    if (!name.endsWith('.pdf') && !name.endsWith('.docx')) return Future.value(const Err(ValidationFailure('Choose a PDF or a Word (.docx) file.')));
    if (p.bytes.length > maxBytes) return Future.value(const Err(ValidationFailure('That file is over 5 MB. Choose a smaller PDF or Word file.')));
    return _repo.importFile(p.bytes, fileName: p.fileName, ai: p.ai);
  }
}

@injectable
class GetResumeVersions implements UseCase<List<ResumeVersion>, NoParams> {
  const GetResumeVersions(this._repo);
  final ResumeRepository _repo;
  @override
  Future<Result<List<ResumeVersion>>> call(NoParams p) => _repo.versions();
}

@injectable
class RunResumeAi implements UseCase<AiReply, AiRequest> {
  const RunResumeAi(this._repo);
  final ResumeRepository _repo;
  @override
  Future<Result<AiReply>> call(AiRequest r) {
    if ((r.action == AiAction.tailor || r.action == AiAction.cover) && r.job == null) {
      return Future.value(const Err(ValidationFailure('Pick or paste a job first (in the ATS tab).')));
    }
    return _repo.ai(r);
  }
}

/// Resume Premium in the app.
///
/// Android with Google's choice screen: Google Play, or Razorpay reported to Google.
/// Elsewhere (or while testing with ANDROID_BILLING=razorpay): Razorpay only.
/// Money taken but not yet confirmed is "pending", never an error: the server confirms it on its own.
enum BuyOutcome { active, pending, cancelled }

class BuyPremiumRequest extends Equatable {
  const BuyPremiumRequest(this.premium, {this.state});
  final ResumePremium premium;
  /// Needed for Google's tax report when Google's choice screen is used.
  final String? state;
  @override
  List<Object?> get props => [premium, state];
}

@injectable
class BuyResumePremium implements UseCase<BuyOutcome, BuyPremiumRequest> {
  const BuyResumePremium(this._repo, this._gateway, this._store);
  final ResumeRepository _repo;
  final PaymentGateway _gateway;
  final StoreBilling _store;

  /// Whether Google's screen comes first (so the state must be asked for).
  static bool usesStore(ResumePremium p, StoreBilling store) => store.supported && (p.android?.userChoice ?? false) && (p.playProductId ?? '').isNotEmpty;

  @override
  Future<Result<BuyOutcome>> call(BuyPremiumRequest r) async {
    if (!usesStore(r.premium, _store)) return _razorpay();
    if ((r.state ?? '').isEmpty) return const Err(ValidationFailure('Choose your state to continue.'));
    final start = await _repo.startPlayPurchase();
    if (start case Err(:final failure)) return Err(failure);
    final s = await _store.buy(productId: start.valueOrNull!, accountId: r.premium.android!.accountId);
    switch (s) {
      case StoreCancelled():
        return const Success(BuyOutcome.cancelled);
      case StorePending():
        return const Success(BuyOutcome.pending);
      case StoreFailed(:final message):
        return Err(ServerFailure(message));
      case StoreChoseRazorpay(:final externalToken):
        return _razorpay(externalToken: externalToken, state: r.state);
      case StorePurchased(:final productId, :final token):
        final v = await _repo.verifyStorePurchase(productId: productId, token: token);
        if (v case Err(failure: ServerFailure(statusCode: final int code)) when code >= 400 && code < 500) return Err(v.failureOrNull!);
        return Success(v.valueOrNull == 'paid' ? BuyOutcome.active : BuyOutcome.pending);
    }
  }

  Future<Result<BuyOutcome>> _razorpay({String? externalToken, String? state}) async {
    final order = await _repo.createOrder(externalToken: externalToken, state: externalToken == null ? null : state);
    switch (order) {
      case Err(:final failure):
        return Err(failure);
      case Success(value: final o):
        final g = await _gateway.open(o);
        switch (g) {
          case GatewayCancelled():
            return const Success(BuyOutcome.cancelled);
          case GatewayPending():
            return const Success(BuyOutcome.pending);
          case GatewayFailed(:final message):
            return Err(ServerFailure(message));
          case GatewaySuccess(:final paymentId, :final orderId, :final signature):
            final v = await _repo.verify(orderId: orderId.isEmpty ? o.orderId : orderId, paymentId: paymentId, signature: signature);
            return Success(v.valueOrNull?.active == true ? BuyOutcome.active : BuyOutcome.pending);
        }
    }
  }
}

/// Confirms Resume Premium Google Play purchases the server hasn't seen (app closed mid-way, pending finished).
@injectable
class RecoverResumePurchases {
  const RecoverResumePurchases(this._repo, this._store);
  final ResumeRepository _repo;
  final StoreBilling _store;

  Future<int> call(AndroidBilling a) async {
    if (!_store.supported || !a.userChoice) return 0;
    try {
      var n = 0;
      for (final p in await _store.unfinished(accountId: a.accountId, prefix: 'resume_premium_')) {
        if (await _repo.verifyStorePurchase(productId: p.productId, token: p.token) case Success(value: 'paid')) n++;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }
}

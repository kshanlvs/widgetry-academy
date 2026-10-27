import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/profile/data/models/candidate_model.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/resume/domain/resume.dart';

@LazySingleton(as: ResumeRepository)
class ResumeRepositoryImpl implements ResumeRepository {
  ResumeRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<ResumePremium>> premium() => guard(() async => ResumeJson.premium(await _api.get('/resume/premium')));

  Map<String, dynamic> _look(ResumeLook l) => {
        'template': l.settings.template,
        'accent': l.settings.accent,
        'title': l.settings.title ?? '',
        'showPhoto': l.settings.showPhoto,
        'hide': l.settings.hide,
        'density': l.settings.density,
        if (l.versionId != null) 'versionId': l.versionId,
      };

  @override
  Future<Result<ResumeFile>> pdf(ResumeLook l) => guard(() async {
        final f = await _api.postForFile('/resume/pdf', body: _look(l));
        return ResumeFile(bytes: f.bytes, fileName: f.fileName ?? 'Resume.pdf', pages: int.tryParse(f.headers['x-resume-pages'] ?? '') ?? 1, watermark: f.headers['x-resume-watermark'] == '1');
      });

  @override
  Future<Result<ResumeFile>> guestPdf(Candidate profile, ResumeSettings look) => guard(() async {
        final body = _look(ResumeLook(look))..remove('showPhoto');
        final f = await _api.postForFile('/resume/guest/pdf', body: {'profile': CandidateModel.toRequest(profile), 'look': body});
        return ResumeFile(bytes: f.bytes, fileName: f.fileName ?? 'Resume.pdf', pages: int.tryParse(f.headers['x-resume-pages'] ?? '') ?? 1, watermark: f.headers['x-resume-watermark'] == '1');
      });

  @override
  Future<Result<AtsResult>> guestAts(Candidate profile, {TargetJob? job}) => guard(() async {
        final j = await _api.post('/resume/guest/ats', body: {
          'profile': CandidateModel.toRequest(profile),
          if (job?.id != null) 'jobId': job!.id,
          if (job?.id == null && job?.text != null) ...{'jobText': job!.text, 'jobTitle': job.title},
        });
        return ResumeJson.ats(j, job);
      });

  @override
  Future<Result<ResumeFile>> docx(ResumeLook l) => guard(() async {
        final f = await _api.postForFile('/resume/docx', body: _look(l));
        return ResumeFile(bytes: f.bytes, fileName: f.fileName ?? 'Resume.docx');
      });

  @override
  Future<Result<AtsResult>> ats({int? versionId, TargetJob? job}) => guard(() async {
        final j = await _api.post('/resume/ats', body: {
          if (versionId != null) 'versionId': versionId,
          if (job?.id != null) 'jobId': job!.id,
          if (job?.id == null && job?.text != null) ...{'jobText': job!.text, 'jobTitle': job.title},
        });
        return ResumeJson.ats(j, job);
      });

  @override
  Future<Result<ImportedResume>> importFile(Uint8List bytes, {required String fileName, bool ai = false}) => guard(() async {
        final type = fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        return ResumeJson.imported(await _api.postFile('/resume/import', bytes, contentType: type, query: ai ? {'ai': '1'} : null));
      });

  @override
  Future<Result<List<ResumeVersion>>> versions() => guard(() async {
        final j = await _api.get('/resume/versions');
        return [for (final v in (j['items'] as List? ?? const [])) ResumeJson.version(v as Map<String, dynamic>)];
      });

  Map<String, dynamic> _data({String? title, String? about, List<String>? skills, Map<int, String>? points}) => {
        if (title != null) 'title': title,
        if (about != null) 'about': about,
        if (skills != null) 'skills': skills,
        if (points != null) 'points': [for (final e in points.entries) {'index': e.key, 'points': e.value}],
      };

  @override
  Future<Result<ResumeVersion>> createVersion(VersionDraft d) => guard(() async {
        final j = await _api.post('/resume/versions', body: {
          'name': d.name,
          'jobId': d.jobId,
          'jobTitle': d.jobTitle,
          'company': d.company,
          'data': _data(title: d.title, about: d.about, skills: d.skills, points: d.points),
        });
        return ResumeJson.version(j['version'] as Map<String, dynamic>);
      });

  @override
  Future<Result<ResumeVersion>> updateVersion(int id, {String? name, String? about, List<String>? skills, Map<int, String>? points}) => guard(() async {
        final data = _data(about: about, skills: skills, points: points);
        final j = await _api.patch('/resume/versions/$id', body: {if (name != null) 'name': name, if (data.isNotEmpty) 'data': data});
        return ResumeJson.version(j['version'] as Map<String, dynamic>);
      });

  @override
  Future<Result<Unit>> deleteVersion(int id) => guard(() async {
        await _api.delete('/resume/versions/$id');
        return unit;
      });

  @override
  Future<Result<AiReply>> ai(AiRequest r) => guard(() async {
        final j = await _api.post('/resume/ai', timeout: const Duration(seconds: 90), body: {
          'action': r.action.name,
          if (r.experienceIndex != null) 'experienceIndex': r.experienceIndex,
          if (r.job != null) ...{'jobText': r.job!.text ?? r.job!.title, 'jobTitle': r.job!.title, 'company': r.job!.company ?? ''},
        });
        return AiReply(ResumeJson.ai(r, j['result'] as Map<String, dynamic>), aiLeftToday: (j['aiLeftToday'] as num?)?.toInt());
      });

  @override
  Future<Result<Candidate>> applyToMain({String? about, Map<int, String> points = const {}, List<String> addSkills = const []}) => guard(() async {
        final j = await _api.patch('/talent/me/resume-content', body: {
          if (about != null) 'about': about,
          if (points.isNotEmpty) 'points': [for (final e in points.entries) {'index': e.key, 'points': e.value}],
          if (addSkills.isNotEmpty) 'addSkills': addSkills,
        });
        return CandidateModel.fromJson(j['profile'] as Map<String, dynamic>).toEntity();
      });

  @override
  Future<Result<String>> startPlayPurchase() => guard(() async => '${(await _api.post('/resume/premium/order', body: {'mode': 'play'}))['productId']}');

  @override
  Future<Result<CheckoutOrder>> createOrder({String? externalToken, String? state}) => guard(() async {
        final j = await _api.post('/resume/premium/order', body: {
          'mode': 'razorpay',
          if (externalToken != null) 'externalTransactionToken': externalToken,
          if (state != null) 'state': state,
        });
        final pre = (j['prefill'] as Map?) ?? const {};
        return CheckoutOrder(
          orderId: '${j['orderId']}',
          amountPaise: (j['amount'] as num).round(),
          currency: '${j['currency'] ?? 'INR'}',
          keyId: '${j['keyId']}',
          name: '${j['name'] ?? 'Widgetry Academy'}',
          description: '${j['description'] ?? 'Resume Premium'}',
          prefillName: '${pre['name'] ?? ''}',
          prefillEmail: '${pre['email'] ?? ''}',
        );
      });

  @override
  Future<Result<ResumePremium>> verify({required String orderId, required String paymentId, required String signature}) => guard(() async {
        final j = await _api.post('/resume/premium/verify', body: {'orderId': orderId, 'paymentId': paymentId, 'signature': signature});
        return ResumeJson.premium(j);
      });

  @override
  Future<Result<String>> verifyStorePurchase({required String productId, required String token}) => guard(() async {
        final j = await _api.post('/resume/premium/play/verify', body: {'productId': productId, 'purchaseToken': token});
        return '${j['status'] ?? 'pending'}';
      });
}

/// Reads the resume API's JSON. Kept apart (and public) so it can be tested without a server.
abstract final class ResumeJson {
  static String? _s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  static List<String> _list(Object? v) => [for (final x in (v as List? ?? const [])) if (_s(x) != null) _s(x)!];

  static ResumePremium premium(Map<String, dynamic> j) {
    final a = j['android'] as Map<String, dynamic>?;
    return ResumePremium(
      active: j['active'] == true,
      expiresAt: DateTime.tryParse('${j['expiresAt'] ?? ''}')?.toLocal(),
      price: (j['price'] as num?)?.round() ?? 299,
      days: (j['days'] as num?)?.round() ?? 30,
      aiLeftToday: (j['aiLeftToday'] as num?)?.toInt(),
      paymentsEnabled: j['paymentsEnabled'] != false,
      playProductId: _s(j['playProductId']),
      maxVersions: (j['maxVersions'] as num?)?.toInt() ?? 5,
      android: a == null ? null : AndroidBilling(userChoice: a['billing'] == 'user_choice', accountId: '${a['accountId'] ?? ''}', states: _list(a['states'])),
    );
  }

  static ResumeVersion version(Map<String, dynamic> j) {
    final d = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ResumeVersion(
      id: (j['id'] as num).toInt(),
      name: '${j['name'] ?? 'Copy'}',
      jobTitle: _s(j['jobTitle']),
      company: _s(j['company']),
      title: _s(d['title']),
      about: _s(d['about']),
      skills: d['skills'] is List ? _list(d['skills']) : null,
      points: {for (final p in (d['points'] as List? ?? const [])) ((p as Map)['index'] as num).toInt(): '${p['points'] ?? ''}'},
    );
  }

  static AtsResult ats(Map<String, dynamic> j, TargetJob? asked) {
    final r = j['result'] as Map<String, dynamic>;
    final kw = (r['keywords'] as Map?)?.cast<String, dynamic>() ?? const {};
    final job = j['job'] as Map<String, dynamic>?;
    return AtsResult(
      score: (r['score'] as num).round(),
      grade: '${r['grade'] ?? ''}',
      mode: '${r['mode'] ?? 'role'}',
      categories: [
        for (final c in (r['categories'] as List? ?? const []))
          AtsCategory(
            label: '${c['label']}',
            score: (c['score'] as num).round(),
            max: (c['max'] as num).round(),
            status: '${c['status'] ?? 'ok'}',
            detail: '${c['detail'] ?? ''}',
            tips: _list(c['tips']),
          ),
      ],
      matched: _list(kw['matched']),
      missing: _list(kw['missing']),
      key: _list(kw['key']),
      job: job == null ? asked : TargetJob(id: _s(job['id']), title: '${job['title'] ?? asked?.title ?? 'Job'}', company: _s(job['company']), text: asked?.text),
    );
  }

  static ImportedResume imported(Map<String, dynamic> j) {
    final p = j['profile'] as Map<String, dynamic>?;
    if (p == null) return ImportedResume(profile: null, message: _s(j['message']));
    final cats = _list(p['categories']);
    return ImportedResume(
      ai: j['ai'] == true,
      found: _list(p['found']),
      profile: Candidate(
        fullName: _s(p['fullName']) ?? '',
        phone: _s(p['phone']),
        headline: _s(p['headline']) ?? '',
        currentCompany: _s(p['currentCompany']),
        experienceYears: (p['experienceYears'] as num?)?.toDouble() ?? 0,
        city: _s(p['city']),
        categories: cats.isEmpty ? const ['flutter'] : cats,
        githubUrl: _s(p['githubUrl']),
        linkedinUrl: _s(p['linkedinUrl']),
        portfolioUrl: _s(p['portfolioUrl']),
        about: _s(p['about']),
        skills: _list(p['skills']).take(15).toList(),
        achievements: _list(p['achievements']),
        languages: _list(p['languages']),
        experience: [
          for (final w in (p['experience'] as List? ?? const []))
            WorkItem(company: _s(w['company']) ?? '', role: _s(w['role']) ?? '', start: _s(w['start']) ?? '', end: _s(w['end']), points: _s(w['points'])),
        ],
        apps: [for (final a in (p['apps'] as List? ?? const [])) AppItem(name: _s(a['name']) ?? '', url: _s(a['url']), role: _s(a['role']), about: _s(a['about']))],
        education: [
          for (final e in (p['education'] as List? ?? const []))
            EduItem(degree: _s(e['degree']) ?? '', institute: _s(e['institute']) ?? '', year: (e['year'] as num?)?.toInt(), score: _s(e['score'])),
        ],
        certifications: [for (final c in (p['certifications'] as List? ?? const [])) CertItem(name: _s(c['name']) ?? '', issuer: _s(c['issuer']), year: (c['year'] as num?)?.toInt())],
      ),
    );
  }

  static AiResult ai(AiRequest r, Map<String, dynamic> j) => switch (r.action) {
        AiAction.summary => SummaryResult('${j['summary'] ?? ''}'),
        AiAction.bullets => BulletsResult(index: r.experienceIndex ?? 0, points: _list(j['points']), note: _s(j['note'])),
        AiAction.cover => CoverResult('${j['letter'] ?? ''}'),
        AiAction.tailor => TailorResult(
            summary: '${j['summary'] ?? ''}',
            jobs: {for (final x in (j['jobs'] as List? ?? const [])) ((x as Map)['index'] as num).toInt(): _list(x['points'])},
            addSkills: _list(j['addSkills']),
            gaps: _list(j['gaps']),
            tips: _list(j['tips']),
          ),
      };
}

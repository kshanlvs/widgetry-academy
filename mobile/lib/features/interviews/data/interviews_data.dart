import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

/// Mapping between the API's JSON and the domain. Kept separate so it can be unit tested.
abstract final class InterviewsJson {
  static String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
  static int _i(Object? v) => (v as num?)?.round() ?? int.tryParse('${v ?? ''}') ?? 0;
  static List<Map<String, dynamic>> _list(Object? v) => (v as List? ?? const []).whereType<Map<String, dynamic>>().toList();

  static MockOption option(Map<String, dynamic> j) => MockOption(id: '${j['id']}', name: '${j['name'] ?? j['id']}', note: '${j['note'] ?? ''}', price: (j['price'] as num?)?.round());

  static MockOptions options(Map<String, dynamic> j) {
    final rules = (j['rules'] as Map?) ?? const {};
    return MockOptions(
      enabled: j['enabled'] == true,
      tracks: _list(j['tracks']).map(option).toList(),
      levels: _list(j['levels']).map(option).toList(),
      formats: _list(j['formats']).map(option).toList(),
      areas: _list(j['areas']).map(option).toList(),
      cancelHours: _i(rules['cancelHours'] ?? 24),
      holdMinutes: _i(rules['holdMinutes'] ?? 15),
    );
  }

  static InterviewerInfo interviewer(Map<String, dynamic> j) => InterviewerInfo(
        name: '${j['name'] ?? ''}',
        title: '${j['title'] ?? ''}',
        company: _s(j['company']),
        years: _i(j['years']),
        tracks: [for (final t in (j['tracks'] as List? ?? const [])) '$t'],
        bio: _s(j['bio']),
        linkedinUrl: _s(j['linkedinUrl']),
      );

  static DateTime time(Object? v) => (DateTime.tryParse('${v ?? ''}') ?? DateTime.now()).toLocal();

  static InterviewSlot slot(Map<String, dynamic> j) => InterviewSlot(
        id: _i(j['id']),
        startsAt: time(j['startsAt']),
        durationMin: _i(j['durationMin'] ?? 60),
        interviewer: j['interviewer'] is Map<String, dynamic> ? interviewer(j['interviewer'] as Map<String, dynamic>) : null,
        status: '${j['status'] ?? 'open'}',
      );

  static Scorecard scorecard(Map<String, dynamic> j) => Scorecard(
        scores: {for (final e in ((j['scores'] as Map?) ?? const {}).entries) '${e.key}': _i(e.value)},
        overall: (j['overall'] as num?)?.toDouble() ?? 0,
        strengths: '${j['strengths'] ?? ''}',
        improve: '${j['improve'] ?? ''}',
        recommendation: '${j['recommendation'] ?? ''}',
        shared: j['shared'] == true,
      );

  static CandidateSummary? candidate(Map<String, dynamic>? p, String? fallbackName, String? email) {
    if (p == null) return null;
    final links = <String, String>{
      if (_s(p['githubUrl']) != null) 'GitHub': '${p['githubUrl']}',
      if (_s(p['linkedinUrl']) != null) 'LinkedIn': '${p['linkedinUrl']}',
      if (_s(p['portfolioUrl']) != null) 'Portfolio': '${p['portfolioUrl']}',
      for (final a in _list(p['apps']))
        if (_s(a['url']) != null) '${a['name'] ?? 'App'}': '${a['url']}',
    };
    return CandidateSummary(
      name: '${p['fullName'] ?? fallbackName ?? ''}',
      email: _s(p['email']) ?? email,
      headline: _s(p['headline']),
      experienceYears: (p['experienceYears'] as num?)?.toDouble(),
      skills: [for (final s in (p['skills'] as List? ?? const [])) '$s'],
      links: links,
      about: _s(p['about']),
    );
  }

  static MockBooking booking(Map<String, dynamic> j) {
    final c = (j['candidate'] as Map?) ?? const {};
    return MockBooking(
      id: _i(j['id']),
      status: '${j['status'] ?? 'created'}',
      startsAt: time(j['startsAt']),
      durationMin: _i(j['durationMin'] ?? 60),
      track: '${j['track'] ?? ''}',
      level: '${j['level'] ?? ''}',
      format: '${j['format'] ?? ''}',
      title: '${j['title'] ?? 'Mock interview'}',
      focus: _s(j['focus']),
      amount: _i(j['amount']),
      paymentId: _s(j['paymentId']),
      canCancel: j['canCancel'] == true,
      interviewer: j['interviewer'] is Map<String, dynamic> ? interviewer(j['interviewer'] as Map<String, dynamic>) : null,
      meetingLink: _s(j['meetingLink']),
      scorecard: j['scorecard'] is Map<String, dynamic> ? scorecard(j['scorecard'] as Map<String, dynamic>) : null,
      candidateName: _s(c['name']),
      candidateEmail: _s(c['email']),
      candidate: candidate(j['candidateProfile'] as Map<String, dynamic>?, _s(c['name']), _s(c['email'])),
      canScore: j['canScore'] == true,
      canMarkNoShow: j['canMarkNoShow'] == true,
      asInterviewer: j['viewer'] == 'interviewer',
    );
  }

  static InterviewerProfile profile(Map<String, dynamic> j) => InterviewerProfile(
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        title: '${j['title'] ?? ''}',
        company: _s(j['company']),
        years: _i(j['years']),
        tracks: [for (final t in (j['tracks'] as List? ?? const [])) '$t'],
        bio: _s(j['bio']),
        linkedinUrl: _s(j['linkedinUrl']),
        meetingLink: _s(j['meetingLink']),
      );

  static CheckoutOrder order(Map<String, dynamic> j) {
    final pre = (j['prefill'] as Map?) ?? const {};
    return CheckoutOrder(
      orderId: '${j['orderId']}',
      amountPaise: _i(j['amount']),
      currency: '${j['currency'] ?? 'INR'}',
      keyId: '${j['keyId']}',
      name: '${j['name'] ?? 'Widgetry Academy'}',
      description: '${j['description'] ?? 'Mock interview'}',
      prefillName: '${pre['name'] ?? ''}',
      prefillEmail: '${pre['email'] ?? ''}',
      prefillContact: '${pre['contact'] ?? ''}',
    );
  }
}

@LazySingleton(as: InterviewsRepository)
class InterviewsRepositoryImpl implements InterviewsRepository {
  InterviewsRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<MockOptions>> options() => guard(() async => InterviewsJson.options(await _api.get('/mock/options')));

  @override
  Future<Result<List<InterviewSlot>>> slots(String track) => guard(() async {
        final j = await _api.get('/mock/slots', query: {'track': track});
        return [for (final s in (j['slots'] as List? ?? const []).whereType<Map<String, dynamic>>()) InterviewsJson.slot(s)];
      });

  @override
  Future<Result<(int, CheckoutOrder)>> book(BookRequest r) => guard(() async {
        final j = await _api.post('/mock/book', body: {
          'slotId': r.slotId,
          'track': r.track,
          'level': r.level,
          'format': r.format,
          if ((r.focus ?? '').trim().isNotEmpty) 'focus': r.focus!.trim(),
          'shareProfile': r.shareProfile,
        });
        return ((j['bookingId'] as num).round(), InterviewsJson.order(j));
      });

  @override
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature}) => guard(() async {
        final j = await _api.post('/mock/verify', body: {'orderId': orderId, 'paymentId': paymentId, 'signature': signature});
        return '${j['status'] ?? 'confirmed'}';
      });

  @override
  Future<Result<List<MockBooking>>> mine() => guard(() async {
        final j = await _api.get('/mock/mine');
        return [for (final b in (j['bookings'] as List? ?? const []).whereType<Map<String, dynamic>>()) InterviewsJson.booking(b)];
      });

  @override
  Future<Result<MockBooking>> booking(int id) => guard(() async => InterviewsJson.booking((await _api.get('/mock/bookings/$id'))['booking'] as Map<String, dynamic>));

  @override
  Future<Result<String>> cancel(int id) => guard(() async => '${(await _api.post('/mock/bookings/$id/cancel'))['message'] ?? 'Cancelled.'}');

  @override
  Future<Result<Unit>> share(int id, bool shared) => guard(() async {
        await _api.put('/mock/bookings/$id/share', body: {'shared': shared});
        return unit;
      });

  @override
  Future<Result<InterviewerDashboard?>> dashboard() => guard(() async {
        final j = await _api.get('/mock/interviewer/me');
        final me = j['interviewer'];
        if (me is! Map<String, dynamic>) return null;
        return InterviewerDashboard(
          me: InterviewsJson.profile(me),
          slots: [for (final s in (j['slots'] as List? ?? const []).whereType<Map<String, dynamic>>()) InterviewsJson.slot(s)],
          bookings: [for (final b in (j['bookings'] as List? ?? const []).whereType<Map<String, dynamic>>()) InterviewsJson.booking(b)],
        );
      });

  @override
  Future<Result<InterviewerProfile>> saveInterviewer(InterviewerProfile p) => guard(() async {
        final j = await _api.put('/mock/interviewer/me', body: {
          'title': p.title,
          'company': p.company ?? '',
          'years': p.years,
          'tracks': p.tracks,
          'bio': p.bio ?? '',
          'linkedinUrl': p.linkedinUrl ?? '',
          'meetingLink': p.meetingLink ?? '',
        });
        return InterviewsJson.profile(j['interviewer'] as Map<String, dynamic>);
      });

  @override
  Future<Result<(int, int)>> addSlots(List<DateTime> starts, int durationMin) => guard(() async {
        final j = await _api.post('/mock/interviewer/slots', body: {
          'starts': [for (final s in starts) s.toUtc().toIso8601String()],
          'durationMin': durationMin,
        });
        return ((j['added'] as num? ?? 0).round(), (j['skipped'] as num? ?? 0).round());
      });

  @override
  Future<Result<Unit>> deleteSlot(int id) => guard(() async {
        await _api.delete('/mock/interviewer/slots/$id');
        return unit;
      });

  @override
  Future<Result<double>> sendScorecard(int bookingId, ScorecardInput s) => guard(() async {
        final j = await _api.post('/mock/interviewer/bookings/$bookingId/scorecard', body: {
          'scores': s.scores,
          'strengths': s.strengths.trim(),
          'improve': s.improve.trim(),
          'recommendation': s.recommendation,
        });
        return (j['overall'] as num? ?? 0).toDouble();
      });

  @override
  Future<Result<Unit>> markNoShow(int bookingId) => guard(() async {
        await _api.post('/mock/interviewer/bookings/$bookingId/no-show');
        return unit;
      });
}

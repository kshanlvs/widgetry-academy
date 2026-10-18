import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

/// A choice like a track, level or format. [price] is set for levels (rupees).
class MockOption extends Equatable {
  const MockOption({required this.id, required this.name, this.note = '', this.price});
  final String id;
  final String name;
  final String note;
  final int? price;
  @override
  List<Object?> get props => [id, name, note, price];
}

class MockOptions extends Equatable {
  const MockOptions({required this.enabled, required this.tracks, required this.levels, required this.formats, required this.areas, this.cancelHours = 24, this.holdMinutes = 15});
  /// False until payments are set up on the server.
  final bool enabled;
  final List<MockOption> tracks;
  final List<MockOption> levels;
  final List<MockOption> formats;
  /// What the interviewer scores.
  final List<MockOption> areas;
  final int cancelHours;
  final int holdMinutes;

  String trackName(String id) => tracks.where((t) => t.id == id).firstOrNull?.name ?? id;
  String levelName(String id) => levels.where((t) => t.id == id).firstOrNull?.name ?? id;
  String formatName(String id) => formats.where((t) => t.id == id).firstOrNull?.name ?? id;
  String areaName(String id) => areas.where((t) => t.id == id).firstOrNull?.name ?? id;
  int? priceFor(String level) => levels.where((l) => l.id == level).firstOrNull?.price;
  int get lowestPrice => levels.map((l) => l.price ?? 0).fold<int>(levels.isEmpty ? 0 : (levels.first.price ?? 0), (a, b) => b < a ? b : a);

  @override
  List<Object?> get props => [enabled, tracks, levels, formats, areas, cancelHours, holdMinutes];
}

class InterviewerInfo extends Equatable {
  const InterviewerInfo({required this.name, required this.title, this.company, this.years = 0, this.tracks = const [], this.bio, this.linkedinUrl});
  final String name;
  final String title;
  final String? company;
  final int years;
  final List<String> tracks;
  final String? bio;
  final String? linkedinUrl;

  /// "Senior Flutter Engineer · Swiggy · 7 yrs"
  String get line => [title, if ((company ?? '').isNotEmpty) company!, if (years > 0) '$years yrs'].join(' · ');

  @override
  List<Object?> get props => [name, title, company, years, tracks, bio, linkedinUrl];
}

class InterviewSlot extends Equatable {
  const InterviewSlot({required this.id, required this.startsAt, required this.durationMin, this.interviewer, this.status = 'open'});
  final int id;
  /// Local time.
  final DateTime startsAt;
  final int durationMin;
  final InterviewerInfo? interviewer;
  /// open, held, booked (interviewer view)
  final String status;
  DateTime get endsAt => startsAt.add(Duration(minutes: durationMin));
  @override
  List<Object?> get props => [id, startsAt, durationMin, interviewer, status];
}

class Scorecard extends Equatable {
  const Scorecard({required this.scores, required this.overall, required this.strengths, required this.improve, required this.recommendation, this.shared = false});
  /// area id → 1..5
  final Map<String, int> scores;
  final double overall;
  final String strengths;
  final String improve;
  /// strong_hire, hire, lean_no, no
  final String recommendation;
  final bool shared;

  static const recommendations = {'strong_hire': 'Strong hire', 'hire': 'Hire', 'lean_no': 'Not yet', 'no': 'No hire'};
  String get recommendationLabel => recommendations[recommendation] ?? recommendation;

  Scorecard copyWith({bool? shared}) => Scorecard(scores: scores, overall: overall, strengths: strengths, improve: improve, recommendation: recommendation, shared: shared ?? this.shared);

  @override
  List<Object?> get props => [scores, overall, strengths, improve, recommendation, shared];
}

/// A short view of the candidate, for the interviewer (only when the candidate allowed it).
class CandidateSummary extends Equatable {
  const CandidateSummary({required this.name, this.email, this.headline, this.experienceYears, this.skills = const [], this.links = const {}, this.about});
  final String name;
  final String? email;
  final String? headline;
  final double? experienceYears;
  final List<String> skills;
  /// label → url (GitHub, LinkedIn, Portfolio, apps)
  final Map<String, String> links;
  final String? about;
  @override
  List<Object?> get props => [name, email, headline, experienceYears, skills, links, about];
}

class MockBooking extends Equatable {
  const MockBooking({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.durationMin,
    required this.track,
    required this.level,
    required this.format,
    required this.title,
    this.focus,
    this.amount = 0,
    this.paymentId,
    this.canCancel = false,
    this.interviewer,
    this.meetingLink,
    this.scorecard,
    this.candidateName,
    this.candidateEmail,
    this.candidate,
    this.canScore = false,
    this.canMarkNoShow = false,
    this.asInterviewer = false,
  });
  final int id;
  /// created (payment pending), confirmed, completed, cancelled, no_show, refund_due
  final String status;
  final DateTime startsAt;
  final int durationMin;
  final String track;
  final String level;
  final String format;
  final String title;
  final String? focus;
  /// Rupees.
  final int amount;
  final String? paymentId;
  final bool canCancel;
  final InterviewerInfo? interviewer;
  final String? meetingLink;
  final Scorecard? scorecard;
  // Interviewer view
  final String? candidateName;
  final String? candidateEmail;
  final CandidateSummary? candidate;
  final bool canScore;
  final bool canMarkNoShow;
  /// True when the signed-in user is this booking's interviewer.
  final bool asInterviewer;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMin));
  bool get isUpcoming => status == 'confirmed' && endsAt.isAfter(DateTime.now());
  /// The joining button opens 10 minutes before the start and stays until the end.
  bool canJoin(DateTime now) => meetingLink != null && status == 'confirmed' && now.isAfter(startsAt.subtract(const Duration(minutes: 10))) && now.isBefore(endsAt.add(const Duration(minutes: 30)));

  MockBooking withScorecard(Scorecard? s) => MockBooking(
        id: id, status: status, startsAt: startsAt, durationMin: durationMin, track: track, level: level, format: format, title: title,
        focus: focus, amount: amount, paymentId: paymentId, canCancel: canCancel, interviewer: interviewer, meetingLink: meetingLink,
        scorecard: s, candidateName: candidateName, candidateEmail: candidateEmail, candidate: candidate, canScore: canScore, canMarkNoShow: canMarkNoShow, asInterviewer: asInterviewer,
      );

  @override
  List<Object?> get props => [id, status, startsAt, durationMin, track, level, format, title, focus, amount, paymentId, canCancel, interviewer, meetingLink, scorecard, candidateName, candidateEmail, candidate, canScore, canMarkNoShow, asInterviewer];
}

class InterviewerProfile extends Equatable {
  const InterviewerProfile({required this.name, required this.email, required this.title, this.company, this.years = 0, this.tracks = const [], this.bio, this.linkedinUrl, this.meetingLink});
  final String name;
  final String email;
  final String title;
  final String? company;
  final int years;
  final List<String> tracks;
  final String? bio;
  final String? linkedinUrl;
  final String? meetingLink;
  @override
  List<Object?> get props => [name, email, title, company, years, tracks, bio, linkedinUrl, meetingLink];
}

class InterviewerDashboard extends Equatable {
  const InterviewerDashboard({required this.me, this.slots = const [], this.bookings = const []});
  final InterviewerProfile me;
  final List<InterviewSlot> slots;
  final List<MockBooking> bookings;
  @override
  List<Object?> get props => [me, slots, bookings];
}

class BookRequest extends Equatable {
  const BookRequest({required this.slotId, required this.track, required this.level, required this.format, this.focus, this.shareProfile = true});
  final int slotId;
  final String track;
  final String level;
  final String format;
  final String? focus;
  final bool shareProfile;
  @override
  List<Object?> get props => [slotId, track, level, format, focus, shareProfile];
}

class ScorecardInput extends Equatable {
  const ScorecardInput({required this.scores, required this.strengths, required this.improve, required this.recommendation});
  final Map<String, int> scores;
  final String strengths;
  final String improve;
  final String recommendation;
  @override
  List<Object?> get props => [scores, strengths, improve, recommendation];
}

abstract interface class InterviewsRepository {
  Future<Result<MockOptions>> options();
  Future<Result<List<InterviewSlot>>> slots(String track);
  /// Holds the slot and creates the Razorpay order. Returns the booking id with the order.
  Future<Result<(int, CheckoutOrder)>> book(BookRequest r);
  /// Returns the booking status after payment ("confirmed", or "refund_due" if the slot was lost).
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature});
  Future<Result<List<MockBooking>>> mine();
  Future<Result<MockBooking>> booking(int id);
  /// Returns the server's message.
  Future<Result<String>> cancel(int id);
  Future<Result<Unit>> share(int id, bool shared);

  /// Null when the signed-in user isn't an interviewer.
  Future<Result<InterviewerDashboard?>> dashboard();
  Future<Result<InterviewerProfile>> saveInterviewer(InterviewerProfile p);
  /// Returns (added, skipped).
  Future<Result<(int, int)>> addSlots(List<DateTime> starts, int durationMin);
  Future<Result<Unit>> deleteSlot(int id);
  Future<Result<double>> sendScorecard(int bookingId, ScorecardInput s);
  Future<Result<Unit>> markNoShow(int bookingId);
}

enum BookingOutcomeKind { confirmed, pending, cancelled, slotLost }

class BookingOutcome extends Equatable {
  const BookingOutcome(this.kind, {this.bookingId, this.paymentId});
  final BookingOutcomeKind kind;
  final int? bookingId;
  final String? paymentId;
  @override
  List<Object?> get props => [kind, bookingId, paymentId];
}

/// Hold the slot → Razorpay Checkout → server confirmation. A one-to-one live session,
/// so Razorpay is used directly on every platform (Google Play Billing doesn't apply).
/// Paid but not confirmed (network dropped) is "pending": the server confirms it on its own.
@injectable
class BookMockInterview {
  const BookMockInterview(this._repo, this._gateway);
  final InterviewsRepository _repo;
  final PaymentGateway _gateway;

  Future<Result<BookingOutcome>> call(BookRequest r) async {
    final b = await _repo.book(r);
    switch (b) {
      case Err(:final failure):
        return Err(failure);
      case Success(value: (final id, final order)):
        final g = await _gateway.open(order);
        switch (g) {
          case GatewayCancelled():
            await _repo.cancel(id); // let go of the hold straight away
            return const Success(BookingOutcome(BookingOutcomeKind.cancelled));
          case GatewayPending():
            return Success(BookingOutcome(BookingOutcomeKind.pending, bookingId: id));
          case GatewayFailed(:final message):
            return Err(ServerFailure(message));
          case GatewaySuccess(:final paymentId, :final orderId, :final signature):
            final v = await _repo.verify(orderId: orderId.isEmpty ? order.orderId : orderId, paymentId: paymentId, signature: signature);
            return Success(switch (v) {
              Success(value: 'confirmed') => BookingOutcome(BookingOutcomeKind.confirmed, bookingId: id, paymentId: paymentId),
              Success(value: 'refund_due') => BookingOutcome(BookingOutcomeKind.slotLost, bookingId: id, paymentId: paymentId),
              _ => BookingOutcome(BookingOutcomeKind.pending, bookingId: id, paymentId: paymentId),
            });
        }
    }
  }
}

import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

/// A short live course (crash course) such as the Bloc crash course. Prices and dates come from the server.
class Workshop extends Equatable {
  const Workshop({
    required this.slug,
    required this.title,
    required this.status,
    required this.price,
    this.earlyPrice,
    this.earlySeatsLeft,
    this.earlyUntil,
    this.startsAt,
    this.schedule,
    this.durationMin = 300,
    this.seatsLeft = 0,
    this.brochureUrl,
  });
  final String slug;
  final String title;
  /// "draft" (dates coming soon), "open", "closed", "done"
  final String status;
  /// Rupees.
  final int price;
  /// Rupees, while the early-bird price is on.
  final int? earlyPrice;
  final int? earlySeatsLeft;
  final DateTime? earlyUntil;
  final DateTime? startsAt;
  /// Dates as the admin wrote them, e.g. "Sat 8 & Sun 9 Nov · 11 AM–1:30 PM IST".
  final String? schedule;
  final int durationMin;
  final int seatsLeft;
  /// Syllabus PDF, if the course has one.
  final String? brochureUrl;

  /// What you'd pay today.
  int get payNow => earlyPrice ?? price;
  bool get isOpen => status == 'open' && seatsLeft > 0;
  bool get isFull => status == 'open' && seatsLeft <= 0;
  bool get datesComingSoon => status == 'draft';
  String get webUrlPath => '/$slug.html';

  @override
  List<Object?> get props => [slug, title, status, price, earlyPrice, earlySeatsLeft, earlyUntil, startsAt, schedule, durationMin, seatsLeft, brochureUrl];
}

/// Your seat, once paid.
class WorkshopEnrolment extends Equatable {
  const WorkshopEnrolment({required this.status, required this.amount, this.paymentId, this.meetingLink});
  /// "confirmed" or "refunded"
  final String status;
  final int amount;
  final String? paymentId;
  /// Shown once the admin adds it.
  final String? meetingLink;
  bool get confirmed => status == 'confirmed';
  @override
  List<Object?> get props => [status, amount, paymentId, meetingLink];
}

class WorkshopDetail extends Equatable {
  const WorkshopDetail({required this.workshop, this.mine, this.paymentsOpen = false, this.android, this.playProductId});
  final Workshop workshop;
  final WorkshopEnrolment? mine;
  /// False until Razorpay keys are set on the server.
  final bool paymentsOpen;
  /// Set when signed in: how Google Play is set up.
  final AndroidBilling? android;
  /// Google Play product for today's price ("short_course_799"), if there is one.
  final String? playProductId;
  @override
  List<Object?> get props => [workshop, mine, paymentsOpen, android, playProductId];
}

abstract interface class WorkshopsRepository {
  Future<Result<List<Workshop>>> list();
  Future<Result<WorkshopDetail>> detail(String slug);
  /// Holds a seat before Google Play's purchase screen. Returns the product to buy.
  Future<Result<String>> holdForPlay(String slug, {required String name, required String phone});
  /// Creates a Razorpay order. [externalToken] and [state] are set when the student chose Razorpay on Google's screen.
  Future<Result<CheckoutOrder>> createOrder(String slug, {required String name, required String phone, String? externalToken, String? state});
  /// Returns "confirmed" when the seat is yours.
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature});
  /// Google Play purchase → "confirmed" or "pending".
  Future<Result<String>> verifyStorePurchase({required String productId, required String token});
  /// Lets go of an unpaid seat.
  Future<Result<Unit>> release(String slug);
}

class EnrolRequest extends Equatable {
  const EnrolRequest({required this.detail, required this.name, required this.phone, this.state});
  final WorkshopDetail detail;
  final String name;
  final String phone;
  /// Needed for Google's tax report when Google's choice screen is used.
  final String? state;
  @override
  List<Object?> get props => [detail, name, phone, state];
}

enum EnrolOutcome { enrolled, pending, cancelled }

/// Pays for a seat.
///
/// Android with Google Play's choice screen: the seat is held, then Google's screen opens.
/// Google Play → the server checks the purchase; Razorpay → Razorpay order and Checkout, reported to Google.
/// Elsewhere (or while testing with ANDROID_BILLING=razorpay): Razorpay only.
/// Money taken but not yet confirmed is "pending", never an error: the server confirms it on its own.
@injectable
class EnrolInWorkshop {
  const EnrolInWorkshop(this._repo, this._gateway, this._store);
  final WorkshopsRepository _repo;
  final PaymentGateway _gateway;
  final StoreBilling _store;

  /// Whether Google's screen comes first (so the state must be asked for).
  static bool usesStore(WorkshopDetail d, StoreBilling store) => store.supported && (d.android?.userChoice ?? false) && (d.playProductId ?? '').isNotEmpty;

  Future<Result<EnrolOutcome>> call(EnrolRequest r) async {
    final slug = r.detail.workshop.slug;
    if (!usesStore(r.detail, _store)) return _razorpay(slug, r);
    if ((r.state ?? '').isEmpty) return const Err(ValidationFailure('Choose your state to continue.'));

    final hold = await _repo.holdForPlay(slug, name: r.name, phone: r.phone);
    if (hold case Err(:final failure)) return Err(failure);
    final product = hold.valueOrNull!;
    final s = await _store.buy(productId: product, accountId: r.detail.android!.accountId);
    switch (s) {
      case StoreCancelled():
        await _repo.release(slug);
        return const Success(EnrolOutcome.cancelled);
      case StorePending():
        return const Success(EnrolOutcome.pending);
      case StoreFailed(:final message):
        await _repo.release(slug);
        return Err(ServerFailure(message));
      case StoreChoseRazorpay(:final externalToken):
        await _repo.release(slug);
        return _razorpay(slug, r, externalToken: externalToken);
      case StorePurchased(:final productId, :final token):
        final v = await _repo.verifyStorePurchase(productId: productId, token: token);
        // Refused by the server (no seat to match, someone else's purchase): say why.
        if (v case Err(failure: ServerFailure(statusCode: final int code)) when code >= 400 && code < 500) return Err(v.failureOrNull!);
        return Success(v case Success(value: 'confirmed') ? EnrolOutcome.enrolled : EnrolOutcome.pending);
    }
  }

  Future<Result<EnrolOutcome>> _razorpay(String slug, EnrolRequest r, {String? externalToken}) async {
    final order = await _repo.createOrder(slug, name: r.name, phone: r.phone, externalToken: externalToken, state: externalToken == null ? null : r.state);
    switch (order) {
      case Err(:final failure):
        return Err(failure);
      case Success(value: final o):
        final g = await _gateway.open(o);
        switch (g) {
          case GatewayCancelled():
            await _repo.release(slug);
            return const Success(EnrolOutcome.cancelled);
          case GatewayPending():
            return const Success(EnrolOutcome.pending);
          case GatewayFailed(:final message):
            return Err(ServerFailure(message));
          case GatewaySuccess(:final paymentId, :final orderId, :final signature):
            final v = await _repo.verify(orderId: orderId.isEmpty ? o.orderId : orderId, paymentId: paymentId, signature: signature);
            return Success(v case Success(value: 'confirmed') ? EnrolOutcome.enrolled : EnrolOutcome.pending);
        }
    }
  }
}

/// Confirms short-course Google Play purchases the server hasn't seen (app closed mid-way, pending finished).
@injectable
class RecoverWorkshopPurchases {
  const RecoverWorkshopPurchases(this._repo, this._store);
  final WorkshopsRepository _repo;
  final StoreBilling _store;

  Future<int> call(AndroidBilling a) async {
    if (!_store.supported || !a.userChoice) return 0;
    try {
      var n = 0;
      for (final p in await _store.unfinished(accountId: a.accountId, prefix: 'short_course_')) {
        if (await _repo.verifyStorePurchase(productId: p.productId, token: p.token) case Success(value: 'confirmed')) n++;
      }
      return n;
    } catch (_) {
      return 0; // tried again next time
    }
  }
}

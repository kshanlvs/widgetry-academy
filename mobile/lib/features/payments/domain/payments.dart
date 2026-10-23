import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';

/// A way to pay, decided by the server (prices never live in the app).
class PayPlan extends Equatable {
  const PayPlan({required this.id, required this.title, required this.note, required this.amount, required this.fullPrice, this.recommended = false, this.playProductId});
  /// "early-bird", "regular", "booking" or "balance"
  final String id;
  final String title;
  final String note;
  /// Rupees to pay now.
  final int amount;
  /// Full course price for this plan.
  final int fullPrice;
  final bool recommended;
  /// The matching one-time product in Google Play ("course_fee_full"…), same price.
  final String? playProductId;
  @override
  List<Object?> get props => [id, title, note, amount, fullPrice, recommended, playProductId];
}

/// How the Android app takes payments, decided by the server.
/// With user choice billing, Google shows its screen first and the student picks
/// Google Play or Razorpay (India alternative billing).
class AndroidBilling extends Equatable {
  const AndroidBilling({required this.userChoice, required this.accountId, this.states = const []});
  /// False during internal testing (server ANDROID_BILLING=razorpay): Razorpay only.
  final bool userChoice;
  /// Anonymous id passed to Google so a purchase can be matched to this account.
  final String accountId;
  /// Indian states and union territories as Google expects them ("WEST BENGAL").
  final List<String> states;
  @override
  List<Object?> get props => [userChoice, accountId, states];
}

class PaymentOptions extends Equatable {
  const PaymentOptions({required this.enabled, required this.course, required this.status, this.plans = const [], this.amountPaid = 0, this.android});
  /// False until Razorpay keys are set on the server.
  final bool enabled;
  final String course;
  /// "unregistered", "unpaid", "part-paid", "paid", "refunded", "cancelled"
  final String status;
  final List<PayPlan> plans;
  final int amountPaid;
  final AndroidBilling? android;
  bool get isPaid => status == 'paid';
  @override
  List<Object?> get props => [enabled, course, status, plans, amountPaid, android];
}

/// A Razorpay order created by the server, ready for Checkout.
class CheckoutOrder extends Equatable {
  const CheckoutOrder({required this.orderId, required this.amountPaise, required this.currency, required this.keyId, required this.name, required this.description, this.prefillName = '', this.prefillEmail = '', this.prefillContact = ''});
  final String orderId;
  final int amountPaise;
  final String currency;
  final String keyId;
  final String name;
  final String description;
  final String prefillName;
  final String prefillEmail;
  final String prefillContact;
  @override
  List<Object?> get props => [orderId, amountPaise, currency, keyId, name, description, prefillName, prefillEmail, prefillContact];
}

/// What Razorpay Checkout returned.
sealed class GatewayResult {
  const GatewayResult();
}

final class GatewaySuccess extends GatewayResult {
  const GatewaySuccess({required this.paymentId, required this.orderId, required this.signature});
  final String paymentId;
  final String orderId;
  final String signature;
}

final class GatewayCancelled extends GatewayResult {
  const GatewayCancelled();
}

/// Paid in another app (e.g. an external wallet): the server confirms it through the webhook.
final class GatewayPending extends GatewayResult {
  const GatewayPending();
}

final class GatewayFailed extends GatewayResult {
  const GatewayFailed(this.message);
  final String message;
}

enum PaymentOutcomeKind { paid, partPaid, cancelled, pending }

class PaymentOutcome extends Equatable {
  const PaymentOutcome(this.kind, {this.amount = 0, this.paymentId});
  final PaymentOutcomeKind kind;
  /// Rupees paid.
  final int amount;
  final String? paymentId;
  @override
  List<Object?> get props => [kind, amount, paymentId];
}

/// Opens the payment sheet. Behind an interface so the flow can be tested without Razorpay.
abstract interface class PaymentGateway {
  Future<GatewayResult> open(CheckoutOrder order);
}

/// What Google Play's purchase screen returned.
sealed class StoreResult {
  const StoreResult();
}

/// Paid with Google Play. The server checks the token with Google, then consumes it.
final class StorePurchased extends StoreResult {
  const StorePurchased({required this.productId, required this.token});
  final String productId;
  final String token;
  @override
  bool operator ==(Object other) => other is StorePurchased && other.productId == productId && other.token == token;
  @override
  int get hashCode => Object.hash(productId, token);
}

/// The student picked Razorpay on Google's choice screen. The token goes with the
/// Razorpay order so the server can report the sale to Google.
final class StoreChoseRazorpay extends StoreResult {
  const StoreChoseRazorpay(this.externalToken);
  final String externalToken;
}

final class StoreCancelled extends StoreResult {
  const StoreCancelled();
}

/// Started but not finished (e.g. pay cash at a shop). Google tells us when it's done.
final class StorePending extends StoreResult {
  const StorePending();
}

final class StoreFailed extends StoreResult {
  const StoreFailed(this.message);
  final String message;
}

/// Google Play Billing, behind an interface so the flow can be tested without a phone.
abstract interface class StoreBilling {
  /// True on Android, where Play Billing exists.
  bool get supported;
  Future<StoreResult> buy({required String productId, required String accountId});
  /// Purchases Google has but our server hasn't confirmed (app closed mid-way, pending finished…),
  /// for products whose id starts with [prefix] ("course_fee_" for the main course, "short_course_" for crash courses).
  Future<List<StorePurchased>> unfinished({required String accountId, String prefix = 'course_fee_'});
}

/// One payment made in the app, for the receipts list.
class Receipt extends Equatable {
  const Receipt({required this.orderId, required this.paymentId, required this.plan, required this.title, required this.amount, this.method, this.paidAt});
  final String orderId;
  final String paymentId;
  final String plan;
  final String title;
  /// Rupees.
  final int amount;
  /// "upi", "card", "netbanking", "wallet"…
  final String? method;
  final DateTime? paidAt;

  String get methodLabel => switch (method) {
        'upi' => 'UPI',
        'card' => 'Card',
        'netbanking' => 'Net banking',
        'wallet' => 'Wallet',
        'emi' => 'EMI',
        'google_play' => 'Google Play',
        null || '' => 'Online',
        final String m => m[0].toUpperCase() + m.substring(1),
      };

  bool get viaGooglePlay => method == 'google_play';
  /// "UPI via Razorpay", "Google Play"
  String get paidWith => viaGooglePlay ? methodLabel : '$methodLabel via Razorpay';

  @override
  List<Object?> get props => [orderId, paymentId, plan, title, amount, method, paidAt];
}

/// Fee summary plus receipts, from the server (it also recovers payments that weren't confirmed).
class PaymentHistory extends Equatable {
  const PaymentHistory({required this.course, required this.status, this.plan, this.amountPaid = 0, this.total, this.due, this.name, this.email, this.phone, this.items = const []});
  final String course;
  /// "unregistered", "unpaid", "part-paid", "paid", "refunded", "cancelled"
  final String status;
  final String? plan;
  final int amountPaid;
  /// Full fee for the chosen plan, once chosen.
  final int? total;
  /// Balance still to pay (0 when paid; null when no plan yet).
  final int? due;
  final String? name;
  final String? email;
  final String? phone;
  final List<Receipt> items;
  @override
  List<Object?> get props => [course, status, plan, amountPaid, total, due, name, email, phone, items];
}

/// Anything bought: the main course fee, a short course or a mock interview.
/// Built by the server from its records, so a new course needs no app update.
class PurchaseOrder extends Equatable {
  const PurchaseOrder({
    required this.id,
    required this.kind,
    required this.title,
    required this.item,
    required this.amount,
    this.status = 'paid',
    this.plan,
    this.orderId,
    this.paymentId,
    this.method,
    this.paidAt,
    this.appPath,
  });

  /// Unique across kinds, e.g. "short_course-12".
  final String id;
  /// "course_fee", "short_course" or "mock_interview" (new kinds may appear; they show like any other).
  final String kind;
  /// What was bought, e.g. "Bloc Crash Course" or "Mock interview".
  final String title;
  /// The line on the receipt, e.g. "Course fee (early bird)".
  final String item;
  /// Rupees.
  final int amount;
  /// "paid", "refunded" or "refund_pending".
  final String status;
  final String? plan;
  final String? orderId;
  final String? paymentId;
  final String? method;
  final DateTime? paidAt;
  /// Where it lives in the app, e.g. "/short-courses/bloc-crash-course".
  final String? appPath;

  bool get isPaid => status == 'paid';
  /// The id to quote to support.
  String get reference => paymentId ?? orderId ?? id;

  /// Same wording as [Receipt].
  Receipt get asReceipt => Receipt(orderId: orderId ?? reference, paymentId: reference, plan: plan ?? kind, title: item, amount: amount, method: method, paidAt: paidAt);

  @override
  List<Object?> get props => [id, kind, title, item, amount, status, plan, orderId, paymentId, method, paidAt, appPath];
}

/// A course the student is in (or was, if refunded).
class EnrolledCourse extends Equatable {
  const EnrolledCourse({
    required this.kind,
    required this.slug,
    required this.title,
    required this.status,
    this.amountPaid = 0,
    this.startsAt,
    this.schedule,
    this.meetingLink,
    this.brochureUrl,
    this.appPath,
  });
  /// "flagship" or "short_course".
  final String kind;
  final String slug;
  final String title;
  /// "enrolled", "booked" (part paid), "registered" (not paid) or "refunded".
  final String status;
  final int amountPaid;
  final DateTime? startsAt;
  final String? schedule;
  /// Class link, once paid.
  final String? meetingLink;
  final String? brochureUrl;
  final String? appPath;

  bool get isShortCourse => kind == 'short_course';
  bool get isActive => status == 'enrolled' || status == 'booked';

  @override
  List<Object?> get props => [kind, slug, title, status, amountPaid, startsAt, schedule, meetingLink, brochureUrl, appPath];
}

/// Everything a student has bought, newest order first.
class Purchases extends Equatable {
  const Purchases({this.courses = const [], this.orders = const []});
  final List<EnrolledCourse> courses;
  final List<PurchaseOrder> orders;

  /// Short courses the student is in, for the Courses tab.
  List<EnrolledCourse> get activeShortCourses => courses.where((c) => c.isShortCourse && c.isActive).toList();

  @override
  List<Object?> get props => [courses, orders];
}

/// Makes a PDF receipt the student can save or share. [history] gives the buyer's details and,
/// for the main course fee, the fee summary.
abstract interface class ReceiptBuilder {
  Future<List<int>> build(PaymentHistory history, PurchaseOrder order);
}

abstract interface class PaymentsRepository {
  Future<Result<PaymentHistory>> history();
  /// Every course and order on the account, all kinds.
  Future<Result<Purchases>> purchases();
  Future<Result<PaymentOptions>> options();
  /// [externalToken] and [state] are set when the student chose Razorpay on Google's screen.
  Future<Result<CheckoutOrder>> createOrder(String planId, {String? externalToken, String? state});
  /// Returns the new pay status ("paid" or "part-paid").
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature});
  /// Google Play purchase → "paid", "part-paid" or "pending" (Google is still waiting for the money).
  Future<Result<String>> verifyStorePurchase({required String productId, required String token});
}

@injectable
class GetPaymentHistory implements UseCase<PaymentHistory, NoParams> {
  const GetPaymentHistory(this._repo);
  final PaymentsRepository _repo;
  @override
  Future<Result<PaymentHistory>> call(NoParams p) => _repo.history();
}

@injectable
class GetPurchases implements UseCase<Purchases, NoParams> {
  const GetPurchases(this._repo);
  final PaymentsRepository _repo;
  @override
  Future<Result<Purchases>> call(NoParams p) => _repo.purchases();
}

@injectable
class GetPaymentOptions implements UseCase<PaymentOptions, NoParams> {
  const GetPaymentOptions(this._repo);
  final PaymentsRepository _repo;
  @override
  Future<Result<PaymentOptions>> call(NoParams p) => _repo.options();
}

/// What to pay, and (on Android) how Google Play is set up and the student's state.
class PayRequest extends Equatable {
  const PayRequest(this.plan, {this.android, this.state});
  final PayPlan plan;
  final AndroidBilling? android;
  /// Needed for Google's tax report when the student chooses Razorpay.
  final String? state;
  @override
  List<Object?> get props => [plan, android, state];
}

/// The whole payment.
///
/// Android with user choice billing: Google's screen first, where the student picks
/// Google Play (server checks the purchase) or Razorpay (server order → Razorpay
/// Checkout → server confirmation, then reported to Google). Elsewhere: Razorpay only.
///
/// If money was taken but the confirmation can't reach the server, the result is
/// "pending", never an error: the server confirms it on its own (webhook / recovery).
@injectable
class PayForCourse implements UseCase<PaymentOutcome, PayRequest> {
  const PayForCourse(this._repo, this._gateway, this._store);
  final PaymentsRepository _repo;
  final PaymentGateway _gateway;
  final StoreBilling _store;

  /// Whether this request goes through Google's screen first.
  static bool usesStore(PayRequest r, StoreBilling store) => store.supported && (r.android?.userChoice ?? false) && (r.plan.playProductId ?? '').isNotEmpty;

  @override
  Future<Result<PaymentOutcome>> call(PayRequest r) async {
    final plan = r.plan;
    if (!usesStore(r, _store)) return _razorpay(plan);
    if ((r.state ?? '').isEmpty) return const Err(ValidationFailure('Choose your state to continue.'));

    final s = await _store.buy(productId: plan.playProductId!, accountId: r.android!.accountId);
    switch (s) {
      case StoreCancelled():
        return const Success(PaymentOutcome(PaymentOutcomeKind.cancelled));
      case StorePending():
        return Success(PaymentOutcome(PaymentOutcomeKind.pending, amount: plan.amount));
      case StoreFailed(:final message):
        return Err(ServerFailure(message));
      case StoreChoseRazorpay(:final externalToken):
        return _razorpay(plan, externalToken: externalToken, state: r.state);
      case StorePurchased(:final productId, :final token):
        final v = await _repo.verifyStorePurchase(productId: productId, token: token);
        // Refused by the server (not due, someone else's purchase): say why. Anything else
        // (no connection…) is "confirming": the purchase stays with Google and is confirmed next time.
        if (v case Err(failure: ServerFailure(statusCode: final int code)) when code >= 400 && code < 500) return Err(v.failureOrNull!);
        return Success(switch (v) {
          Success(value: 'paid') => PaymentOutcome(PaymentOutcomeKind.paid, amount: plan.amount),
          Success(value: 'part-paid') => PaymentOutcome(PaymentOutcomeKind.partPaid, amount: plan.amount),
          _ => PaymentOutcome(PaymentOutcomeKind.pending, amount: plan.amount),
        });
    }
  }

  Future<Result<PaymentOutcome>> _razorpay(PayPlan plan, {String? externalToken, String? state}) async {
    final order = await _repo.createOrder(plan.id, externalToken: externalToken, state: state);
    switch (order) {
      case Err(:final failure):
        return Err(failure);
      case Success(value: final o):
        final g = await _gateway.open(o);
        switch (g) {
          case GatewayCancelled():
            return const Success(PaymentOutcome(PaymentOutcomeKind.cancelled));
          case GatewayPending():
            return Success(PaymentOutcome(PaymentOutcomeKind.pending, amount: plan.amount));
          case GatewayFailed(:final message):
            return Err(ServerFailure(message));
          case GatewaySuccess(:final paymentId, :final orderId, :final signature):
            final v = await _repo.verify(orderId: orderId.isEmpty ? o.orderId : orderId, paymentId: paymentId, signature: signature);
            return Success(switch (v) {
              Success(value: 'paid') => PaymentOutcome(PaymentOutcomeKind.paid, amount: plan.amount, paymentId: paymentId),
              Success() => PaymentOutcome(PaymentOutcomeKind.partPaid, amount: plan.amount, paymentId: paymentId),
              Err() => PaymentOutcome(PaymentOutcomeKind.pending, amount: plan.amount, paymentId: paymentId),
            });
        }
    }
  }
}

/// Confirms Google Play purchases the server hasn't seen yet. Returns how many were confirmed.
/// Safe to run any time: the server ignores purchases it already counted.
@injectable
class RecoverStorePurchases implements UseCase<int, AndroidBilling> {
  const RecoverStorePurchases(this._repo, this._store);
  final PaymentsRepository _repo;
  final StoreBilling _store;

  @override
  Future<Result<int>> call(AndroidBilling a) async {
    if (!_store.supported || !a.userChoice) return const Success(0);
    try {
      var n = 0;
      for (final p in await _store.unfinished(accountId: a.accountId)) {
        final v = await _repo.verifyStorePurchase(productId: p.productId, token: p.token);
        if (v case Success(value: 'paid' || 'part-paid')) n++;
      }
      return Success(n);
    } catch (_) {
      return const Success(0); // tried again next time
    }
  }
}

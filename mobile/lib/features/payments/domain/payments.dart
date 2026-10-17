import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';

/// A way to pay, decided by the server (prices never live in the app).
class PayPlan extends Equatable {
  const PayPlan({required this.id, required this.title, required this.note, required this.amount, required this.fullPrice, this.recommended = false});
  /// "early-bird", "regular", "booking" or "balance"
  final String id;
  final String title;
  final String note;
  /// Rupees to pay now.
  final int amount;
  /// Full course price for this plan.
  final int fullPrice;
  final bool recommended;
  @override
  List<Object?> get props => [id, title, note, amount, fullPrice, recommended];
}

class PaymentOptions extends Equatable {
  const PaymentOptions({required this.enabled, required this.course, required this.status, this.plans = const [], this.amountPaid = 0});
  /// False until Razorpay keys are set on the server.
  final bool enabled;
  final String course;
  /// "unregistered", "unpaid", "part-paid", "paid", "refunded", "cancelled"
  final String status;
  final List<PayPlan> plans;
  final int amountPaid;
  bool get isPaid => status == 'paid';
  @override
  List<Object?> get props => [enabled, course, status, plans, amountPaid];
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

abstract interface class PaymentsRepository {
  Future<Result<PaymentOptions>> options();
  Future<Result<CheckoutOrder>> createOrder(String planId);
  /// Returns the new pay status ("paid" or "part-paid").
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature});
}

@injectable
class GetPaymentOptions implements UseCase<PaymentOptions, NoParams> {
  const GetPaymentOptions(this._repo);
  final PaymentsRepository _repo;
  @override
  Future<Result<PaymentOptions>> call(NoParams p) => _repo.options();
}

/// The whole payment: server order → Razorpay Checkout → server confirmation.
/// If Checkout succeeded but the confirmation can't reach the server, the result is "pending":
/// the money is safe and Razorpay's webhook confirms it on the server.
@injectable
class PayForCourse implements UseCase<PaymentOutcome, PayPlan> {
  const PayForCourse(this._repo, this._gateway);
  final PaymentsRepository _repo;
  final PaymentGateway _gateway;

  @override
  Future<Result<PaymentOutcome>> call(PayPlan plan) async {
    final order = await _repo.createOrder(plan.id);
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

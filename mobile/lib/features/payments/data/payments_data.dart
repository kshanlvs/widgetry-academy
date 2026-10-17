import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

@LazySingleton(as: PaymentsRepository)
class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<PaymentOptions>> options() => guard(() async {
        final j = await _api.get('/payments/plans');
        return PaymentOptions(
          enabled: j['enabled'] == true,
          course: '${j['course'] ?? 'Flutter in 10 Days'}',
          status: '${j['status'] ?? 'unpaid'}',
          amountPaid: (j['amountPaid'] as num?)?.round() ?? 0,
          plans: [
            for (final p in (j['plans'] as List? ?? const []).whereType<Map<String, dynamic>>())
              PayPlan(
                id: '${p['id']}',
                title: '${p['title'] ?? ''}',
                note: '${p['note'] ?? ''}',
                amount: (p['amount'] as num?)?.round() ?? 0,
                fullPrice: (p['fullPrice'] as num?)?.round() ?? 0,
                recommended: p['recommended'] == true,
              ),
          ],
        );
      });

  @override
  Future<Result<CheckoutOrder>> createOrder(String planId) => guard(() async {
        final j = await _api.post('/payments/order', body: {'plan': planId});
        final pre = (j['prefill'] as Map?) ?? const {};
        return CheckoutOrder(
          orderId: '${j['orderId']}',
          amountPaise: (j['amount'] as num).round(),
          currency: '${j['currency'] ?? 'INR'}',
          keyId: '${j['keyId']}',
          name: '${j['name'] ?? 'Widgetry Academy'}',
          description: '${j['description'] ?? ''}',
          prefillName: '${pre['name'] ?? ''}',
          prefillEmail: '${pre['email'] ?? ''}',
          prefillContact: '${pre['contact'] ?? ''}',
        );
      });

  @override
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature}) => guard(() async {
        final j = await _api.post('/payments/verify', body: {'orderId': orderId, 'paymentId': paymentId, 'signature': signature});
        return '${j['status'] ?? 'paid'}';
      });
}

/// Razorpay Standard Checkout (UPI, cards, net banking, wallets) through the official plugin.
@LazySingleton(as: PaymentGateway)
class RazorpayGateway implements PaymentGateway {
  Razorpay? _razorpay;
  Completer<GatewayResult>? _pending;

  Razorpay get _rzp => _razorpay ??= Razorpay()
    ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
    ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
    ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);

  @override
  Future<GatewayResult> open(CheckoutOrder o) {
    _finish(const GatewayCancelled()); // a previous sheet that never reported back
    final c = Completer<GatewayResult>();
    _pending = c;
    try {
      _rzp.open({
        'key': o.keyId,
        'order_id': o.orderId,
        'amount': o.amountPaise,
        'currency': o.currency,
        'name': o.name,
        'description': o.description,
        'prefill': {'name': o.prefillName, 'email': o.prefillEmail, 'contact': o.prefillContact},
        'theme': {'color': '#0F6B56'},
        'retry': {'enabled': true, 'max_count': 3},
        'send_sms_hash': true,
      });
    } catch (_) {
      _finish(const GatewayFailed("Couldn't open the payment screen. Please update the app and try again."));
    }
    return c.future;
  }

  void _onSuccess(PaymentSuccessResponse r) =>
      _finish(GatewaySuccess(paymentId: r.paymentId ?? '', orderId: r.orderId ?? '', signature: r.signature ?? ''));

  void _onError(PaymentFailureResponse r) {
    if (r.code == Razorpay.PAYMENT_CANCELLED) {
      _finish(const GatewayCancelled());
    } else if (r.code == Razorpay.NETWORK_ERROR) {
      _finish(const GatewayFailed('No internet connection. No money was taken. Please try again.'));
    } else {
      _finish(const GatewayFailed("The payment didn't go through. If money was taken, your bank returns it automatically. Please try again."));
    }
  }

  void _onWallet(ExternalWalletResponse r) => _finish(const GatewayPending());

  void _finish(GatewayResult result) {
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(result);
    _pending = null;
  }
}

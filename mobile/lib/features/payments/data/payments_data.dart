import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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
  Future<Result<PaymentHistory>> history() => guard(() async {
        final j = await _api.get('/payments/mine');
        final s = (j['summary'] as Map?) ?? const {};
        int? n(Object? v) => (v as num?)?.round();
        String? str(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
        return PaymentHistory(
          course: '${j['course'] ?? 'Flutter in 10 Days'}',
          status: '${s['status'] ?? 'unpaid'}',
          plan: str(s['plan']),
          amountPaid: n(s['amountPaid']) ?? 0,
          total: n(s['total']),
          due: n(s['due']),
          name: str(s['name']),
          email: str(s['email']),
          phone: str(s['phone']),
          items: [
            for (final r in (j['items'] as List? ?? const []).whereType<Map<String, dynamic>>())
              Receipt(
                orderId: '${r['orderId']}',
                paymentId: '${r['paymentId'] ?? ''}',
                plan: '${r['plan'] ?? ''}',
                title: '${r['title'] ?? 'Course fee'}',
                amount: n(r['amount']) ?? 0,
                method: str(r['method']),
                paidAt: DateTime.tryParse('${r['paidAt'] ?? ''}')?.toLocal(),
              ),
          ],
        );
      });

  @override
  Future<Result<Purchases>> purchases() => guard(() async => purchasesFromJson(await _api.get('/me/purchases')));

  /// Unknown kinds and statuses are kept as they are, so the server can add new ones.
  static Purchases purchasesFromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.round() ?? 0;
    String? str(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
    DateTime? at(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    return Purchases(
      courses: [
        for (final c in (j['courses'] as List? ?? const []).whereType<Map<String, dynamic>>())
          EnrolledCourse(
            kind: '${c['kind'] ?? 'short_course'}',
            slug: '${c['slug'] ?? ''}',
            title: '${c['title'] ?? 'Course'}',
            status: '${c['status'] ?? 'enrolled'}',
            amountPaid: n(c['amountPaid']),
            startsAt: at(c['startsAt']),
            schedule: str(c['schedule']),
            meetingLink: str(c['meetingLink']),
            brochureUrl: str(c['brochureUrl']),
            appPath: str(c['appPath']),
          ),
      ],
      orders: [
        for (final o in (j['orders'] as List? ?? const []).whereType<Map<String, dynamic>>())
          PurchaseOrder(
            id: '${o['id']}',
            kind: '${o['kind'] ?? 'course_fee'}',
            title: '${o['title'] ?? 'Course'}',
            item: '${o['item'] ?? 'Course fee'}',
            amount: n(o['amount']),
            status: '${o['status'] ?? 'paid'}',
            plan: str(o['plan']),
            orderId: str(o['orderId']),
            paymentId: str(o['paymentId']),
            method: str(o['method']),
            paidAt: at(o['paidAt']),
            appPath: str(o['appPath']),
          ),
      ],
    );
  }

  @override
  Future<Result<PaymentOptions>> options() => guard(() async {
        final j = await _api.get('/payments/plans');
        final a = j['android'] as Map?;
        return PaymentOptions(
          android: a == null
              ? null
              : AndroidBilling(
                  userChoice: a['billing'] == 'user_choice',
                  accountId: '${a['accountId'] ?? ''}',
                  states: [for (final x in (a['states'] as List? ?? const [])) '$x'],
                ),
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
                playProductId: p['playProductId'] == null ? null : '${p['playProductId']}',
              ),
          ],
        );
      });

  @override
  Future<Result<CheckoutOrder>> createOrder(String planId, {String? externalToken, String? state}) => guard(() async {
        final j = await _api.post('/payments/order', body: {
          'plan': planId,
          if (externalToken != null) 'externalTransactionToken': externalToken,
          if (externalToken != null && state != null) 'state': state,
        });
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

  @override
  Future<Result<String>> verifyStorePurchase({required String productId, required String token}) => guard(() async {
        final j = await _api.post('/payments/play/verify', body: {'productId': productId, 'purchaseToken': token});
        return '${j['status'] ?? 'pending'}';
      });
}

/// Google Play Billing with user choice (India alternative billing): Google shows the
/// student Google Play and Razorpay side by side. Purchases are not consumed here;
/// the server consumes them after counting the payment, so nothing is lost if the app closes.
@LazySingleton(as: StoreBilling)
class PlayStoreBilling implements StoreBilling {
  final InAppPurchase _iap = InAppPurchase.instance;
  InAppPurchaseAndroidPlatformAddition get _android => _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
  Future<void>? _ready;

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _init() => _ready ??= _android.setBillingChoice(BillingChoiceMode.userChoiceBilling).catchError((Object e) {
        _ready = null;
        throw e;
      });

  static const _unavailable = StoreFailed("Google Play payments aren't available on this phone. Update the Play Store app, sign in to it, and try again.");
  static const _owned = '_owned';

  @override
  Future<StoreResult> buy({required String productId, required String accountId}) async {
    try {
      await _init();
      if (!await _iap.isAvailable()) return _unavailable;
      final q = await _iap.queryProductDetails({productId});
      final product = q.productDetails.where((p) => p.id == productId).firstOrNull;
      if (product == null) return const StoreFailed("This payment option isn't available right now. Please try again in a while, or message us on WhatsApp.");

      final done = Completer<StoreResult>();
      void finish(StoreResult r) {
        if (!done.isCompleted) done.complete(r);
      }

      final purchases = _iap.purchaseStream.listen((list) {
        for (final p in list) {
          if (p.productID.isNotEmpty && p.productID != productId) continue;
          final token = p.verificationData.serverVerificationData;
          switch (p.status) {
            case PurchaseStatus.purchased || PurchaseStatus.restored when token.isNotEmpty:
              finish(StorePurchased(productId: productId, token: token));
            case PurchaseStatus.pending:
              finish(const StorePending());
            case PurchaseStatus.canceled:
              finish(const StoreCancelled());
            case PurchaseStatus.error:
              final owned = (p.error?.message ?? '').contains('itemAlreadyOwned');
              finish(owned ? const StoreFailed(_owned) : StoreFailed(_message(p.error?.message)));
            default:
              break;
          }
        }
      }, onError: (Object _) => finish(const StoreFailed("The payment didn't go through. No money was taken. Please try again.")));
      final choice = _android.userChoiceDetailsStream.listen((d) => finish(StoreChoseRazorpay(d.externalTransactionToken)));

      try {
        final started = await _iap.buyConsumable(
          purchaseParam: GooglePlayPurchaseParam(productDetails: product, applicationUserName: accountId),
          autoConsume: false,
        );
        if (!started) finish(_unavailable);
        var r = await done.future;
        // Bought earlier but never confirmed (e.g. the app closed): hand that purchase to the server.
        if (r is StoreFailed && r.message == _owned) {
          final mine = (await unfinished(accountId: accountId, prefix: productId)).where((p) => p.productId == productId).firstOrNull;
          r = mine ?? const StoreFailed('A previous payment is still being processed. Please try again in a few minutes.');
        }
        return r;
      } finally {
        await purchases.cancel();
        await choice.cancel();
      }
    } on PlatformException {
      return _unavailable;
    }
  }

  @override
  Future<List<StorePurchased>> unfinished({required String accountId, String prefix = 'course_fee_'}) async {
    await _init();
    final r = await _android.queryPastPurchases();
    return [
      for (final p in r.pastPurchases)
        if (p.productID.startsWith(prefix) &&
            p.status == PurchaseStatus.purchased &&
            (p.billingClientPurchase.obfuscatedAccountId == null || p.billingClientPurchase.obfuscatedAccountId == accountId))
          StorePurchased(productId: p.productID, token: p.verificationData.serverVerificationData),
    ];
  }

  static String _message(String? code) => switch (code ?? '') {
        final c when c.contains('serviceUnavailable') || c.contains('networkError') => 'No connection to Google Play. No money was taken. Please try again.',
        final c when c.contains('billingUnavailable') => _unavailable.message,
        _ => "The payment didn't go through. No money was taken. Please try again.",
      };
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

import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/workshops/domain/workshops.dart';

/// Mapping between the API's JSON and the domain. Kept separate so it can be unit tested.
abstract final class WorkshopsJson {
  static String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
  static int? _iOrNull(Object? v) => v == null ? null : ((v as num?)?.round() ?? int.tryParse('$v'));
  static DateTime? _t(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal();

  static Workshop workshop(Map<String, dynamic> j) => Workshop(
        slug: '${j['slug'] ?? ''}',
        title: '${j['title'] ?? ''}',
        status: '${j['status'] ?? 'draft'}',
        price: _iOrNull(j['price']) ?? 0,
        earlyPrice: _iOrNull(j['earlyPrice']),
        earlySeatsLeft: _iOrNull(j['earlySeatsLeft']),
        earlyUntil: _t(j['earlyUntil']),
        startsAt: _t(j['startsAt']),
        schedule: _s(j['schedule']),
        durationMin: _iOrNull(j['durationMin']) ?? 300,
        seatsLeft: _iOrNull(j['seatsLeft']) ?? 0,
      );

  static WorkshopDetail detail(Map<String, dynamic> j) {
    final m = j['mine'] as Map<String, dynamic>?;
    final a = j['android'] as Map<String, dynamic>?;
    return WorkshopDetail(
      workshop: workshop(j['workshop'] as Map<String, dynamic>),
      mine: m == null
          ? null
          : WorkshopEnrolment(status: '${m['status'] ?? ''}', amount: _iOrNull(m['amount']) ?? 0, paymentId: _s(m['paymentId']), meetingLink: _s(m['meetingLink'])),
      paymentsOpen: j['paymentsOpen'] == true,
      android: a == null
          ? null
          : AndroidBilling(
              userChoice: a['billing'] == 'user_choice',
              accountId: '${a['accountId'] ?? ''}',
              states: [for (final s in (a['states'] as List? ?? const [])) '$s'],
            ),
      playProductId: _s(a?['playProductId']),
    );
  }

  static CheckoutOrder order(Map<String, dynamic> j) {
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
  }
}

@LazySingleton(as: WorkshopsRepository)
class WorkshopsRepositoryImpl implements WorkshopsRepository {
  WorkshopsRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<Workshop>>> list() => guard(() async {
        final j = await _api.get('/workshops');
        return [for (final w in (j['items'] as List? ?? const []).whereType<Map<String, dynamic>>()) WorkshopsJson.workshop(w)];
      });

  @override
  Future<Result<WorkshopDetail>> detail(String slug) => guard(() async => WorkshopsJson.detail(await _api.get('/workshops/${Uri.encodeComponent(slug)}')));

  @override
  Future<Result<String>> holdForPlay(String slug, {required String name, required String phone}) => guard(() async {
        final j = await _api.post('/workshops/${Uri.encodeComponent(slug)}/enroll', body: {'name': name, 'phone': phone, 'mode': 'play'});
        return '${j['productId']}';
      });

  @override
  Future<Result<CheckoutOrder>> createOrder(String slug, {required String name, required String phone, String? externalToken, String? state}) => guard(() async {
        final j = await _api.post('/workshops/${Uri.encodeComponent(slug)}/enroll', body: {
          'name': name,
          'phone': phone,
          if (externalToken != null) 'externalTransactionToken': externalToken,
          if (externalToken != null && state != null) 'state': state,
        });
        return WorkshopsJson.order(j);
      });

  @override
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature}) => guard(() async {
        final j = await _api.post('/workshops/verify', body: {'orderId': orderId, 'paymentId': paymentId, 'signature': signature});
        return '${j['status'] ?? 'confirmed'}';
      });

  @override
  Future<Result<String>> verifyStorePurchase({required String productId, required String token}) => guard(() async {
        final j = await _api.post('/workshops/play/verify', body: {'productId': productId, 'purchaseToken': token});
        return '${j['status'] ?? 'confirmed'}';
      });

  @override
  Future<Result<Unit>> release(String slug) => guard(() async {
        await _api.post('/workshops/${Uri.encodeComponent(slug)}/release', body: const <String, dynamic>{});
        return unit;
      });
}

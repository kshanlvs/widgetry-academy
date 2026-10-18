import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/workshops/data/workshops_data.dart';
import 'package:widgetry_academy/features/workshops/domain/workshops.dart';
import 'package:widgetry_academy/features/workshops/presentation/workshop_page.dart' show shortCourseSlug;

class FakeRepo implements WorkshopsRepository {
  final calls = <String>[];
  Result<String> verifyResult = const Success('confirmed');
  Result<String> storeResult = const Success('confirmed');
  String? lastToken, lastState;

  @override
  Future<Result<List<Workshop>>> list() async => const Success([]);
  @override
  Future<Result<WorkshopDetail>> detail(String slug) async => throw UnimplementedError();
  @override
  Future<Result<String>> holdForPlay(String slug, {required String name, required String phone}) async {
    calls.add('hold');
    return const Success('short_course_799');
  }

  @override
  Future<Result<CheckoutOrder>> createOrder(String slug, {required String name, required String phone, String? externalToken, String? state}) async {
    calls.add('order');
    lastToken = externalToken;
    lastState = state;
    return const Success(order);
  }

  @override
  Future<Result<String>> verify({required String orderId, required String paymentId, required String signature}) async {
    calls.add('verify');
    return verifyResult;
  }

  @override
  Future<Result<String>> verifyStorePurchase({required String productId, required String token}) async {
    calls.add('verifyStore:$productId');
    return storeResult;
  }

  @override
  Future<Result<Unit>> release(String slug) async {
    calls.add('release');
    return const Success(unit);
  }
}

class FakeGateway implements PaymentGateway {
  FakeGateway(this.result);
  final GatewayResult result;
  @override
  Future<GatewayResult> open(CheckoutOrder order) async => result;
}

class FakeStore implements StoreBilling {
  FakeStore(this.result, {this.supported = true, this.left = const []});
  final StoreResult result;
  @override
  final bool supported;
  final List<StorePurchased> left;
  String? asked;
  @override
  Future<StoreResult> buy({required String productId, required String accountId}) async => result;
  @override
  Future<List<StorePurchased>> unfinished({required String accountId, String prefix = 'course_fee_'}) async {
    asked = prefix;
    return left.where((p) => p.productId.startsWith(prefix)).toList();
  }
}

const order = CheckoutOrder(orderId: 'order_W1', amountPaise: 79900, currency: 'INR', keyId: 'rzp_test', name: 'Widgetry Academy', description: 'Bloc');
const ok = GatewaySuccess(paymentId: 'pay_1', orderId: 'order_W1', signature: 'sig');
const bloc = Workshop(slug: 'bloc-crash-course', title: 'Bloc State Management Crash Course', status: 'open', price: 999, earlyPrice: 799, seatsLeft: 10);
const play = AndroidBilling(userChoice: true, accountId: 'acc1', states: ['WEST BENGAL']);
const withPlay = WorkshopDetail(workshop: bloc, paymentsOpen: true, android: play, playProductId: 'short_course_799');
const webOnly = WorkshopDetail(workshop: bloc, paymentsOpen: true);
final noStore = FakeStore(const StoreCancelled(), supported: false);

EnrolRequest req(WorkshopDetail d, {String? state = 'WEST BENGAL'}) => EnrolRequest(detail: d, name: 'Asha', phone: '9876543210', state: state);

void main() {
  group('EnrolInWorkshop', () {
    test('Razorpay only (no Google Play): order → checkout → confirmed', () async {
      final repo = FakeRepo();
      final r = await EnrolInWorkshop(repo, FakeGateway(ok), noStore)(req(webOnly));
      expect(r.valueOrNull, EnrolOutcome.enrolled);
      expect(repo.calls, ['order', 'verify']);
      expect(repo.lastToken, isNull);
    });

    test('closing Razorpay Checkout lets go of the seat', () async {
      final repo = FakeRepo();
      final r = await EnrolInWorkshop(repo, FakeGateway(const GatewayCancelled()), noStore)(req(webOnly));
      expect(r.valueOrNull, EnrolOutcome.cancelled);
      expect(repo.calls, ['order', 'release']);
    });

    test('paid but confirmation failed: pending, never an error', () async {
      final repo = FakeRepo()..verifyResult = const Err(NetworkFailure());
      final r = await EnrolInWorkshop(repo, FakeGateway(ok), noStore)(req(webOnly));
      expect(r.valueOrNull, EnrolOutcome.pending);
    });

    test('Google Play needs the state first', () async {
      final repo = FakeRepo();
      final r = await EnrolInWorkshop(repo, FakeGateway(ok), FakeStore(const StoreCancelled()))(req(withPlay, state: null));
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('paid with Google Play: seat held, purchase checked by the server', () async {
      final repo = FakeRepo();
      final r = await EnrolInWorkshop(repo, FakeGateway(ok), FakeStore(const StorePurchased(productId: 'short_course_799', token: 'tok')))(req(withPlay));
      expect(r.valueOrNull, EnrolOutcome.enrolled);
      expect(repo.calls, ['hold', 'verifyStore:short_course_799']);
    });

    test('server refuses the Google Play purchase: the reason is shown', () async {
      final repo = FakeRepo()..storeResult = const Err(ServerFailure('No seat to match', statusCode: 409));
      final r = await EnrolInWorkshop(repo, FakeGateway(ok), FakeStore(const StorePurchased(productId: 'short_course_799', token: 'tok')))(req(withPlay));
      expect(r.failureOrNull?.message, 'No seat to match');
    });

    test('Razorpay picked on Google\'s screen: hold released, order carries the token and state', () async {
      final repo = FakeRepo();
      final r = await EnrolInWorkshop(repo, FakeGateway(ok), FakeStore(const StoreChoseRazorpay('ext-tok')))(req(withPlay));
      expect(r.valueOrNull, EnrolOutcome.enrolled);
      expect(repo.calls, ['hold', 'release', 'order', 'verify']);
      expect([repo.lastToken, repo.lastState], ['ext-tok', 'WEST BENGAL']);
    });

    test('cancelled on Google\'s screen: seat released', () async {
      final repo = FakeRepo();
      final r = await EnrolInWorkshop(repo, FakeGateway(ok), FakeStore(const StoreCancelled()))(req(withPlay));
      expect(r.valueOrNull, EnrolOutcome.cancelled);
      expect(repo.calls, ['hold', 'release']);
    });
  });

  test('recovery only looks at short-course purchases', () async {
    final repo = FakeRepo();
    final store = FakeStore(const StoreCancelled(), left: const [StorePurchased(productId: 'short_course_799', token: 'a'), StorePurchased(productId: 'course_fee_full', token: 'b')]);
    expect(await RecoverWorkshopPurchases(repo, store)(play), 1);
    expect(store.asked, 'short_course_');
    expect(repo.calls, ['verifyStore:short_course_799']);
  });

  test('JSON: detail with seat, joining link and Google Play product', () {
    final d = WorkshopsJson.detail({
      'workshop': {'slug': 'bloc-crash-course', 'title': 'Bloc', 'status': 'open', 'price': 999, 'earlyPrice': 799, 'earlySeatsLeft': 3, 'seatsLeft': 12, 'startsAt': '2026-11-08T05:30:00.000Z', 'schedule': 'Sat & Sun'},
      'mine': {'status': 'confirmed', 'amount': 799, 'paymentId': 'pay_1', 'meetingLink': 'https://meet.google.com/x'},
      'paymentsOpen': true,
      'android': {'billing': 'user_choice', 'accountId': 'acc', 'states': ['KERALA'], 'playProductId': 'short_course_799'},
    });
    expect(d.workshop.payNow, 799);
    expect(d.workshop.isOpen, isTrue);
    expect(d.mine?.confirmed, isTrue);
    expect(d.mine?.meetingLink, 'https://meet.google.com/x');
    expect(d.android?.userChoice, isTrue);
    expect(d.playProductId, 'short_course_799');
  });

  test('JSON: signed out, dates coming soon', () {
    final d = WorkshopsJson.detail({'workshop': {'slug': 'x-course', 'title': 'X', 'status': 'draft', 'price': 999, 'seatsLeft': 40}, 'mine': null, 'paymentsOpen': false, 'android': null});
    expect(d.workshop.datesComingSoon, isTrue);
    expect(d.workshop.payNow, 999);
    expect([d.mine, d.android, d.playProductId], [null, null, null]);
  });

  test('course cards that link to a short course page open it in the app', () {
    expect(shortCourseSlug('bloc-crash-course.html'), 'bloc-crash-course');
    expect(shortCourseSlug('#register'), isNull);
    expect(shortCourseSlug('apps.html'), isNull);
    expect(shortCourseSlug('https://widgetryacademy.in/bloc-crash-course.html'), isNull);
  });
}

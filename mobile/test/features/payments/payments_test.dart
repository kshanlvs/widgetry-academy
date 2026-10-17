import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/payments/presentation/checkout_cubit.dart';

class MockRepo extends Mock implements PaymentsRepository {}

class FakeGateway implements PaymentGateway {
  FakeGateway(this.result);
  GatewayResult result;
  CheckoutOrder? opened;
  @override
  Future<GatewayResult> open(CheckoutOrder order) async {
    opened = order;
    return result;
  }
}

class FakeStore implements StoreBilling {
  FakeStore(this.result, {this.supported = true, this.left = const []});
  StoreResult result;
  @override
  bool supported;
  List<StorePurchased> left;
  String? boughtProduct, boughtFor;
  @override
  Future<StoreResult> buy({required String productId, required String accountId}) async {
    boughtProduct = productId;
    boughtFor = accountId;
    return result;
  }

  @override
  Future<List<StorePurchased>> unfinished({required String accountId}) async => left;
}

final noStore = FakeStore(const StoreCancelled(), supported: false);

const booking = PayPlan(id: 'booking', title: 'Book', note: '', amount: 2500, fullPrice: 4999, playProductId: 'course_fee_booking');
const regular = PayPlan(id: 'regular', title: 'Pay in full', note: '', amount: 4999, fullPrice: 4999, recommended: true, playProductId: 'course_fee_full');
const play = AndroidBilling(userChoice: true, accountId: 'acc1', states: ['KERALA', 'WEST BENGAL']);
const order = CheckoutOrder(orderId: 'order_1', amountPaise: 250000, currency: 'INR', keyId: 'rzp_test', name: 'Widgetry Academy', description: 'Flutter in 10 Days');
const ok = GatewaySuccess(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig');

void main() {
  late MockRepo repo;
  setUp(() {
    repo = MockRepo();
    when(() => repo.createOrder(any(), externalToken: any(named: 'externalToken'), state: any(named: 'state'))).thenAnswer((_) async => const Success(order));
  });

  group('PayForCourse', () {
    test('order → checkout → server confirms: part payment', () async {
      final gw = FakeGateway(ok);
      when(() => repo.verify(orderId: 'order_1', paymentId: 'pay_1', signature: 'sig')).thenAnswer((_) async => const Success('part-paid'));
      final r = await PayForCourse(repo, gw, noStore)(const PayRequest(booking));
      expect(r.valueOrNull, const PaymentOutcome(PaymentOutcomeKind.partPaid, amount: 2500, paymentId: 'pay_1'));
      expect(gw.opened, order);
      verify(() => repo.createOrder('booking')).called(1);
    });

    test('paid in full', () async {
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Success('paid'));
      final r = await PayForCourse(repo, FakeGateway(ok), noStore)(const PayRequest(regular));
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.paid);
    });

    test('cancelled in Checkout: nothing is confirmed', () async {
      final r = await PayForCourse(repo, FakeGateway(const GatewayCancelled()), noStore)(const PayRequest(booking));
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.cancelled);
      verifyNever(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature')));
    });

    test('paid but the confirmation could not reach the server: pending, never an error', () async {
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Err(NetworkFailure()));
      final r = await PayForCourse(repo, FakeGateway(ok), noStore)(const PayRequest(booking));
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.pending);
    });

    test('failed payment and failed order creation are errors', () async {
      expect((await PayForCourse(repo, FakeGateway(const GatewayFailed('Declined')), noStore)(const PayRequest(booking))).failureOrNull, const ServerFailure('Declined'));
      when(() => repo.createOrder(any(), externalToken: any(named: 'externalToken'), state: any(named: 'state'))).thenAnswer((_) async => const Err(ServerFailure('Please register for the course first.', statusCode: 409)));
      final r = await PayForCourse(repo, FakeGateway(ok), noStore)(const PayRequest(booking));
      expect(r.failureOrNull?.message, 'Please register for the course first.');
    });
  });

  group('PayForCourse on Android (Google Play user choice)', () {
    test('paid with Google Play: the server checks the purchase; Razorpay is never opened', () async {
      final gw = FakeGateway(ok), store = FakeStore(const StorePurchased(productId: 'course_fee_full', token: 'tok'));
      when(() => repo.verifyStorePurchase(productId: 'course_fee_full', token: 'tok')).thenAnswer((_) async => const Success('paid'));
      final r = await PayForCourse(repo, gw, store)(const PayRequest(regular, android: play, state: 'KERALA'));
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.paid);
      expect([store.boughtProduct, store.boughtFor], ['course_fee_full', 'acc1']);
      expect(gw.opened, isNull);
    });

    test('chose Razorpay on Google\'s screen: the order carries Google\'s token and the state', () async {
      final gw = FakeGateway(ok);
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Success('part-paid'));
      final r = await PayForCourse(repo, gw, FakeStore(const StoreChoseRazorpay('ext-tok')))(const PayRequest(booking, android: play, state: 'WEST BENGAL'));
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.partPaid);
      verify(() => repo.createOrder('booking', externalToken: 'ext-tok', state: 'WEST BENGAL')).called(1);
      expect(gw.opened, order);
    });

    test('state is required before Google\'s screen', () async {
      final store = FakeStore(const StoreCancelled());
      final r = await PayForCourse(repo, FakeGateway(ok), store)(const PayRequest(booking, android: play));
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(store.boughtProduct, isNull);
    });

    test('server testing mode (Razorpay only) skips Google', () async {
      final store = FakeStore(const StoreCancelled());
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Success('paid'));
      final r = await PayForCourse(repo, FakeGateway(ok), store)(const PayRequest(regular, android: AndroidBilling(userChoice: false, accountId: 'acc1')));
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.paid);
      expect(store.boughtProduct, isNull);
    });

    test('Google pending, cancelled, failed; confirmation offline is pending; refused by server is an error', () async {
      Future<Result<PaymentOutcome>> run(StoreResult s) => PayForCourse(repo, FakeGateway(ok), FakeStore(s))(const PayRequest(booking, android: play, state: 'KERALA'));
      expect((await run(const StorePending())).valueOrNull?.kind, PaymentOutcomeKind.pending);
      expect((await run(const StoreCancelled())).valueOrNull?.kind, PaymentOutcomeKind.cancelled);
      expect((await run(const StoreFailed('No Play'))).failureOrNull, const ServerFailure('No Play'));
      when(() => repo.verifyStorePurchase(productId: any(named: 'productId'), token: any(named: 'token'))).thenAnswer((_) async => const Err(NetworkFailure()));
      expect((await run(const StorePurchased(productId: 'course_fee_booking', token: 't'))).valueOrNull?.kind, PaymentOutcomeKind.pending);
      when(() => repo.verifyStorePurchase(productId: any(named: 'productId'), token: any(named: 'token'))).thenAnswer((_) async => const Err(ServerFailure('Not due', statusCode: 409)));
      expect((await run(const StorePurchased(productId: 'course_fee_booking', token: 't'))).failureOrNull?.message, 'Not due');
    });

    test('recovers purchases the server has not confirmed', () async {
      when(() => repo.verifyStorePurchase(productId: any(named: 'productId'), token: any(named: 'token'))).thenAnswer((_) async => const Success('paid'));
      final store = FakeStore(const StoreCancelled(), left: const [StorePurchased(productId: 'course_fee_full', token: 'old')]);
      expect((await RecoverStorePurchases(repo, store)(play)).valueOrNull, 1);
      verify(() => repo.verifyStorePurchase(productId: 'course_fee_full', token: 'old')).called(1);
      expect((await RecoverStorePurchases(repo, noStore)(play)).valueOrNull, 0);
    });
  });

  group('CheckoutCubit', () {
    const options = PaymentOptions(enabled: true, course: 'Flutter in 10 Days', status: 'unpaid', plans: [booking, regular]);
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    CheckoutCubit cubit(PaymentGateway gw, [StoreBilling? store]) {
      final s = store ?? noStore;
      return CheckoutCubit(GetPaymentOptions(repo), PayForCourse(repo, gw, s), RecoverStorePurchases(repo, s), s, prefs);
    }

    blocTest<CheckoutCubit, CheckoutState>(
      'Android: asks for the state, remembers it, and confirms a leftover Google Play payment on load',
      setUp: () {
        when(() => repo.options()).thenAnswer((_) async => const Success(PaymentOptions(enabled: true, course: 'F', status: 'unpaid', plans: [booking, regular], android: play)));
        when(() => repo.verifyStorePurchase(productId: any(named: 'productId'), token: any(named: 'token'))).thenAnswer((_) async => const Success('part-paid'));
      },
      build: () => cubit(FakeGateway(ok), FakeStore(const StoreCancelled(), left: const [StorePurchased(productId: 'course_fee_booking', token: 'old')])),
      act: (c) async {
        await c.load();
        expect(c.needsState, isTrue);
        expect(c.canPay, isFalse);
        await c.chooseState('KERALA');
      },
      verify: (c) {
        expect(c.canPay, isTrue);
        expect(prefs.getString('pay_tax_state'), 'KERALA');
        verify(() => repo.options()).called(2); // reloaded after the recovered payment
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'loads options and preselects the recommended plan',
      setUp: () => when(() => repo.options()).thenAnswer((_) async => const Success(options)),
      build: () => cubit(FakeGateway(ok)),
      act: (c) => c.load(),
      verify: (c) => expect(c.state.selected, regular),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'cancelling shows a message and stays on the plans',
      setUp: () => when(() => repo.options()).thenAnswer((_) async => const Success(options)),
      build: () => cubit(FakeGateway(const GatewayCancelled())),
      act: (c) async {
        await c.load();
        await c.pay();
      },
      verify: (c) {
        expect(c.state.outcome, isNull);
        expect(c.state.paying, isFalse);
        expect(c.state.message, contains('cancelled'));
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'a successful payment shows the outcome',
      setUp: () {
        when(() => repo.options()).thenAnswer((_) async => const Success(options));
        when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Success('paid'));
      },
      build: () => cubit(FakeGateway(ok)),
      act: (c) async {
        await c.load();
        await c.pay();
      },
      verify: (c) => expect(c.state.outcome?.kind, PaymentOutcomeKind.paid),
    );
  });

  test('options model', () {
    expect(const PaymentOptions(enabled: true, course: 'x', status: 'paid').isPaid, isTrue);
    expect(const NoParams(), const NoParams());
    expect(const Receipt(orderId: 'GPA.1', paymentId: 'GPA.1', plan: 'regular', title: 'Fee', amount: 4999, method: 'google_play').paidWith, 'Google Play');
    expect(const Receipt(orderId: 'o', paymentId: 'p', plan: 'regular', title: 'Fee', amount: 4999, method: 'upi').paidWith, 'UPI via Razorpay');
  });
}

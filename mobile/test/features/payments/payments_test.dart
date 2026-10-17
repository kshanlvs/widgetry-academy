import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

const booking = PayPlan(id: 'booking', title: 'Book', note: '', amount: 2500, fullPrice: 4999);
const regular = PayPlan(id: 'regular', title: 'Pay in full', note: '', amount: 4999, fullPrice: 4999, recommended: true);
const order = CheckoutOrder(orderId: 'order_1', amountPaise: 250000, currency: 'INR', keyId: 'rzp_test', name: 'Widgetry Academy', description: 'Flutter in 10 Days');
const ok = GatewaySuccess(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig');

void main() {
  late MockRepo repo;
  setUp(() {
    repo = MockRepo();
    when(() => repo.createOrder(any())).thenAnswer((_) async => const Success(order));
  });

  group('PayForCourse', () {
    test('order → checkout → server confirms: part payment', () async {
      final gw = FakeGateway(ok);
      when(() => repo.verify(orderId: 'order_1', paymentId: 'pay_1', signature: 'sig')).thenAnswer((_) async => const Success('part-paid'));
      final r = await PayForCourse(repo, gw)(booking);
      expect(r.valueOrNull, const PaymentOutcome(PaymentOutcomeKind.partPaid, amount: 2500, paymentId: 'pay_1'));
      expect(gw.opened, order);
      verify(() => repo.createOrder('booking')).called(1);
    });

    test('paid in full', () async {
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Success('paid'));
      final r = await PayForCourse(repo, FakeGateway(ok))(regular);
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.paid);
    });

    test('cancelled in Checkout: nothing is confirmed', () async {
      final r = await PayForCourse(repo, FakeGateway(const GatewayCancelled()))(booking);
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.cancelled);
      verifyNever(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature')));
    });

    test('paid but the confirmation could not reach the server: pending, never an error', () async {
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Err(NetworkFailure()));
      final r = await PayForCourse(repo, FakeGateway(ok))(booking);
      expect(r.valueOrNull?.kind, PaymentOutcomeKind.pending);
    });

    test('failed payment and failed order creation are errors', () async {
      expect((await PayForCourse(repo, FakeGateway(const GatewayFailed('Declined')))(booking)).failureOrNull, const ServerFailure('Declined'));
      when(() => repo.createOrder(any())).thenAnswer((_) async => const Err(ServerFailure('Please register for the course first.', statusCode: 409)));
      final r = await PayForCourse(repo, FakeGateway(ok))(booking);
      expect(r.failureOrNull?.message, 'Please register for the course first.');
    });
  });

  group('CheckoutCubit', () {
    const options = PaymentOptions(enabled: true, course: 'Flutter in 10 Days', status: 'unpaid', plans: [booking, regular]);

    blocTest<CheckoutCubit, CheckoutState>(
      'loads options and preselects the recommended plan',
      setUp: () => when(() => repo.options()).thenAnswer((_) async => const Success(options)),
      build: () => CheckoutCubit(GetPaymentOptions(repo), PayForCourse(repo, FakeGateway(ok))),
      act: (c) => c.load(),
      verify: (c) => expect(c.state.selected, regular),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'cancelling shows a message and stays on the plans',
      setUp: () => when(() => repo.options()).thenAnswer((_) async => const Success(options)),
      build: () => CheckoutCubit(GetPaymentOptions(repo), PayForCourse(repo, FakeGateway(const GatewayCancelled()))),
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
      build: () => CheckoutCubit(GetPaymentOptions(repo), PayForCourse(repo, FakeGateway(ok))),
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
  });
}

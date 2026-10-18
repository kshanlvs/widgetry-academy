import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/interviews/data/interviews_data.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';
import 'package:widgetry_academy/features/interviews/presentation/interviews_cubits.dart';
import 'package:widgetry_academy/features/interviews/presentation/widgets.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

class MockRepo extends Mock implements InterviewsRepository {}

class FakeGateway implements PaymentGateway {
  FakeGateway(this.result);
  final GatewayResult result;
  CheckoutOrder? opened;
  @override
  Future<GatewayResult> open(CheckoutOrder order) async {
    opened = order;
    return result;
  }
}

const order = CheckoutOrder(orderId: 'order_M1', amountPaise: 79900, currency: 'INR', keyId: 'rzp_test', name: 'Widgetry Academy', description: 'Mock interview');
const request = BookRequest(slotId: 7, track: 'flutter', level: 'mid', format: 'technical');

void main() {
  setUpAll(() => registerFallbackValue(request));

  group('JSON', () {
    test('options, slots and bookings map from the API', () {
      final o = InterviewsJson.options({
        'enabled': true,
        'tracks': [{'id': 'flutter', 'name': 'Flutter'}],
        'levels': [{'id': 'fresher', 'name': 'Fresher', 'note': '0–1 years', 'price': 499}, {'id': 'mid', 'name': 'Mid level', 'price': 799}],
        'formats': [{'id': 'technical', 'name': 'Technical round', 'note': 'Core concepts'}],
        'areas': [{'id': 'coding', 'name': 'Problem solving & code'}],
        'rules': {'cancelHours': 24, 'holdMinutes': 15},
      });
      expect(o.priceFor('mid'), 799);
      expect(o.lowestPrice, 499);
      expect(o.areaName('coding'), 'Problem solving & code');

      final s = InterviewsJson.slot({'id': 3, 'startsAt': '2026-10-25T12:30:00.000Z', 'durationMin': 60, 'interviewer': {'name': 'Arjun', 'title': 'Senior Flutter Engineer', 'company': 'Swiggy', 'years': 7}});
      expect(s.startsAt, DateTime.utc(2026, 10, 25, 12, 30).toLocal());
      expect(s.interviewer!.line, 'Senior Flutter Engineer · Swiggy · 7 yrs');

      final b = InterviewsJson.booking({
        'id': 9, 'status': 'completed', 'startsAt': '2026-10-25T12:30:00.000Z', 'durationMin': 60, 'track': 'flutter', 'level': 'mid', 'format': 'technical',
        'title': 'Mock interview · Flutter · Mid level', 'amount': 799, 'viewer': 'candidate',
        'scorecard': {'scores': {'coding': 4, 'knowledge': 3}, 'overall': 3.5, 'strengths': 'a', 'improve': 'b', 'recommendation': 'hire', 'shared': true},
      });
      expect(b.scorecard!.scores['coding'], 4);
      expect(b.scorecard!.recommendationLabel, 'Hire');
      expect(b.asInterviewer, isFalse);

      final asInterviewer = InterviewsJson.booking({
        'id': 9, 'status': 'confirmed', 'startsAt': '2026-10-25T12:30:00.000Z', 'track': 'flutter', 'level': 'mid', 'format': 'technical', 'viewer': 'interviewer',
        'candidate': {'name': 'Riya', 'email': 'r@x.dev'},
        'candidateProfile': {'fullName': 'Riya Sen', 'headline': 'Flutter Developer', 'skills': ['Bloc'], 'githubUrl': 'https://github.com/riya', 'apps': [{'name': 'ShopEasy', 'url': 'https://play.google.com/x'}]},
      });
      expect(asInterviewer.asInterviewer, isTrue);
      expect(asInterviewer.candidate!.links.keys, ['GitHub', 'ShopEasy']);
    });
  });

  group('BookMockInterview', () {
    late MockRepo repo;
    setUp(() {
      repo = MockRepo();
      when(() => repo.book(any())).thenAnswer((_) async => const Success((41, order)));
      when(() => repo.cancel(any())).thenAnswer((_) async => const Success('Cancelled'));
    });

    test('hold → Razorpay → confirmed', () async {
      final gw = FakeGateway(const GatewaySuccess(paymentId: 'pay_1', orderId: 'order_M1', signature: 'sig'));
      when(() => repo.verify(orderId: 'order_M1', paymentId: 'pay_1', signature: 'sig')).thenAnswer((_) async => const Success('confirmed'));
      final r = await BookMockInterview(repo, gw)(request);
      expect(r.valueOrNull, const BookingOutcome(BookingOutcomeKind.confirmed, bookingId: 41, paymentId: 'pay_1'));
      expect(gw.opened, order);
    });

    test('slot lost after a late payment is reported, not hidden', () async {
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Success('refund_due'));
      final r = await BookMockInterview(repo, FakeGateway(const GatewaySuccess(paymentId: 'p', orderId: 'order_M1', signature: 's')))(request);
      expect(r.valueOrNull?.kind, BookingOutcomeKind.slotLost);
    });

    test('closing Checkout releases the held slot at once', () async {
      final r = await BookMockInterview(repo, FakeGateway(const GatewayCancelled()))(request);
      expect(r.valueOrNull?.kind, BookingOutcomeKind.cancelled);
      verify(() => repo.cancel(41)).called(1);
    });

    test('paid but confirmation failed is pending; a taken slot is an error', () async {
      when(() => repo.verify(orderId: any(named: 'orderId'), paymentId: any(named: 'paymentId'), signature: any(named: 'signature'))).thenAnswer((_) async => const Err(NetworkFailure()));
      expect((await BookMockInterview(repo, FakeGateway(const GatewaySuccess(paymentId: 'p', orderId: '', signature: 's')))(request)).valueOrNull?.kind, BookingOutcomeKind.pending);
      when(() => repo.book(any())).thenAnswer((_) async => const Err(ServerFailure('Someone just booked this slot. Please pick another.', statusCode: 409)));
      expect((await BookMockInterview(repo, FakeGateway(const GatewayCancelled()))(request)).failureOrNull?.message, contains('slot'));
    });
  });

  test('slots are grouped by day, in order', () {
    final d1 = DateTime(2026, 10, 25, 18), d2 = DateTime(2026, 10, 24, 19);
    final s = BookState(slots: [
      InterviewSlot(id: 1, startsAt: d1, durationMin: 60),
      InterviewSlot(id: 2, startsAt: d2, durationMin: 60),
      InterviewSlot(id: 3, startsAt: d1.add(const Duration(hours: 1)), durationMin: 45),
    ]);
    expect(s.days, [DateTime(2026, 10, 24), DateTime(2026, 10, 25)]);
    expect(s.slotsOn(DateTime(2026, 10, 25)).map((x) => x.id), [1, 3]);
  });

  test('join opens 10 minutes before and labels read naturally', () {
    final start = DateTime(2026, 10, 25, 18);
    final b = MockBooking(id: 1, status: 'confirmed', startsAt: start, durationMin: 60, track: 'flutter', level: 'mid', format: 'technical', title: 't', meetingLink: 'https://meet.google.com/x');
    expect(b.canJoin(start.subtract(const Duration(minutes: 11))), isFalse);
    expect(b.canJoin(start.subtract(const Duration(minutes: 9))), isTrue);
    expect(dayLabel(DateTime(2026, 10, 25, 9), now: DateTime(2026, 10, 24, 22)), 'Tomorrow');
    expect(startsIn(start, now: start.subtract(const Duration(hours: 3))), 'in 3 hours');
  });
}

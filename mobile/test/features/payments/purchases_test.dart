import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/payments/data/payments_data.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

void main() {
  // Same shape as GET /api/me/purchases
  final json = <String, dynamic>{
    'courses': [
      {'kind': 'flagship', 'slug': 'flutter-in-10-days', 'title': 'Flutter in 10 Days', 'status': 'enrolled', 'amountPaid': 4999, 'appPath': '/courses'},
      {'kind': 'short_course', 'slug': 'bloc-crash-course', 'title': 'Bloc Crash Course', 'status': 'enrolled', 'amountPaid': 799, 'startsAt': '2026-10-24T05:30:00.000Z', 'meetingLink': 'https://meet.google.com/abc', 'appPath': '/short-courses/bloc-crash-course'},
      {'kind': 'short_course', 'slug': 'old-course', 'title': 'Old Course', 'status': 'refunded', 'amountPaid': 0},
    ],
    'orders': [
      {'id': 'mock_interview-3', 'kind': 'mock_interview', 'title': 'Mock interview', 'item': 'Flutter · Mid level · 45 min', 'amount': 999, 'status': 'refund_pending', 'orderId': 'order_m', 'paymentId': 'pay_m', 'method': 'upi', 'paidAt': '2026-10-22T10:00:00.000Z', 'appPath': '/interviews/3'},
      {'id': 'short_course-12', 'kind': 'short_course', 'title': 'Bloc Crash Course', 'item': 'Course fee (early bird)', 'amount': 799, 'status': 'paid', 'orderId': 'order_b', 'paymentId': null, 'method': 'card', 'paidAt': '2026-10-21T10:00:00.000Z'},
      {'id': 'new_kind-1', 'kind': 'workshop_bundle', 'title': 'Something new', 'item': 'Bundle', 'amount': 1500, 'status': 'paid'},
    ],
  };

  test('reads every course and order, including kinds the app does not know yet', () {
    final p = PaymentsRepositoryImpl.purchasesFromJson(json);
    expect(p.courses.map((c) => c.slug), ['flutter-in-10-days', 'bloc-crash-course', 'old-course']);
    expect(p.orders.map((o) => o.kind), ['mock_interview', 'short_course', 'workshop_bundle']);
    expect(p.orders.first.isPaid, isFalse);
    expect(p.orders.first.paidAt, isNotNull);
    expect(p.courses[1].meetingLink, 'https://meet.google.com/abc');
  });

  test('only paid-for short courses show in the Courses tab', () {
    final p = PaymentsRepositoryImpl.purchasesFromJson(json);
    expect(p.activeShortCourses.map((c) => c.slug), ['bloc-crash-course']);
    expect(CoursesState(purchases: p).myShortCourses.single.title, 'Bloc Crash Course');
    expect(const CoursesState().myShortCourses, isEmpty);
  });

  test('a receipt always has an id to quote', () {
    final p = PaymentsRepositoryImpl.purchasesFromJson(json);
    expect(p.orders[0].reference, 'pay_m');
    expect(p.orders[1].reference, 'order_b', reason: 'falls back to the order id');
    expect(p.orders[2].reference, 'new_kind-1');
    expect(p.orders[1].asReceipt.paidWith, 'Card via Razorpay');
  });

  test('signing out clears purchases', () {
    final s = CoursesState(signedIn: true, purchases: PaymentsRepositoryImpl.purchasesFromJson(json));
    expect(s.copyWith(signedIn: false, clearRegistration: true, clearPurchases: true).purchases, isNull);
    expect(s.copyWith(loading: false).purchases, isNotNull);
  });
}

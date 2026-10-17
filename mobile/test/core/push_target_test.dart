import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/core/notifications/push_service.dart';

void main() {
  test('a single new job opens that job', () {
    expect(PushService.targetFor({'type': 'job', 'jobId': 'k3x9', 'link': 'https://widgetryacademy.in/job.html?id=k3x9'}).route, '/jobs/k3x9');
  });

  test('a batch of new jobs opens that category tab', () {
    expect(PushService.targetFor({'type': 'jobs', 'category': 'android'}).route, '/jobs?cat=android');
  });

  test('verification opens the profile', () => expect(PushService.targetFor({'type': 'profile'}).route, '/profile'));

  test('payment confirmation opens receipts', () => expect(PushService.targetFor({'type': 'payment', 'link': 'https://widgetryacademy.in/#fees'}).route, '/payments'));

  test('academy links map to app screens', () {
    expect(PushService.targetFor({'type': 'announcement', 'link': 'https://widgetryacademy.in/#courses'}).route, '/courses');
    expect(PushService.targetFor({'type': 'announcement', 'link': 'https://widgetryacademy.in/blog/flutter-developer-salary-india.html'}).route, '/blog');
  });

  test('other https links open in the browser; anything else opens jobs', () {
    final t = PushService.targetFor({'type': 'myjobs', 'link': 'https://widgetryacademy.in/post-job.html'});
    expect(t.route, isNull);
    expect(t.url, 'https://widgetryacademy.in/post-job.html');
    expect(PushService.targetFor({}).route, '/jobs');
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/exceptions.dart';
import 'package:widgetry_academy/core/utils/validators.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';

/// Reads the same Firestore data as widgetryacademy.in: courses, settings/batch and registrations/{uid}.
abstract interface class CoursesDataSource {
  Future<List<Course>> courses();
  Future<BatchInfo> batch();
  Future<Registration?> myRegistration();
  Future<Registration> register(Registration r);
}

@LazySingleton(as: CoursesDataSource)
class CoursesFirestoreDataSource implements CoursesDataSource {
  CoursesFirestoreDataSource(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Shown when no "Flutter in 10 Days" card has been saved in admin (same as the website).
  static const builtInFlagship = Course(
    id: 'flutter-in-10-days',
    title: 'Flutter in 10 Days',
    tagline: 'Build and publish your own Android app with Flutter, live over 5 weekends.',
    meta: 'Live online · 10 sessions · 2 hours each',
    tags: ['Flutter', 'Dart', 'Firebase', 'Real app'],
    outcome: 'An installable Android app, a GitHub portfolio and a certificate.',
    status: 'open',
    flagship: true,
    badge: 'Flagship course',
    showBatch: true,
    order: 0,
  );

  @override
  Future<List<Course>> courses() => _run(() async {
        final snap = await _db.collection('courses').get();
        final list = snap.docs
            .map((d) => _course(d.id, d.data()))
            .whereType<Course>()
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        final hasFlutter = list.any((c) => c.title.trim().toLowerCase() == 'flutter in 10 days');
        return [if (!hasFlutter) builtInFlagship, ...list];
      });

  Course? _course(String id, Map<String, dynamic> m) {
    if (m['showOnSite'] != true || m['status'] == 'hidden' || (m['title'] ?? '').toString().isEmpty) return null;
    int? n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    String? s(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
    return Course(
      id: id,
      title: '${m['title']}',
      tagline: s(m['tagline']),
      meta: s(m['meta']),
      tags: (m['tags'] as List? ?? const []).map((e) => '$e').toList(),
      steps: (m['steps'] as List? ?? const []).whereType<Map>().map((e) => CourseStep('${e['t'] ?? ''}', '${e['d'] ?? ''}')).where((e) => e.title.isNotEmpty).toList(),
      outcome: s(m['outcome']),
      price: n(m['price']),
      mrp: n(m['mrp']),
      priceNote: s(m['priceNote']),
      mentorName: s(m['mentorName']),
      mentorLine: s(m['mentorLine']),
      status: '${m['status'] ?? 'open'}',
      flagship: m['flagship'] == true,
      badge: s(m['badge']),
      ctaLink: s(m['ctaLink']),
      showBatch: m['showBatch'] == true,
      order: n(m['order']) ?? 99,
    );
  }

  @override
  Future<BatchInfo> batch() => _run(() async {
        final d = (await _db.collection('settings').doc('batch').get()).data() ?? const {};
        String? s(String k) => d[k] == null || '${d[k]}'.trim().isEmpty ? null : '${d[k]}'.trim();
        return BatchInfo(name: s('name'), startDate: s('startDate'), days: s('days'), time: s('time'), mode: s('mode'), demo: s('demo'), seatsLeft: d['seatsLeft'] is num ? (d['seatsLeft'] as num).toInt() : null);
      });

  @override
  Future<Registration?> myRegistration() => _run(() async {
        final u = _auth.currentUser;
        if (u == null) return null;
        final d = (await _db.collection('registrations').doc(u.uid).get()).data();
        return d == null ? null : _registration(d);
      });

  Registration _registration(Map<String, dynamic> d) => Registration(
        name: '${d['name'] ?? ''}',
        email: '${d['email'] ?? ''}',
        phone: '${d['phone'] ?? ''}',
        level: '${d['level'] ?? ''}',
        experience: '${d['experience'] ?? ''}',
        course: '${d['batch'] ?? ''}',
        payStatus: '${d['payStatus'] ?? 'pending'}',
        status: '${d['status'] ?? 'registered'}',
        amountPaid: (d['amountPaid'] as num?)?.round() ?? 0,
        plan: d['plan'] as String?,
      );

  @override
  Future<Registration> register(Registration r) => _run(() async {
        final u = _auth.currentUser;
        if (u == null || u.email == null) throw const AuthException('Please sign in first.');
        // Exactly the fields and starting values the Firestore rules allow
        final rec = <String, dynamic>{
          'name': r.name.trim().substring(0, r.name.trim().length.clamp(0, 99)),
          'email': u.email,
          'phone': '+91${Validators.normalizeIndianMobile(r.phone)}',
          'level': r.level,
          'experience': r.experience,
          'batch': r.course,
          'status': 'registered',
          'emailVerified': false,
          'phoneVerified': false,
          'amountPaid': 0,
          'paymentId': null,
          'payStatus': 'pending',
          'plan': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _db.collection('registrations').doc(u.uid).set(rec);
        return Registration(name: rec['name'] as String, email: u.email!, phone: rec['phone'] as String, level: r.level, experience: r.experience, course: r.course);
      });

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') throw const NetworkException();
      if (e.code == 'permission-denied') throw const ServerException("You're already registered, or this action isn't allowed.", statusCode: 403);
      throw ServerException(e.message ?? 'Something went wrong. Please try again.');
    }
  }
}

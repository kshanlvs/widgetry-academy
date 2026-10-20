import 'package:equatable/equatable.dart';

class CourseStep extends Equatable {
  const CourseStep(this.title, [this.detail = '']);
  final String title;
  final String detail;
  @override
  List<Object?> get props => [title, detail];
}

/// A course card, edited in Admin → Courses on the website.
class Course extends Equatable {
  const Course({
    required this.id,
    required this.title,
    this.tagline,
    this.meta,
    this.tags = const [],
    this.steps = const [],
    this.outcome,
    this.price,
    this.mrp,
    this.priceNote,
    this.mentorName,
    this.mentorLine,
    this.status = 'open',
    this.flagship = false,
    this.badge,
    this.ctaLink,
    this.brochure,
    this.showBatch = false,
    this.order = 99,
    this.startDate,
    this.live,
  });

  final String id;
  final String title;
  final String? tagline;
  final String? meta;
  final List<String> tags;
  final List<CourseStep> steps;
  final String? outcome;
  final int? price;
  final int? mrp;
  final String? priceNote;
  final String? mentorName;
  final String? mentorLine;
  /// "open" or "soon"
  final String status;
  final bool flagship;
  final String? badge;
  /// Payment page (e.g. a Razorpay link) or a page on the website
  final String? ctaLink;
  /// Syllabus PDF: a path on the website ("brochures/bloc-crash-course.pdf") or an https link.
  final String? brochure;
  final bool showBatch;
  final int order;
  /// "Starts on" from Admin → Courses, as typed (e.g. "Sat 24 Oct 2026"). Not used for short courses.
  final String? startDate;
  /// Dates and enrolment of the short course this card opens, from Admin → Short courses.
  final CourseLive? live;

  bool get isOpen => status != 'soon';

  /// The short course page this card opens ("bloc-crash-course.html" → "bloc-crash-course"), if any.
  String? get shortSlug => shortSlugOf(ctaLink);
  static String? shortSlugOf(String? link) => RegExp(r'^([a-z0-9][a-z0-9-]*-course)\.html$').firstMatch((link ?? '').trim())?.group(1);

  /// The same rule as the website's course cards: a short course shows its own dates,
  /// other courses their "Starts on" date, and only then the Next batch tab (Flutter in 10 Days).
  bool get usesBatch => (showBatch || flagship) && shortSlug == null && (startDate ?? '').isEmpty;
  String? get dateLine => live?.line ?? (shortSlug == null && (startDate ?? '').isNotEmpty ? 'Starts $startDate' : null);
  /// False while a short course's enrolment isn't open (dates coming soon, full, closed).
  bool get enrolling => live?.open ?? true;

  Course withLive(CourseLive? l, {int? price, int? mrp, String? priceNote}) => Course(
        id: id, title: title, tagline: tagline, meta: meta, tags: tags, steps: steps, outcome: outcome,
        price: l == null ? this.price : (price ?? this.price), mrp: l == null ? this.mrp : mrp, priceNote: l == null ? this.priceNote : priceNote,
        mentorName: mentorName, mentorLine: mentorLine, status: status, flagship: flagship, badge: badge, ctaLink: ctaLink,
        brochure: brochure, showBatch: showBatch, order: order, startDate: startDate, live: l,
      );

  /// Brochures for courses saved before the "brochure" field existed (matched by title, like the website).
  static const _knownBrochures = {
    'flutter in 10 days': 'Widgetry-Academy-Flutter-Brochure.pdf',
    'bloc crash course': 'brochures/bloc-crash-course.pdf',
    'bloc state management crash course': 'brochures/bloc-crash-course.pdf',
    'flutter, bloc & clean architecture': 'brochures/flutter-clean-architecture-course.pdf',
    'food delivery app with flutter & firebase': 'brochures/food-delivery-app-course.pdf',
  };

  /// The syllabus PDF as a full link, or null if this course has none.
  String? brochureUrl(String siteUrl) {
    final key = title.toLowerCase().replaceAll(RegExp(r'\s*&\s*'), ' & ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final b = (brochure ?? '').trim().isNotEmpty ? brochure!.trim() : _knownBrochures[key];
    if (b == null) return null;
    if (b.startsWith('https://')) return b;
    return RegExp(r'^[\w./-]+\.pdf$', caseSensitive: false).hasMatch(b) ? '$siteUrl/$b' : null;
  }

  @override
  List<Object?> get props => [id, title, tagline, meta, tags, steps, outcome, price, mrp, priceNote, mentorName, mentorLine, status, flagship, badge, ctaLink, brochure, showBatch, order, startDate, live];
}

/// What a short course's card says: "Starts Sat 8 Nov…" and whether people can pay now.
class CourseLive extends Equatable {
  const CourseLive({required this.line, required this.open, this.tag});
  final String line;
  final bool open;
  /// Replaces "Enrolling" on the card when not open, e.g. "Dates soon", "Batch full".
  final String? tag;
  @override
  List<Object?> get props => [line, open, tag];
}

/// Next batch details, edited in Admin → Next batch.
class BatchInfo extends Equatable {
  const BatchInfo({this.name, this.startDate, this.days, this.time, this.mode, this.demo, this.seatsLeft});
  final String? name;
  final String? startDate;
  final String? days;
  final String? time;
  final String? mode;
  final String? demo;
  final int? seatsLeft;
  bool get isEmpty => startDate == null && days == null && time == null;
  @override
  List<Object?> get props => [name, startDate, days, time, mode, demo, seatsLeft];
}

class Registration extends Equatable {
  const Registration({required this.name, required this.email, required this.phone, required this.level, required this.experience, required this.course, this.payStatus = 'pending', this.status = 'registered', this.amountPaid = 0, this.plan});
  final String name;
  final String email;
  final String phone;
  final String level;
  final String experience;
  /// Course of interest (stored as "batch" on the website)
  final String course;
  /// "pending" (or "unpaid"), "part-paid", "paid", "refunded", "cancelled" (same values as Admin → Registrations).
  final String payStatus;
  final String status;
  /// Rupees paid so far.
  final int amountPaid;
  /// "early-bird", "regular" or "booking", once chosen.
  final String? plan;

  bool get isPaid => payStatus == 'paid' || payStatus == 'full' || payStatus == 'completed';
  bool get isPartPaid => !isPaid && (payStatus == 'part-paid' || amountPaid > 0);
  bool get isClosed => payStatus == 'refunded' || payStatus == 'cancelled';

  @override
  List<Object?> get props => [name, email, phone, level, experience, course, payStatus, status, amountPaid, plan];
}

/// Options shared with the website's registration form.
abstract final class RegistrationOptions {
  static const levels = ['Class 10', 'Class 11', 'Class 12', 'Undergraduate (1st–2nd year)', 'Undergraduate (3rd–4th year)', 'Graduate', 'Working professional'];
  static const experience = ['None, complete beginner', 'A little (school/college)', 'Comfortable with one language'];
}

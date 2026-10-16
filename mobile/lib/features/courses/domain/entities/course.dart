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
    this.showBatch = false,
    this.order = 99,
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
  final bool showBatch;
  final int order;

  bool get isOpen => status != 'soon';

  @override
  List<Object?> get props => [id, title, tagline, meta, tags, steps, outcome, price, mrp, priceNote, mentorName, mentorLine, status, flagship, badge, ctaLink, showBatch, order];
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
  const Registration({required this.name, required this.email, required this.phone, required this.level, required this.experience, required this.course, this.payStatus = 'pending', this.status = 'registered'});
  final String name;
  final String email;
  final String phone;
  final String level;
  final String experience;
  /// Course of interest (stored as "batch" on the website)
  final String course;
  final String payStatus;
  final String status;

  bool get isPaid => payStatus == 'paid' || payStatus == 'full' || payStatus == 'part';

  @override
  List<Object?> get props => [name, email, phone, level, experience, course, payStatus, status];
}

/// Options shared with the website's registration form.
abstract final class RegistrationOptions {
  static const levels = ['Class 10', 'Class 11', 'Class 12', 'Undergraduate (1st–2nd year)', 'Undergraduate (3rd–4th year)', 'Graduate', 'Working professional'];
  static const experience = ['None, complete beginner', 'A little (school/college)', 'Comfortable with one language'];
}

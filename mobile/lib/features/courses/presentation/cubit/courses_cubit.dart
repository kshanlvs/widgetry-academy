import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';
import 'package:widgetry_academy/features/auth/domain/usecases/auth_usecases.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/domain/usecases/courses_usecases.dart';
import 'package:widgetry_academy/features/workshops/domain/workshops.dart';

class CoursesState extends Equatable {
  const CoursesState({this.loading = true, this.courses = const [], this.batch = const BatchInfo(), this.registration, this.signedIn = false, this.error, this.submitting = false, this.message});
  final bool loading;
  final List<Course> courses;
  final BatchInfo batch;
  final Registration? registration;
  final bool signedIn;
  final String? error;
  final bool submitting;
  final String? message;

  Course? byId(String id) => courses.where((c) => c.id == id).firstOrNull;

  /// The course this student registered for (registrations store its title), if any.
  Course? get myCourse {
    final r = registration;
    if (r == null || r.isClosed) return null;
    return courses.where((c) => c.title == r.course).firstOrNull ?? courses.where((c) => c.flagship).firstOrNull ?? courses.where((c) => c.isOpen).firstOrNull;
  }

  CoursesState copyWith({bool? loading, List<Course>? courses, BatchInfo? batch, Registration? registration, bool clearRegistration = false, bool? signedIn, String? error, bool? submitting, String? message}) => CoursesState(
        loading: loading ?? this.loading,
        courses: courses ?? this.courses,
        batch: batch ?? this.batch,
        registration: clearRegistration ? null : (registration ?? this.registration),
        signedIn: signedIn ?? this.signedIn,
        error: error,
        submitting: submitting ?? this.submitting,
        message: message,
      );

  @override
  List<Object?> get props => [loading, courses, batch, registration, signedIn, error, submitting, message];
}

/// Courses, next batch and the user's registration. App-wide so the tab, detail and registration screens agree.
@lazySingleton
class CoursesCubit extends Cubit<CoursesState> {
  CoursesCubit(WatchAuthState watchAuth, this._courses, this._batch, this._mine, this._register, this._shortCourses) : super(const CoursesState()) {
    _sub = watchAuth(const NoParams()).listen((u) {
      final signedIn = u != null;
      if (signedIn == state.signedIn && !state.loading) return;
      emit(state.copyWith(signedIn: signedIn, clearRegistration: !signedIn));
      if (signedIn) _loadRegistration();
    });
    load();
  }

  final GetCourses _courses;
  final GetNextBatch _batch;
  final GetMyRegistration _mine;
  final RegisterForCourse _register;
  final WorkshopsRepository _shortCourses;
  StreamSubscription<AppUser?>? _sub;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final results = await Future.wait([_courses(const NoParams()), _batch(const NoParams()), _shortCourses.list()]);
    final shorts = results[2].valueOrNull as List<Workshop>?;
    final courses = (results[0].valueOrNull as List<Course>?)?.map((c) => withShortCourse(c, shorts)).toList();
    final batch = results[1].valueOrNull as BatchInfo?;
    emit(state.copyWith(loading: false, courses: courses ?? state.courses, batch: batch ?? state.batch, error: courses == null ? results[0].failureOrNull?.message : null));
    if (state.signedIn) await _loadRegistration();
  }

  Future<void> _loadRegistration() async {
    final r = await _mine(const NoParams());
    final reg = r.valueOrNull;
    emit(state.copyWith(registration: reg, clearRegistration: reg == null));
  }

  Future<bool> register(Registration r) async {
    emit(state.copyWith(submitting: true));
    final res = await _register(r);
    return res.fold((f) {
      emit(state.copyWith(submitting: false, error: f.message));
      return false;
    }, (reg) {
      emit(state.copyWith(submitting: false, registration: reg, message: "You're registered! We'll send batch details on WhatsApp."));
      return true;
    });
  }

  /// A card that opens a short course page shows that course's dates, enrolment and price, so the card and the
  /// page always agree (same rule as the website). [shorts] is null when they couldn't be loaded: the card stays as saved.
  static Course withShortCourse(Course c, List<Workshop>? shorts) {
    final slug = c.shortSlug;
    if (slug == null || shorts == null || !c.isOpen) return c;
    final w = shorts.where((x) => x.slug == slug).firstOrNull;
    if (w == null) return c.withLive(const CourseLive(line: 'Next batch dates coming soon', open: false, tag: 'Dates soon'), price: c.price, mrp: c.mrp, priceNote: c.priceNote);
    final dates = w.schedule ?? (w.startsAt == null ? null : 'Starts ${Fmt.date(w.startsAt!)}');
    final note = w.earlyPrice == null ? null : 'Early-bird price${w.earlySeatsLeft == null ? '' : ' · ${w.earlySeatsLeft} seat${w.earlySeatsLeft == 1 ? '' : 's'} left'}';
    final live = w.isOpen
        ? CourseLive(line: dates ?? 'Dates coming soon', open: true)
        : w.isFull
            ? const CourseLive(line: 'This batch is full', open: false, tag: 'Batch full')
            : CourseLive(line: dates == null ? 'Dates coming soon' : '$dates · enrolment opens soon', open: false, tag: 'Dates soon');
    return c.withLive(live, price: w.payNow, mrp: w.earlyPrice == null ? null : w.price, priceNote: note);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

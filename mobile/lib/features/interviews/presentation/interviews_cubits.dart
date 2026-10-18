import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/interviews/domain/interviews.dart';

// ---------- Landing: what it is, prices, my bookings ----------

class InterviewsState extends Equatable {
  const InterviewsState({this.loading = true, this.options, this.bookings = const [], this.isInterviewer = false, this.error});
  final bool loading;
  final MockOptions? options;
  final List<MockBooking> bookings;
  final bool isInterviewer;
  final String? error;

  List<MockBooking> get upcoming => bookings.where((b) => b.status == 'created' || b.isUpcoming).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  List<MockBooking> get past => bookings.where((b) => !upcoming.contains(b)).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  @override
  List<Object?> get props => [loading, options, bookings, isInterviewer, error];
}

@injectable
class InterviewsCubit extends Cubit<InterviewsState> {
  InterviewsCubit(this._repo, this._auth) : super(const InterviewsState());
  final InterviewsRepository _repo;
  final AuthCubit _auth;

  Future<void> load() async {
    final signedIn = _auth.state.isSignedIn;
    final results = await Future.wait([
      _repo.options(),
      if (signedIn) _repo.mine(),
      if (signedIn) _repo.dashboard(),
    ]);
    if (isClosed) return;
    final o = results[0] as Result<MockOptions>;
    final mine = signedIn ? results[1] as Result<List<MockBooking>> : const Success(<MockBooking>[]);
    final dash = signedIn ? results[2] as Result<InterviewerDashboard?> : const Success<InterviewerDashboard?>(null);
    emit(InterviewsState(
      loading: false,
      options: o.valueOrNull ?? state.options,
      bookings: mine.valueOrNull ?? state.bookings,
      isInterviewer: dash.valueOrNull != null,
      error: o.failureOrNull?.message,
    ));
  }
}

// ---------- Booking: choose → pick a slot → confirm and pay ----------

enum BookStep { choose, slot, confirm }

class BookState extends Equatable {
  const BookState({
    this.loading = true,
    this.options,
    this.step = BookStep.choose,
    this.track = 'flutter',
    this.level,
    this.format = 'technical',
    this.slotsLoading = false,
    this.slots = const [],
    this.day,
    this.slot,
    this.focus = '',
    this.shareProfile = true,
    this.paying = false,
    this.outcome,
    this.error,
    this.message,
  });
  final bool loading;
  final MockOptions? options;
  final BookStep step;
  final String track;
  final String? level;
  final String format;
  final bool slotsLoading;
  final List<InterviewSlot> slots;
  /// Selected day (date only, local).
  final DateTime? day;
  final InterviewSlot? slot;
  final String focus;
  final bool shareProfile;
  final bool paying;
  final BookingOutcome? outcome;
  final String? error;
  final String? message;

  int? get price => level == null ? null : options?.priceFor(level!);

  /// Days that have at least one slot, in order.
  List<DateTime> get days {
    final seen = <DateTime>{};
    for (final s in slots) {
      seen.add(DateTime(s.startsAt.year, s.startsAt.month, s.startsAt.day));
    }
    return seen.toList()..sort();
  }

  List<InterviewSlot> slotsOn(DateTime d) => slots.where((s) => s.startsAt.year == d.year && s.startsAt.month == d.month && s.startsAt.day == d.day).toList();

  BookState copyWith({
    bool? loading,
    MockOptions? options,
    BookStep? step,
    String? track,
    String? level,
    String? format,
    bool? slotsLoading,
    List<InterviewSlot>? slots,
    DateTime? day,
    InterviewSlot? slot,
    bool clearSlot = false,
    String? focus,
    bool? shareProfile,
    bool? paying,
    BookingOutcome? outcome,
    String? error,
    String? message,
  }) =>
      BookState(
        loading: loading ?? this.loading,
        options: options ?? this.options,
        step: step ?? this.step,
        track: track ?? this.track,
        level: level ?? this.level,
        format: format ?? this.format,
        slotsLoading: slotsLoading ?? this.slotsLoading,
        slots: slots ?? this.slots,
        day: clearSlot ? (day ?? this.day) : (day ?? this.day),
        slot: clearSlot ? null : (slot ?? this.slot),
        focus: focus ?? this.focus,
        shareProfile: shareProfile ?? this.shareProfile,
        paying: paying ?? this.paying,
        outcome: outcome ?? this.outcome,
        error: error,
        message: message,
      );

  @override
  List<Object?> get props => [loading, options, step, track, level, format, slotsLoading, slots, day, slot, focus, shareProfile, paying, outcome, error, message];
}

@injectable
class BookInterviewCubit extends Cubit<BookState> {
  BookInterviewCubit(this._repo, this._book) : super(const BookState());
  final InterviewsRepository _repo;
  final BookMockInterview _book;

  Future<void> load({String? track, String? level}) async {
    final r = await _repo.options();
    if (isClosed) return;
    r.fold(
      (f) => emit(BookState(loading: false, error: f.message)),
      (o) => emit(BookState(
        loading: false,
        options: o,
        track: track ?? (o.tracks.isNotEmpty ? o.tracks.first.id : 'flutter'),
        level: level,
        format: o.formats.isNotEmpty ? o.formats.first.id : 'technical',
      )),
    );
  }

  void setTrack(String t) => emit(state.copyWith(track: t));
  void setLevel(String l) => emit(state.copyWith(level: l));
  void setFormat(String f) => emit(state.copyWith(format: f));
  void setFocus(String f) => emit(state.copyWith(focus: f));
  void setShareProfile(bool v) => emit(state.copyWith(shareProfile: v));

  Future<void> toSlots() async {
    if (state.level == null) {
      emit(state.copyWith(message: 'Choose your level first.'));
      return;
    }
    emit(state.copyWith(step: BookStep.slot, slotsLoading: true, clearSlot: true));
    await refreshSlots();
  }

  Future<void> refreshSlots() async {
    final r = await _repo.slots(state.track);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(slotsLoading: false, message: f.message)),
      (slots) {
        final days = BookState(slots: slots).days;
        final keep = state.day != null && days.contains(state.day) ? state.day : (days.isEmpty ? null : days.first);
        emit(BookState(
          loading: false,
          options: state.options,
          step: state.step,
          track: state.track,
          level: state.level,
          format: state.format,
          slots: slots,
          day: keep,
          focus: state.focus,
          shareProfile: state.shareProfile,
        ));
      },
    );
  }

  void pickDay(DateTime d) => emit(state.copyWith(day: d, clearSlot: true));
  void pickSlot(InterviewSlot s) => emit(state.copyWith(slot: s, step: BookStep.confirm));

  void back() {
    if (state.paying) return;
    emit(state.copyWith(step: state.step == BookStep.confirm ? BookStep.slot : BookStep.choose));
  }

  Future<void> pay() async {
    final s = state.slot, level = state.level;
    if (s == null || level == null || state.paying) return;
    emit(state.copyWith(paying: true));
    final r = await _book(BookRequest(slotId: s.id, track: state.track, level: level, format: state.format, focus: state.focus, shareProfile: state.shareProfile));
    if (isClosed) return;
    r.fold(
      (f) {
        emit(state.copyWith(paying: false, message: f.message));
        // The slot may have just been taken: show what's still open
        if (f.message.contains('slot')) {
          emit(state.copyWith(step: BookStep.slot, clearSlot: true));
          refreshSlots();
        }
      },
      (o) => o.kind == BookingOutcomeKind.cancelled
          ? emit(state.copyWith(paying: false, message: 'Payment cancelled. No money was taken.'))
          : emit(state.copyWith(paying: false, outcome: o)),
    );
  }
}

// ---------- One booking (candidate or interviewer) ----------

class BookingState extends Equatable {
  const BookingState({this.loading = true, this.booking, this.options, this.busy = false, this.error, this.message});
  final bool loading;
  final MockBooking? booking;
  final MockOptions? options;
  final bool busy;
  final String? error;
  final String? message;

  BookingState copyWith({bool? loading, MockBooking? booking, MockOptions? options, bool? busy, String? error, String? message}) =>
      BookingState(loading: loading ?? this.loading, booking: booking ?? this.booking, options: options ?? this.options, busy: busy ?? this.busy, error: error, message: message);

  @override
  List<Object?> get props => [loading, booking, options, busy, error, message];
}

@injectable
class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this._repo) : super(const BookingState());
  final InterviewsRepository _repo;
  int? _id;

  Future<void> load(int id) async {
    _id = id;
    final rs = await Future.wait([_repo.booking(id), _repo.options()]);
    if (isClosed) return;
    final b = rs[0] as Result<MockBooking>, o = rs[1] as Result<MockOptions>;
    b.fold(
      (f) => emit(BookingState(loading: false, error: f.message, options: o.valueOrNull)),
      (v) => emit(BookingState(loading: false, booking: v, options: o.valueOrNull)),
    );
  }

  Future<void> refresh() async {
    if (_id != null) await load(_id!);
  }

  Future<void> cancel() async {
    final b = state.booking;
    if (b == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final r = await _repo.cancel(b.id);
    if (isClosed) return;
    await r.fold((f) async => emit(state.copyWith(busy: false, message: f.message)), (msg) async {
      emit(state.copyWith(busy: false, message: msg));
      await refresh();
    });
  }

  Future<void> share(bool shared) async {
    final b = state.booking;
    final card = b?.scorecard;
    if (b == null || card == null) return;
    emit(state.copyWith(booking: b.withScorecard(card.copyWith(shared: shared))));
    final r = await _repo.share(b.id, shared);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(booking: b, message: f.message)),
      (_) => emit(state.copyWith(message: shared ? 'Shown on your profile' : 'Removed from your profile')),
    );
  }

  Future<void> markNoShow() async {
    final b = state.booking;
    if (b == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final r = await _repo.markNoShow(b.id);
    if (isClosed) return;
    await r.fold((f) async => emit(state.copyWith(busy: false, message: f.message)), (_) async {
      emit(state.copyWith(busy: false, message: 'Marked as no-show'));
      await refresh();
    });
  }

  Future<bool> sendScorecard(ScorecardInput s) async {
    final b = state.booking;
    if (b == null || state.busy) return false;
    emit(state.copyWith(busy: true));
    final r = await _repo.sendScorecard(b.id, s);
    if (isClosed) return false;
    return r.fold((f) {
      emit(state.copyWith(busy: false, message: f.message));
      return false;
    }, (overall) {
      emit(state.copyWith(busy: false, message: 'Feedback sent · overall ${overall.toStringAsFixed(1)}'));
      refresh();
      return true;
    });
  }
}

// ---------- Interviewer dashboard ----------

class InterviewerState extends Equatable {
  const InterviewerState({this.loading = true, this.dashboard, this.options, this.busy = false, this.error, this.message});
  final bool loading;
  final InterviewerDashboard? dashboard;
  final MockOptions? options;
  final bool busy;
  final String? error;
  final String? message;

  InterviewerState copyWith({bool? loading, InterviewerDashboard? dashboard, MockOptions? options, bool? busy, String? error, String? message}) =>
      InterviewerState(loading: loading ?? this.loading, dashboard: dashboard ?? this.dashboard, options: options ?? this.options, busy: busy ?? this.busy, error: error, message: message);

  @override
  List<Object?> get props => [loading, dashboard, options, busy, error, message];
}

@injectable
class InterviewerCubit extends Cubit<InterviewerState> {
  InterviewerCubit(this._repo) : super(const InterviewerState());
  final InterviewsRepository _repo;

  Future<void> load() async {
    final rs = await Future.wait([_repo.dashboard(), _repo.options()]);
    if (isClosed) return;
    final d = rs[0] as Result<InterviewerDashboard?>, o = rs[1] as Result<MockOptions>;
    d.fold(
      (f) => emit(InterviewerState(loading: false, error: f.message, options: o.valueOrNull)),
      (v) => emit(InterviewerState(loading: false, dashboard: v, options: o.valueOrNull, error: v == null ? 'notInterviewer' : null)),
    );
  }

  Future<bool> saveProfile(InterviewerProfile p) async {
    emit(state.copyWith(busy: true));
    final r = await _repo.saveInterviewer(p);
    if (isClosed) return false;
    return r.fold((f) {
      emit(state.copyWith(busy: false, message: f.message));
      return false;
    }, (me) {
      final d = state.dashboard;
      emit(state.copyWith(busy: false, dashboard: d == null ? null : InterviewerDashboard(me: me, slots: d.slots, bookings: d.bookings), message: 'Profile saved'));
      return true;
    });
  }

  Future<bool> addSlots(List<DateTime> starts, int durationMin) async {
    emit(state.copyWith(busy: true));
    final r = await _repo.addSlots(starts, durationMin);
    if (isClosed) return false;
    switch (r) {
      case Err(:final failure):
        emit(state.copyWith(busy: false, message: failure.message));
        return false;
      case Success(value: (final added, final skipped)):
        await load();
        if (isClosed) return true;
        emit(state.copyWith(message: skipped == 0 ? 'Added $added ${added == 1 ? 'slot' : 'slots'}' : 'Added $added · skipped $skipped that overlap'));
        return true;
    }
  }

  Future<void> deleteSlot(InterviewSlot s) async {
    final d = state.dashboard;
    if (d == null) return;
    emit(state.copyWith(dashboard: InterviewerDashboard(me: d.me, slots: d.slots.where((x) => x.id != s.id).toList(), bookings: d.bookings)));
    final r = await _repo.deleteSlot(s.id);
    if (isClosed) return;
    r.fold((f) => emit(state.copyWith(dashboard: d, message: f.message)), (_) => emit(state.copyWith(message: 'Slot removed')));
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/workshops/domain/workshops.dart';

/// Short courses for the home screen.
class WorkshopsListState extends Equatable {
  const WorkshopsListState({this.loading = true, this.items = const []});
  final bool loading;
  final List<Workshop> items;
  @override
  List<Object?> get props => [loading, items];
}

@injectable
class WorkshopsListCubit extends Cubit<WorkshopsListState> {
  WorkshopsListCubit(this._repo) : super(const WorkshopsListState());
  final WorkshopsRepository _repo;

  Future<void> load() async {
    final r = await _repo.list();
    if (isClosed) return;
    // Quietly empty on failure: the home screen just doesn't show the row
    emit(WorkshopsListState(loading: false, items: r.valueOrNull ?? const []));
  }
}

class WorkshopState extends Equatable {
  const WorkshopState({this.loading = true, this.detail, this.error, this.taxState, this.paying = false, this.message, this.justEnrolled = false, this.pending = false});
  final bool loading;
  final WorkshopDetail? detail;
  /// Couldn't load the course.
  final String? error;
  /// For Google's tax report when Google's choice screen is used.
  final String? taxState;
  final bool paying;
  /// One-off message (payment failed, cancelled…).
  final String? message;
  /// Paid in this session: show a thank-you.
  final bool justEnrolled;
  /// Paid, waiting for confirmation.
  final bool pending;

  WorkshopState copyWith({bool? loading, WorkshopDetail? detail, String? error, String? taxState, bool? paying, String? message, bool? justEnrolled, bool? pending}) => WorkshopState(
        loading: loading ?? this.loading,
        detail: detail ?? this.detail,
        error: error,
        taxState: taxState ?? this.taxState,
        paying: paying ?? this.paying,
        message: message,
        justEnrolled: justEnrolled ?? this.justEnrolled,
        pending: pending ?? this.pending,
      );

  @override
  List<Object?> get props => [loading, detail, error, taxState, paying, message, justEnrolled, pending];
}

/// One short course: details, your seat, and paying for it.
@injectable
class WorkshopCubit extends Cubit<WorkshopState> {
  WorkshopCubit(this._repo, this._enrol, this._recover, this._store, this._prefs) : super(const WorkshopState());
  final WorkshopsRepository _repo;
  final EnrolInWorkshop _enrol;
  final RecoverWorkshopPurchases _recover;
  final StoreBilling _store;
  final SharedPreferences _prefs;

  static const _stateKey = 'pay_tax_state'; // shared with the course checkout
  String _slug = '';

  bool get needsState => state.detail != null && EnrolInWorkshop.usesStore(state.detail!, _store);

  Future<void> load(String slug) async {
    _slug = slug;
    if (state.detail == null) emit(const WorkshopState());
    var r = await _repo.detail(slug);
    // A Google Play payment that finished after the app closed: confirm it first
    final android = r.valueOrNull?.android;
    if (android != null && r.valueOrNull?.mine == null && await _recover(android) > 0) r = await _repo.detail(slug);
    if (isClosed) return;
    final saved = _prefs.getString(_stateKey);
    r.fold(
      (f) => emit(state.copyWith(loading: false, error: f.message)),
      (d) => emit(state.copyWith(
        loading: false,
        detail: d,
        taxState: saved != null && (d.android?.states.contains(saved) ?? false) ? saved : null,
        pending: d.mine?.confirmed == true ? false : null,
      )),
    );
  }

  Future<void> chooseState(String s) async {
    emit(state.copyWith(taxState: s));
    await _prefs.setString(_stateKey, s);
  }

  Future<void> enrol({required String name, required String phone}) async {
    final d = state.detail;
    if (d == null || state.paying) return;
    if (needsState && (state.taxState ?? '').isEmpty) {
      emit(state.copyWith(message: 'Choose your state to continue.'));
      return;
    }
    emit(state.copyWith(paying: true));
    final r = await _enrol(EnrolRequest(detail: d, name: name.trim(), phone: phone.trim(), state: state.taxState));
    if (isClosed) return;
    switch (r.valueOrNull) {
      case EnrolOutcome.cancelled:
        emit(state.copyWith(paying: false, message: 'Payment cancelled. No money was taken.'));
      case EnrolOutcome.enrolled:
        emit(state.copyWith(paying: false, justEnrolled: true));
        await load(_slug);
      case EnrolOutcome.pending:
        emit(state.copyWith(paying: false, pending: true, message: "We're confirming your payment. It usually takes a minute."));
        await load(_slug);
      case null:
        emit(state.copyWith(paying: false, message: r.failureOrNull?.message ?? 'Something went wrong. Please try again.'));
    }
  }
}

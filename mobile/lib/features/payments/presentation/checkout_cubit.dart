import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

class CheckoutState extends Equatable {
  const CheckoutState({this.loading = true, this.options, this.selected, this.taxState, this.paying = false, this.outcome, this.error, this.message});
  final bool loading;
  final PaymentOptions? options;
  final PayPlan? selected;
  /// The student's state, for Google's tax report (Android with Google Play's choice screen).
  final String? taxState;
  final bool paying;
  final PaymentOutcome? outcome;
  /// Couldn't load the payment options.
  final String? error;
  /// One-off message (payment failed, cancelled…).
  final String? message;

  CheckoutState copyWith({bool? loading, PaymentOptions? options, PayPlan? selected, String? taxState, bool? paying, PaymentOutcome? outcome, String? error, String? message}) => CheckoutState(
        loading: loading ?? this.loading,
        options: options ?? this.options,
        selected: selected ?? this.selected,
        taxState: taxState ?? this.taxState,
        paying: paying ?? this.paying,
        outcome: outcome ?? this.outcome,
        error: error,
        message: message,
      );

  @override
  List<Object?> get props => [loading, options, selected, taxState, paying, outcome, error, message];
}

@injectable
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._options, this._pay, this._recover, this._store, this._prefs) : super(const CheckoutState());
  final GetPaymentOptions _options;
  final PayForCourse _pay;
  final RecoverStorePurchases _recover;
  final StoreBilling _store;
  final SharedPreferences _prefs;

  static const _stateKey = 'pay_tax_state';

  /// Google's screen comes first, so the state is asked for on our screen.
  bool get needsState {
    final o = state.options, plan = state.selected;
    return o != null && plan != null && PayForCourse.usesStore(PayRequest(plan, android: o.android), _store);
  }

  bool get canPay => state.selected != null && !state.paying && (!needsState || (state.taxState ?? '').isNotEmpty);

  Future<void> load() async {
    emit(const CheckoutState());
    var r = await _options(const NoParams());
    // A Google Play payment that finished after the app closed: confirm it first
    final android = r.valueOrNull?.android;
    if (android != null) {
      final n = await _recover(android);
      if ((n.valueOrNull ?? 0) > 0) r = await _options(const NoParams());
    }
    if (isClosed) return;
    final saved = _prefs.getString(_stateKey);
    r.fold(
      (f) => emit(CheckoutState(loading: false, error: f.message)),
      (o) => emit(CheckoutState(
        loading: false,
        options: o,
        selected: o.plans.where((p) => p.recommended).firstOrNull ?? o.plans.firstOrNull,
        taxState: saved != null && (o.android?.states.contains(saved) ?? false) ? saved : null,
      )),
    );
  }

  void select(PayPlan p) {
    if (!state.paying) emit(state.copyWith(selected: p));
  }

  Future<void> chooseState(String s) async {
    emit(state.copyWith(taxState: s));
    await _prefs.setString(_stateKey, s);
  }

  Future<void> pay() async {
    final plan = state.selected;
    if (plan == null || state.paying) return;
    if (!canPay) {
      emit(state.copyWith(message: 'Choose your state to continue.'));
      return;
    }
    emit(state.copyWith(paying: true));
    final r = await _pay(PayRequest(plan, android: state.options?.android, state: state.taxState));
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(paying: false, message: f.message)),
      (o) => o.kind == PaymentOutcomeKind.cancelled
          ? emit(state.copyWith(paying: false, message: 'Payment cancelled. No money was taken.'))
          : emit(state.copyWith(paying: false, outcome: o)),
    );
  }
}

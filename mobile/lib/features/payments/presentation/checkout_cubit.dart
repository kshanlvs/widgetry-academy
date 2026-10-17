import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

class CheckoutState extends Equatable {
  const CheckoutState({this.loading = true, this.options, this.selected, this.paying = false, this.outcome, this.error, this.message});
  final bool loading;
  final PaymentOptions? options;
  final PayPlan? selected;
  final bool paying;
  final PaymentOutcome? outcome;
  /// Couldn't load the payment options.
  final String? error;
  /// One-off message (payment failed, cancelled…).
  final String? message;

  CheckoutState copyWith({bool? loading, PaymentOptions? options, PayPlan? selected, bool? paying, PaymentOutcome? outcome, String? error, String? message}) => CheckoutState(
        loading: loading ?? this.loading,
        options: options ?? this.options,
        selected: selected ?? this.selected,
        paying: paying ?? this.paying,
        outcome: outcome ?? this.outcome,
        error: error,
        message: message,
      );

  @override
  List<Object?> get props => [loading, options, selected, paying, outcome, error, message];
}

@injectable
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._options, this._pay) : super(const CheckoutState());
  final GetPaymentOptions _options;
  final PayForCourse _pay;

  Future<void> load() async {
    emit(const CheckoutState());
    final r = await _options(const NoParams());
    r.fold(
      (f) => emit(CheckoutState(loading: false, error: f.message)),
      (o) => emit(CheckoutState(loading: false, options: o, selected: o.plans.where((p) => p.recommended).firstOrNull ?? o.plans.firstOrNull)),
    );
  }

  void select(PayPlan p) {
    if (!state.paying) emit(state.copyWith(selected: p));
  }

  Future<void> pay() async {
    final plan = state.selected;
    if (plan == null || state.paying) return;
    emit(state.copyWith(paying: true));
    final r = await _pay(plan);
    r.fold(
      (f) => emit(state.copyWith(paying: false, message: f.message)),
      (o) => o.kind == PaymentOutcomeKind.cancelled
          ? emit(state.copyWith(paying: false, message: 'Payment cancelled. No money was taken.'))
          : emit(state.copyWith(paying: false, outcome: o)),
    );
  }
}

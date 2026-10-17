import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:printing/printing.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

class PaymentsState extends Equatable {
  const PaymentsState({this.loading = true, this.history, this.error});
  final bool loading;
  final PaymentHistory? history;
  final String? error;
  @override
  List<Object?> get props => [loading, history, error];
}

@injectable
class PaymentsCubit extends Cubit<PaymentsState> {
  PaymentsCubit(this._get) : super(const PaymentsState());
  final GetPaymentHistory _get;

  Future<void> load() async {
    final r = await _get(const NoParams());
    if (isClosed) return;
    r.fold((f) => emit(PaymentsState(loading: false, history: state.history, error: f.message)), (h) => emit(PaymentsState(loading: false, history: h)));
  }
}

/// Fee summary and receipts. Opening it also recovers any payment that wasn't confirmed.
class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<PaymentsCubit>()..load(),
        child: BlocConsumer<PaymentsCubit, PaymentsState>(
          // The server may have just recovered a payment: keep the course screens in step
          listenWhen: (a, b) => a.history?.status != b.history?.status && b.history != null,
          listener: (context, s) => context.read<CoursesCubit>().load(),
          builder: (context, s) {
            final h = s.history;
            final cubit = context.read<PaymentsCubit>();
            return Scaffold(
              appBar: AppBar(title: const Text('Payments & receipts'), titleSpacing: 0),
              body: s.loading
                  ? const SkeletonList(count: 3, leading: false)
                  : h == null
                      ? ErrorView(message: s.error ?? 'Could not load your payments.', onRetry: cubit.load)
                      : RefreshIndicator(onRefresh: cubit.load, child: _Body(h: h)),
            );
          },
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.h});
  final PaymentHistory h;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final links = getIt<LinkLauncher>();
    final courses = context.read<CoursesCubit>().state.courses;
    final course = courses.where((c) => c.title == h.course).firstOrNull ?? courses.where((c) => c.flagship).firstOrNull ?? courses.firstOrNull;
    final (statusText, statusColor) = switch (h.status) {
      'paid' => ('Paid in full', AppColors.ok),
      'part-paid' => ('Balance due', AppColors.warn),
      'refunded' => ('Refunded', p.muted),
      'cancelled' => ('Cancelled', p.muted),
      'unregistered' => ('Not registered', p.muted),
      _ => ('Not paid yet', AppColors.warn),
    };

    return ListView(padding: const EdgeInsets.only(bottom: Space.xxxl), children: [
      // Summary
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(h.course, style: t.titleMedium)),
                Pill(text: statusText, color: statusColor),
              ]),
              const SizedBox(height: Space.lg),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.rupees(h.amountPaid), style: t.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                if (h.total != null) Padding(padding: const EdgeInsets.only(left: 6, bottom: 3), child: Text('paid of ${Fmt.rupees(h.total!)}', style: t.bodySmall)),
              ]),
              if (h.total != null && h.total! > 0) ...[
                const SizedBox(height: Space.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: (h.amountPaid / h.total!).clamp(0.0, 1.0), minHeight: 6, color: h.status == 'paid' ? AppColors.ok : AppColors.gold),
                ),
              ],
              if ((h.due ?? 0) > 0) ...[
                const SizedBox(height: Space.md),
                Text('Balance of ${Fmt.rupees(h.due!)} is due before the course starts.', style: t.bodySmall),
              ],
              if ((h.status == 'unpaid' || h.status == 'part-paid') && course != null) ...[
                const SizedBox(height: Space.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.push('/courses/${course.id}/pay'),
                    child: Text(h.status == 'part-paid' ? 'Pay balance ${h.due == null ? '' : Fmt.rupees(h.due!)}'.trim() : 'Pay course fee'),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),

      // Receipts
      const SectionLabel('Receipts'),
      if (h.items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Text(
            h.amountPaid > 0
                ? 'Your payment was recorded by our team. You got a receipt by email; for a copy, message us on WhatsApp.'
                : 'No payments yet. Receipts for payments made in the app appear here.',
            style: t.bodyMedium?.copyWith(color: p.muted),
          ),
        )
      else
        Group(children: [for (final r in h.items) _ReceiptRow(h: h, r: r)]),

      // Help
      const SectionLabel('Help'),
      Group(children: [
        ListTile(
          leading: const Icon(Icons.support_agent_rounded, size: 22),
          title: const Text('Problem with a payment?'),
          subtitle: const Text('Money taken but not showing? We fix it the same day.'),
          trailing: Icon(Icons.north_east_rounded, size: 18, color: p.faint),
          onTap: () => links.openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I need help with my payment for ${h.course}. My email: ${h.email ?? ''}')}'),
        ),
        ListTile(
          leading: const Icon(Icons.replay_rounded, size: 22),
          title: const Text('Refund policy'),
          trailing: Icon(Icons.north_east_rounded, size: 18, color: p.faint),
          onTap: () => links.openInApp(AppConfig.refundUrl),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: p.faint),
          const SizedBox(width: Space.sm),
          Expanded(child: Text('Payments are processed securely by Razorpay or Google Play. We never see or store your card or UPI details.', style: t.bodySmall?.copyWith(color: p.faint))),
        ]),
      ),
    ]);
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.h, required this.r});
  final PaymentHistory h;
  final Receipt r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.ok.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.md)),
        child: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.ok),
      ),
      title: Text(r.title),
      subtitle: Text([if (r.paidAt != null) Fmt.date(r.paidAt!), r.methodLabel].join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(Fmt.rupees(r.amount), style: t.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        Icon(Icons.chevron_right_rounded, color: p.faint),
      ]),
      onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, useSafeArea: true, builder: (_) => _ReceiptSheet(h: h, r: r)),
    );
  }
}

class _ReceiptSheet extends StatefulWidget {
  const _ReceiptSheet({required this.h, required this.r});
  final PaymentHistory h;
  final Receipt r;
  @override
  State<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<_ReceiptSheet> {
  bool _busy = false;

  Future<void> _pdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await getIt<ReceiptBuilder>().build(widget.h, widget.r);
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'Widgetry-receipt-${widget.r.paymentId}.pdf');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't create the receipt. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = widget.r;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 22),
          const SizedBox(width: Space.sm),
          Text('Payment received', style: t.titleMedium),
        ]),
        const SizedBox(height: Space.md),
        Text(Fmt.rupees(r.amount), style: t.headlineMedium),
        Text('${widget.h.course} · ${r.title}', style: t.bodySmall),
        const SizedBox(height: Space.lg),
        Fact(label: 'Payment ID', value: r.paymentId),
        const SizedBox(height: Space.md),
        Fact(label: 'Paid on', value: [if (r.paidAt != null) Fmt.date(r.paidAt!), r.paidWith].join(' · ')),
        const SizedBox(height: Space.xl),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: r.paymentId));
                showMessage(context, 'Payment ID copied');
              },
              child: const Text('Copy ID'),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(child: FilledButton(onPressed: _busy ? null : _pdf, child: BusyLabel(busy: _busy, label: 'PDF receipt'))),
        ]),
      ]),
    );
  }
}

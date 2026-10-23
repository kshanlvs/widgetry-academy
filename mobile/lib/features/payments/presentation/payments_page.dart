import 'dart:async';
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
  const PaymentsState({this.loading = true, this.history, this.purchases, this.error});
  final bool loading;
  /// Main course fee summary and the buyer's details.
  final PaymentHistory? history;
  /// Every order, all kinds. Null if it couldn't be loaded (the main course receipts still show).
  final Purchases? purchases;
  final String? error;

  /// All orders, newest first.
  List<PurchaseOrder> get orders =>
      purchases?.orders ??
      [
        for (final r in history?.items ?? const <Receipt>[])
          PurchaseOrder(id: 'course_fee-${r.orderId}', kind: 'course_fee', title: history!.course, item: r.title, amount: r.amount, plan: r.plan, orderId: r.orderId, paymentId: r.paymentId.isEmpty ? null : r.paymentId, method: r.method, paidAt: r.paidAt),
      ];

  @override
  List<Object?> get props => [loading, history, purchases, error];
}

@injectable
class PaymentsCubit extends Cubit<PaymentsState> {
  PaymentsCubit(this._get, this._purchases) : super(const PaymentsState());
  final GetPaymentHistory _get;
  final GetPurchases _purchases;

  Future<void> load() async {
    final (h, all) = await (_get(const NoParams()), _purchases(const NoParams())).wait;
    if (isClosed) return;
    h.fold(
      (f) => emit(PaymentsState(loading: false, history: state.history, purchases: all.valueOrNull ?? state.purchases, error: f.message)),
      (v) => emit(PaymentsState(loading: false, history: v, purchases: all.valueOrNull ?? state.purchases)),
    );
  }
}

/// Every order (course fees, short courses, mock interviews) with PDF receipts.
/// Opening it also recovers any payment that wasn't confirmed.
class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<PaymentsCubit>()..load(),
        child: BlocConsumer<PaymentsCubit, PaymentsState>(
          // The server may have just recovered a payment: keep the course screens in step
          listenWhen: (a, b) => b.history != null && (a.history?.status != b.history?.status || a.purchases != b.purchases),
          listener: (context, s) => context.read<CoursesCubit>().load(),
          builder: (context, s) {
            final h = s.history;
            final cubit = context.read<PaymentsCubit>();
            return Scaffold(
              appBar: AppBar(title: const Text('Orders & receipts'), titleSpacing: 0),
              body: s.loading
                  ? const SkeletonList(count: 3, leading: false)
                  : h == null
                      ? ErrorView(message: s.error ?? 'Could not load your orders.', onRetry: cubit.load)
                      : RefreshIndicator(onRefresh: cubit.load, child: _Body(h: h, orders: s.orders, shortCourses: s.purchases?.activeShortCourses ?? const [])),
            );
          },
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.h, required this.orders, required this.shortCourses});
  final PaymentHistory h;
  final List<PurchaseOrder> orders;
  final List<EnrolledCourse> shortCourses;

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
      // Main course fee summary, for students who registered for it
      if (h.status != 'unregistered') Padding(
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

      // Short courses bought
      if (shortCourses.isNotEmpty) ...[
        const SectionLabel('My short courses'),
        Group(children: [
          for (final c in shortCourses)
            ListTile(
              leading: const Icon(Icons.school_outlined, size: 22),
              title: Text(c.title),
              subtitle: Text(c.schedule ?? (c.startsAt == null ? 'Enrolled' : 'Starts ${Fmt.date(c.startsAt!)}')),
              trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
              onTap: c.appPath == null ? null : () => context.push(c.appPath!),
            ),
        ]),
      ],

      // Every order
      const SectionLabel('Orders'),
      if (orders.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Text(
            h.amountPaid > 0
                ? 'Your payment was recorded by our team. You got a receipt by email; for a copy, message us on WhatsApp.'
                : 'No orders yet. Everything you buy, with its receipt, appears here.',
            style: t.bodyMedium?.copyWith(color: p.muted),
          ),
        )
      else
        Group(children: [for (final o in orders) _OrderRow(h: h, o: o)]),

      // Help
      const SectionLabel('Help'),
      Group(children: [
        ListTile(
          leading: const Icon(Icons.support_agent_rounded, size: 22),
          title: const Text('Problem with a payment?'),
          subtitle: const Text('Money taken but not showing? We fix it the same day.'),
          trailing: Icon(Icons.north_east_rounded, size: 18, color: p.faint),
          onTap: () => links.openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I need help with a payment. My email: ${h.email ?? ''}')}'),
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

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.h, required this.o});
  final PaymentHistory h;
  final PurchaseOrder o;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final color = o.isPaid ? AppColors.ok : o.status == 'refund_pending' ? AppColors.warn : p.muted;
    final icon = switch (o.kind) {
      'short_course' => Icons.school_outlined,
      'mock_interview' => Icons.record_voice_over_outlined,
      _ => Icons.receipt_long_rounded,
    };
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.md)),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(o.title),
      subtitle: Text([o.item, if (o.paidAt != null) Fmt.date(o.paidAt!), if (!o.isPaid) _statusText(o.status)].join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(Fmt.rupees(o.amount), style: t.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        Icon(Icons.chevron_right_rounded, color: p.faint),
      ]),
      onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, useSafeArea: true, builder: (_) => _ReceiptSheet(h: h, o: o)),
    );
  }
}

String _statusText(String status) => switch (status) {
      'paid' => 'Payment received',
      'refund_pending' => 'Refund on its way',
      'refunded' => 'Refunded',
      _ => status,
    };

class _ReceiptSheet extends StatefulWidget {
  const _ReceiptSheet({required this.h, required this.o});
  final PaymentHistory h;
  final PurchaseOrder o;
  @override
  State<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<_ReceiptSheet> {
  bool _busy = false;

  Future<void> _pdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await getIt<ReceiptBuilder>().build(widget.h, widget.o);
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'Widgetry-receipt-${widget.o.reference}.pdf');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't create the receipt. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final o = widget.o;
    final r = o.asReceipt;
    final path = o.appPath;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(o.isPaid ? Icons.check_circle_rounded : Icons.undo_rounded, color: o.isPaid ? AppColors.ok : AppColors.warn, size: 22),
          const SizedBox(width: Space.sm),
          Text(_statusText(o.status), style: t.titleMedium),
        ]),
        const SizedBox(height: Space.md),
        Text(Fmt.rupees(o.amount), style: t.headlineMedium),
        Text('${o.title} · ${o.item}', style: t.bodySmall),
        const SizedBox(height: Space.lg),
        Fact(label: 'Payment ID', value: o.reference),
        const SizedBox(height: Space.md),
        Fact(label: 'Paid on', value: [if (o.paidAt != null) Fmt.date(o.paidAt!), r.paidWith].join(' · ')),
        const SizedBox(height: Space.xl),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: o.reference));
                showMessage(context, 'Payment ID copied');
              },
              child: const Text('Copy ID'),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(child: FilledButton(onPressed: _busy ? null : _pdf, child: BusyLabel(busy: _busy, label: 'PDF receipt'))),
        ]),
        if (path != null && path != '/courses') ...[
          const SizedBox(height: Space.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(path);
              },
              child: Text(o.kind == 'mock_interview' ? 'Open interview' : 'Open course'),
            ),
          ),
        ],
      ]),
    );
  }
}

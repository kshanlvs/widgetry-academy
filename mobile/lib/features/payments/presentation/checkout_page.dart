import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/courses/presentation/pages/course_detail_page.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/payments/presentation/checkout_cubit.dart';

/// Pay the course fee in the app with Razorpay (UPI, cards, net banking, wallets).
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<CheckoutCubit>()..load(),
        child: BlocConsumer<CheckoutCubit, CheckoutState>(
          listenWhen: (a, b) => (b.message != null && b.message != a.message) || (b.outcome != null && a.outcome == null),
          listener: (context, s) {
            if (s.message != null) showMessage(context, s.message!);
            // Refresh the registration so the course screen shows the new status
            if (s.outcome != null) context.read<CoursesCubit>().load();
          },
          builder: (context, s) {
            final p = Palette.of(context);
            final o = s.options;
            final Widget body;
            if (s.loading) {
              body = const LoadingView();
            } else if (s.error != null) {
              body = ErrorView(message: s.error!, onRetry: context.read<CheckoutCubit>().load);
            } else if (s.outcome != null) {
              body = _Done(outcome: s.outcome!);
            } else if (o == null || !o.enabled) {
              body = _NotYet(courseId: courseId);
            } else if (o.isPaid || o.plans.isEmpty) {
              body = _Done(outcome: PaymentOutcome(PaymentOutcomeKind.paid, amount: o.amountPaid), already: true);
            } else {
              body = _Plans(state: s);
            }
            final showBar = !s.loading && s.error == null && s.outcome == null && o != null && o.enabled && o.plans.isNotEmpty && !o.isPaid;
            return PopScope(
              canPop: !s.paying,
              child: Scaffold(
                backgroundColor: p.surface,
                appBar: AppBar(backgroundColor: p.surface, title: Text(s.outcome == null ? 'Pay course fee' : ''), titleSpacing: 0, automaticallyImplyLeading: !s.paying),
                body: body,
                bottomNavigationBar: !showBar
                    ? null
                    : BottomActionBar(
                        child: FilledButton(
                          onPressed: s.paying || s.selected == null ? null : context.read<CheckoutCubit>().pay,
                          child: BusyLabel(busy: s.paying, label: s.selected == null ? 'Choose an option' : 'Pay ${Fmt.rupees(s.selected!.amount)}'),
                        ),
                      ),
              ),
            );
          },
        ),
      );
}

class _Plans extends StatelessWidget {
  const _Plans({required this.state});
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final o = state.options!;
    final cubit = context.read<CheckoutCubit>();
    return ListView(padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxl), children: [
      Text(o.course, style: t.headlineSmall),
      const SizedBox(height: 6),
      Text(o.status == 'part-paid' ? 'Your seat is booked. Pay the balance to complete your fee.' : 'Choose how you want to pay. Your seat is confirmed as soon as the payment goes through.',
          style: t.bodyMedium?.copyWith(color: p.muted)),
      const SizedBox(height: Space.xxl),
      for (final plan in o.plans) ...[
        _PlanTile(plan: plan, selected: state.selected?.id == plan.id, enabled: !state.paying, onTap: () {
          tick();
          cubit.select(plan);
        }),
        const SizedBox(height: Space.md),
      ],
      const SizedBox(height: Space.lg),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: p.accent),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text('Secure payment by Razorpay. Pay with UPI, debit or credit card, net banking or wallets. You get a receipt by email.', style: t.bodySmall),
        ),
      ]),
      const SizedBox(height: Space.md),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.replay_rounded, size: 18, color: p.accent),
        const SizedBox(width: Space.md),
        Expanded(child: Text('Full refund if the course isn\'t right for you before Session 2.', style: t.bodySmall)),
      ]),
    ]);
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.selected, required this.enabled, required this.onTap});
  final PayPlan plan;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.soft.withValues(alpha: 0.55) : p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: selected ? p.accent : p.line, width: selected ? 1.6 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(top: 2),
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? p.accent : p.faint, width: selected ? 6 : 1.6)),
              ),
              const SizedBox(width: Space.md + 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(plan.title, style: t.titleSmall)),
                    if (plan.recommended) ...[
                      const SizedBox(width: Space.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(5)),
                        child: Text('Best value', style: t.bodySmall?.copyWith(color: AppColors.warn, fontWeight: FontWeight.w700, fontSize: 11.5)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(plan.note, style: t.bodySmall),
                ]),
              ),
              const SizedBox(width: Space.md),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.rupees(plan.amount), style: t.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                if (plan.amount < plan.fullPrice && plan.id != 'balance') Text('of ${Fmt.rupees(plan.fullPrice)}', style: t.bodySmall?.copyWith(color: p.faint)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Success, booking, or "confirming" screen after paying.
class _Done extends StatelessWidget {
  const _Done({required this.outcome, this.already = false});
  final PaymentOutcome outcome;
  final bool already;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final (icon, color, title, text) = switch (outcome.kind) {
      PaymentOutcomeKind.paid => (Icons.check_rounded, AppColors.ok, already ? 'Your fee is paid' : 'Payment successful', 'Your seat is confirmed. Batch details and the class link come on WhatsApp.'),
      PaymentOutcomeKind.partPaid => (Icons.check_rounded, AppColors.ok, 'Seat booked', 'We received your booking payment. Pay the balance from the course screen before the course starts.'),
      _ => (Icons.hourglass_top_rounded, AppColors.warn, 'Confirming your payment', 'Your bank is confirming the payment. This usually takes a minute; we notify you when it is done. Please don\'t pay again.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page + 4, Space.xxl, Space.page + 4, Space.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.centerLeft, child: child),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 34),
          ),
        ),
        const SizedBox(height: Space.xl),
        Text(title, style: AppTheme.display(size: 24, color: p.ink)),
        const SizedBox(height: Space.sm),
        Text(text, style: t.bodyLarge?.copyWith(color: p.muted)),
        if (outcome.amount > 0 && !already) ...[
          const SizedBox(height: Space.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Column(children: [
              Fact(label: 'Amount', value: Fmt.rupees(outcome.amount)),
              if (outcome.paymentId != null) ...[const SizedBox(height: Space.md), Fact(label: 'Payment ID', value: outcome.paymentId!)],
            ]),
          ),
        ],
        const Spacer(),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.pop(), child: const Text('Done'))),
        const SizedBox(height: Space.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => getIt<LinkLauncher>().openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent('Hi, I just paid for Flutter in 10 Days${outcome.paymentId == null ? '' : ' (payment ${outcome.paymentId})'}.')}'),
            child: const Text('Message us on WhatsApp'),
          ),
        ),
      ]),
    );
  }
}

/// Before Razorpay keys are set on the server: pay on the website, or ask on WhatsApp.
class _NotYet extends StatelessWidget {
  const _NotYet({required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final course = context.read<CoursesCubit>().state.byId(courseId);
    final links = getIt<LinkLauncher>();
    return EmptyView(
      icon: Icons.payments_outlined,
      title: 'In-app payment is coming soon',
      message: 'You can pay securely on our website now, or message us and we\'ll help you.',
      action: Column(children: [
        FilledButton(
          onPressed: () => links.openInApp(course == null ? '${AppConfig.siteUrl}/#fees' : CourseDetailPage.paymentLink(course)),
          child: const Text('Pay on the website'),
        ),
        const SizedBox(height: Space.sm),
        TextButton(onPressed: () => links.openExternal('https://wa.me/${AppConfig.whatsappNumber}'), child: const Text('WhatsApp us')),
      ]),
    );
  }
}

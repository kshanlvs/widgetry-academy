import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/payments/presentation/checkout_page.dart' show TaxStateField;
import 'package:widgetry_academy/features/workshops/domain/workshops.dart';
import 'package:widgetry_academy/features/workshops/presentation/workshops_cubits.dart';

/// The short course a homepage course card points to, if any: its button links to a page like
/// "bloc-crash-course.html" (short course pages end in "-course.html").
String? shortCourseSlug(String? link) => RegExp(r'^([a-z0-9][a-z0-9-]*-course)\.html$').firstMatch((link ?? '').trim())?.group(1);

/// A short live course: dates, price, your seat and the joining link.
class WorkshopPage extends StatelessWidget {
  const WorkshopPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<WorkshopCubit>()..load(slug),
        child: _View(slug: slug),
      );
}

class _View extends StatefulWidget {
  const _View({required this.slug});
  final String slug;
  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _wa(String text) => 'https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent(text)}';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    if (!_prefilled && auth.user?.displayName != null) {
      _name.text = auth.user!.displayName!;
      _prefilled = true;
    }
    final links = getIt<LinkLauncher>();
    return BlocConsumer<WorkshopCubit, WorkshopState>(
      listenWhen: (a, b) => (b.message != null && b.message != a.message) || (b.justEnrolled && !a.justEnrolled),
      listener: (context, s) {
        final m = s.justEnrolled && s.message == null ? "You're enrolled! See you in class." : s.message;
        if (m != null) ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)));
        if (s.justEnrolled) HapticFeedback.mediumImpact();
      },
      builder: (context, s) {
        final cubit = context.read<WorkshopCubit>();
        final d = s.detail;
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: s.loading ? const LoadingView() : ErrorView(message: s.error ?? 'Could not load this course.', onRetry: () => cubit.load(widget.slug)),
          );
        }
        final w = d.workshop;
        final enrolled = d.mine?.confirmed == true;
        final signedIn = auth.isSignedIn;
        final canPay = w.isOpen && d.paymentsOpen && signedIn && !enrolled;

        void pay() {
          if (!(_form.currentState?.validate() ?? false)) return;
          FocusScope.of(context).unfocus();
          cubit.enrol(name: _name.text, phone: _phone.text);
        }

        final Widget? action = enrolled
            ? null
            : !w.isOpen
                ? FilledButton.tonal(
                    onPressed: () => links.openExternal(_wa(w.datesComingSoon
                        ? 'Hi! Please tell me when the ${w.title} dates are out.'
                        : 'Hi! Please add me to the waiting list for the next ${w.title}.')),
                    child: Text(w.datesComingSoon ? 'Notify me on WhatsApp' : 'Join the waiting list'),
                  )
                : !d.paymentsOpen
                    ? FilledButton(onPressed: () => links.openExternal(_wa("Hi! I'd like to enrol in the ${w.title}.")), child: const Text('Enrol on WhatsApp'))
                    : !signedIn
                        ? FilledButton(onPressed: () => context.push('/sign-in?from=${Uri.encodeComponent('/short-courses/${w.slug}')}'), child: const Text('Sign in to enrol'))
                        : FilledButton(onPressed: s.paying ? null : pay, child: BusyLabel(busy: s.paying, label: 'Pay ${Fmt.rupees(w.payNow)} & enrol'));

        return Scaffold(
          appBar: AppBar(
            title: Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            titleSpacing: 0,
            actions: [
              IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share_rounded, size: 21), onPressed: () => links.share('${w.title} at Widgetry Academy\n${AppConfig.siteUrl}${w.webUrlPath}')),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => cubit.load(widget.slug),
            child: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xxl), children: [
                _Header(w: w),
                const SizedBox(height: Space.lg),
                if (enrolled)
                  _Enrolled(d: d, onJoin: (u) => links.openExternal(u), onWhatsApp: () => links.openExternal(_wa("Hi! I'm enrolled in the ${w.title} and have a question.")))
                else ...[
                  if (s.pending) ...[
                    _Note(icon: Icons.hourglass_top_rounded, text: "We're confirming your payment. Pull down to refresh in a minute. If money was taken, your seat is safe."),
                    const SizedBox(height: Space.md),
                  ],
                  _Price(w: w),
                  if (canPay) ...[
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _name,
                      enabled: !s.paying,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Your full name'),
                      validator: (v) => (v ?? '').trim().length < 2 ? 'Please enter your full name' : null,
                    ),
                    const SizedBox(height: Space.md),
                    TextFormField(
                      controller: _phone,
                      enabled: !s.paying,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: '98765 43210', helperText: 'We share class updates here'),
                      validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Enter your WhatsApp number' : null,
                    ),
                    if (cubit.needsState) ...[
                      const SizedBox(height: Space.md),
                      TaxStateField(value: s.taxState, states: d.android?.states ?? const [], enabled: !s.paying, onChanged: cubit.chooseState),
                    ],
                    const SizedBox(height: Space.sm),
                    Text(
                      cubit.needsState ? 'Pay with Google Play, or with UPI, cards or net banking through Razorpay.' : 'Pay securely with UPI, cards or net banking through Razorpay.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
                const SizedBox(height: Space.xl),
                Group(margin: EdgeInsets.zero, children: [
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Full syllabus'),
                    subtitle: const Text('Topics, who it\'s for and what you need'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => links.openInApp('${AppConfig.siteUrl}${w.webUrlPath}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.undo_rounded),
                    title: const Text('Refund policy'),
                    subtitle: const Text('Full refund if you cancel before the first session'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => links.openInApp(AppConfig.refundUrl),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: const Text('Ask a question'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => links.openExternal(_wa('Hi! I have a question about the ${w.title}.')),
                  ),
                ]),
              ]),
            ),
          ),
          bottomNavigationBar: action == null ? null : BottomActionBar(child: action),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.w});
  final Workshop w;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final hours = (w.durationMin / 60).round();
    final when = w.schedule ?? (w.startsAt == null ? null : 'Starts ${Fmt.date(w.startsAt!)}');
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)),
          child: Text('LIVE CRASH COURSE', style: t.labelSmall?.copyWith(color: const Color(0xFF0C2A23), fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        ),
        const SizedBox(height: Space.md),
        Text(w.title, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: Space.sm),
        Text('Live online · about $hours hours · code along and ask anything', style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
        if (when != null) ...[
          const SizedBox(height: Space.md),
          Row(children: [
            const Icon(Icons.event_rounded, size: 18, color: AppColors.gold),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(when, style: t.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
        ],
      ]),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.w});
  final Workshop w;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final status = w.datesComingSoon
        ? 'Dates coming soon. Get a message when enrolment opens.'
        : w.isFull
            ? 'This batch is full.'
            : !w.isOpen
                ? 'Enrolment is closed.'
                : '${w.seatsLeft} seat${w.seatsLeft == 1 ? '' : 's'} left';
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(Fmt.rupees(w.payNow), style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
          if (w.earlyPrice != null) ...[
            const SizedBox(width: Space.sm),
            Text(Fmt.rupees(w.price), style: t.titleMedium?.copyWith(decoration: TextDecoration.lineThrough, color: p.faint)),
          ],
        ]),
        if (w.earlyPrice != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            'Early-bird price${w.earlySeatsLeft != null ? ' · ${w.earlySeatsLeft} left at this price' : ''}${w.earlyUntil != null ? ' · until ${Fmt.date(w.earlyUntil!)}' : ''}',
            style: t.bodySmall?.copyWith(color: AppColors.warn, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: Space.sm),
        Text(status, style: t.bodyMedium?.copyWith(color: p.muted)),
      ]),
    );
  }
}

class _Enrolled extends StatelessWidget {
  const _Enrolled({required this.d, required this.onJoin, required this.onWhatsApp});
  final WorkshopDetail d;
  final ValueChanged<String> onJoin;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final m = d.mine!;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_rounded, color: p.accent),
          const SizedBox(width: Space.sm),
          Text("You're enrolled", style: t.titleMedium),
        ]),
        const SizedBox(height: Space.md),
        if (m.meetingLink != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(onPressed: () => onJoin(m.meetingLink!), icon: const Icon(Icons.videocam_rounded), label: const Text('Join the live session')),
          ),
          const SizedBox(height: Space.sm),
          Text('Join 5 minutes early with Flutter ready on your laptop.', style: t.bodySmall),
        ] else
          Text('The joining link will appear here before the first session. We\'ll also message you on WhatsApp.', style: t.bodyMedium),
        const SizedBox(height: Space.md),
        Text('Paid ${Fmt.rupees(m.amount)}${m.paymentId != null ? ' · ${m.paymentId}' : ''}', style: t.bodySmall?.copyWith(color: p.muted)),
        TextButton(onPressed: onWhatsApp, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Questions? Message us on WhatsApp')),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: AppColors.warn),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.ink))),
      ]),
    );
  }
}

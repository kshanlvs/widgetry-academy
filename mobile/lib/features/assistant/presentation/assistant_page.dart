import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/assistant/domain/assistant.dart';
import 'package:widgetry_academy/features/assistant/presentation/assistant_cubit.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';

/// Full-screen chat with the Widgetry Assistant.
class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => getIt<AssistantCubit>()..start(), child: const _AssistantView());
}

class _AssistantView extends StatefulWidget {
  const _AssistantView();
  @override
  State<_AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<_AssistantView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _links = getIt<LinkLauncher>();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final v = _input.text.trim().isNotEmpty;
      if (v != _canSend) setState(() => _canSend = v);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final v = _input.text;
    if (v.trim().isEmpty) return;
    _input.clear();
    context.read<AssistantCubit>().ask(v);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      });

  /// Website actions mapped to app screens: course sections open the course, pages open in the in-app browser.
  void _run(ChatAction a) {
    switch (a.type) {
      case 'tutor':
        context.push('/tutor?q=${Uri.encodeQueryComponent(a.target)}');
      case 'wa':
        _links.openExternal('https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent(a.target)}');
      case 'link':
        _links.openInApp('${AppConfig.siteUrl}/${a.target}');
      default:
        final courses = context.read<CoursesCubit>().state.courses;
        final main = courses.where((c) => c.flagship && c.isOpen).firstOrNull ?? courses.where((c) => c.isOpen).firstOrNull;
        if (a.target == 'courses' || main == null) {
          context.go('/courses');
        } else if (a.target == 'register') {
          context.push('/courses/${main.id}/register');
        } else {
          context.push('/courses/${main.id}');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: p.surface,
      appBar: AppBar(
        backgroundColor: p.surface,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: p.line)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(Radii.md)),
            child: const BrandMark(size: 20, onDark: true),
          ),
          const SizedBox(width: Space.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Widgetry Assistant', style: t.titleMedium),
            Row(children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.greenBright, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Answers in seconds', style: t.bodySmall),
            ]),
          ]),
        ]),
      ),
      body: BlocConsumer<AssistantCubit, AssistantState>(
        listener: (_, __) => _toBottom(),
        builder: (context, s) {
          if (s.error != null) return ErrorView(message: s.error!, onRetry: context.read<AssistantCubit>().start);
          if (!s.ready) return const LoadingView();
          final cubit = context.read<AssistantCubit>();
          return Column(children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
                children: [
                  for (final m in s.messages) Padding(padding: const EdgeInsets.only(bottom: Space.sm + 2), child: _Bubble(message: m, onAction: _run)),
                  if (s.typing) const Align(alignment: Alignment.centerLeft, child: _TypingDots()),
                  if (s.suggestions.isNotEmpty) ...[
                    if (s.suggestionsLabel != null) Padding(padding: const EdgeInsets.fromLTRB(2, Space.sm, 0, Space.sm), child: Text(s.suggestionsLabel!.toUpperCase(), style: t.labelSmall)),
                    Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                      for (final it in s.suggestions)
                        ActionChip(
                          label: Text(it.question),
                          onPressed: () {
                            tick();
                            cubit.ask(it.question, intent: it);
                          },
                        ),
                    ]),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm + 2, Space.md, Space.xs),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          maxLength: 300,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Type your question…',
                            counterText: '',
                            fillColor: p.bg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.line)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.accent, width: 1.4)),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _canSend && !s.typing ? 1 : 0.4,
                        child: IconButton.filled(
                          tooltip: 'Send',
                          onPressed: _canSend && !s.typing ? _send : null,
                          style: IconButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent, disabledBackgroundColor: p.accent, disabledForegroundColor: p.onAccent, fixedSize: const Size(46, 46)),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Automatic answers · For anything else, chat with us on WhatsApp', textAlign: TextAlign.center, style: t.bodySmall?.copyWith(fontSize: 11.5, color: p.faint)),
                    ),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onAction});
  final ChatMessage message;
  final void Function(ChatAction) onAction;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    final mine = message is UserMessage;
    final m = message;
    final style = t.bodyMedium?.copyWith(color: mine ? p.onAccent : p.ink, height: 1.5);
    Widget text = Text(m.text, style: style);
    if (m is BotMessage && m.highlight != null && m.text.contains(m.highlight!)) {
      final parts = m.text.split(m.highlight!);
      text = Text.rich(TextSpan(style: style, children: [
        TextSpan(text: parts.first),
        TextSpan(text: m.highlight, style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: parts.skip(1).join(m.highlight!)),
      ]));
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 6), child: child)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: mine ? p.accent : p.soft,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 6),
                bottomRight: Radius.circular(mine ? 6 : 18),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              text,
              if (m is BotMessage && m.actions.isNotEmpty) ...[
                const SizedBox(height: Space.md),
                Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [for (final a in m.actions) _ActionButton(action: a, onTap: () => onAction(a))]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onTap});
  final ChatAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (bg, fg, border) = switch (action.type) {
      'wa' => (AppColors.whatsapp, Colors.white, Colors.transparent),
      'link' => (p.surface, p.ink, p.line),
      _ => (AppColors.deep, Colors.white, Colors.transparent),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (action.type == 'wa') ...[Icon(Icons.chat_rounded, size: 15, color: fg), const SizedBox(width: 6)],
            Text(action.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13.5)),
            if (action.type == 'link') ...[const SizedBox(width: 4), Icon(Icons.north_east_rounded, size: 14, color: p.muted)],
          ]),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      label: 'Assistant is typing',
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.sm),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: p.soft, borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(6))),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Transform.translate(
                offset: Offset(0, -3 * _bump((_c.value - i * 0.15) % 1)),
                child: Container(width: 7, height: 7, decoration: BoxDecoration(color: p.muted.withValues(alpha: 0.4 + 0.6 * _bump((_c.value - i * 0.15) % 1)), shape: BoxShape.circle)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  static double _bump(double x) => x < 0.4 ? (x < 0.2 ? x / 0.2 : (0.4 - x) / 0.2) : 0;
}

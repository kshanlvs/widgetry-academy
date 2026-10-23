import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/tutor/domain/tutor.dart';
import 'package:widgetry_academy/features/tutor/presentation/tutor_cubit.dart';
import 'package:widgetry_academy/features/tutor/presentation/tutor_text.dart';

/// Widgetry Tutor: AI answers about Flutter, Dart and Widgetry's courses, based on our own material.
/// [question] (from "Ask Widgetry Tutor" elsewhere in the app) is asked straight away.
class TutorPage extends StatelessWidget {
  const TutorPage({super.key, this.question});
  final String? question;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) {
          final c = getIt<TutorCubit>();
          if ((question ?? '').trim().isNotEmpty) c.ask(question!);
          return c;
        },
        child: const _TutorView(),
      );
}

class _TutorView extends StatefulWidget {
  const _TutorView();
  @override
  State<_TutorView> createState() => _TutorViewState();
}

class _TutorViewState extends State<_TutorView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _canSend = false;

  static const _starters = [
    "What's the difference between Cubit and Bloc?",
    'Explain setState with a small example',
    'How do I become a Flutter developer?',
    'What will I build in the Bloc crash course?',
  ];

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

  void _send([String? text]) {
    final v = text ?? _input.text;
    if (v.trim().isEmpty) return;
    if (text == null) _input.clear();
    tick();
    context.read<TutorCubit>().ask(v);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      });

  Future<void> _history() async {
    final cubit = context.read<TutorCubit>();
    cubit.loadHistory();
    final picked = await showModalBottomSheet<TutorConversation>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(value: cubit, child: const _HistorySheet()),
    );
    if (picked != null) cubit.open(picked);
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
            child: const Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.gold),
          ),
          const SizedBox(width: Space.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Widgetry Tutor', style: t.titleMedium),
            Text('AI · answers from our courses', style: t.bodySmall),
          ]),
        ]),
        actions: [
          IconButton(tooltip: 'Past chats', icon: const Icon(Icons.history_rounded), onPressed: _history),
          IconButton(tooltip: 'New chat', icon: const Icon(Icons.add_comment_outlined), onPressed: () => context.read<TutorCubit>().newChat()),
        ],
      ),
      body: BlocConsumer<TutorCubit, TutorState>(
        listenWhen: (a, b) => a.messages.length != b.messages.length || a.thinking != b.thinking || (b.error != null && a.error != b.error),
        listener: (context, s) {
          if (s.error != null) showMessage(context, s.error!);
          _toBottom();
        },
        builder: (context, s) {
          final cubit = context.read<TutorCubit>();
          return Column(children: [
            Expanded(
              child: s.loadingChat
                  ? const Center(child: CircularProgressIndicator())
                  : s.messages.isEmpty
                      ? _Welcome(starters: _starters, onAsk: _send)
                      : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
                          children: [
                            for (final m in s.messages)
                              Padding(
                                padding: const EdgeInsets.only(bottom: Space.md),
                                child: m.isUser ? _UserBubble(message: m, onRetry: () => cubit.retry(m)) : _Answer(message: m, onContinue: () => _send('Please continue')),
                              ),
                            if (s.thinking) const _Thinking(),
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
                          maxLength: 2000,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Ask about Flutter, Dart or our courses…',
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
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _canSend && !s.thinking ? _send : null,
                        style: IconButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent, disabledBackgroundColor: p.accent.withValues(alpha: 0.4), disabledForegroundColor: p.onAccent, fixedSize: const Size(46, 46)),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        ['AI can make mistakes. Check important details.', if (s.questionsLeft != null) '${s.questionsLeft} questions left today'].join(' · '),
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(fontSize: 11.5, color: p.faint),
                      ),
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

class _Welcome extends StatelessWidget {
  const _Welcome({required this.starters, required this.onAsk});
  final List<String> starters;
  final void Function(String) onAsk;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return ListView(padding: const EdgeInsets.all(Space.xl), children: [
      const SizedBox(height: Space.xl),
      Text("Hi! I'm Widgetry Tutor.", style: t.headlineSmall),
      const SizedBox(height: Space.sm),
      Text(
        'Ask me anything about Flutter and Dart, your code, Flutter careers, or our courses. I answer from what we teach at Widgetry and show you where it comes from.',
        style: t.bodyMedium?.copyWith(color: p.muted),
      ),
      const SizedBox(height: Space.xl),
      Text('TRY ASKING', style: t.labelSmall),
      const SizedBox(height: Space.sm),
      Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [for (final s in starters) ActionChip(label: Text(s), onPressed: () => onAsk(s))]),
    ]);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.onRetry});
  final TutorMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: message.failed ? p.soft : p.accent,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(6)),
            ),
            child: Text(message.text, style: t.bodyMedium?.copyWith(color: message.failed ? p.ink : p.onAccent, height: 1.5)),
          ),
          if (message.failed)
            TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text("Didn't send. Tap to retry")),
        ]),
      ),
    );
  }
}

/// A tutor answer: formatted text, then the Widgetry pages it came from.
class _Answer extends StatelessWidget {
  const _Answer({required this.message, required this.onContinue});
  final TutorMessage message;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    final links = getIt<LinkLauncher>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: p.soft,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(6)),
        ),
        child: TutorText(message.text),
      ),
      if (message.sources.isNotEmpty) ...[
        const SizedBox(height: Space.sm),
        Text('FROM WIDGETRY', style: t.labelSmall?.copyWith(color: p.faint)),
        const SizedBox(height: 4),
        Wrap(spacing: Space.sm, runSpacing: Space.xs, children: [
          for (final s in message.sources)
            ActionChip(
              avatar: Icon(Icons.menu_book_outlined, size: 16, color: p.accent),
              label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 240), child: Text(s.title, overflow: TextOverflow.ellipsis)),
              onPressed: () => links.openInApp(s.url),
            ),
        ]),
      ],
      Row(children: [
        IconButton(
          tooltip: 'Copy answer',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.copy_rounded, size: 17, color: p.faint),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message.text));
            showMessage(context, 'Answer copied');
          },
        ),
        if (message.truncated) TextButton(onPressed: onContinue, child: const Text('Answer was cut short · Continue')),
      ]),
    ]);
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: 'Widgetry Tutor is thinking',
      child: Row(children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)),
        const SizedBox(width: Space.sm),
        Text('Looking through our material and thinking…', style: t.bodySmall?.copyWith(color: p.muted)),
      ]),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return BlocBuilder<TutorCubit, TutorState>(
      builder: (context, s) {
        final list = s.history;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm), child: Text('Past chats', style: t.titleMedium)),
            if (list == null)
              const Padding(padding: EdgeInsets.all(Space.xl), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xl), child: Text('No chats yet. Your questions will appear here.', style: t.bodyMedium?.copyWith(color: p.muted)))
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final c in list)
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: c.updatedAt == null ? null : Text(Fmt.timeAgo(c.updatedAt)),
                      selected: c.id == s.conversationId,
                      onTap: () => Navigator.of(context).pop(c),
                    ),
                ]),
              ),
            const SizedBox(height: Space.md),
          ]),
        );
      },
    );
  }
}

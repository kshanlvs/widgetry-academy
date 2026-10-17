import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/assistant/domain/assistant.dart';

sealed class ChatMessage extends Equatable {
  const ChatMessage(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

final class UserMessage extends ChatMessage {
  const UserMessage(super.text);
}

final class BotMessage extends ChatMessage {
  const BotMessage(super.text, {this.actions = const [], this.highlight});
  final List<ChatAction> actions;
  /// Part of [text] to show in bold (e.g. the course name in the greeting).
  final String? highlight;
  @override
  List<Object?> get props => [text, actions, highlight];
}

class AssistantState extends Equatable {
  const AssistantState({this.ready = false, this.messages = const [], this.typing = false, this.suggestions = const [], this.suggestionsLabel, this.error});
  final bool ready;
  final List<ChatMessage> messages;
  final bool typing;
  /// Follow-up questions shown as chips under the latest answer.
  final List<ChatIntent> suggestions;
  final String? suggestionsLabel;
  final String? error;

  AssistantState copyWith({bool? ready, List<ChatMessage>? messages, bool? typing, List<ChatIntent>? suggestions, String? suggestionsLabel, String? error}) => AssistantState(
        ready: ready ?? this.ready,
        messages: messages ?? this.messages,
        typing: typing ?? this.typing,
        suggestions: suggestions ?? this.suggestions,
        suggestionsLabel: suggestionsLabel ?? this.suggestionsLabel,
        error: error,
      );

  @override
  List<Object?> get props => [ready, messages, typing, suggestions, suggestionsLabel, error];
}

/// The Widgetry Assistant: instant answers about the course, the same as the website's chat.
/// Answers never state fees, dates or seats; for those it points to the live course screen.
@injectable
class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(this._load) : super(const AssistantState());
  final LoadKnowledgeBase _load;
  KnowledgeBase? _kb;

  /// How long the "typing" dots show before an answer. Tests set this to zero.
  Duration Function(int answerLength) typingDelay = (n) => Duration(milliseconds: 550 + math.min(500, n * 2));

  String get course => _kb?.course ?? 'Flutter in 10 Days';

  Future<void> start() async {
    if (state.ready) return;
    final r = await _load(const NoParams());
    r.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (kb) {
        _kb = kb;
        emit(state.copyWith(
          ready: true,
          messages: [BotMessage("Hi! I'm the Widgetry Assistant. Ask me anything about ${kb.course}, or pick a question below.", highlight: kb.course)],
          suggestions: _ids(kb.starters),
          suggestionsLabel: 'Popular questions',
        ));
      },
    );
  }

  /// [intent] is set when a suggestion chip is tapped, so its answer is used directly.
  Future<void> ask(String text, {ChatIntent? intent}) async {
    final kb = _kb;
    final q = text.trim();
    if (kb == null || q.isEmpty || state.typing || isClosed) return;
    emit(state.copyWith(messages: [...state.messages, UserMessage(q)], typing: true, suggestions: const []));
    final it = intent ?? IntentMatcher.match(kb, q);
    await Future<void>.delayed(typingDelay(it?.answer.length ?? 60));
    if (isClosed) return;
    if (it != null) {
      emit(state.copyWith(typing: false, messages: [...state.messages, BotMessage(it.answer, actions: it.actions)], suggestions: _ids(it.related), suggestionsLabel: 'Related'));
    } else {
      emit(state.copyWith(
        typing: false,
        messages: [
          ...state.messages,
          BotMessage("I don't have an answer for that yet. Ask us on WhatsApp and we'll reply quickly.",
              actions: [ChatAction(label: 'Ask on WhatsApp', type: 'wa', target: 'Hi! I have a question about ${kb.course}: $q')]),
        ],
        suggestions: _ids(const ['fee', 'batch', 'beginner', 'build']),
        suggestionsLabel: 'Popular questions',
      ));
    }
  }

  List<ChatIntent> _ids(List<String> ids) => [for (final id in ids) ?_kb?.byId(id)];
}

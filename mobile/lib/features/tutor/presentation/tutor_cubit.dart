import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/features/tutor/domain/tutor.dart';

class TutorState extends Equatable {
  const TutorState({this.conversationId, this.messages = const [], this.thinking = false, this.loadingChat = false, this.questionsLeft, this.error, this.history});
  /// Null until the first answer of a new chat arrives.
  final int? conversationId;
  final List<TutorMessage> messages;
  /// Waiting for an answer.
  final bool thinking;
  /// Opening a past chat.
  final bool loadingChat;
  final int? questionsLeft;
  /// Shown once as a snackbar.
  final String? error;
  /// Past chats, loaded when the history sheet opens.
  final List<TutorConversation>? history;

  TutorState copyWith({int? conversationId, bool clearConversation = false, List<TutorMessage>? messages, bool? thinking, bool? loadingChat, int? questionsLeft, String? error, List<TutorConversation>? history}) => TutorState(
        conversationId: clearConversation ? null : (conversationId ?? this.conversationId),
        messages: messages ?? this.messages,
        thinking: thinking ?? this.thinking,
        loadingChat: loadingChat ?? this.loadingChat,
        questionsLeft: questionsLeft ?? this.questionsLeft,
        error: error,
        history: history ?? this.history,
      );

  @override
  List<Object?> get props => [conversationId, messages, thinking, loadingChat, questionsLeft, error, history];
}

/// Widgetry Tutor: the AI tutor. The app keeps only what's on screen; the server keeps the history,
/// finds the relevant Widgetry material (RAG) and asks Claude.
@injectable
class TutorCubit extends Cubit<TutorState> {
  TutorCubit(this._repo) : super(const TutorState());
  final TutorRepository _repo;

  Future<void> ask(String text) async {
    final q = text.trim();
    if (q.isEmpty || state.thinking || isClosed) return;
    emit(state.copyWith(messages: [...state.messages, TutorMessage(role: TutorRole.user, text: q)], thinking: true));
    await _send(q);
  }

  /// Sends a question that failed again.
  Future<void> retry(TutorMessage failed) async {
    if (state.thinking || !failed.failed) return;
    emit(state.copyWith(messages: [for (final m in state.messages) identical(m, failed) ? m.copyWith(failed: false) : m], thinking: true));
    await _send(failed.text);
  }

  Future<void> _send(String q) async {
    final r = await _repo.ask(q, conversationId: state.conversationId);
    if (isClosed) return;
    r.fold(
      (f) {
        // Mark the newest copy of this question as failed so the student can tap to retry
        final i = state.messages.lastIndexWhere((m) => m.isUser && m.text == q);
        final msgs = [...state.messages];
        if (i >= 0) msgs[i] = msgs[i].copyWith(failed: true);
        emit(state.copyWith(messages: msgs, thinking: false, error: f.message));
      },
      (reply) => emit(state.copyWith(
        conversationId: reply.conversationId,
        messages: [...state.messages, reply.answer],
        thinking: false,
        questionsLeft: reply.questionsLeftToday,
      )),
    );
  }

  void newChat() {
    if (state.thinking) return;
    emit(TutorState(questionsLeft: state.questionsLeft, history: state.history));
  }

  Future<void> loadHistory() async {
    final r = await _repo.conversations();
    if (isClosed) return;
    r.fold((f) => emit(state.copyWith(error: f.message, history: const [])), (list) => emit(state.copyWith(history: list)));
  }

  Future<void> open(TutorConversation c) async {
    if (state.thinking) return;
    emit(state.copyWith(loadingChat: true));
    final r = await _repo.messages(c.id);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(loadingChat: false, error: f.message)),
      (msgs) => emit(state.copyWith(conversationId: c.id, messages: msgs, loadingChat: false)),
    );
  }
}

import 'package:equatable/equatable.dart';
import 'package:widgetry_academy/core/result/result.dart';

/// A Widgetry page an answer drew on (course page, blog post or FAQ). Shown under the answer.
class TutorSource extends Equatable {
  const TutorSource({required this.title, required this.url});
  final String title;
  final String url;
  @override
  List<Object?> get props => [title, url];
}

enum TutorRole { user, tutor }

/// One bubble in the chat.
class TutorMessage extends Equatable {
  const TutorMessage({required this.role, required this.text, this.sources = const [], this.truncated = false, this.failed = false});
  final TutorRole role;
  final String text;
  final List<TutorSource> sources;
  /// The answer hit the length cap; the student can ask "continue".
  final bool truncated;
  /// A question that couldn't be sent; tapping it tries again.
  final bool failed;

  bool get isUser => role == TutorRole.user;

  TutorMessage copyWith({bool? failed}) => TutorMessage(role: role, text: text, sources: sources, truncated: truncated, failed: failed ?? this.failed);

  @override
  List<Object?> get props => [role, text, sources, truncated, failed];
}

/// A past chat, for the history list.
class TutorConversation extends Equatable {
  const TutorConversation({required this.id, required this.title, this.updatedAt});
  final int id;
  final String title;
  final DateTime? updatedAt;
  @override
  List<Object?> get props => [id, title, updatedAt];
}

/// What the server returns for one question.
class TutorReply extends Equatable {
  const TutorReply({required this.conversationId, required this.answer, this.questionsLeftToday});
  final int conversationId;
  final TutorMessage answer;
  final int? questionsLeftToday;
  @override
  List<Object?> get props => [conversationId, answer, questionsLeftToday];
}

/// The server keeps the history and does the retrieval (RAG); the app sends only the new question.
abstract interface class TutorRepository {
  /// [conversationId] is null for a new chat.
  Future<Result<TutorReply>> ask(String question, {int? conversationId});
  Future<Result<List<TutorConversation>>> conversations();
  Future<Result<List<TutorMessage>>> messages(int conversationId);
}

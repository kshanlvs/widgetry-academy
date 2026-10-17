import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';

/// A button under an answer. [type]: "go" (a course screen), "link" (a website page), "wa" (WhatsApp with [target] as the message).
class ChatAction extends Equatable {
  const ChatAction({required this.label, required this.type, required this.target});
  final String label;
  final String type;
  final String target;
  @override
  List<Object?> get props => [label, type, target];
}

/// One question the assistant can answer: [keywords] point to it, [related] are follow-up question ids.
class ChatIntent extends Equatable {
  const ChatIntent({required this.id, required this.question, required this.keywords, required this.answer, this.actions = const [], this.related = const []});
  final String id;
  final String question;
  final List<String> keywords;
  final String answer;
  final List<ChatAction> actions;
  final List<String> related;
  @override
  List<Object?> get props => [id, question, keywords, answer, actions, related];
}

/// Everything the assistant knows. Same content as the website's chatbot (public/chatbot.js).
class KnowledgeBase extends Equatable {
  KnowledgeBase({required this.course, required this.intents, required this.starters, required Set<String> generic})
      : generic = {for (final g in generic) g.toLowerCase()},
        _byId = {for (final i in intents) i.id: i};

  final String course;
  final List<ChatIntent> intents;
  final List<String> starters;
  /// Words that hint at a topic but shouldn't decide it on their own.
  final Set<String> generic;
  final Map<String, ChatIntent> _byId;

  ChatIntent? byId(String id) => _byId[id];

  @override
  List<Object?> get props => [course, intents, starters, generic];
}

/// Picks the best answer for a question. The same scoring as the website, so both answer alike.
abstract final class IntentMatcher {
  static final _strip = RegExp(r'[^a-z0-9₹.+\- ]+');
  static final _spaces = RegExp(r'\s+');

  static String normalize(String s) => ' ${s.toLowerCase().replaceAll(_strip, ' ').replaceAll(_spaces, ' ').trim()} ';

  static ChatIntent? match(KnowledgeBase kb, String text) {
    final t = normalize(text);
    ChatIntent? best;
    var bestScore = 0.0;
    for (final it in kb.intents) {
      var score = 0.0;
      for (final kw in it.keywords) {
        final k = kw.trim().toLowerCase();
        if (k.isEmpty) continue;
        final hit = k.length <= 3 ? t.contains(' $k ') : t.contains(k);
        if (!hit) continue;
        score += kb.generic.contains(k) ? 0.6 : 1 + k.split(' ').length * 0.6 + (k.length > 6 ? 0.3 : 0);
      }
      // Greetings lose to real questions
      if (it.id == 'hello' || it.id == 'thanks') score *= 0.7;
      if (score > bestScore) {
        bestScore = score;
        best = it;
      }
    }
    return bestScore >= 1 ? best : null;
  }
}

abstract interface class AssistantRepository {
  Future<Result<KnowledgeBase>> knowledge();
}

@injectable
class LoadKnowledgeBase implements UseCase<KnowledgeBase, NoParams> {
  const LoadKnowledgeBase(this._repo);
  final AssistantRepository _repo;
  @override
  Future<Result<KnowledgeBase>> call(NoParams p) => _repo.knowledge();
}

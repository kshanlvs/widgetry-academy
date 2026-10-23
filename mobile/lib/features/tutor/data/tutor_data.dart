import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/tutor/domain/tutor.dart';

/// Talks to the Widgetry API: POST /chat, GET /chat/conversations, GET /chat/conversations/:id/messages.
@LazySingleton(as: TutorRepository)
class ApiTutorRepository implements TutorRepository {
  ApiTutorRepository(this._api);
  final ApiClient _api;

  /// Claude can take a while on a long answer, so this call waits longer than usual.
  static const _answerTimeout = Duration(seconds: 60);

  @override
  Future<Result<TutorReply>> ask(String question, {int? conversationId}) => guard(() async {
        final j = await _api.post('/chat', body: {'message': question, if (conversationId != null) 'conversationId': conversationId}, timeout: _answerTimeout);
        final usage = (j['usage'] as Map?) ?? const {};
        return TutorReply(
          conversationId: (j['conversationId'] as num).toInt(),
          answer: TutorMessage(role: TutorRole.tutor, text: '${j['reply'] ?? ''}', sources: sourcesFromJson(j['sources']), truncated: j['truncated'] == true),
          questionsLeftToday: (usage['questionsLeftToday'] as num?)?.toInt(),
        );
      });

  @override
  Future<Result<List<TutorConversation>>> conversations() => guard(() async {
        final j = await _api.get('/chat/conversations');
        return [
          for (final c in (j['conversations'] as List? ?? const []).whereType<Map<String, dynamic>>())
            TutorConversation(id: (c['id'] as num).toInt(), title: '${c['title'] ?? 'Chat'}', updatedAt: DateTime.tryParse('${c['updatedAt'] ?? ''}')?.toLocal()),
        ];
      });

  @override
  Future<Result<List<TutorMessage>>> messages(int conversationId) => guard(() async {
        final j = await _api.get('/chat/conversations/$conversationId/messages');
        return [
          for (final m in (j['messages'] as List? ?? const []).whereType<Map<String, dynamic>>())
            TutorMessage(role: m['role'] == 'user' ? TutorRole.user : TutorRole.tutor, text: '${m['content'] ?? ''}', sources: sourcesFromJson(m['sources'])),
        ];
      });

  static List<TutorSource> sourcesFromJson(Object? v) => [
        for (final s in (v is List ? v : const []).whereType<Map<String, dynamic>>())
          if ('${s['url'] ?? ''}'.startsWith('https://')) TutorSource(title: '${s['title'] ?? 'Widgetry'}', url: '${s['url']}'),
      ];
}

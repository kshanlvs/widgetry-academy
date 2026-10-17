import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/assistant/domain/assistant.dart';

/// Builds the knowledge base from assets/chatbot/intents.json.
/// That file is generated from the website's chatbot by `node mobile/tool/sync_chatbot.mjs`.
KnowledgeBase parseKnowledgeBase(Map<String, dynamic> json) => KnowledgeBase(
      course: '${json['course'] ?? 'Flutter in 10 Days'}',
      starters: [for (final s in (json['starters'] as List? ?? const [])) '$s'],
      generic: {for (final g in (json['generic'] as List? ?? const [])) '$g'},
      intents: [
        for (final m in (json['intents'] as List? ?? const []).whereType<Map<String, dynamic>>())
          ChatIntent(
            id: '${m['id']}',
            question: '${m['q'] ?? ''}',
            keywords: [for (final k in (m['k'] as List? ?? const [])) '$k'],
            answer: '${m['a'] ?? ''}',
            actions: [
              for (final a in (m['act'] as List? ?? const []).whereType<Map<String, dynamic>>())
                ChatAction(label: '${a['label']}', type: '${a['type']}', target: '${a['target']}'),
            ],
            related: [for (final r in (m['rel'] as List? ?? const [])) '$r'],
          ),
      ],
    );

@LazySingleton(as: AssistantRepository)
class AssetAssistantRepository implements AssistantRepository {
  static const asset = 'assets/chatbot/intents.json';
  KnowledgeBase? _cache;

  @override
  Future<Result<KnowledgeBase>> knowledge() => guard(() async {
        return _cache ??= parseKnowledgeBase(jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>);
      });
}

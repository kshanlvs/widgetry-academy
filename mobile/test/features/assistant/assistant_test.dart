import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/assistant/data/assistant_data.dart';
import 'package:widgetry_academy/features/assistant/domain/assistant.dart';
import 'package:widgetry_academy/features/assistant/presentation/assistant_cubit.dart';

class MockLoad extends Mock implements LoadKnowledgeBase {}

void main() {
  // The real answers, generated from the website's chatbot
  final kb = parseKnowledgeBase(jsonDecode(File('assets/chatbot/intents.json').readAsStringSync()) as Map<String, dynamic>);

  String? answer(String q) => IntentMatcher.match(kb, q)?.id;

  group('IntentMatcher (same answers as the website)', () {
    test('loads every answer and the starter questions', () {
      expect(kb.intents.length, greaterThan(20));
      expect(kb.starters, isNotEmpty);
      for (final id in kb.starters) {
        expect(kb.byId(id), isNotNull, reason: 'starter $id');
      }
      for (final it in kb.intents) {
        for (final r in it.related) {
          expect(kb.byId(r), isNotNull, reason: '${it.id} links to missing $r');
        }
      }
    });

    test('understands common questions, including Hinglish', () {
      expect(answer('What is the fee?'), 'fee');
      expect(answer('kitna paisa lagega'), 'fee');
      expect(answer('When does the next batch start?'), 'batch');
      expect(answer('I have never coded before'), 'beginner');
      expect(answer('Do I get a certificate'), 'certificate');
      expect(answer('is there a refund'), 'refund');
      expect(answer('Do I need a MacBook?'), 'mac');
      expect(answer('can I pay with UPI'), 'pay');
      // Every course has its own answers
      expect(answer('What courses do you offer?'), 'courses');
      expect(answer('Tell me about the Bloc crash course'), 'bloc');
      expect(answer('bloc course syllabus'), 'blocsyllabus');
      expect(answer('clean architecture course syllabus'), 'cleansyllabus');
      expect(answer('do I need to know cricket'), 'cleanwho');
      expect(answer('which course should I take'), 'which');
      expect(answer('where is my receipt'), 'myorders');
    });

    test('a real question beats a greeting', () {
      expect(answer('hi'), 'hello');
      expect(answer('hi, what is the fee'), 'fee');
    });

    test('short keywords match whole words only', () {
      // "pc" is a keyword; "upcoming" must not match it
      expect(IntentMatcher.normalize('Hello, World!'), ' hello world ');
      expect(answer('upcoming'), isNot('need'));
    });

    test('unknown questions get no answer', () => expect(answer('asdfgh qwerty'), isNull));
  });

  group('AssistantCubit', () {
    late MockLoad load;
    setUp(() {
      load = MockLoad();
      when(() => load(const NoParams())).thenAnswer((_) async => Success(kb));
    });

    AssistantCubit build() => AssistantCubit(load)..typingDelay = (_) => Duration.zero;

    blocTest<AssistantCubit, AssistantState>(
      'greets and offers popular questions',
      build: build,
      act: (c) => c.start(),
      verify: (c) {
        expect(c.state.ready, isTrue);
        expect(c.state.messages.single, isA<BotMessage>());
        expect(c.state.suggestions.map((s) => s.id), kb.starters);
      },
    );

    blocTest<AssistantCubit, AssistantState>(
      'answers a question with its buttons and related questions',
      build: build,
      act: (c) async {
        await c.start();
        await c.ask('how much is the fee');
      },
      verify: (c) {
        final fee = kb.byId('fee')!;
        final last = c.state.messages.last as BotMessage;
        expect(c.state.messages[1], const UserMessage('how much is the fee'));
        expect(last.text, fee.answer);
        expect(last.actions, fee.actions);
        expect(c.state.suggestions.map((s) => s.id), fee.related);
        expect(c.state.typing, isFalse);
      },
    );

    blocTest<AssistantCubit, AssistantState>(
      'unknown question offers WhatsApp with the question filled in (and the AI tutor once it is switched on)',
      build: build,
      act: (c) async {
        await c.start();
        await c.ask('asdfgh qwerty');
      },
      verify: (c) {
        final last = c.state.messages.last as BotMessage;
        expect(last.actions.map((a) => a.type), [if (AppConfig.tutorEnabled) 'tutor', 'wa']);
        expect(last.actions.every((a) => a.target.contains('asdfgh qwerty')), isTrue);
      },
    );

    blocTest<AssistantCubit, AssistantState>(
      'ignores empty messages',
      build: build,
      act: (c) async {
        await c.start();
        await c.ask('   ');
      },
      verify: (c) => expect(c.state.messages, hasLength(1)),
    );
  });
}

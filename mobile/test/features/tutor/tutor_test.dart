import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/tutor/data/tutor_data.dart';
import 'package:widgetry_academy/features/tutor/domain/tutor.dart';
import 'package:widgetry_academy/features/tutor/presentation/tutor_cubit.dart';
import 'package:widgetry_academy/features/tutor/presentation/tutor_text.dart';

class MockRepo extends Mock implements TutorRepository {}

void main() {
  late MockRepo repo;
  setUp(() => repo = MockRepo());

  const answer = TutorMessage(role: TutorRole.tutor, text: 'Cubit uses methods.', sources: [TutorSource(title: 'Bloc tutorial', url: 'https://widgetryacademy.in/blog/flutter-bloc-tutorial.html')]);

  blocTest<TutorCubit, TutorState>(
    'a question shows at once, then the answer with its sources; the chat id is kept for follow-ups',
    build: () {
      when(() => repo.ask('Cubit or Bloc?', conversationId: null)).thenAnswer((_) async => const Success(TutorReply(conversationId: 7, answer: answer, questionsLeftToday: 29)));
      when(() => repo.ask('Example?', conversationId: 7)).thenAnswer((_) async => const Success(TutorReply(conversationId: 7, answer: answer, questionsLeftToday: 28)));
      return TutorCubit(repo);
    },
    act: (c) async {
      await c.ask('Cubit or Bloc?');
      await c.ask('Example?');
    },
    verify: (c) {
      expect(c.state.conversationId, 7);
      expect(c.state.messages.map((m) => m.role), [TutorRole.user, TutorRole.tutor, TutorRole.user, TutorRole.tutor]);
      expect(c.state.messages[1].sources.single.title, 'Bloc tutorial');
      expect(c.state.questionsLeft, 28);
      verify(() => repo.ask('Example?', conversationId: 7)).called(1);
    },
  );

  blocTest<TutorCubit, TutorState>(
    'a failed question is marked so it can be retried, and retrying sends it again',
    build: () {
      var calls = 0;
      when(() => repo.ask('Hi', conversationId: null)).thenAnswer((_) async => ++calls == 1 ? const Err(NetworkFailure('No internet')) : const Success(TutorReply(conversationId: 1, answer: answer)));
      return TutorCubit(repo);
    },
    act: (c) async {
      await c.ask('Hi');
      expect(c.state.messages.single.failed, isTrue);
      expect(c.state.error, 'No internet');
      await c.retry(c.state.messages.single);
    },
    verify: (c) {
      expect(c.state.messages.first.failed, isFalse);
      expect(c.state.messages.last.text, 'Cubit uses methods.');
    },
  );

  test('sources only keep https links', () {
    final s = ApiTutorRepository.sourcesFromJson([
      {'title': 'Bloc', 'url': 'https://widgetryacademy.in/blog/flutter-bloc-tutorial.html'},
      {'title': 'Bad', 'url': 'javascript:alert(1)'},
    ]);
    expect(s.map((x) => x.title), ['Bloc']);
    expect(ApiTutorRepository.sourcesFromJson(null), isEmpty);
  });

  test('answers are split into prose and code blocks', () {
    final b = TutorText.blocks('Use a Cubit:\n\n```dart\nclass A extends Cubit<int> {}\n```\nThat is all.');
    expect(b.map((x) => x.code), [false, true, false]);
    expect(b[1].lang, 'dart');
    expect(b[1].body, 'class A extends Cubit<int> {}');
    // An answer cut off inside a code block still shows the code
    expect(TutorText.blocks('```dart\nvoid main() {').single.body, 'void main() {');
  });
}

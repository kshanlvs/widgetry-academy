---
title: "Flutter Clean Architecture Explained: Layers, Folder Structure and a Real Example"
seo_title: Flutter Clean Architecture Explained, With Example
description: What clean architecture means in Flutter, the domain, data and presentation layers, a feature-first folder structure, and a full example with Bloc and tests.
date: 2026-10-20
tag: Learning
keywords: flutter clean architecture, clean architecture flutter example, flutter folder structure, flutter bloc clean architecture, flutter architecture, domain layer flutter, repository pattern flutter
cta: cleanarch
---

"We follow clean architecture" appears in a lot of Flutter job descriptions, and "explain the architecture of your last app" is a favourite interview question. Yet most tutorials either drown you in theory or show a folder tree with fifteen empty files.

This guide explains clean architecture in plain words, then builds one small, real feature through every layer: recording balls in a cricket scorer. By the end you will know what goes where, and why.

## The one rule that matters

Clean architecture splits your app into layers, and has one rule:

> **Code can only depend on layers closer to the centre. The centre knows nothing about the outside.**

In a Flutter app, that gives three layers:

| Layer | What lives here | Knows about Flutter? | Knows about APIs, Firebase, databases? |
|---|---|---|---|
| **Domain** (centre) | Entities, business rules, repository *interfaces*, use cases | No | No |
| **Data** | Repository *implementations*, API clients, local storage, JSON mapping | No | Yes |
| **Presentation** | Widgets, pages, Blocs and Cubits | Yes | No |

The domain layer is plain Dart. That's the point: your most important logic (the rules of your app) can't break because Firebase changed an API or a designer moved a button, and you can test it without a phone.

## Feature-first folder structure

Group code by **feature** first, then by layer. It scales much better than one giant `models/`, `screens/` and `services/` folder:

```text
lib/
  core/                 # shared: DI setup, theme, error types, network client
  features/
    scoring/
      domain/
        entities/       # Ball, Innings
        repositories/   # MatchRepository (abstract)
        usecases/       # RecordBall
      data/
        repositories/   # LocalMatchRepository
      presentation/
        cubit/          # ScoreCubit
        pages/          # ScoringPage
    teams/
      ...
```

When you work on scoring, everything you need is in one place. When you delete a feature, you delete one folder.

## Step 1: The domain, plain Dart

Start with the entities: the things your app is about. A cricket ball can be runs, a wide or a wicket. Dart 3 sealed classes model this perfectly:

```dart
sealed class Ball {
  const Ball();
  int get runs;
  bool get countsInOver => true; // wides don't use up a ball
}

final class Runs extends Ball {
  const Runs(this.runs);
  @override
  final int runs;
}

final class Wide extends Ball {
  const Wide();
  @override
  int get runs => 1;
  @override
  bool get countsInOver => false;
}

final class Wicket extends Ball {
  const Wicket();
  @override
  int get runs => 0;
}
```

The innings holds the balls and knows the rules of scoring:

```dart
class Innings {
  const Innings({this.balls = const []});
  final List<Ball> balls;

  int get total => balls.fold(0, (sum, b) => sum + b.runs);
  int get wickets => balls.whereType<Wicket>().length;
  int get legalBalls => balls.where((b) => b.countsInOver).length;
  String get overs => '${legalBalls ~/ 6}.${legalBalls % 6}';

  Innings add(Ball ball) => Innings(balls: [...balls, ball]);
}
```

Next, the domain says **what** it needs from storage, without saying **how**. That's an interface:

```dart
abstract interface class MatchRepository {
  Future<Innings> load(String matchId);
  Future<void> save(String matchId, Innings innings);
}
```

And a **use case**: one action the user can take, with its rules in one place:

```dart
class RecordBall {
  const RecordBall(this._repo);
  final MatchRepository _repo;

  Future<Innings> call(String matchId, Innings current, Ball ball) async {
    final next = current.add(ball);
    await _repo.save(matchId, next);
    return next;
  }
}
```

Is a use case overkill for two lines? Sometimes. It earns its place when the rules grow: "after a wicket, ask for the new batter", "after 6 legal balls, change the bowler". Those rules belong here, not in a widget.

## Step 2: The data layer

Now implement the interface. This version saves to the phone with `shared_preferences`; later you could add a Firebase version without touching the domain:

```dart
class LocalMatchRepository implements MatchRepository {
  LocalMatchRepository(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<Innings> load(String matchId) async {
    final codes = _prefs.getStringList('match_$matchId') ?? const [];
    return Innings(balls: codes.map(_decode).toList());
  }

  @override
  Future<void> save(String matchId, Innings innings) =>
      _prefs.setStringList('match_$matchId', innings.balls.map(_encode).toList());

  static String _encode(Ball b) => switch (b) {
        Runs(:final runs) => 'r$runs',
        Wide() => 'wd',
        Wicket() => 'w',
      };

  static Ball _decode(String s) => switch (s) {
        'wd' => const Wide(),
        'w' => const Wicket(),
        _ => Runs(int.parse(s.substring(1))),
      };
}
```

The conversion between storage format and entities lives here, and only here.

## Step 3: Presentation with Bloc

The Cubit calls the use case and emits the new innings. It doesn't know about storage at all:

```dart
class ScoreCubit extends Cubit<Innings> {
  ScoreCubit(this._recordBall, this.matchId) : super(const Innings());
  final RecordBall _recordBall;
  final String matchId;

  Future<void> record(Ball ball) async => emit(await _recordBall(matchId, state, ball));
}
```

And the widget just draws the state and sends taps:

```dart
BlocBuilder<ScoreCubit, Innings>(
  builder: (context, innings) => Text(
    '${innings.total}/${innings.wickets}  (${innings.overs} ov)',
    style: Theme.of(context).textTheme.displaySmall,
  ),
);

FilledButton(
  onPressed: () => context.read<ScoreCubit>().record(const Runs(4)),
  child: const Text('4'),
);
```

New to Bloc? Our [Flutter Bloc tutorial](flutter-bloc-tutorial.html) covers Cubit, Bloc, BlocListener and testing from scratch.

## Step 4: Wiring it together (dependency injection)

Something has to create the real `LocalMatchRepository` and hand it to the use case. That's dependency injection. With `get_it`:

```dart
final getIt = GetIt.instance;

void setupDependencies(SharedPreferences prefs) {
  getIt
    ..registerLazySingleton<MatchRepository>(() => LocalMatchRepository(prefs))
    ..registerFactory(() => RecordBall(getIt()));
}
```

The Cubit receives `RecordBall`, which receives "some `MatchRepository`". Nothing in the domain or presentation ever writes `LocalMatchRepository`, so swapping it is a one-line change. Larger apps often generate this wiring with `injectable`.

## Step 5: Why this pays off in tests

The scoring rules are plain Dart, so testing them needs no emulator and no mocks:

```dart
test('a wide adds a run but not a ball', () {
  final innings = const Innings().add(const Runs(4)).add(const Wide());
  expect(innings.total, 5);
  expect(innings.overs, '0.1');
});
```

To test the Cubit, give `RecordBall` a fake repository that keeps the innings in memory. You can check every scoring rule and screen state in seconds, which is exactly what interviewers mean when they ask "how did you make your app testable?"

## When clean architecture is overkill

Be honest about the cost. Three layers mean more files. For a two-screen prototype, a hackathon project or a quick demo, a Cubit that calls an API directly is fine.

It pays off when the app will **live and grow**: more features, more developers, more data sources, and tests you trust. Most production apps fall into that group, which is why teams hiring Flutter developers ask about it.

## Common mistakes

1. **Flutter imports in the domain.** If `domain/` imports `package:flutter/...`, Firebase or `dio`, the rule is broken.
2. **Returning API models from repositories.** Map JSON to your own entities in the data layer, so an API change doesn't ripple through the app.
3. **Business rules in widgets or Blocs.** "Six legal balls make an over" belongs in the domain, not in a button's `onPressed`.
4. **Empty use cases everywhere.** A use case that only forwards one call adds noise. Add them where there are real rules, and be consistent within a team.
5. **Layer-first folders for a big app.** `models/`, `screens/` and `services/` with 200 files each is hard to navigate. Go feature-first.

## Frequently asked questions

### What are the layers of clean architecture in Flutter?

Three: the domain layer (entities, repository interfaces and use cases, in plain Dart), the data layer (repository implementations, API and database code, JSON mapping) and the presentation layer (widgets plus Blocs or Cubits). Dependencies point inward, towards the domain.

### Do I need Bloc for clean architecture?

No. Clean architecture is about separating layers; Bloc is one way to build the presentation layer. Riverpod, Provider or even plain ChangeNotifier can sit on top of the same domain and data layers. Bloc is a popular pairing because both push you towards testable, predictable code.

### What is a use case in Flutter clean architecture?

A use case is a small class for one action the user can take, such as RecordBall or PlaceOrder. It holds the rules for that action and talks to repositories through interfaces, so the rules can be tested without Flutter or a backend.

### Is clean architecture good for small Flutter apps?

For very small apps and prototypes it can be more structure than you need. For apps that will grow, be maintained by a team, or need reliable tests, it saves time within a few months. A lighter version (entities, repositories and Blocs, without use cases) is a good middle ground.

### How do I explain my app's architecture in an interview?

Name the layers and say what lives in each, give one concrete example from your app (for instance, how a button tap travels from the widget to the Bloc, the use case and the repository), and explain one benefit you actually got, such as testing business rules without an emulator or swapping a data source easily.

---
title: "Flutter Clean Architecture & Bloc Course (Live)"
url: "https://widgetryacademy.in/flutter-clean-architecture-course.html"
kind: "course"
---

LIVE COURSE · 3 WEEKENDS
## Learn clean Flutter by building a cricket scorer.
OOP, clean architecture, Bloc and testing, learned on one real app: score a gully match ball by ball, with runs, extras, wickets, strike changes, undo and a full scorecard. Then use it in your own weekend matches.
- 6 live sessions · about 15 hours
- Code along, ask anything
- Full source code on GitHub
- For people who know Flutter basics
## Why a cricket scorer?
Most architecture courses build a weather app. It fetches data and shows it, so the layers feel like extra work. A cricket match is full of rules, and rules are exactly what clean architecture and Bloc are for.
## Every ball is a Bloc event
BallBowled, WicketFell, UndoLastBall. You'll see why Bloc exists instead of memorising it.
## OOP with a real reason
A wide, a no-ball and a wicket all change the score differently. That's polymorphism you'll never forget.
## Rules you can test
Strike changes, end of over, all out. Each rule becomes a unit test that runs without a phone.
## What we'll cover⬇ Download syllabus (PDF)
Two sessions each weekend. Every topic goes straight into the app, so the theory always has a reason.
SESSION 1 · ~2.5 HOURS
## Dart OOP through the game
- Classes, constructors and encapsulation: Match, Innings, Over, Player
- Why the score can't be edited directly
- Immutable objects, copyWith and value equality
- Composition over inheritance, and why
You build: the match and innings models
SESSION 2 · ~2.5 HOURS
## Polymorphism and the rules of cricket
- Abstract and sealed classes: legal ball, wide, no-ball, wicket
- Pattern matching with Dart 3 switch
- Strike changes, end of over and all out, written test-first
- The SOLID principles with examples from the app
You build: a scoring engine with unit tests
SESSION 3 · ~2.5 HOURS
## Clean architecture
- Presentation, domain and data layers, and the dependency rule
- Use cases: StartMatch, RecordBall, UndoLastBall
- Repository interfaces, and saving matches on the phone
- Dependency injection with get_it
You build: matches that survive closing the app
SESSION 4 · ~2.5 HOURS
## Bloc in depth
- A match Bloc where every ball is an event
- Undo by replaying events
- BlocListener for wicket and end-of-over dialogs
- Cubit vs Bloc, and when to use which
You build: the live scoring screen
SESSION 5 · ~2.5 HOURS
## Scorecard and history
- Batting and bowling scorecards from the same data
- Match history and a result summary
- Sharing the scorecard as an image
- Testing Blocs with bloc_test and mocktail
You build: a scorecard you can share on WhatsApp
SESSION 6 · ~2.5 HOURS
## Ship it and explain it
- A release APK you can install on any phone
- A README with screenshots that recruiters will read
- How to explain your architecture in an interview
- Code review practice: check an AI-written feature against the architecture and fix it
- Open Q&A on your own projects
You build: a finished, tested app on your GitHub
## Code you can explain in an interview
Each kind of ball is its own class, and the compiler makes sure every one is handled. Add a new kind of ball later, and Dart tells you every place that needs updating.
You'll leave knowing where every line belongs, and why the screen never changes the score directly.
sealed class Delivery { const Delivery(); }
class Legal extends Delivery { final int runs; ... }
class Wide extends Delivery { final int extra; ... }
class NoBall extends Delivery { final int runs; ... }
class Wicket extends Delivery { final Dismissal how; ... }
Innings record(Delivery d) => switch (d) {
Legal(:final runs) => _addBall(runs: runs),
Wide(:final extra) => _addExtra(1 + extra),
NoBall(:final runs) => _addExtra(1 + runs),
Wicket(:final how) => _addWicket(how),
## Is this for you?
This is not a beginner course. It's for people who can build Flutter screens and want to build them properly.
## Your code works, but it's messy
Everything lives in one widget, and changing one thing breaks another. You want a structure you can trust.
## You're preparing for jobs
Clean architecture, Bloc and testing come up in Flutter interviews again and again. Learn to explain them with your own project.
## You did the Bloc crash course
This goes much further: OOP, architecture, dependency injection, saving data and testing a whole app.
You'll need: a laptop with Flutter installed, VS Code or Android Studio, and a GitHub account. Totally new to Flutter? Start with Flutter in 10 Days. Want just Bloc in a weekend? Try the Bloc crash course.
## Your instructor
## Kishan Kumar Sharma
Flutter developer for 5+ years and Senior Software Engineer at Relevance Lab. Uses Bloc and clean architecture in production apps every day, and has worked on large consumer apps as part of a team. Founder of Widgetry Academy.
## Questions
Do I need to know Bloc or clean architecture already?
No. We start both from zero. You need Flutter basics: widgets, StatefulWidget and setState, and basic Dart. We cover the OOP you need in the first session.
Do I need to know cricket rules?
Only the basics: runs, overs, wides, no-balls and wickets. We go through every rule we use in the first session, and the app keeps them simple (a limited-overs match, no rain rules).
How do I join the sessions?
The sessions are live online. After you pay, the joining link appears on this page (sign in with the same account), and we also share the details on WhatsApp.
Will I get the code?
Yes. The full source code of everything we build is shared on GitHub after the course.
Can I get a refund?
Yes, a full refund if you cancel before the first session starts. If we cancel or move the batch, you get a full refund or a seat in the next batch. See the refund policy.
Why learn architecture when AI can write code?
Because AI writes code, not structure. It happily puts business rules in widgets or calls APIs from a Bloc. In the last session an AI writes a feature for the cricket scorer and you review it against everything you've learned, the way a code review works at a real company. Knowing how an app should be built is what lets you use AI safely.
Can I read about clean architecture first?
Yes. Our free guide Flutter clean architecture explained walks through the layers with a small cricket scorer example. The course builds the full app live, with tests.
I have another question
Message us on WhatsApp or use the contact page.

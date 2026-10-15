---
title: "Flutter Interview Questions and Answers (2026): Freshers to Experienced"
description: The Flutter interview questions Indian companies actually ask, with clear answers: widgets, state management, async Dart, performance and architecture.
date: 2026-10-13
tag: Interviews
keywords: flutter interview questions, flutter interview questions for freshers, flutter interview questions and answers, dart interview questions, flutter developer interview
cta: jobs
---

Flutter interviews in India usually follow the same pattern: fundamentals first (widgets, state, layout), then practical topics (APIs, state management, async Dart), then for experienced roles, architecture, testing and performance. Many companies also give a small take-home task or a live coding round.

Here are the questions that come up most, with short, clear answers you can build on. Don't memorise them word for word. Interviewers can tell, and they will ask a follow-up. Understand the idea, then explain it in your own words with an example from your projects.

## Basics (freshers and interns)

### 1. What is the difference between StatelessWidget and StatefulWidget?

A `StatelessWidget` has no data that changes over its lifetime. It builds once from its inputs. A `StatefulWidget` has a separate `State` object that can change, and calling `setState()` tells Flutter to rebuild it. Use stateless widgets by default and stateful ones only when the widget itself owns changing data.

### 2. What is BuildContext?

`BuildContext` is a handle to a widget's position in the widget tree. You use it to look up things above the widget, such as `Theme.of(context)`, `MediaQuery.of(context)` or `Navigator.of(context)`.

### 3. Explain hot reload vs hot restart.

**Hot reload** injects changed code into the running app and rebuilds the UI while keeping the current state. **Hot restart** restarts the app from scratch and resets state. Some changes, like changes to `main()` or global initialisers, need a hot restart.

### 4. What does the `const` keyword do in Flutter?

A `const` widget is created at compile time and reused. Flutter can skip rebuilding it, which improves performance. Mark widgets `const` whenever their inputs never change.

### 5. What is the difference between `final` and `const` in Dart?

Both can be set only once. A `final` value is set at runtime, for example from an API response. A `const` value must be known at compile time and is deeply immutable.

### 6. What are keys and when do you need them?

Keys help Flutter match widgets to their state when widgets of the same type move, are added or are removed in a list. Without keys, reordering a list of stateful items can show the wrong state in the wrong item. Use `ValueKey` with a unique id for list items, and `GlobalKey` when you need to access a widget's state from elsewhere (for example a `Form`).

### 7. Explain the StatefulWidget lifecycle.

`createState()` → `initState()` (run once: start listeners, controllers) → `didChangeDependencies()` → `build()` (can run many times) → `didUpdateWidget()` (when the parent rebuilds with new configuration) → `deactivate()` → `dispose()` (clean up controllers, streams and listeners).

## Layout and UI

### 8. What is the difference between Expanded and Flexible?

Both share space in a `Row` or `Column`. `Expanded` forces its child to fill the available space. `Flexible` lets the child be smaller than the available space if it wants.

### 9. How do you build a list with thousands of items efficiently?

Use `ListView.builder` (or `ListView.separated`), which builds only the items visible on screen. Avoid `ListView(children: [...])` for long lists, because it builds every child up front.

### 10. How do you make a layout responsive?

Use `LayoutBuilder` or `MediaQuery` to adapt to the available width, flexible widgets like `Expanded` and `Wrap`, and avoid fixed pixel sizes for large elements. Test on small phones and tablets.

## Async Dart

### 11. What is the difference between a Future and a Stream?

A `Future` delivers one value (or an error) later, like one API call. A `Stream` delivers many values over time, like live chat messages or location updates. Use `FutureBuilder` and `StreamBuilder` to show them in the UI.

### 12. Is Dart single-threaded? How do you run heavy work?

Dart runs your code on a single thread with an **event loop**, so `async`/`await` doesn't create new threads; it waits without blocking. For heavy CPU work, like parsing a very large JSON file or image processing, use an **isolate** (for example `Isolate.run` or `compute`) so the UI stays smooth.

### 13. What is the difference between the microtask queue and the event queue?

Both hold work for the event loop. Microtasks (from `scheduleMicrotask` and completed futures) run first, before the next event such as a timer, tap or I/O callback. In practice: too much microtask work can delay UI events.

## State management

### 14. Why do we need state management libraries if we have setState?

`setState` is fine for state that lives in one widget. When many screens share data (a cart, a signed-in user), passing it down manually gets messy. Libraries like Provider, Bloc and Riverpod make shared state predictable and testable, and keep business logic out of widgets.

### 15. Explain Bloc vs Cubit.

Both come from the `flutter_bloc` package. A **Cubit** exposes functions that emit new states directly, which is simple and great for most features. A **Bloc** receives **events** and maps them to states, which adds structure, makes every change traceable, and suits complex flows.

### 16. What is InheritedWidget?

`InheritedWidget` lets data flow down the tree so any descendant can read it efficiently, and descendants rebuild when it changes. `Theme`, `MediaQuery` and the Provider package are built on this idea.

## Architecture, testing and performance (experienced)

### 17. How do you structure a large Flutter app?

A common approach is **clean architecture** with feature folders: a presentation layer (widgets and state management), a domain layer (entities and use cases) and a data layer (repositories, API and local data sources). Dependencies point inwards, so business logic doesn't depend on Flutter or the API. Use dependency injection (for example `get_it` or Riverpod) to wire it together.

### 18. What kinds of tests do you write in Flutter?

**Unit tests** for pure logic (blocs, repositories, use cases), **widget tests** for individual screens and components, and **integration tests** for full user flows on a device. A healthy app has many unit tests, a good number of widget tests and a few integration tests.

### 19. How do you find and fix performance problems?

Run the app in **profile mode** and use **Flutter DevTools**: the performance view to find slow frames, and the widget rebuild stats to find widgets rebuilding too often. Common fixes: `const` widgets, smaller `setState` scopes, `ListView.builder`, caching images, moving heavy work to isolates, and `RepaintBoundary` around complex animated parts.

### 20. How does Flutter talk to native Android or iOS code?

Through **platform channels**: a `MethodChannel` sends messages between Dart and Kotlin/Java or Swift/Objective-C. Plugins like camera and location use this under the hood. For type-safe channels, many teams use the `pigeon` package.

### 21. What is the difference between JIT and AOT compilation in Flutter?

In debug mode, Flutter uses **JIT** (just-in-time) compilation, which enables hot reload. Release builds use **AOT** (ahead-of-time) compilation to native machine code, which gives fast start-up and smooth performance.

## How to prepare in one week

1. **Revise these questions** and connect each answer to your own project ("in my food delivery app, I used Bloc for the cart because...").
2. **Rebuild a small feature from memory**: a list from an API with loading and error states. Many live coding rounds ask exactly this.
3. **Read your own code** on GitHub. Interviewers will ask why you made certain choices.
4. **Prepare two stories**: a hard bug you fixed and a feature you are proud of.
5. **Update your resume** so it matches the job description. Our [Flutter resume guide](flutter-developer-resume.html) shows how.

Ready to apply? Browse current [Flutter, Android and iOS jobs](../jobs.html) on Widgetry Jobs.

## Frequently asked questions

### What are the most common Flutter interview questions for freshers?

StatelessWidget vs StatefulWidget, the widget lifecycle, hot reload vs hot restart, Future vs Stream, keys, `const`, and how you used state management and APIs in your own projects.

### Do Flutter interviews include coding rounds?

Often, yes. Expect a small task such as building a screen that loads a list from an API with loading and error states, or a take-home app. Some companies also ask basic data structures and algorithms questions.

### How should I prepare for a Flutter interview as an experienced developer?

Go deeper on architecture, testing, performance profiling with DevTools, platform channels and state management trade-offs, and prepare examples from apps you have shipped.

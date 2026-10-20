---
title: "Flutter Bloc Tutorial for Beginners: Cubit, Bloc and Testing, With a Real Example"
seo_title: Flutter Bloc Tutorial for Beginners (2026) | Widgetry
description: Learn Flutter Bloc step by step: Cubit vs Bloc, events and states, BlocBuilder and BlocListener, loading data from a repository, and testing with bloc_test.
date: 2026-10-20
tag: Learning
keywords: flutter bloc tutorial, flutter bloc, cubit vs bloc, flutter state management, bloc_test, flutter_bloc example, bloc pattern flutter
cta: bloc
---

If you have built a few Flutter screens with `setState`, you have probably hit the point where it stops working well. The same data is needed on three screens, a button on one page should update a badge on another, and your widgets are full of loading flags and `try`/`catch` blocks.

Bloc fixes this by moving your app's logic out of the widgets. It is also one of the state management libraries you will see most often in Flutter job descriptions in India, so it is worth learning properly. This tutorial takes you from your first Cubit to a tested feature.

## What Bloc actually is

Bloc (Business Logic Component) is a pattern, and `flutter_bloc` is the package that implements it. The idea is simple:

- **Widgets** show the current state and send input (a button tap, a text change).
- **A Bloc or Cubit** receives that input, does the work (calculate, call an API, save), and **emits a new state**.
- **Widgets rebuild** when the state changes.

Your widgets never decide *how* things work. They only describe *what the screen looks like* for a given state. That makes the logic easy to test and easy to reuse.

## Cubit vs Bloc

The package gives you two tools. They share the same idea, but you talk to them differently.

| | Cubit | Bloc |
|---|---|---|
| You call | Methods: `cubit.increment()` | Events: `bloc.add(CartItemAdded(item))` |
| Boilerplate | Less | More (an event class per action) |
| Good for | Most screens | Complex flows, when you want a clear log of every action, or to debounce or transform events |

**Start with Cubit.** Switch to Bloc for a feature when you need what events give you. Both are tested and used the same way in your widgets.

## Setup

Add the packages to `pubspec.yaml`:

```yaml
dependencies:
  flutter_bloc: ^9.1.0
  equatable: ^2.0.7

dev_dependencies:
  bloc_test: ^10.0.0
```

`equatable` lets Bloc compare two states by their values, so it can skip rebuilds when nothing really changed.

The examples below use a simple product model:

```dart
class Product extends Equatable {
  const Product({required this.id, required this.name, required this.price});
  final String id;
  final String name;
  final int price; // in rupees

  @override
  List<Object> get props => [id, name, price];
}
```

## Your first Cubit

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0); // the starting state

  void increment() => emit(state + 1);
  void reset() => emit(0);
}
```

Provide it above the screen that needs it, then read it in the widgets:

```dart
BlocProvider(
  create: (_) => CounterCubit(),
  child: const CounterPage(),
);

// Inside CounterPage
BlocBuilder<CounterCubit, int>(
  builder: (context, count) => Text('Count: $count'),
);

FilledButton(
  onPressed: () => context.read<CounterCubit>().increment(),
  child: const Text('Add'),
);
```

Two rules to remember:

- `context.read<T>()` gets the Cubit **without** listening. Use it in callbacks like `onPressed`.
- `BlocBuilder` (or `context.watch<T>()`) **listens** and rebuilds. Use it where the UI shows state.

## Loading data: states for loading, success and error

Real screens load data. Model each situation as its own state with Dart 3 sealed classes, so the compiler makes sure you handle every case:

```dart
sealed class ProductsState {}

final class ProductsLoading extends ProductsState {}

final class ProductsLoaded extends ProductsState {
  ProductsLoaded(this.products);
  final List<Product> products;
}

final class ProductsError extends ProductsState {
  ProductsError(this.message);
  final String message;
}
```

The Cubit gets its data from a **repository**, a class whose only job is fetching and saving data. The Cubit doesn't know or care whether it comes from an API, Firebase or a local database:

```dart
class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit(this._repo) : super(ProductsLoading());
  final ProductRepository _repo;

  Future<void> load() async {
    emit(ProductsLoading());
    try {
      emit(ProductsLoaded(await _repo.fetchProducts()));
    } catch (_) {
      emit(ProductsError('Could not load products. Check your connection.'));
    }
  }
}
```

In the widget, a `switch` on the state covers all three cases:

```dart
BlocBuilder<ProductsCubit, ProductsState>(
  builder: (context, state) => switch (state) {
    ProductsLoading() => const Center(child: CircularProgressIndicator()),
    ProductsError(:final message) => Center(child: Text(message)),
    ProductsLoaded(:final products) => ProductList(products: products),
  },
);
```

If you add a fourth state later, every `switch` that forgets it becomes a compile error, not a crash in production.

## A Bloc with events: a shopping cart

A cart is a good fit for Bloc, because every action (add, remove, clear) is a clear event:

```dart
sealed class CartEvent {}

final class CartItemAdded extends CartEvent {
  CartItemAdded(this.product);
  final Product product;
}

final class CartItemRemoved extends CartEvent {
  CartItemRemoved(this.productId);
  final String productId;
}

class CartState extends Equatable {
  const CartState({this.items = const []});
  final List<Product> items;

  int get total => items.fold(0, (sum, p) => sum + p.price);

  @override
  List<Object> get props => [items];
}

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<CartItemAdded>((event, emit) {
      emit(CartState(items: [...state.items, event.product]));
    });
    on<CartItemRemoved>((event, emit) {
      emit(CartState(items: state.items.where((p) => p.id != event.productId).toList()));
    });
  }
}
```

Notice that each handler builds a **new list** instead of changing the old one. That matters (see the mistakes below).

Sending events and showing the result:

```dart
context.read<CartBloc>().add(CartItemAdded(product));

// Rebuild only when the number of items changes
final count = context.select((CartBloc bloc) => bloc.state.items.length);
```

## BlocListener: for things that happen once

`BlocBuilder` is for drawing the screen. For one-time actions (a snackbar, navigating to another page, a dialog), use `BlocListener`, which runs once per state change and never rebuilds:

```dart
BlocListener<CheckoutCubit, CheckoutState>(
  listener: (context, state) {
    if (state is CheckoutFailed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
    }
    if (state is CheckoutDone) context.go('/orders');
  },
  child: const CheckoutForm(),
);
```

Need both? `BlocConsumer` combines a builder and a listener.

## Testing with bloc_test

Because the logic lives outside the widgets, you can test it in plain Dart, in milliseconds:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shoe = Product(id: 'p1', name: 'Shoe', price: 1999);

  blocTest<CartBloc, CartState>(
    'adding a product puts it in the cart',
    build: CartBloc.new,
    act: (bloc) => bloc.add(CartItemAdded(shoe)),
    expect: () => [const CartState(items: [shoe])],
  );

  blocTest<CartBloc, CartState>(
    'removing a product takes it out again',
    build: CartBloc.new,
    seed: () => const CartState(items: [shoe]),
    act: (bloc) => bloc.add(CartItemRemoved('p1')),
    expect: () => [const CartState()],
  );
}
```

For `ProductsCubit`, pass a fake repository that returns a fixed list or throws, and check that you get `ProductsLoaded` or `ProductsError`. Interviewers love asking how you test state management, and this is the answer they want to hear.

## Common mistakes

1. **Changing the old state instead of creating a new one.** `state.items.add(p); emit(state);` emits the *same* object, so nothing rebuilds. Always build a new list or a new state.
2. **Forgetting Equatable** (or `==`). Without it, two states with the same data look different, and you get extra rebuilds and confusing tests.
3. **Creating a Bloc inside `build()`.** It gets recreated on every rebuild and loses its state. Create it in `BlocProvider(create: ...)`.
4. **Navigating inside `BlocBuilder`.** The builder can run many times. Use `BlocListener` for navigation and snackbars.
5. **Putting everything in one giant Bloc.** One Bloc or Cubit per feature or screen is easier to read and test.
6. **Calling APIs directly from the Bloc.** Put data access in a repository, so you can swap the real one for a fake in tests.

## Where Bloc fits in a bigger app

In a production app, Bloc is the **presentation** layer's brain. Below it sit **use cases** (the business rules) and **repositories** (data). This layering is called clean architecture, and it is what most teams using Bloc follow. We explain it with a full example in [Flutter clean architecture explained](flutter-clean-architecture.html).

## Frequently asked questions

### Is Bloc still worth learning in 2026?

Yes. Bloc remains one of the most common state management choices in production Flutter apps and in Flutter job descriptions, especially at larger companies that value testable, predictable code. Even if a team uses Riverpod, the ideas you learn with Bloc (separating logic from UI, immutable state, testing) carry over directly.

### Should I use Cubit or Bloc?

Start with Cubit for most screens because it needs less code. Use Bloc when you want every user action to be an explicit event, for example to log them, debounce search input, or handle complex flows. You can mix both in one app.

### Bloc or Riverpod, which is better?

Both are good and widely used. Bloc gives you a strict, predictable structure that large teams like. Riverpod is more flexible and has less boilerplate. If you are job hunting in India, Bloc appears in more job posts, so learning it first is a safe choice.

### Do I need Equatable with Bloc?

It is strongly recommended. Equatable makes two states with the same values equal, so Bloc can skip pointless rebuilds and your tests can compare expected states easily. Dart records or overriding == yourself also work.

### How long does it take to learn Bloc?

If you already know Flutter basics, you can understand Cubit in an afternoon and be comfortable with Bloc, BlocListener, repositories and bloc_test after a weekend of focused practice on a real feature.

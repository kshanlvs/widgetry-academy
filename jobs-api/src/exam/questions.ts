// Exam Center question bank. Questions test how and why, not definitions.
// The answers never leave the server: the website gets the prompt and options only, and grading happens in routes/exam.ts.
// type: "single" = one right option · "multi" = select all that apply (all-or-nothing) · "order" = put the items in order.

export type Level = "junior" | "mid" | "senior";
export interface Question {
  id: string;
  level: Level;
  topic: string;
  type: "single" | "multi" | "order";
  prompt: string;
  code?: string;
  options: { id: string; text: string }[];
  answer: string[];          // option ids; for "order" the ids in the right order
  explain: string;
}

const q = (level: Level) => (id: string, topic: string, type: Question["type"], prompt: string, options: [string, string][], answer: string[], explain: string, code?: string): Question =>
  ({ id, level, topic, type, prompt, code, options: options.map(([id, text]) => ({ id, text })), answer, explain });

const J = q("junior"), M = q("mid"), S = q("senior");

export const LEVELS: { id: Level; name: string; years: string; questions: number; minutes: number; pass: number; blurb: string; topics: string[] }[] = [
  { id: "junior", name: "Junior", years: "0–2 years", questions: 15, minutes: 20, pass: 70, blurb: "Layout constraints, setState, the lifecycle, async basics and Dart null safety: why things behave the way they do.", topics: ["Layout", "State", "Lifecycle", "Async", "Dart"] },
  { id: "mid", name: "Mid level", years: "2–5 years", questions: 15, minutes: 25, pass: 70, blurb: "Keys and element reuse, InheritedWidget, Provider and Bloc traps, streams, animations and widget tests.", topics: ["Widgets & elements", "State management", "Streams", "Performance", "Testing"] },
  { id: "senior", name: "Senior", years: "5+ years", questions: 15, minutes: 30, pass: 70, blurb: "The frame pipeline, jank on the UI vs raster thread, isolates, memory leaks, release builds and architecture.", topics: ["Rendering", "Performance", "Concurrency", "Architecture", "Release"] },
];

export const QUESTIONS: Question[] = [
  // ───────────── Junior ─────────────
  J("j-tight", "Layout", "single", "This is the whole app. Why does the red box fill the entire screen instead of being 100 × 100?", [
    ["a", "Container ignores width and height when it has no child"],
    ["b", "The screen gives its child tight constraints (exactly the screen size), and a widget must respect its parent's constraints"],
    ["c", "MaterialApp is missing, so sizes are not applied"],
    ["d", "Colors make a Container expand to fill its parent"],
  ], ["b"], "Constraints go down, sizes go up, and the parent sets the position. The root widget receives tight constraints equal to the screen, so whatever width you ask for, the box must be exactly the screen size. Wrap it in Center (which loosens the constraints) and it becomes 100 × 100.",
  `void main() => runApp(
  Container(width: 100, height: 100, color: Colors.red),
);`),

  J("j-unbounded", "Layout", "single", "This crashes with “RenderFlex children have non-zero flex but incoming height constraints are unbounded”. Why?", [
    ["a", "ListView gives its children unlimited height, so Expanded has no finite space to fill"],
    ["b", "Column can't be placed inside a ListView at all"],
    ["c", "Expanded only works inside a Row"],
    ["d", "The Column needs a key"],
  ], ["a"], "A ListView scrolls, so it lets each child be as tall as it wants (unbounded height). Expanded means “take the remaining space”, and remaining space of infinity is meaningless. Give the Column a bounded height (for example a SizedBox around it) or drop the Expanded.",
  `ListView(
  children: [
    Column(children: [
      const Text('Title'),
      Expanded(child: Container(color: Colors.blue)),
    ]),
  ],
)`),

  J("j-rowtext", "Layout", "single", "A long product name in a Row shows yellow-and-black overflow stripes. What is the right fix, and why does it work?", [
    ["a", "Set overflow: TextOverflow.ellipsis on the Text alone"],
    ["b", "Wrap the Text in Expanded (or Flexible), so the Row gives it a bounded width and the text can wrap or ellipsize"],
    ["c", "Wrap the Row in a SingleChildScrollView"],
    ["d", "Give the Text a smaller fontSize"],
  ], ["b"], "In a Row, children without flex are laid out with unbounded width, so the Text thinks it can be infinitely wide and never wraps. Expanded gives it the leftover width as a limit. Only then do softWrap or TextOverflow.ellipsis have a width to work with, which is why ellipsis alone does nothing.",
  `Row(children: [
  const Icon(Icons.shopping_bag),
  Text(product.name), // a very long name
])`),

  J("j-setstate-3", "State", "single", "A button calls setState three times in one tap. How many times does build() run?", [
    ["a", "Three times, once per setState"],
    ["b", "Once, in the next frame"],
    ["c", "Zero, because the calls cancel each other"],
    ["d", "Once immediately, then twice in the next frame"],
  ], ["b"], "setState runs your callback right away, then only marks the element as dirty and asks for a new frame. Marking an already-dirty element again does nothing, so the framework rebuilds it once when the next frame is drawn.",
  `onPressed: () {
  setState(() => a++);
  setState(() => b++);
  setState(() => c++);
}`),

  J("j-silent", "State", "single", "Button A does count++ without setState, three times. Then button B calls setState to change something else. What does the counter show now?", [
    ["a", "0, because the changes were lost"],
    ["b", "3, because build() reads the current value of count whenever it runs"],
    ["c", "1, because only the last change is kept"],
    ["d", "It throws an error"],
  ], ["b"], "count++ really changed the field: nothing told Flutter to redraw. When B's setState triggers a rebuild, build() reads count, which is now 3. This is why such bugs look random: the screen updates only when something else rebuilds.",
  `int count = 0;
// Button A
onPressed: () { count++; }
// Button B
onPressed: () { setState(() => dark = !dark); }`),

  J("j-lifecycle-order", "Lifecycle", "order", "Put these in the order Flutter calls them for one StatefulWidget that appears on screen and is later removed.", [
    ["a", "build()"], ["b", "initState()"], ["c", "createState()"], ["d", "dispose()"], ["e", "didChangeDependencies()"],
  ], ["c", "b", "e", "a", "d"], "createState makes the State, initState runs once for setup, didChangeDependencies runs right after initState (the first moment you can use inherited data like Theme.of), then build. dispose runs once when the State is removed for good.",
  ),

  J("j-controller-build", "Lifecycle", "single", "What goes wrong if you create the controller inside build()?", [
    ["a", "Nothing, it's just a style choice"],
    ["b", "Every rebuild creates a new controller, so typed text and cursor position are lost, and the old controllers are never disposed"],
    ["c", "The TextField becomes read-only"],
    ["d", "It only fails in release mode"],
  ], ["b"], "build() can run many times (keyboard opening, parent rebuilds, theme changes). Each run makes a fresh controller with empty text and drops the old one without dispose(). Create it once as a State field or in initState, and dispose it in dispose().",
  `@override
Widget build(BuildContext context) {
  final controller = TextEditingController();
  return TextField(controller: controller);
}`),

  J("j-mounted", "Lifecycle", "single", "The user opens this screen and presses back before the API replies. What happens, and what is the fix?", [
    ["a", "Nothing happens; setState is ignored safely"],
    ["b", "Flutter reports “setState() called after dispose()”; check `if (!mounted) return;` after the await"],
    ["c", "The app navigates back to the screen automatically"],
    ["d", "The API call is cancelled automatically"],
  ], ["b"], "await pauses the function, not the user. When the reply arrives the State may already be disposed, and calling setState on it is an error (and a sign of a leak). mounted is false after dispose, so check it after every await before touching state or context.",
  `Future<void> load() async {
  final data = await api.getProducts();
  setState(() => products = data);
}`),

  J("j-eventloop", "Async", "single", "What does this print?", [
    ["a", "1 2 3 4"], ["b", "1 4 2 3"], ["c", "1 4 3 2"], ["d", "1 3 4 2"],
  ], ["c"], "Synchronous code runs first (1, 4). Then Dart empties the microtask queue (3) before taking the next event from the event queue, which is where Future(() …) callbacks go (2). Microtasks always run before the next event.",
  `void main() {
  print('1');
  Future(() => print('2'));
  scheduleMicrotask(() => print('3'));
  print('4');
}`),

  J("j-noawait", "Async", "single", "saveToServer() is async and throws. Why does the catch block never run?", [
    ["a", "catch only works for synchronous code inside async functions"],
    ["b", "Without await, the try block finishes before the Future fails, so the error escapes as an unhandled async error"],
    ["c", "Async errors can't be caught in Dart"],
    ["d", "The error is swallowed because the function returns void"],
  ], ["b"], "Calling an async function returns a Future immediately. The try block is done by the time the Future completes with an error, so nothing is there to catch it. `await saveToServer();` keeps the error inside the try.",
  `try {
  saveToServer();
} catch (e) {
  showError(e);
}`),

  J("j-final-const", "Dart", "single", "What happens when this runs?", [
    ["a", "Both lines work"],
    ["b", "a.add(2) works; b.add(2) throws an Unsupported operation error at runtime"],
    ["c", "Both throw, because final and const mean the same thing"],
    ["d", "a.add(2) throws; b.add(2) works"],
  ], ["b"], "final means the variable can't point to a different list, but the list itself can still change. const makes a compile-time constant that is deeply immutable, so modifying it throws at runtime.",
  `final a = [1];
a.add(2);
const b = [1];
b.add(2);`),

  J("j-crash", "Dart", "multi", "This all compiles. Which lines can still crash at runtime? Select all that apply.", [
    ["a", "name!.length when name is null"],
    ["b", "Reading a late variable before it is assigned"],
    ["c", "int.parse('12a')"],
    ["d", "name?.length when name is null"],
    ["e", "products.first when products is empty"],
  ], ["a", "b", "c", "e"], "Null safety removes many crashes, but ! is a promise you make to the compiler; if you're wrong it throws. late moves the check to runtime (LateInitializationError). int.parse throws FormatException and .first on an empty list throws StateError. ?. simply returns null.",
  ),

  J("j-hotreload", "Tooling", "single", "You change code inside initState() and hot reload. The screen doesn't show the change. Why?", [
    ["a", "Hot reload is broken; reinstall Flutter"],
    ["b", "Hot reload keeps the existing State objects, so initState has already run and won't run again; hot restart or reopen the screen"],
    ["c", "initState only runs in release mode"],
    ["d", "You must save the file twice"],
  ], ["b"], "Hot reload injects new code and rebuilds, but it keeps the app's state. initState runs only when a State is created, so the old one isn't re-initialised. The same goes for main() and already-initialised global or static fields. Hot restart throws the state away.",
  ),

  J("j-builder", "Performance", "single", "ListView.builder with itemCount: 10000. How many item widgets are built when the screen opens?", [
    ["a", "All 10,000"],
    ["b", "Only the ones visible on screen, plus a small cache area just beyond the edges"],
    ["c", "Exactly 20"],
    ["d", "None until the user scrolls"],
  ], ["b"], "The builder is lazy: it calls itemBuilder only for items in the viewport plus the cacheExtent (a small area around it), and drops them as they scroll away. That's why long lists should use .builder.",
  ),

  J("j-const", "Performance", "single", "Why does adding const to a widget make rebuilds cheaper?", [
    ["a", "const widgets are drawn by the GPU instead of the CPU"],
    ["b", "The same widget instance is reused, so when the parent rebuilds Flutter sees an identical widget and skips rebuilding that subtree"],
    ["c", "const widgets can never change, so Flutter caches their pixels forever"],
    ["d", "It only makes the app smaller, not faster"],
  ], ["b"], "A const constructor call returns one canonical instance. When the parent rebuilds, the framework compares the new widget with the old one; if it's the identical object, it stops there. Without const, a new instance is created and that child rebuilds too.",
  `Column(children: [
  const AppLogo(),
  Text('$count'),
])`),

  J("j-keys-basic", "Widgets & elements", "single", "Each row is a StatefulWidget with its own checkbox. Item 1 is ticked. You delete item 1 from the list (no keys used). What does the user see?", [
    ["a", "Item 1 disappears and all checkboxes are correct"],
    ["b", "Item 2 now appears ticked, because the first State is kept and reused for whatever is in the first position"],
    ["c", "All checkboxes reset"],
    ["d", "The app crashes"],
  ], ["b"], "Without keys, Flutter matches old and new children by type and position. The first State object stays in position 0 and is reused for item 2, so the tick moves with it. A ValueKey(item.id) on each row makes the state follow the item.",
  `ListView(children: [
  for (final item in items) TodoRow(item: item),
])`),

  J("j-context", "Widgets & elements", "single", "What is a BuildContext, really?", [
    ["a", "A copy of the app's settings"],
    ["b", "The Element: this widget's place in the tree, which is why Theme.of(context) can look upward for the nearest Theme"],
    ["c", "The screen the widget is on"],
    ["d", "A global object shared by every widget"],
  ], ["b"], "BuildContext is an interface that Element implements. It knows where the widget sits, so .of(context) walks up from that spot. It's also why a context from above a Scaffold can't find that Scaffold.",
  ),

  J("j-pop-result", "Navigation", "single", "The second screen calls Navigator.pop(context, 'saved'). What is result if the user uses the system back button instead?", [
    ["a", "'saved'"], ["b", "null"], ["c", "An exception is thrown"], ["d", "An empty string"],
  ], ["b"], "Navigator.push returns a Future that completes when the route is popped, with whatever was passed to pop. The system back button pops without a value, so result is null. Always handle null.",
  `final result = await Navigator.push<String>(
  context,
  MaterialPageRoute(builder: (_) => const EditScreen()),
);`),

  J("j-caret", "Tooling", "single", "pubspec.yaml has `http: ^0.13.4`. Which versions can pub pick?", [
    ["a", ">=0.13.4 <1.0.0"], ["b", ">=0.13.4 <0.14.0"], ["c", "Exactly 0.13.4"], ["d", "Any version newer than 0.13.4"],
  ], ["b"], "Caret means “compatible with”. For 1.0.0 and above that's up to the next major version, but below 1.0 the minor version counts as breaking, so ^0.13.4 stops before 0.14.0.",
  ),

  J("j-expanded", "Layout", "single", "What is the real difference between Expanded and Flexible?", [
    ["a", "Expanded is for Rows, Flexible is for Columns"],
    ["b", "Expanded forces the child to fill its share of space (tight fit); Flexible lets the child be smaller than its share (loose fit)"],
    ["c", "Flexible can't take a flex value"],
    ["d", "There is no difference"],
  ], ["b"], "Expanded is literally Flexible with fit: FlexFit.tight. Both get a share of the remaining space, but only Expanded makes the child exactly that size.",
  ),

  J("j-stateless-rebuild", "Widgets & elements", "multi", "When does a (non-const) StatelessWidget's build() run again? Select all that apply.", [
    ["a", "When its parent rebuilds and creates it again"],
    ["b", "When an InheritedWidget it reads with .of(context) changes, e.g. Theme"],
    ["c", "Never, a StatelessWidget builds only once"],
    ["d", "Every frame, 60 times a second"],
  ], ["a", "b"], "Stateless doesn't mean it builds once. It means it has no mutable State of its own. It rebuilds when its parent passes a new instance, or when inherited data it depends on changes.",
  ),

  // ───────────── Mid level ─────────────
  M("m-uniquekey", "Widgets & elements", "single", "A form field widget loses its typed text on every rebuild. The list uses the code below. Why?", [
    ["a", "UniqueKey is too slow"],
    ["b", "A new UniqueKey is created on every build, so the key never matches the old one and Flutter throws away the old element and State each time"],
    ["c", "Keys only work on StatelessWidgets"],
    ["d", "TextFields can't be inside a ListView"],
  ], ["b"], "An element is reused only when the new widget has the same runtimeType and the same key. UniqueKey() is equal only to itself, so a fresh one every build means a new State every build. Use a stable ValueKey(item.id).",
  `for (final f in fields)
  FieldRow(key: UniqueKey(), field: f),`),

  M("m-canupdate", "Widgets & elements", "multi", "A StatefulWidget sits at the same place in the tree. Which changes make Flutter throw away its State and create a new one? Select all that apply.", [
    ["a", "Giving it a different key"],
    ["b", "Wrapping it in Padding only when a flag is true"],
    ["c", "Passing a different value to one of its constructor parameters"],
    ["d", "Its parent calling setState"],
  ], ["a", "b"], "State survives if, at the same position, the widget has the same runtimeType and key (Widget.canUpdate). A new key fails that test. Conditionally adding a Padding changes what sits at that position, so the child is now one level deeper and gets a new element. New constructor values only trigger didUpdateWidget.",
  ),

  M("m-inherited", "State management", "single", "Two widgets read the same InheritedWidget. One uses dependOnInheritedWidgetOfExactType, the other getInheritedWidgetOfExactType. When the data changes, what happens?", [
    ["a", "Both rebuild"],
    ["b", "Only the dependOn… widget is registered as a dependent, so only it gets didChangeDependencies and rebuilds"],
    ["c", "Neither rebuilds until hot reload"],
    ["d", "Only the get… widget rebuilds"],
  ], ["b"], "dependOnInheritedWidgetOfExactType looks up the widget and subscribes the caller. getInheritedWidgetOfExactType only looks it up. This is the same split as Provider's context.watch vs context.read.",
  ),

  M("m-didupdate", "Lifecycle", "single", "The parent switches userId from 1 to 2, but the card keeps showing user 1. What's missing?", [
    ["a", "A call to setState in the parent"],
    ["b", "didUpdateWidget: Flutter reused the same State, so initState never ran again; compare oldWidget.userId with widget.userId and refetch"],
    ["c", "A GlobalKey on the card"],
    ["d", "The card should be a StatelessWidget"],
  ], ["b"], "Same type at the same position means the State is kept and given the new widget. initState runs once per State, so its fetch never repeats. didUpdateWidget(oldWidget) is called with the old settings, and build runs right after it.",
  `class _ProfileCardState extends State<ProfileCard> {
  late Future<User> user;
  @override
  void initState() {
    super.initState();
    user = api.fetchUser(widget.userId);
  }
  // ...
}`),

  M("m-select", "State management", "single", "The cart badge only shows the item count, but it rebuilds every time the total price changes. What should it use?", [
    ["a", "context.read<CartModel>().count"],
    ["b", "context.select<CartModel, int>((c) => c.count), which rebuilds only when that value changes"],
    ["c", "A GlobalKey"],
    ["d", "Consumer<CartModel> around the whole page"],
  ], ["b"], "watch rebuilds on every notifyListeners. select still listens, but compares the selected value and rebuilds only when it differs. read doesn't listen at all, so the badge would never update.",
  `final cart = context.watch<CartModel>();
return Badge(label: Text(cart.count.toString()));`),

  M("m-value", "State management", "single", "Inside a ListView, each row needs a ChangeNotifier that already exists in a list. Why use ChangeNotifierProvider.value here instead of create?", [
    ["a", ".value is faster"],
    ["b", "create would build a new object and dispose it when the row leaves the tree; .value just passes an existing object and never disposes it"],
    ["c", "create doesn't work inside lists"],
    ["d", "They are identical"],
  ], ["b"], "create owns the object: it makes it once and disposes it with the provider. Rows in a scrolling list are created and destroyed as you scroll, so create would dispose objects you still need. .value is for objects owned somewhere else.",
  ),

  M("m-bloc-equal", "State management", "single", "The Cubit adds an item and emits, but the UI doesn't rebuild. The state class extends Equatable. Why?", [
    ["a", "emit must be awaited"],
    ["b", "The same list object was mutated and emitted again, so the new state equals the old one and emit skips notifying"],
    ["c", "Cubits can't hold lists"],
    ["d", "BlocBuilder needs a buildWhen"],
  ], ["b"], "emit ignores a state that is == the current one. Mutating the list in place means old and new states hold the same list, so they compare equal. Emit a new state with a new list: `emit(CartState([...state.items, item]))`.",
  `void add(Item item) {
  state.items.add(item);
  emit(CartState(state.items));
}`),

  M("m-listener", "State management", "single", "Where should you show a SnackBar or navigate when a Bloc emits LoginSuccess?", [
    ["a", "Inside BlocBuilder's builder"],
    ["b", "In a BlocListener, because the builder may run many times for the same state and must only describe UI"],
    ["c", "In initState"],
    ["d", "Inside the Bloc using a global context"],
  ], ["b"], "builder can be called repeatedly (rebuilds, hot reload, parent changes), so a navigation inside it can fire twice. BlocListener's listener runs once per state change, which is what one-off side effects need.",
  ),

  M("m-futurebuilder", "Async", "single", "Every time the keyboard opens, the products reload and a spinner flashes. Why?", [
    ["a", "FutureBuilder always refetches when the keyboard opens"],
    ["b", "fetchProducts() is called inside build, so every rebuild creates a new Future and FutureBuilder starts waiting again"],
    ["c", "The API caches nothing"],
    ["d", "MediaQuery is broken"],
  ], ["b"], "Opening the keyboard changes MediaQuery and rebuilds the screen. Each build calls fetchProducts() again. Create the Future once in initState (or in your state management) and pass that same Future in.",
  `@override
Widget build(BuildContext context) {
  return FutureBuilder(
    future: api.fetchProducts(),
    builder: (context, snap) => ...,
  );
}`),

  M("m-stream-twice", "Streams", "single", "Two widgets listen to the same stream from a regular StreamController. What happens?", [
    ["a", "Both get every event"],
    ["b", "The second listen throws “Bad state: Stream has already been listened to”"],
    ["c", "Events are split between them"],
    ["d", "Only the newest listener gets events"],
  ], ["b"], "A plain StreamController makes a single-subscription stream, which buffers events until its one listener arrives. For many listeners use StreamController.broadcast() or asBroadcastStream().",
  ),

  M("m-broadcast", "Streams", "single", "A broadcast stream emits an event while no one is listening. What happens to that event?", [
    ["a", "It is buffered until someone listens"],
    ["b", "It is dropped; broadcast streams don't buffer for late listeners"],
    ["c", "It throws an error"],
    ["d", "It is delivered twice"],
  ], ["b"], "Broadcast streams send each event only to whoever is subscribed at that moment. That suits live updates but means a screen that subscribes late misses earlier events. Keep the latest value somewhere (a Bloc state, ValueNotifier) if late screens need it.",
  ),

  M("m-vsync", "Animations", "multi", "Why does AnimationController need vsync: this (a TickerProvider)? Select all that apply.", [
    ["a", "Ticks line up with the screen's frames"],
    ["b", "Tickers are muted when the widget is not visible (TickerMode), saving battery"],
    ["c", "It makes the animation run on a separate thread"],
    ["d", "It disposes the controller automatically"],
  ], ["a", "b"], "The ticker calls the controller once per frame, and TickerMode can silence it for widgets off screen (like a tab you left). It doesn't use another thread and doesn't dispose anything: you still call controller.dispose().",
  ),

  M("m-listview-children", "Performance", "single", "ListView(children: List.generate(1000, (i) => ProductTile(i))). What actually happens up front?", [
    ["a", "Nothing is created until scrolled into view"],
    ["b", "All 1,000 ProductTile widget objects are constructed at once; only the visible ones get elements and render objects"],
    ["c", "All 1,000 are built, laid out and painted"],
    ["d", "Flutter throws because lists over 500 need a builder"],
  ], ["b"], "With a children list, you construct every widget yourself before ListView even sees them. The list still only mounts what's visible, but the construction cost and memory are paid for all 1,000. ListView.builder constructs them on demand.",
  ),

  M("m-cachewidth", "Performance", "single", "A grid of 4000 × 3000 photos, shown as 120 × 120 thumbnails, makes memory jump. What's the cheapest effective fix?", [
    ["a", "Use a smaller BoxFit"],
    ["b", "Pass cacheWidth/cacheHeight so the images are decoded at thumbnail size instead of full resolution"],
    ["c", "Wrap each image in a RepaintBoundary"],
    ["d", "Use const"],
  ], ["b"], "Images are decoded to raw pixels at their real size: one 4000 × 3000 photo is about 48 MB in memory regardless of how small it's drawn. cacheWidth/cacheHeight (ResizeImage) decode it close to the size it's shown.",
  ),

  M("m-keepalive", "Widgets & elements", "single", "In a TabBarView, the scroll position of tab 1 resets every time you come back to it. What keeps it?", [
    ["a", "Make the tab a StatelessWidget"],
    ["b", "AutomaticKeepAliveClientMixin with wantKeepAlive => true, and calling super.build(context)"],
    ["c", "A const constructor"],
    ["d", "Increasing cacheExtent to 0"],
  ], ["b"], "TabBarView is built on a PageView, which disposes pages that go off screen. The keep-alive mixin asks the list to keep that page's element alive. Forgetting super.build(context) silently disables it.",
  ),

  M("m-http400", "Testing", "single", "In a testWidgets test, your real HTTP call always returns status 400. Why?", [
    ["a", "The test server is down"],
    ["b", "flutter_test overrides HttpClient so every real request returns 400; tests shouldn't hit the network, so inject a fake client or repository"],
    ["c", "Widget tests run offline only on CI"],
    ["d", "You need to call pumpAndSettle first"],
  ], ["b"], "Widget tests install HttpOverrides that answer every request with 400, so tests stay fast and deterministic. Design for it: depend on an interface (a repository or http.Client) and pass a fake in tests.",
  ),

  M("m-settle", "Testing", "single", "tester.pumpAndSettle() times out on a screen with a CircularProgressIndicator. Why?", [
    ["a", "The indicator is broken in tests"],
    ["b", "pumpAndSettle waits until no frames are scheduled, but an indeterminate spinner animates forever"],
    ["c", "You need to await twice"],
    ["d", "Spinners only work on a real device"],
  ], ["b"], "pumpAndSettle keeps pumping while frames are still scheduled. An endless animation always schedules another frame, so it never settles. Use pump(duration), or make the loading finish in the test.",
  ),

  M("m-ensure", "Platform", "single", "main() reads SharedPreferences before runApp and crashes with “Binding has not yet been initialized”. Why?", [
    ["a", "SharedPreferences doesn't work on Android"],
    ["b", "Plugins talk to the platform through the Flutter binding; runApp normally creates it, so call WidgetsFlutterBinding.ensureInitialized() first"],
    ["c", "main() can't be async"],
    ["d", "You must use a FutureBuilder"],
  ], ["b"], "Platform channels need the binding's messenger. runApp sets up the binding, but your code runs before it. ensureInitialized() creates the binding early so plugin calls in main work.",
  `Future<void> main() async {
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}`),

  M("m-isolate", "Performance", "single", "Parsing a 5 MB JSON response freezes the UI for 400 ms. Why does moving it to Isolate.run (or compute) help, and what's the catch?", [
    ["a", "It runs on the GPU; no catch"],
    ["b", "Parsing runs on another isolate, so the UI isolate keeps drawing frames; the catch is that input and result are copied between isolates, so it's not worth it for small payloads"],
    ["c", "It makes the JSON smaller"],
    ["d", "It caches the result; the catch is extra disk space"],
  ], ["b"], "Dart runs your code and the frame building on one isolate. A long synchronous task blocks frames. A separate isolate has its own memory, so data is sent across (the result is passed back efficiently when the isolate exits). For tiny payloads, the setup costs more than it saves.",
  ),

  M("m-sizeof", "Performance", "single", "Why is MediaQuery.sizeOf(context) better than MediaQuery.of(context).size?", [
    ["a", "It's shorter to type, nothing else"],
    ["b", "It depends only on the size aspect, so the widget doesn't rebuild when unrelated values like keyboard insets or text scale change"],
    ["c", "It works without a MaterialApp"],
    ["d", "MediaQuery.of is deprecated and returns null"],
  ], ["b"], "MediaQuery.of subscribes to everything in MediaQueryData, so opening the keyboard (viewInsets) rebuilds every widget that read the size. sizeOf uses InheritedModel aspects to subscribe to size only.",
  ),

  M("m-setstate-order", "State", "order", "Put these steps in order for a tap that calls setState(() => count++).", [
    ["a", "build() runs and returns new widgets"],
    ["b", "Your callback runs (count becomes 1)"],
    ["c", "Layout and paint update the pixels"],
    ["d", "The element is marked dirty and a frame is scheduled"],
  ], ["b", "d", "a", "c"], "setState runs the callback synchronously, then markNeedsBuild marks the element dirty and asks the engine for a frame. On the next frame the framework rebuilds dirty elements, then lays out and paints what changed.",
  ),

  M("m-asyncgap", "Navigation", "single", "After `await repo.save()`, you call Navigator.of(context).pop(). The analyzer warns “Don't use BuildContext across async gaps”. What's the safe pattern?", [
    ["a", "Store context in a global variable before the await"],
    ["b", "Check `if (!context.mounted) return;` after the await, before using context"],
    ["c", "Use a Timer instead of await"],
    ["d", "Ignore the lint; it's only style"],
  ], ["b"], "While awaiting, the widget may have been removed. Its context then points to a detached element, and using it can crash or act on the wrong route. context.mounted tells you whether it's still in the tree.",
  ),

  // ───────────── Senior ─────────────
  S("s-eventloop", "Concurrency", "single", "What does this print?", [
    ["a", "A B C D E"], ["b", "A E B C D"], ["c", "A E C D B"], ["d", "A E D C B"],
  ], ["c"], "Synchronous code first: A, E. Then the microtask queue, in the order things were scheduled: C, then Future.value()'s completion, which runs its then-callback D. Only then the event queue, where Future(() …) lives: B.",
  `void main() {
  print('A');
  Future(() => print('B'));
  scheduleMicrotask(() => print('C'));
  Future.value().then((_) => print('D'));
  print('E');
}`),

  S("s-pipeline", "Rendering", "order", "Put the work for one frame in order.", [
    ["a", "Paint: record drawing commands into layers"],
    ["b", "Build: rebuild dirty elements"],
    ["c", "Rasterize: the raster thread turns layers into pixels on the GPU"],
    ["d", "Animate: tickers run and update animation values"],
    ["e", "Layout: compute sizes and positions"],
  ], ["d", "b", "e", "a", "c"], "On vsync the framework runs transient callbacks (animations), then the build, layout and paint phases on the UI thread, producing a layer tree. That tree is handed to the raster thread, which draws it with the GPU. A frame is late if either thread takes too long.",
  ),

  S("s-raster", "Performance", "single", "DevTools shows the UI thread at 4 ms per frame but the raster thread at 30 ms during a fade animation over a complex card list. Most likely cause?", [
    ["a", "Too many setState calls"],
    ["b", "GPU-heavy effects such as an Opacity or ShaderMask over a complex subtree (saveLayer), clipping, or oversized images"],
    ["c", "Slow JSON parsing"],
    ["d", "Too many StatelessWidgets"],
  ], ["b"], "The UI thread finished quickly, so build, layout and paint are fine. The cost is in rasterizing: saveLayer (used by Opacity on complex content, ShaderMask, some clips) renders offscreen and composites again. Use FadeTransition or opacity on simple layers, avoid clips where possible, and size images correctly.",
  ),

  S("s-impeller", "Performance", "single", "Users see stutter the first time an animation runs, but never again. With the Skia renderer, why? And what does Impeller change?", [
    ["a", "The Dart code is interpreted the first time; Impeller compiles it ahead of time"],
    ["b", "Shaders were compiled at runtime the first time they were needed; Impeller uses shaders compiled ahead of time, so there's no first-run compilation"],
    ["c", "Images were downloaded the first time; Impeller caches them"],
    ["d", "It's garbage collection; Impeller disables it"],
  ], ["b"], "First-run jank is the classic shader compilation problem: a new effect needs a GPU shader built on the spot, which can take longer than a frame. Impeller pre-compiles a smaller fixed set of shaders when the engine is built, removing that runtime step.",
  ),

  S("s-intrinsic", "Rendering", "single", "Why does the Flutter team call IntrinsicHeight expensive, especially when nested?", [
    ["a", "It allocates a new isolate"],
    ["b", "It asks children for their intrinsic size before the real layout, an extra layout-like pass; nesting multiplies it and can grow to O(n²) over depth"],
    ["c", "It disables the raster cache"],
    ["d", "It forces a repaint every frame"],
  ], ["b"], "Normal layout is a single pass: constraints down, sizes up. Intrinsics first query how big children would like to be, then lay them out. Each nested intrinsic widget repeats this for its subtree, which grows fast with depth.",
  ),

  S("s-relayout", "Rendering", "single", "A Text inside SizedBox(width: 200, height: 48) changes every second. Why doesn't this re-layout the whole page?", [
    ["a", "Text never needs layout"],
    ["b", "The SizedBox passes tight constraints, so its child is a relayout boundary: its size can't change, and layout stops there instead of going up to the parents"],
    ["c", "Flutter caches layouts for 1 second"],
    ["d", "Because SizedBox is const"],
  ], ["b"], "A render object becomes a relayout boundary when its parent can't be affected by its size: tight constraints, a parent that ignores the size, or sizedByParent. markNeedsLayout then stops at the boundary instead of walking up the tree.",
  ),

  S("s-paintonly", "Rendering", "multi", "A progress ring repaints 60 times a second next to a heavy static list. Which statements are true? Select all that apply.", [
    ["a", "Changing only a color calls markNeedsPaint, not markNeedsLayout"],
    ["b", "Wrapping the ring in a RepaintBoundary gives it its own layer, so the list isn't repainted every frame"],
    ["c", "Making the ring const stops it from animating"],
    ["d", "RepaintBoundary should wrap every widget for best speed"],
  ], ["a", "b"], "Paint-only changes skip layout. Without a boundary, repainting the ring can repaint everything sharing its layer. A RepaintBoundary isolates it. But each boundary costs memory and compositing, so add them where profiling shows frequent repaints, not everywhere.",
  ),

  S("s-globalkey", "Widgets & elements", "single", "A video player moves from a small card into a full-screen layout (a different parent) and playback restarts. How do you keep its State, and what does it cost?", [
    ["a", "Make it const; free"],
    ["b", "Give it the same GlobalKey in both places so the element and State are reparented; GlobalKeys are registered globally and reparenting is expensive, so use them sparingly"],
    ["c", "Use a ValueKey; free"],
    ["d", "Save the position in SharedPreferences"],
  ], ["b"], "Local keys only match among siblings of the same parent. A GlobalKey is unique across the app, so when it appears under a new parent in the same frame, the framework moves the existing element and State there instead of creating new ones.",
  ),

  S("s-isolate-memory", "Concurrency", "single", "Why can't two isolates share a List<Product> the way two threads share an object in Java?", [
    ["a", "They can, if the list is final"],
    ["b", "Each isolate has its own heap; messages are copied (except immutable or transferable data, and the result passed by Isolate.exit, which can be handed over without a copy)"],
    ["c", "Lists can't be sent at all"],
    ["d", "Isolates share memory, but Dart hides it"],
  ], ["b"], "Isolates don't share mutable memory, which is why Dart has no data races or locks for app code. SendPort copies the object graph. Isolate.exit can pass its final result without copying, and TransferableTypedData moves bytes cheaply.",
  ),

  S("s-leaks", "Performance", "multi", "Which of these leak memory (or cause “used after dispose” errors) if you forget the cleanup? Select all that apply.", [
    ["a", "appState.addListener(_onChange) in initState with no removeListener"],
    ["b", "A StreamSubscription that is never cancelled"],
    ["c", "Timer.periodic that is never cancelled"],
    ["d", "Using a const widget"],
    ["e", "context.read<T>() inside onPressed"],
  ], ["a", "b", "c"], "Each of the first three gives a long-lived object a callback that holds your State (and its context). After the screen closes, that object keeps the State alive and may call setState on it. Remove, cancel and dispose in dispose(). const widgets and read() hold nothing.",
  ),

  S("s-errors", "Architecture", "single", "You set FlutterError.onError to report errors to your crash tool, but errors thrown in async code outside widgets are still missing. What else is needed?", [
    ["a", "Nothing; FlutterError.onError catches everything"],
    ["b", "PlatformDispatcher.instance.onError, which receives uncaught asynchronous errors that the framework's handler doesn't see"],
    ["c", "Wrap every Future in try/catch"],
    ["d", "Run the app in debug mode"],
  ], ["b"], "FlutterError.onError catches errors the framework reports (build, layout, paint, gestures). Errors from Futures and Streams nobody handled go to the root zone, which PlatformDispatcher.instance.onError exposes. Production apps set both.",
  ),

  S("s-sealed", "Dart", "single", "PaymentState is a sealed class with Loading, Paid and Failed. A teammate adds Refunded. What happens to this switch?", [
    ["a", "It returns null for Refunded at runtime"],
    ["b", "It becomes a compile-time error because the switch is no longer exhaustive"],
    ["c", "It throws at runtime only when Refunded is used"],
    ["d", "Nothing; the default case handles it"],
  ], ["b"], "A sealed class's subtypes are all known to the compiler, so a switch expression over them must cover every case. Adding a subtype turns every incomplete switch into an error, so you can't forget a screen. Avoid adding `_ =>` to sealed switches, or you lose this check.",
  `Widget view(PaymentState s) => switch (s) {
  Loading() => const Spinner(),
  Paid(:final receipt) => ReceiptView(receipt),
  Failed(:final reason) => ErrorView(reason),
};`),

  S("s-treeshake", "Release", "single", "flutter build apk fails with “This application cannot tree shake icons fonts. It has non-constant instances of IconData”. Why?", [
    ["a", "The icon font file is missing"],
    ["b", "Icons are created at runtime from codes (e.g. IconData(server.code)), so the build can't know which glyphs to keep when it shrinks the icon font"],
    ["c", "MaterialIcons can't be used in release"],
    ["d", "Too many icons are used"],
  ], ["b"], "In release builds Flutter keeps only the glyphs your code references as constants, which cuts the font from hundreds of KB to a few. A runtime-built IconData defeats that analysis. Map server values to const Icons.x, or build with --no-tree-shake-icons and accept the size.",
  ),

  S("s-obfuscate", "Release", "single", "You build with --obfuscate --split-debug-info=build/symbols. Crash reports now show unreadable names. What must you do?", [
    ["a", "Rebuild without obfuscation"],
    ["b", "Keep the symbol files from that exact build and use them to symbolicate stack traces (flutter symbolize, or upload them to your crash tool)"],
    ["c", "Nothing; it can't be reversed"],
    ["d", "Enable ProGuard"],
  ], ["b"], "Obfuscation renames symbols, and split-debug-info moves the mapping out of the app into those files. They are tied to that build, so store them per release (CI artifacts). Without them, production stack traces can't be decoded.",
  ),

  S("s-clean", "Architecture", "single", "In clean architecture, the domain layer needs products. Where do the ProductRepository interface and its implementation live?", [
    ["a", "Both in the data layer"],
    ["b", "Interface in domain, implementation in data; domain depends on nothing outside it, so data depends on domain, not the other way round"],
    ["c", "Both in presentation"],
    ["d", "Interface in data, implementation in domain"],
  ], ["b"], "The dependency rule points inward. Domain declares what it needs (an abstract repository), and data provides it with Dio, Firebase or a database. You can then swap the backend or test the domain with a fake, without touching use cases.",
  ),

  S("s-restore", "Architecture", "single", "A user fills half a long form, switches to the camera app, and Android kills your app in the background. On return the form is empty. Which mechanism brings it back?", [
    ["a", "Hot restart"],
    ["b", "State restoration: restorationScopeId on the app, a RestorationMixin with restorationId, and Restorable values (e.g. RestorableTextEditingController)"],
    ["c", "AutomaticKeepAliveClientMixin"],
    ["d", "A GlobalKey on the form"],
  ], ["b"], "Keep-alive and keys only work while the process is alive. When the OS kills it, the State is gone. Restoration saves small bits of state into the OS-provided bundle and gives them back when the app is recreated.",
  ),

  S("s-model", "State management", "single", "A large AppSettings InheritedWidget holds theme, locale and 20 other values. Every dependent rebuilds when any one value changes. What fixes this without splitting it into many widgets?", [
    ["a", "Make it a GlobalKey"],
    ["b", "InheritedModel with aspects, so each dependent registers for the aspects it uses and is notified only when those change"],
    ["c", "Call setState less"],
    ["d", "Use getInheritedWidgetOfExactType everywhere"],
  ], ["b"], "InheritedModel adds updateShouldNotifyDependent, which gets the set of aspects each dependent asked for. MediaQuery.sizeOf works this way. Using get… instead would stop updates entirely.",
  ),

  S("s-concurrency", "State management", "single", "In a search Bloc, a slow response for “fl” arrives after the fast response for “flutter” and overwrites it. Why, and what's the usual fix?", [
    ["a", "Blocs process events strictly one at a time; increase the timeout"],
    ["b", "Bloc handles events concurrently by default, so older handlers can finish last; use a restartable() transformer (and a debounce) so a new query cancels the old one"],
    ["c", "Equatable compares wrong; remove it"],
    ["d", "Use setState instead of Bloc"],
  ], ["b"], "Since Bloc 8, on<Event> handlers run concurrently unless you give a transformer. For search you want the latest input to win: restartable() from bloc_concurrency cancels the in-flight handler, and debouncing avoids firing on every keystroke.",
  ),

  S("s-channels", "Platform", "single", "A MethodChannel handler on Android reads a 50 MB file before replying, and the app freezes and gets an ANR. Why?", [
    ["a", "Dart isolates are blocked by file I/O"],
    ["b", "Channel handlers run on the platform's main thread by default; do heavy work on a background thread and reply when done (or use a background task queue)"],
    ["c", "The codec can't send large data"],
    ["d", "MethodChannels only work on iOS"],
  ], ["b"], "Platform channel calls arrive on Android's main (UI) thread. Blocking it freezes the whole app and triggers Application Not Responding. Move the work off the main thread, then send the result back; reply on the platform thread.",
  ),

  S("s-golden", "Testing", "single", "Golden tests pass on developers' Macs and fail on Linux CI with tiny pixel differences in text. Why, and what's the usual fix?", [
    ["a", "CI screens are smaller"],
    ["b", "Text rendering and fonts differ between operating systems; generate and compare goldens in one environment (e.g. CI or a container) and load real fonts in tests"],
    ["c", "Golden tests can't run on Linux"],
    ["d", "Increase the test timeout"],
  ], ["b"], "Goldens compare exact pixels, and font hinting, antialiasing and the default test font vary by platform. Teams pick one source of truth (often CI), regenerate goldens there, and load the app's fonts so text isn't the fallback test font.",
  ),
];

export const byId = new Map(QUESTIONS.map(x => [x.id, x]));
export const levelInfo = (id: string) => LEVELS.find(l => l.id === id);

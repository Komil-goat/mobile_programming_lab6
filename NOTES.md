# Lab Notes: Real-Time Data Ticker with AsyncValue

## Part 2 — Model and stream provider

### 1. Why is the feed behind its own Provider instead of being constructed inside tickerProvider?
- **Testability and Overriding**: It allows mocking or overriding `tickFeedProvider` in tests and demos (e.g. `tickFeedProvider.overrideWithValue(...)`) without modifying or reconstructing `tickerProvider`.
- **Separation of Concerns**: `TickFeed` handles data generation and network simulation, while `tickerProvider` manages reactive stream state and UI subscription lifecycle.
- **Dynamic Configuration**: It allows `tickFeedProvider` to reactively watch configuration providers (like `failAfterProvider`) and re-instantiate or reconfigure the feed when parameters change.

### 2. What does autoDispose do when the user navigates away mid-stream?
- When the screen unmounts and there are no active listeners, Riverpod automatically cancels the stream subscription and disposes `tickerProvider`.
- Disposing cancels the underlying `StreamSubscription`, stopping the async generator (`async*`) loop and timer to prevent memory leaks and wasted CPU cycles.
- When the user navigates back to the screen, Riverpod creates a fresh instance of the provider and stream.

### 3. What AsyncValue does tickerProvider hold during the 800 ms delay, and what is hasValue at that moment?
- **AsyncValue**: `AsyncLoading<List<Tick>>()`
- **hasValue**: `false` (no data has been emitted yet).

---

## Part 3 — Ticker UI with AsyncValue pattern matching

### Exercise 3.3: Break the switch on purpose
When commenting out the `AsyncLoading()` arm, `flutter analyze` produces the following exact diagnostic:
```
error • The type 'AsyncValue<List<Tick>>' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'AsyncLoading<List<Tick>>()'. Try adding a wildcard pattern or cases that match 'AsyncLoading<List<Tick>>()' • lib/ticker_page.dart:14:13 • non_exhaustive_switch_expression
```
**Compile-time guarantee**: Because `AsyncValue` is a sealed class hierarchy in Dart 3, switch expressions are checked for exhaustiveness at compile time. If any subtype or unhandled condition is missing, compilation fails immediately, preventing unhandled runtime states.

### Exercise 3.4: Pattern-match on content, not just state
- **Why must the specific arms (`AsyncData(value: [])` and `AsyncData(value: [final only])`) come before the general `AsyncData(:final value)` arm?**
  In Dart switch expressions, pattern evaluation happens sequentially from top to bottom, choosing the first arm that matches. The general arm `AsyncData(:final value)` matches *any* `AsyncData` holding a `List<Tick>` (including empty lists and single-element lists). If placed above the specialized arms, it would shadow them and the specialized arms would never be reached (dead code).

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

---

## Part 4 — Errors, retry, and preserving previous data

### Exercise 4.3: Refresh vs Invalidate
- **Which one keeps previous rows visible during reload?**
  Both keep previous data in `AsyncValue.value` while `isLoading` becomes `true`. However, `ref.refresh(tickerProvider.future)` forces an immediate refresh and returns a `Future` that completes when the new data arrives. In contrast, `ref.invalidate(tickerProvider)` marks the provider as dirty, triggering a lazy recomputation on the next read/listener notification, and returns `void`.
- **Why does `refresh(...future)` return something awaitable?**
  `RefreshIndicator.onRefresh` requires a `Future<void> Function()` so it knows when the asynchronous refresh operation has finished in order to dismiss its loading spinner. By returning `tickerProvider.future`, `RefreshIndicator` stays active until the new stream emits its first tick.

### Exercise 4.4: Distinguish a reconnect from a first load
- **Full-screen spinner prevention**:
  The pattern arm `AsyncValue(:final value?, isLoading: true)` matches any loading state where `value` is non-null (i.e. previously loaded data exists). Because this arm sits above the general `AsyncLoading()` arm, reconnects and retries display previous data (e.g. with a top progress bar or dimmed list) rather than showing the cold-start full-screen spinner.
- **Difference between `isRefreshing` and `isReloading` on AsyncValue**:
  `isRefreshing` indicates whether the provider is actively re-evaluating while retaining either a previous value or a previous error (covers both `ref.refresh` and re-execution with old state), whereas `isReloading` indicates whether an `AsyncData` or `AsyncError` specifically is in a loading state while keeping its previous data (it is false if there was only a previous error).

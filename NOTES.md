# Lab Notes: Real-Time Data Ticker with AsyncValue

---

## Part 2 — Model and Stream Provider

### 1. Why is the feed behind its own Provider instead of being constructed inside tickerProvider?
- **Testability and Dependency Injection**: Putting `TickFeed` in `tickFeedProvider` allows tests and demonstrations to override it via `tickFeedProvider.overrideWithValue(...)` or `overrideWith(...)` without altering the logic of `tickerProvider`.
- **Separation of Concerns**: `TickFeed` handles data generation, pricing simulation, and network-like failure behaviors. `tickerProvider` is purely responsible for managing reactive state lifecycle and streaming the data to listeners.
- **Dynamic Configuration**: It allows `tickFeedProvider` to watch configuration providers (such as `failAfterProvider`) so that when configuration changes, Riverpod automatically recreates or updates the feed.

### 2. What does autoDispose do when the user navigates away mid-stream?
- **Cancels Stream Subscriptions**: When all UI listeners unmount and the listener count drops to zero, Riverpod disposes `tickerProvider`.
- **Frees Resources**: Disposing cancels the underlying `StreamSubscription`, immediately pausing or stopping the `async*` generator loop and preventing timers or memory leaks from running in the background.
- **Fresh Initialization**: When the user navigates back to the screen later, `tickerProvider` is instantiated anew with a clean stream.

### 3. What AsyncValue does tickerProvider hold during the 800 ms delay, and what is hasValue at that moment?
- **AsyncValue**: `AsyncLoading<List<Tick>>()`
- **hasValue**: `false` (no initial tick data has been emitted yet).

---

## Part 3 — Ticker UI with AsyncValue Pattern Matching

### Exercise 3.3: Break the switch on purpose
When the `AsyncLoading()` arm is omitted from the switch expression:
```dart
      body: switch (ticks) {
        AsyncData(:final value) => ListView(...),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        // AsyncLoading() => const Center(child: CircularProgressIndicator()),
      }
```
`flutter analyze` reports the following exact diagnostic:
```
error • The type 'AsyncValue<List<Tick>>' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'AsyncLoading<List<Tick>>()'. Try adding a wildcard pattern or cases that match 'AsyncLoading<List<Tick>>()' • lib/ticker_page.dart:14:13 • non_exhaustive_switch_expression
```
**Compile-time guarantee**: Dart 3 sealed class hierarchy guarantees compile-time exhaustiveness checking. If a developer forgets to handle any subtype (like `AsyncLoading`), the compiler refuses to build the application, eliminating unhandled state crashes at runtime.

### Exercise 3.4: Pattern-match on content, not just state
- **Arms added**:
  ```dart
  AsyncData(value: []) => const Center(child: Text('No symbols subscribed')),
  AsyncData(value: [final only]) => Center(child: TickRow(only)),
  AsyncData(:final value) => ListView(...),
  ```
- **Why must specific arms come before the general `AsyncData(:final value)` arm?**
  Dart switch expressions evaluate patterns sequentially from top to bottom and select the first arm whose pattern matches. Because `AsyncData(:final value)` matches any list (including empty and single-element lists), placing it first would shadow the more specific patterns, making them unreachable dead code.

---

## Part 4 — Errors, Retry, and Preserving Previous Data

### Exercise 4.3: Refresh vs Invalidate
- **Which one keeps the previous rows visible during reload?**
  Both keep the previous rows visible when matched with `AsyncValue(:final value?, isLoading: true)`. However, `ref.refresh(tickerProvider.future)` immediately triggers a refresh and returns a `Future<List<Tick>>` representing completion of the next emission. On the other hand, `ref.invalidate(tickerProvider)` marks the provider as outdated/dirty and returns `void`.
- **Why does `refresh(...future)` return something awaitable?**
  `RefreshIndicator.onRefresh` requires a `Future<void> Function()`. By returning `tickerProvider.future`, `RefreshIndicator` remains in its refreshing state until the provider emits its next value, dismissing the spinner only when the operation completes.

### Exercise 4.4: Distinguish a reconnect from a first load
- **Preventing full-screen spinner on retry**:
  Because `AsyncValue(:final value?, isLoading: true)` matches any loading state with previously cached non-null data and sits above `AsyncLoading()`, retries and reconnects display the existing list (with a progress indicator or dimmed rows) rather than dropping into the cold-start full-screen spinner.
- **Difference between `isRefreshing` and `isReloading`**:
  `isRefreshing` is true whenever a provider is being re-evaluated while retaining either previous data or a previous error (e.g. after `ref.refresh` or invalidation), whereas `isReloading` is true specifically when an `AsyncData` or `AsyncError` is in a loading state while retaining previous valid data (`hasValue == true`).

---

## Checkpoint Questions

### 1. Which three subtypes make AsyncValue sealed, and what does the analyzer report when a switch expression misses one?
- **Subtypes**: `AsyncData<T>`, `AsyncLoading<T>`, and `AsyncError<T>`.
- **Analyzer report**: The analyzer reports a `non_exhaustive_switch_expression` error stating that the type `AsyncValue<T>` isn't exhaustively matched because it doesn't match the missing subtype pattern (for example: `The type 'AsyncValue<List<Tick>>' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'AsyncLoading<List<Tick>>()'`).

### 2. When does AsyncError.value carry a non-null value, and when is it null?
- `AsyncError.value` carries a **non-null value** when the provider previously completed successfully and emitted valid data, and then subsequently encountered an error during a refresh or stream update (preserving stale data).
- `AsyncError.value` is **null** (or throws when `hasValue == false`) on a cold start failure where the provider encountered an error on its initial execution before any valid data was ever produced.

### 3. What is the difference between ref.refresh(provider), ref.refresh(provider.future), and ref.invalidate(provider)?
- `ref.refresh(provider)`: Forces the provider to dispose immediately, recomputes it synchronously/starts a new evaluation, and returns the newly created value/state (`AsyncValue<T>`).
- `ref.refresh(provider.future)`: Equivalent to refreshing the provider, but specifically returns the `Future<T>` of the next resolved data, making it directly awaitable (ideal for `RefreshIndicator`).
- `ref.invalidate(provider)`: Marks the provider as dirty without instantly recomputing it. The provider is lazily recomputed on the next read or microtask, and the call returns `void`.

### 4. Why does AsyncValue(:final value?, isLoading: true) need to sit above AsyncData(:final value)?
- In Dart pattern matching, evaluation proceeds from top to bottom.
- When an `AsyncData` is refreshing or reloading, it still has `value != null`, but `isLoading` is also `true`.
- If `AsyncData(:final value)` were placed first, it would match any `AsyncData` regardless of its loading flag, swallowing the reloading state and preventing the loading indicator / progress bar from rendering.

### 5. Give one reason to prefer switch expressions over .when(...) for AsyncValue, and one situation where .when is still convenient?
- **Reason to prefer switch expressions**: Switch expressions support deep Dart 3 pattern matching, object destructuring, guards, and content-based pattern matching (e.g. matching empty lists `AsyncData(value: [])`, single elements `AsyncData(value: [final only])`, or specific error types like `AsyncError(error: FeedException())`). They are also checked directly by the compiler with zero function-call overhead.
- **Situation where `.when(...)` is convenient**: When handling simple, standard three-state rendering (`data`, `error`, `loading`) with named parameters without needing sub-pattern matching, or when using `.whenOrNull` / `.maybeWhen` to handle only one or two specific states while falling back to a default value.

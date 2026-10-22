Lab Notes

1. Why is the feed behind its own Provider instead of being constructed inside tickerProvider?
- Testability and Overriding: It allows mocking or overriding tickFeedProvider in tests and demos (e.g. tickFeedProvider.overrideWithValue(...)) without touching tickerProvider.
- Separation of Concerns: TickFeed handles data generation, while tickerProvider manages reactive stream state and UI subscription.
- Dynamic Configuration: It lets tickFeedProvider watch configuration providers (like failAfterProvider) and recreate the feed when settings change.

2. What does autoDispose do when the user navigates away mid-stream?
- When the screen unmounts and there are no active listeners, Riverpod automatically disposes tickerProvider.
- Disposing it cancels the underlying stream subscription, stopping the timer and async* generator loop to prevent memory and CPU leaks.
- When the user navigates back, the provider initializes a fresh stream.

3. What AsyncValue does tickerProvider hold during the 800 ms delay, and what is hasValue at that moment?
- AsyncValue: AsyncLoading<List<Tick>>()
- hasValue: false (no data has been emitted yet).

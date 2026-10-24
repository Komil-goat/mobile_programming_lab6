import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/tick.dart';
import '../services/tick_feed.dart';

/// Configurable failure threshold for demos and tests.
final failAfterProvider = StateProvider<int?>((ref) => null);

/// Overridable in tests and in the error demo.
final tickFeedProvider = Provider<TickFeed>((ref) {
  return TickFeed(failAfter: ref.watch(failAfterProvider));
});

final tickerProvider = StreamProvider.autoDispose<List<Tick>>((ref) {
  return ref.watch(tickFeedProvider).watch();
});
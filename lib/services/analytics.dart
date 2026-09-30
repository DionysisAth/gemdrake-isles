import 'package:flutter/foundation.dart';

/// Minimal analytics interface. The MVP logs locally; swap in Firebase
/// Analytics, GameAnalytics etc. by implementing [log].
abstract class Analytics {
  void log(String event, [Map<String, Object?> params = const {}]);
}

/// Keeps the most recent events in memory and prints them in debug builds.
class LocalAnalytics implements Analytics {
  LocalAnalytics({this.capacity = 200});

  final int capacity;
  final List<(DateTime, String, Map<String, Object?>)> events = [];

  @override
  void log(String event, [Map<String, Object?> params = const {}]) {
    events.add((DateTime.now(), event, params));
    if (events.length > capacity) events.removeAt(0);
    if (kDebugMode) debugPrint('[analytics] $event $params');
  }
}

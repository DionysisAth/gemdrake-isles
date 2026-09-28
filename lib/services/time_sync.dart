import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Free "trusted time": reads the Date header of a well-known HTTPS server
/// and remembers how far the device clock is off. Without a network the
/// device clock is used as is.
class TimeSync {
  TimeSync._();

  /// Added to the device clock by the game's clock.
  static Duration offset = Duration.zero;

  static DateTime now() => DateTime.now().add(offset);

  static Future<void> sync(String url) async {
    if (url.isEmpty) return;
    try {
      final sent = DateTime.now();
      final res = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      final date = res.headers['date'];
      if (date == null) return;
      final server = _parseHttpDate(date);
      if (server == null) return;
      final local = sent.add(DateTime.now().difference(sent) ~/ 2);
      final diff = server.difference(local);
      // The header has 1-second precision; ignore small differences.
      offset = diff.abs() > const Duration(minutes: 2) ? diff : Duration.zero;
    } catch (e) {
      debugPrint('Time check failed: $e');
    }
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Parses an RFC 1123 date such as `Sun, 28 Sep 2026 17:45:12 GMT`.
  @visibleForTesting
  static DateTime? parseHttpDate(String s) => _parseHttpDate(s);

  static DateTime? _parseHttpDate(String s) {
    final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})')
        .firstMatch(s);
    if (m == null) return null;
    final month = _months.indexOf(m.group(2)!) + 1;
    if (month == 0) return null;
    return DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }
}

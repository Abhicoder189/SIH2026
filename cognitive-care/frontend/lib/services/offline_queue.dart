import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Stores completed game events locally until a connection is available.
class OfflineQueue {
  static const _attemptKey = 'pending_attempts_v1';

  static Future<void> enqueueAttempt(Map<String, dynamic> attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _read(prefs);
    attempt['client_event_id'] ??= '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    items.add(attempt);
    await prefs.setString(_attemptKey, jsonEncode(items));
  }

  static Future<int> sync(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _read(prefs);
    final unsynced = <Map<String, dynamic>>[];
    var count = 0;
    for (final event in pending) {
      try {
        await ApiService.syncAttempt(token, event);
        count++;
      } catch (_) {
        unsynced.add(event);
      }
    }
    await prefs.setString(_attemptKey, jsonEncode(unsynced));
    return count;
  }

  static List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_attemptKey);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((item) => Map<String, dynamic>.from(item as Map)),
      );
    } catch (_) {
      return [];
    }
  }
}

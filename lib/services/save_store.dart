import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the game state. Local only for the MVP; a cloud implementation
/// (Firebase / PlayFab) can sit behind the same interface.
abstract class SaveStore {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> data);
  Future<void> clear();
}

class PrefsSaveStore implements SaveStore {
  static const _key = 'gemdrake_isles_save_v1';

  @override
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class MemorySaveStore implements SaveStore {
  Map<String, dynamic>? data;
  int saves = 0;

  @override
  Future<Map<String, dynamic>?> load() async => data == null
      ? null
      : jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

  @override
  Future<void> save(Map<String, dynamic> d) async {
    data = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
    saves++;
  }

  @override
  Future<void> clear() async => data = null;
}

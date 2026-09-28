import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/game_config.dart';

/// Free remote config: the same JSON files as `assets/config/`, hosted on
/// any static web host (GitHub Pages, a public bucket...). Files fetched
/// this launch are used from the next launch on, so a change never
/// switches rules mid-game. A file that fails to parse is ignored.
class RemoteConfig {
  RemoteConfig._();

  static const _prefix = 'remote_config_';

  static Future<GameConfig> load(AssetBundle bundle) async {
    final bundled = await GameConfig.loadJson(bundle);
    final url = ServicesConfig(bundled['services']!).remoteConfigUrl;
    if (url.isEmpty) return GameConfig.fromJson(bundled);
    try {
      final prefs = await SharedPreferences.getInstance();
      final merged = {...bundled};
      for (final name in GameConfig.files) {
        if (name == 'services') continue;
        final cached = prefs.getString('$_prefix$name');
        if (cached != null) {
          merged[name] = jsonDecode(cached) as Map<String, dynamic>;
        }
      }
      return GameConfig.fromJson(merged);
    } catch (e) {
      debugPrint('Remote config ignored: $e');
      return GameConfig.fromJson(bundled);
    }
  }

  /// Downloads the latest files for the next launch.
  static Future<void> refresh(AssetBundle bundle, String url) async {
    if (url.isEmpty) return;
    try {
      final bundled = await GameConfig.loadJson(bundle);
      final prefs = await SharedPreferences.getInstance();
      for (final name in GameConfig.files) {
        if (name == 'services') continue;
        final res = await http
            .get(Uri.parse('$url/$name.json'))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        // Only keep a file the game can actually read.
        GameConfig.fromJson({...bundled, name: json});
        await prefs.setString('$_prefix$name', res.body);
      }
    } catch (e) {
      debugPrint('Remote config refresh failed: $e');
    }
  }
}

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The languages the game is translated into, with their own names.
const languages = {
  'en': 'English',
  'de': 'Deutsch',
  'el': 'Ελληνικά',
  'es': 'Español',
  'fr': 'Français',
  'id': 'Bahasa Indonesia',
  'it': 'Italiano',
  'ja': '日本語',
  'ko': '한국어',
  'pl': 'Polski',
  'pt': 'Português',
  'ru': 'Русский',
  'tr': 'Türkçe',
  'zh': '简体中文',
};

/// The game's current language. Texts are written in English in the code
/// and the config files; `assets/i18n/<code>.json` maps each English text
/// to its translation. A text without a translation stays in English.
class L10n {
  L10n._();

  /// Language code in use. Listen to it to redraw after a change.
  static final current = ValueNotifier<String>('en');
  static Map<String, String> _table = const {};

  static String get code => current.value;

  /// The first of the phone's languages that the game has, else English.
  static String systemLanguage([List<Locale>? locales]) {
    locales ??= PlatformDispatcher.instance.locales;
    for (final l in locales) {
      // Older Android versions report Indonesian as "in".
      final code = l.languageCode == 'in' ? 'id' : l.languageCode;
      if (languages.containsKey(code)) return code;
    }
    return 'en';
  }

  /// Switches to [code] (a key of [languages]); null means the phone's
  /// language.
  static Future<void> use(String? code, {AssetBundle? bundle}) async {
    code ??= systemLanguage();
    if (!languages.containsKey(code)) code = 'en';
    var table = const <String, String>{};
    if (code != 'en') {
      try {
        final raw = await (bundle ?? rootBundle).loadString(
          'assets/i18n/$code.json',
        );
        table = (jsonDecode(raw) as Map<String, dynamic>).cast();
      } catch (e) {
        debugPrint('Translations for $code failed: $e');
        code = 'en';
      }
    }
    _table = table;
    current.value = code;
  }

  /// Uses [table] directly (tests).
  @visibleForTesting
  static void useTable(String code, Map<String, String> table) {
    _table = table;
    current.value = code;
  }
}

/// [en] in the current language, with each `{name}` replaced by
/// `args['name']`.
String tr(String en, [Map<String, Object?> args = const {}]) {
  var s = L10n._table[en] ?? en;
  if (s.isEmpty) s = en;
  for (final MapEntry(:key, :value) in args.entries) {
    s = s.replaceAll('{$key}', '$value');
  }
  return s;
}

/// "Baby Fire Dragon" in the current language.
String dragonName(String level, String type) =>
    tr('{level} {type} Dragon', {'level': level, 'type': type});

/// Uppercase as each language writes it: Greek drops its accents, Turkish
/// keeps the dot on İ.
String upper(String s) {
  switch (L10n.code) {
    case 'el':
      const plain = {
        'ά': 'α',
        'έ': 'ε',
        'ή': 'η',
        'ί': 'ι',
        'ό': 'ο',
        'ύ': 'υ',
        'ώ': 'ω',
        'ΐ': 'ϊ',
        'ΰ': 'ϋ',
        'Ά': 'Α',
        'Έ': 'Ε',
        'Ή': 'Η',
        'Ί': 'Ι',
        'Ό': 'Ο',
        'Ύ': 'Υ',
        'Ώ': 'Ω',
      };
      s = s.split('').map((c) => plain[c] ?? c).join();
    case 'tr':
      s = s.replaceAll('i', 'İ');
  }
  return s.toUpperCase();
}

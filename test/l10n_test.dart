// Translations: language choice, lookups, and every screen in every
// language without text overflowing. With SHOTS=dir it also saves
// screenshots of each screen.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/l10n/strings.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/services/ads_service.dart';
import 'package:gemdrake_isles/ui/app.dart';
import 'package:gemdrake_isles/ui/dialogs/dialogs.dart';
import 'package:gemdrake_isles/ui/dialogs/meta_dialogs.dart';
import 'package:gemdrake_isles/ui/screens/home_shell.dart';

import 'helpers.dart';

Map<String, String> table(String code) =>
    (jsonDecode(File('assets/i18n/$code.json').readAsStringSync()) as Map)
        .cast();

Future<void> loadFonts() async {
  for (final (family, file) in [
    ('Fredoka', 'Fredoka'),
    ('MPlusRounded', 'MPlusRounded'),
  ]) {
    final loader = FontLoader(family);
    for (final w in [400, 500, 600, 700]) {
      final bytes = File('assets/fonts/$file-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(loadFonts);
  tearDown(() => L10n.useTable('en', const {}));

  test('every language has a translation file', () {
    for (final code in languages.keys.where((c) => c != 'en')) {
      expect(File('assets/i18n/$code.json').existsSync(), isTrue, reason: code);
    }
  });

  test('picks the first phone language the game has', () {
    expect(L10n.systemLanguage(const [Locale('el', 'GR')]), 'el');
    expect(
      L10n.systemLanguage(const [Locale('sv'), Locale('de', 'AT')]),
      'de',
    );
    expect(L10n.systemLanguage(const [Locale('in')]), 'id');
    expect(L10n.systemLanguage(const [Locale('zh', 'TW')]), 'zh');
    expect(L10n.systemLanguage(const [Locale('sv')]), 'en');
    expect(L10n.systemLanguage(const []), 'en');
  });

  test('tr translates, fills placeholders and falls back to English', () {
    L10n.useTable('el', {'Level {n}!': 'Επίπεδο {n}!'});
    expect(tr('Level {n}!', {'n': 5}), 'Επίπεδο 5!');
    expect(tr('Not translated'), 'Not translated');
  });

  test('config texts follow the language', () {
    final config = loadConfig();
    L10n.useTable('el', table('el'));
    expect(config.dragonType('fire').name, isNot('Fire'));
    L10n.useTable('en', const {});
    expect(config.dragonType('fire').name, 'Fire');
  });

  for (final code in languages.keys) {
    testWidgets('screens fit in $code', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340); // a 6.4" phone
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      L10n.useTable(code, code == 'en' ? const {} : table(code));
      final game = newController();
      game.state.loginClaimedDay = game.today;
      game.state.level = 12;
      game.state.dragons.addAll([
        Dragon(id: 900, type: 'fire', level: 2),
        Dragon(id: 901, type: 'earth', level: 1),
      ]);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: GemdrakeApp(game: game, ads: SimulatedAdsService(seconds: 0)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final shots = Platform.environment['SHOTS'];
      Future<void> snap(String name) async {
        if (shots == null) return;
        await tester.runAsync(() async {
          final ro =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await ro.toImage(pixelRatio: 2);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$shots/${code}_$name.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
      }

      BuildContext ctx() => tester.element(find.byType(HomeShell));
      Future<void> dialog(String name, void Function(BuildContext) open) async {
        open(ctx());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await snap(name);
        Navigator.of(ctx(), rootNavigator: true).pop();
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> tab(String label, String name) async {
        await tester.tap(find.text(tr(label)).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await snap(name);
      }

      await snap('board');
      await tab('Island', 'island');
      await tester.tap(find.text(tr('Dragons ({n})', {'n': 2})));
      await tester.pump(const Duration(milliseconds: 600));
      await snap('dragons');
      await tab('Festival', 'festival');
      await tab('Book', 'book');
      await tester.tap(find.text(tr('Achievements')).first);
      await tester.pump(const Duration(milliseconds: 400));
      await snap('achievements');
      await tab('Board', 'board2');

      await dialog('settings', showSettings);
      await dialog('languages', showLanguages);
      await dialog('shop', showShop);
      await dialog('daily', showDaily);
      await dialog('energy', showOutOfEnergy);
      await dialog('backup', showBackup);
      await dialog(
        'welcome',
        (c) => showWelcomeBack(
          c,
          WelcomeBack(const Duration(hours: 3, minutes: 12), 4200, 3),
        ),
      );
      await dialog(
        'levelup',
        (c) => showLevelUp(c, 12, 5, [tr('Daily tasks'), 'Pip']),
      );
      await dialog('hatch', (c) => showHatch(c, [game.state.dragons.first]));
      await dialog(
        'task',
        (c) => showTaskComplete(c, game.currentIsland.tasks.first, false),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}

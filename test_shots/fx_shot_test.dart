// Renders the app to PNGs at moments of a big merge (visual check only).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/model/item_ref.dart';
import 'package:gemdrake_isles/services/ads_service.dart';
import 'package:gemdrake_isles/ui/app.dart';
import 'package:gemdrake_isles/ui/dialogs/dialogs.dart';
import 'package:gemdrake_isles/ui/dialogs/meta_dialogs.dart';
import 'package:gemdrake_isles/ui/screens/home_shell.dart';

import '../test/helpers.dart';

Future<void> loadFonts() async {
  final loader = FontLoader('Fredoka');
  for (final w in [400, 500, 600, 700]) {
    final bytes = File('assets/fonts/Fredoka-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  final f = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (f.existsSync()) {
    icons.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await icons.load();
  }
}

Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('${Platform.environment['SHOTS'] ?? '/tmp'}/$name.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadFonts);

  testWidgets('shots', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    final game = newController();
    game.state.loginClaimedDay = game.today;
    final b = game.state.board;
    for (final (i, item) in [(39, 'gem:6'), (40, 'gem:6'), (45, 'plant:2'), (46, 'plant:2')]) {
      b.cells[i] = Piece.item(90000 + i, ItemRef.parse(item));
      b.locks[i] = null;
    }
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: GemdrakeApp(game: game, ads: SimulatedAdsService(seconds: 0)),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await snap(tester, key, 'fx_0');
    game.drop(const Slot.board(40), const Slot.board(39));
    for (final ms in [60, 140, 250, 450]) {
      await tester.pump(Duration(milliseconds: ms == 60 ? 60 : ms - [60, 140, 250, 450][[60, 140, 250, 450].indexOf(ms) - 1]));
      await snap(tester, key, 'fx_$ms');
    }
    await tester.pump(const Duration(seconds: 2));
    game.drop(const Slot.board(46), const Slot.board(45));
    await tester.pump(const Duration(milliseconds: 120));
    await snap(tester, key, 'fx_small');
    await tester.pump(const Duration(seconds: 2));
    // Dialogs
    final ctx = tester.element(find.byType(HomeShell));
    showLevelUp(ctx, 9, 3, ['Ember Forge', 'Tools in orders']);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await snap(tester, key, 'dlg_level');
    Navigator.of(ctx).pop();
    await tester.pump(const Duration(milliseconds: 400));
    showShop(ctx);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await snap(tester, key, 'dlg_shop');
    Navigator.of(ctx).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}

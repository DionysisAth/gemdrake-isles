import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/model/item_ref.dart';
import 'package:gemdrake_isles/services/ads_service.dart';
import 'package:gemdrake_isles/ui/app.dart';

import 'helpers.dart';

void main() {
  // Real font metrics, so layout overflows show up like on a phone.
  setUpAll(() async {
    final loader = FontLoader('Fredoka');
    for (final w in [400, 500, 600, 700]) {
      final bytes = File('assets/fonts/Fredoka-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    bool tutorial = false,
    bool dailyPopup = false,
    void Function(GameStateSetup s)? setup,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532); // iPhone 13-ish
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final game = newController(skipTutorial: !tutorial);
    if (!dailyPopup) game.state.loginClaimedDay = game.today;
    setup?.call(GameStateSetup(game.state));
    await tester.pumpWidget(
      GemdrakeApp(game: game, ads: SimulatedAdsService(seconds: 0)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('board, orders and HUD render', (tester) async {
    await pumpGame(tester);
    expect(find.text('Board'), findsOneWidget);
    expect(find.text('Island'), findsOneWidget);
    expect(find.text('Pip'), findsWidgets);
    expect(find.text('Tip'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tutorial shows the first speech bubble', (tester) async {
    await pumpGame(tester, tutorial: true);
    expect(
      find.textContaining('Welcome to the Gemdrake Isles'),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('Welcome to the Gemdrake Isles'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Tap the Crystal Mine'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('island tab shows restoration tasks and dragons', (tester) async {
    await pumpGame(
      tester,
      setup: (s) {
        s.state.dragons.add(Dragon(id: 999, type: 'fire', level: 2));
        s.state.board.cells[s.state.board.index(3, 4)] = Piece.item(
          998,
          const ItemRef('gem', 2),
        );
      },
    );
    await tester.tap(find.text('Island'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Meadow Ruins'),
      findsWidgets,
    ); // outlined text draws twice
    expect(find.text('Clear the Vines'), findsOneWidget);
    await tester.tap(find.text('Dragons (1)'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Young'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('settings dialog opens', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reward odds'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('daily gift pops up on launch and can be collected', (
    tester,
  ) async {
    await pumpGame(tester, dailyPopup: true);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("Collect today's gift"), findsOneWidget);
    await tester.tap(find.text("Collect today's gift"));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("Collect today's gift"), findsNothing);
    await unmount(tester);
  });

  testWidgets('festival, book and shop screens render', (tester) async {
    await pumpGame(tester, setup: (s) => s.state.level = 6);
    await tester.tap(find.text('Festival'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Play festival board'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    await tester.tap(find.text('Play festival board'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Island board'), findsOneWidget);
    await tester.tap(find.text('Book'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Dragon Book'), findsWidgets);
    await tester.tap(find.byTooltip('Daily'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Daily tasks'), findsOneWidget);
    await unmount(tester);
  });
}

class GameStateSetup {
  GameStateSetup(this.state);
  final GameState state;
}

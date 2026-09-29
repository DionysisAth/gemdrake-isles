// Renders every island theme (ruined, half and fully restored) and the
// board to PNGs (visual check only).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/services/ads_service.dart';
import 'package:gemdrake_isles/ui/app.dart';
import 'package:gemdrake_isles/ui/painters/island_painter.dart';
import 'package:gemdrake_isles/ui/painters/sky_painter.dart';

import '../test/helpers.dart';
import 'fx_shot_test.dart' show loadFonts, snap;

const _elements = [
  'vines',
  'bridge',
  'well',
  'garden',
  'nest',
  'shed',
  'tower',
  'windmill',
  'lanterns',
  'shrine',
];

void main() {
  setUpAll(loadFonts);

  testWidgets('islands', (tester) async {
    tester.view.physicalSize = const Size(780, 1000);
    tester.view.devicePixelRatio = 2;
    for (final theme in ['meadow', 'volcano', 'lagoon', 'crystal', 'shadow']) {
      for (final done in [0, 5, 10]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: Stack(
              textDirection: TextDirection.ltr,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: SkyPainter()),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 30, 8, 0),
                    child: CustomPaint(
                      painter: IslandPainter(
                        progress: {
                          for (final (i, e) in _elements.indexed)
                            e: i < done ? 1.0 : 0.0,
                        },
                        time: 3,
                        theme: theme,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await snap(tester, key, 'island_${theme}_$done');
      }
    }
  });

  testWidgets('board', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    for (final island in [0, 1, 2, 3, 4]) {
      final game = newController();
      game.state.loginClaimedDay = game.today;
      game.state.island = island;
      // Unlock most cells so the tiles show.
      final b = game.state.board;
      for (var i = 0; i < b.locks.length; i++) {
        if (i % 7 != 0) b.locks[i] = null;
      }
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: GemdrakeApp(game: game, ads: SimulatedAdsService(seconds: 0)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await snap(tester, key, 'board_$island');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }
  });
}

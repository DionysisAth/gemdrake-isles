// Renders every dragon type at every level to PNGs (visual check only).
//
//     SHOTS=build/shots flutter test test_shots/dragon_shot_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/ui/painters/dragon_painter.dart';

import '../test/helpers.dart';
import 'fx_shot_test.dart' show snap;

void main() {
  testWidgets('dragons', (tester) async {
    final config = loadConfig();
    final types = config.dragons.types;
    const cell = 150.0;
    tester.view.physicalSize = Size(cell * 5 * 2, cell * types.length * 2);
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            color: const Color(0xFFFFF4DC),
            child: Column(
              children: [
                for (final t in types)
                  Row(
                    children: [
                      for (var l = 1; l <= 5; l++)
                        CustomPaint(
                          size: const Size.square(cell),
                          painter: DragonPainter(type: t, level: l, flap: .4),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await snap(tester, key, 'dragons');

    // Small, as on the board, and blinking / silhouette variants.
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            color: const Color(0xFFE8D9B5),
            child: Wrap(
              children: [
                for (final t in types)
                  for (final l in [1, 3, 5])
                    CustomPaint(
                      size: const Size.square(48),
                      painter: DragonPainter(type: t, level: l),
                    ),
                for (final l in [1, 5])
                  CustomPaint(
                    size: const Size.square(96),
                    painter: DragonPainter(
                      type: types[2],
                      level: l,
                      blink: true,
                    ),
                  ),
                CustomPaint(
                  size: const Size.square(96),
                  painter: DragonPainter(
                    type: types[4],
                    level: 4,
                    silhouette: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snap(tester, key, 'dragons_small');

    // Big, as in the hatch pop-up.
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            color: const Color(0xFF6B4FA0),
            child: Row(
              children: [
                for (final l in [1, 5])
                  CustomPaint(
                    size: const Size.square(375),
                    painter: DragonPainter(type: types[5], level: l),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await snap(tester, key, 'dragons_big');
  });
}

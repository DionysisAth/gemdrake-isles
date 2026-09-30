// Records raw frames and stills for the store listing and the promo video
// (see tool/promo/make_promo.py). Run with SHOTS=<dir>.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/model/item_ref.dart';
import 'package:gemdrake_isles/services/ads_service.dart';
import 'package:gemdrake_isles/ui/app.dart';
import 'package:gemdrake_isles/ui/dialogs/dialogs.dart';
import 'package:gemdrake_isles/ui/painters/island_painter.dart';
import 'package:gemdrake_isles/ui/painters/sky_painter.dart';
import 'package:gemdrake_isles/ui/screens/home_shell.dart';
import 'package:gemdrake_isles/ui/widgets/piece_view.dart';

import '../test/helpers.dart';
import 'fx_shot_test.dart' show loadFonts;

/// 1080-wide output from a 390-wide logical screen: the app on a tall
/// (2:1) phone, the island scenes in 9:16.
const _w = 1080.0, _ratio = _w / 390;
final _out = Platform.environment['SHOTS'] ?? '/tmp/promo';

Future<void> _save(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Pumps [n] frames at 30 fps, saving each one into [scene].
Future<void> _record(
  WidgetTester tester,
  GlobalKey key,
  String scene,
  int n, {
  Future<void> Function(int i)? each,
}) async {
  for (var i = 0; i < n; i++) {
    await each?.call(i);
    await tester.pump(const Duration(microseconds: 33333));
    await _save(
      tester,
      key,
      '$_out/$scene/f_${i.toString().padLeft(4, '0')}.png',
    );
  }
}

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

/// A showcase save: mid-game, lots of items, dragons on the island.
GameController _showcase() {
  final g = newController();
  final s = g.state;
  s.loginClaimedDay = g.today;
  s.level = 9;
  s.coins = 2480;
  s.gems = 146;
  final b = s.board;
  // Leave a little fog at the top for flavour, clear the rest.
  for (var i = 0; i < b.size; i++) {
    if (b.yOf(i) > 0) b.locks[i] = null;
    if (b.cells[i]?.isGenerator != true) b.cells[i] = null;
  }
  void put(int x, int y, String item, [int? id]) {
    final i = b.index(x, y);
    if (b.cells[i] != null || b.locks[i] != null) return;
    b.cells[i] = Piece.item(id ?? s.newId(), ItemRef.parse(item));
  }

  // Merge pairs used by the video (fixed ids so the test can find them).
  put(1, 6, 'gem:5', 90001);
  put(2, 6, 'gem:5', 90002);
  put(4, 7, 'plant:3', 90003);
  put(5, 7, 'plant:3', 90004);
  put(1, 3, 'egg:2', 90005);
  put(2, 4, 'egg:2', 90006);
  const fill = [
    'gem:1',
    'gem:2',
    'gem:3',
    'plant:1',
    'plant:2',
    'gem:4',
    'potion:1',
    'plant:4',
    'gem:2',
    'egg:1',
    'treasure:2',
    'gem:3',
    'plant:2',
    'gem:1',
  ];
  final rnd = Random(4);
  var k = 0;
  for (var y = 1; y < b.rows; y++) {
    for (var x = 0; x < b.cols; x++) {
      if (rnd.nextDouble() < .62) put(x, y, fill[k++ % fill.length]);
    }
  }
  s.dragons.addAll([
    for (final (i, (t, l)) in const [
      ('earth', 3),
      ('water', 2),
      ('fire', 2),
      ('crystal', 1),
      ('earth', 1),
    ].indexed)
      Dragon(id: 80000 + i, type: t, level: l),
  ]);
  for (final d in s.dragons) {
    for (var l = 1; l <= d.level; l++) {
      s.discovered.add('dragon:${d.type}:$l');
    }
  }
  return g;
}

Offset _pieceCenter(WidgetTester tester, int id) =>
    tester.getCenter(find.byKey(ValueKey(id)));

/// Drags piece [from] onto piece [to] over [steps] frames, recording them.
Future<void> _dragMerge(
  WidgetTester tester,
  GlobalKey key,
  String scene,
  int from,
  int to, {
  int steps = 9,
  int after = 22,
  required int Function() next,
}) async {
  final a = _pieceCenter(tester, from), b = _pieceCenter(tester, to);
  final gesture = await tester.startGesture(a);
  await tester.pump(const Duration(milliseconds: 30));
  for (var i = 1; i <= steps; i++) {
    final t = Curves.easeInOut.transform(i / steps);
    await gesture.moveTo(Offset.lerp(a, b, t)!);
    await tester.pump(const Duration(microseconds: 33333));
    await _save(
      tester,
      key,
      '$_out/$scene/f_${next().toString().padLeft(4, '0')}.png',
    );
  }
  await gesture.up();
  for (var i = 0; i < after; i++) {
    await tester.pump(const Duration(microseconds: 33333));
    await _save(
      tester,
      key,
      '$_out/$scene/f_${next().toString().padLeft(4, '0')}.png',
    );
  }
}

/// The island on its own, full screen, with a few dragons flying by.
class _IslandStage extends StatelessWidget {
  const _IslandStage({
    required this.theme,
    required this.progress,
    required this.time,
    required this.game,
  });

  final String theme;
  final Map<String, double> progress;
  final double time;
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final dragons = [
      ('earth', 3, .3, .0),
      ('fire', 2, .22, 2.1),
      ('water', 2, .26, 4.2),
    ];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight;
          return Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: SkyPainter())),
              Positioned(
                left: 0,
                right: 0,
                top: h * .22,
                height: h * .74,
                child: CustomPaint(
                  painter: IslandPainter(
                    progress: progress,
                    time: time,
                    theme: theme,
                  ),
                ),
              ),
              for (final (type, level, y, phase) in dragons)
                Positioned(
                  left: 390 * (.5 + .42 * sin(time * .7 + phase)) - 30,
                  top: h * (y + .05 * sin(time * 1.7 + phase)),
                  child: Transform.flip(
                    flipX: cos(time * .7 + phase) < 0,
                    child: DragonIcon(
                      type: game.config.dragonType(type),
                      level: level,
                      size: 60,
                      flap: (sin(time * 9 + phase) + 1) / 2,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

void main() {
  setUpAll(loadFonts);

  testWidgets('promo', (tester) async {
    tester.view.physicalSize = const Size(_w, 2160);
    tester.view.devicePixelRatio = _ratio;
    final game = _showcase();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: GemdrakeApp(game: game, ads: SimulatedAdsService(seconds: 0)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, key, '$_out/stills/board.png');

    // Scene 1: merges on the board.
    var f = 0;
    int next() => f++;
    await _dragMerge(
      tester,
      key,
      's1_board',
      90001,
      90002,
      next: next,
      after: 30,
    );
    await _dragMerge(
      tester,
      key,
      's1_board',
      90003,
      90004,
      next: next,
      after: 18,
    );
    await _dragMerge(
      tester,
      key,
      's1_board',
      90005,
      90006,
      next: next,
      after: 21,
    );
    await tester.pump(const Duration(seconds: 3));

    // Scene 2: hatching a rare dragon.
    final ctx = tester.element(find.byType(HomeShell));
    showHatch(ctx, [Dragon(id: 99001, type: 'crystal', level: 1)]);
    await _record(tester, key, 's2_hatch', 80);
    await _save(tester, key, '$_out/stills/hatch.png');
    Navigator.of(ctx).pop();
    await tester.pump(const Duration(seconds: 1));

    // Stills: island tab, festival, book.
    for (final t in game.config.island(0).tasks) {
      game.state.completedTasks.add(t.id);
    }
    game.tick();
    await tester.tap(find.text('Island').last);
    await tester.pump(const Duration(seconds: 2));
    await _save(tester, key, '$_out/stills/island.png');
    game.state.level = 12;
    game.tick();
    final ev = game.state.event!;
    ev.points = 340;
    ev.claimedFree.addAll([0, 1]);
    await tester.tap(find.text('Festival').last);
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, key, '$_out/stills/festival.png');
    await tester.tap(find.text('Book').last);
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, key, '$_out/stills/book.png');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));

    tester.view.physicalSize = const Size(_w, 1920);
    // Scene 3: restoring the meadow island.
    Map<String, double> prog(int done, [String? growing, double t = 0]) => {
      for (final (i, e) in _elements.indexed)
        e: i < done ? 1.0 : (e == growing ? t : 0.0),
    };
    const restore = [('tower', 6, 8), ('windmill', 7, 38), ('lanterns', 8, 68)];
    for (var i = 0; i < 100; i++) {
      var done = 6;
      String? growing;
      var t = 0.0;
      for (final (e, idx, start) in restore) {
        if (i >= start) {
          final p = ((i - start) / 22).clamp(0.0, 1.0);
          if (p >= 1) {
            done = idx + 1;
          } else {
            growing = e;
            t = Curves.easeOutBack.transform(p).clamp(0.0, 1.2);
            done = idx;
          }
        }
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _IslandStage(
            theme: 'meadow',
            progress: prog(done, growing, t),
            time: 10 + i / 30,
            game: game,
          ),
        ),
      );
      await _save(
        tester,
        key,
        '$_out/s3_restore/f_${i.toString().padLeft(4, '0')}.png',
      );
    }

    // Scene 4: the other worlds, fully restored.
    var n = 0;
    for (final theme in ['volcano', 'lagoon', 'crystal', 'shadow']) {
      for (var i = 0; i < 22; i++) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: _IslandStage(
              theme: theme,
              progress: prog(10),
              time: 20 + n / 30,
              game: game,
            ),
          ),
        );
        await _save(
          tester,
          key,
          '$_out/s4_worlds/f_${(n++).toString().padLeft(4, '0')}.png',
        );
        if (i == 11) await _save(tester, key, '$_out/stills/world_$theme.png');
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}

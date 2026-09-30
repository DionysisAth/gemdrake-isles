import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:gemdrake_isles/config/game_config.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/logic/new_game.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/model/item_ref.dart';
import 'package:gemdrake_isles/services/notification_service.dart';
import 'package:gemdrake_isles/services/save_store.dart';

GameConfig loadConfig() => GameConfig.fromJson({
  for (final name in GameConfig.files)
    name: jsonDecode(
      File('assets/config/$name.json').readAsStringSync(),
    ) as Map<String, dynamic>,
});

/// A controllable clock for time-based rules.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 1, 1, 12);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

GameController newController({
  GameConfig? config,
  FakeClock? clock,
  int seed = 1,
  bool skipTutorial = true,
  SaveStore? store,
  NotificationService? notifications,
}) {
  final c = config ?? loadConfig();
  final fc = clock ?? FakeClock();
  final state = createNewGame(c, fc.now.millisecondsSinceEpoch);
  if (skipTutorial) state.tutorialStep = c.tutorial.length;
  return GameController(
    config: c,
    state: state,
    clock: fc.call,
    random: Random(seed),
    saveStore: store,
    notifications: notifications,
  );
}

/// Clears the board's open area and removes locks so tests can lay out
/// pieces explicitly.
void clearBoard(GameController g) {
  final b = g.board;
  for (var i = 0; i < b.size; i++) {
    b.cells[i] = null;
    b.locks[i] = null;
  }
}

int put(GameController g, int x, int y, String item) {
  final i = g.board.index(x, y);
  g.board.cells[i] = Piece.item(g.state.newId(), ItemRef.parse(item));
  return i;
}

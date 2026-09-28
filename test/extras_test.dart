import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/services/feedback.dart';

import 'helpers.dart';

class RecordingFeedback extends SilentFeedback {
  final tracks = <String>[];
  final played = <Sfx>[];

  @override
  void setMusicTrack(String track) => tracks.add(track);

  @override
  void play(Sfx sfx, {int level = 1}) => played.add(sfx);
}

void main() {
  test('energy potions merge like items and can be drunk', () {
    final g = newController();
    clearBoard(g);
    final a = put(g, 1, 1, 'potion:1');
    final b = put(g, 2, 1, 'potion:1');
    expect(g.drop(Slot.board(a), Slot.board(b)), isTrue);
    expect(g.board.cells[b]!.item!.key, 'potion:2');
    g.state.energy = 10;
    g.state.energyUpdatedAt = g.nowMs;
    final gain = g.drinkableEnergy(Slot.board(b));
    expect(gain, g.config.item(g.board.cells[b]!.item!).energy);
    expect(g.drink(Slot.board(b)), isTrue);
    expect(g.energy, 10 + gain);
    expect(g.board.cells[b], isNull);
    final gem = put(g, 3, 3, 'gem:2');
    expect(g.drink(Slot.board(gem)), isFalse);
  });

  test('generators can drop potions once the player is level 3', () {
    final c = loadConfig();
    final drops = c.generator('crystal_mine').level(1).drops;
    final potion = drops.where((d) => d.item.chain == 'potion').single;
    expect(potion.minPlayerLevel, 3);
  });

  test('music follows the island', () {
    final fb = RecordingFeedback();
    final c = loadConfig();
    final g = newController(config: c);
    final game = GameController(
      config: c,
      state: g.state,
      feedback: fb,
      clock: g.clock,
    );
    expect(fb.tracks.last, 'meadow');
    game.state.coins = 1 << 30;
    game.state.level = 40;
    for (var pass = 0; pass < 10; pass++) {
      for (final t in game.currentIsland.tasks) {
        if (game.taskAvailable(t)) game.completeTask(t.id);
      }
    }
    game.travelToNextIsland();
    expect(fb.tracks.last, 'volcano');
  });

  test('grown dragons roar, young ones chirp', () {
    final fb = RecordingFeedback();
    final c = loadConfig();
    final g0 = newController(config: c);
    final g = GameController(
      config: c,
      state: g0.state,
      feedback: fb,
      clock: g0.clock,
    );
    g.state.dragons
      ..clear()
      ..addAll([
        Dragon(id: 1, type: 'earth', level: 2),
        Dragon(id: 2, type: 'earth', level: 2),
        Dragon(id: 3, type: 'earth', level: 1),
        Dragon(id: 4, type: 'earth', level: 1),
      ]);
    g.mergeDragons(3, 4);
    expect(fb.played.last, Sfx.chirp);
    g.mergeDragons(1, 2);
    expect(fb.played.last, Sfx.roar);
  });
}

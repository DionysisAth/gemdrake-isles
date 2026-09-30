import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/logic/game_events.dart';
import 'package:gemdrake_isles/logic/order_generator.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/model/item_ref.dart';
import 'package:gemdrake_isles/services/save_store.dart';

import 'helpers.dart';

void main() {
  final config = loadConfig();

  group('config', () {
    test('all references are valid', () {
      for (final g in config.generators) {
        for (final l in g.levels) {
          for (final d in l.drops) {
            expect(
              config.isValidItem(d.item),
              isTrue,
              reason: '${g.id} drops ${d.item}',
            );
          }
        }
      }
      for (final c in config.board.contents) {
        if (c.item != null) expect(config.isValidItem(c.item!), isTrue);
        if (c.generator != null) config.generator(c.generator!);
      }
      for (final o in config.orders.scripted) {
        for (final l in o.lines) {
          expect(config.isValidItem(l.item), isTrue);
        }
        config.orders.character(o.character);
      }
      for (final t in config.dragons.types) {
        config.rarity(t.rarity);
      }
      for (final h in config.dragons.hatchTable) {
        config.dragonType(h.type);
      }
      expect(config.islands, hasLength(5));
      final allIds = <String>{};
      for (final island in config.islands) {
        final ids = island.tasks.map((t) => t.id).toSet();
        expect(allIds.intersection(ids), isEmpty, reason: 'unique task ids');
        allIds.addAll(ids);
        for (final t in island.tasks) {
          expect(ids.containsAll(t.requires), isTrue, reason: t.id);
        }
        expect(island.tasks.length, 10);
        for (final e in island.hatchTable) {
          config.dragonType(e.type);
        }
      }
      for (final c in config.chains) {
        final loot = c.loot;
        if (loot == null) continue;
        for (final e in loot.table) {
          if (e.item != null) expect(config.isValidItem(e.item!), isTrue);
        }
      }
    });

    test('board is 7x9 with locked cells', () {
      final g = newController();
      expect(g.board.cols, 7);
      expect(g.board.rows, 9);
      expect(g.board.locks.where((l) => l != null).length, greaterThan(20));
      expect(
        g.board.indicesWhere((p) => p.generatorId == 'crystal_mine'),
        hasLength(1),
      );
    });
  });

  group('generators & energy', () {
    test('tapping spends energy and places an item next to the generator', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      final gen = g.board.indicesWhere((p) => p.isGenerator).first;
      final before = g.energy;
      final spawned = <SpawnEvent>[];
      g.events.listen((e) {
        if (e is SpawnEvent) spawned.add(e);
      });
      expect(g.produce(gen), ProduceResult.ok);
      expect(g.energy, before - 1);
      expect(spawned, hasLength(1));
      final cell = spawned.single.toCell;
      final dx = (g.board.xOf(cell) - g.board.xOf(gen)).abs();
      final dy = (g.board.yOf(cell) - g.board.yOf(gen)).abs();
      expect(dx + dy, 1);
      expect(g.board.cells[gen]!.charges, 19);
    });

    test('generator recharges after its cooldown', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      final gen = g.board.indicesWhere((p) => p.isGenerator).first;
      final piece = g.board.cells[gen]!;
      piece.charges = 1;
      // Make room so the board never fills.
      clearBoard(g);
      g.board.cells[gen] = piece;
      expect(g.produce(gen), ProduceResult.ok);
      expect(piece.cooldownUntil, isNot(0));
      expect(g.produce(gen), ProduceResult.recharging);
      clock.advance(const Duration(minutes: 10, seconds: 1));
      g.tick();
      expect(piece.charges, 20);
      expect(g.produce(gen), ProduceResult.ok);
    });

    test('energy refills over time, capped at max', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      g.state.energy = 10;
      g.state.energyUpdatedAt = clock.now.millisecondsSinceEpoch;
      clock.advance(const Duration(minutes: 10));
      expect(g.energy, 15);
      clock.advance(const Duration(days: 1));
      expect(g.energy, g.energyMax);
    });

    test('setting the clock backwards does not grant energy', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      g.state.energy = 10;
      g.state.energyUpdatedAt = clock.now.millisecondsSinceEpoch;
      clock.advance(const Duration(hours: -5));
      expect(g.energy, 10);
      clock.advance(const Duration(hours: 5, minutes: 2));
      expect(g.energy, 11);
    });

    test('out of energy blocks production', () {
      final g = newController();
      final gen = g.board.indicesWhere((p) => p.isGenerator).first;
      g.state.energy = 0;
      expect(g.produce(gen), ProduceResult.noEnergy);
    });

    test('full board blocks production without spending energy', () {
      final g = newController();
      final gen = g.board.indicesWhere((p) => p.isGenerator).first;
      for (var i = 0; i < g.board.size; i++) {
        if (g.board.isFree(i)) {
          g.board.cells[i] = Piece.item(
            g.state.newId(),
            const ItemRef('gem', 7),
          );
        }
      }
      final e = g.energy;
      expect(g.produce(gen), ProduceResult.boardFull);
      expect(g.energy, e);
    });
  });

  group('merging', () {
    test('2 identical items merge into 1 of the next level', () {
      final g = newController();
      clearBoard(g);
      final a = put(g, 0, 0, 'gem:1');
      final b = put(g, 2, 2, 'gem:1');
      expect(g.drop(Slot.board(a), Slot.board(b)), isTrue);
      expect(g.board.cells[a], isNull);
      expect(g.board.cells[b]!.item, const ItemRef('gem', 2));
      expect(g.state.discovered, contains('gem:2'));
      expect(g.state.stat('merges'), 1);
    });

    test('different items swap places', () {
      final g = newController();
      clearBoard(g);
      final a = put(g, 0, 0, 'gem:1');
      final b = put(g, 1, 0, 'plant:1');
      g.drop(Slot.board(a), Slot.board(b));
      expect(g.board.cells[a]!.item, const ItemRef('plant', 1));
      expect(g.board.cells[b]!.item, const ItemRef('gem', 1));
    });

    test('max level items do not merge', () {
      final g = newController();
      clearBoard(g);
      final a = put(g, 0, 0, 'gem:7');
      final b = put(g, 2, 0, 'gem:7');
      expect(g.drop(Slot.board(a), Slot.board(b)), isFalse);
      expect(g.board.cells[a]!.item, const ItemRef('gem', 7));
      expect(g.board.cells[b]!.item, const ItemRef('gem', 7));
    });

    test('5 at once gives the 3-item bonus', () {
      final g = newController();
      clearBoard(g);
      // A connected group of 4 plus the dragged one.
      final group = [
        put(g, 2, 2, 'gem:3'),
        put(g, 3, 2, 'gem:3'),
        put(g, 4, 2, 'gem:3'),
        put(g, 3, 3, 'gem:3'),
      ];
      final dragged = put(g, 0, 8, 'gem:3');
      MergeEvent? merge;
      g.events.listen((e) {
        if (e is MergeEvent) merge = e;
      });
      g.drop(Slot.board(dragged), Slot.board(group[1]));
      final results = g.board
          .indicesWhere((p) => p.item == const ItemRef('gem', 4))
          .length;
      final leftovers = g.board
          .indicesWhere((p) => p.item == const ItemRef('gem', 3))
          .length;
      expect(results, 3);
      expect(leftovers, 0);
      expect(merge!.bonus, isTrue);
    });

    test('4 items (group of 3 + dragged) use the standard rule', () {
      final g = newController();
      clearBoard(g);
      final t = put(g, 3, 3, 'gem:2');
      put(g, 3, 4, 'gem:2');
      put(g, 4, 3, 'gem:2');
      final dragged = put(g, 0, 0, 'gem:2');
      g.drop(Slot.board(dragged), Slot.board(t));
      expect(
        g.board.indicesWhere((p) => p.item == const ItemRef('gem', 3)),
        hasLength(1),
      );
      expect(
        g.board.indicesWhere((p) => p.item == const ItemRef('gem', 2)),
        hasLength(2),
      );
    });

    test('merging chips away at adjacent locks', () {
      final g = newController();
      clearBoard(g);
      final lockCell = g.board.index(3, 2);
      g.board.locks[lockCell] = CellLock('fog', 1);
      final rubble = g.board.index(4, 3);
      g.board.locks[rubble] = CellLock('rubble', 2);
      final a = put(g, 0, 0, 'gem:1');
      final b = put(g, 3, 3, 'gem:1');
      g.drop(Slot.board(a), Slot.board(b));
      expect(g.board.locks[lockCell], isNull);
      expect(g.board.locks[rubble]!.hits, 1);
    });

    test('dropping a matching item onto a cobweb frees it', () {
      final g = newController();
      clearBoard(g);
      final webbed = put(g, 3, 3, 'gem:2');
      g.board.locks[webbed] = CellLock('web', 1);
      final a = put(g, 0, 0, 'gem:2');
      g.drop(Slot.board(a), Slot.board(webbed));
      expect(g.board.locks[webbed], isNull);
      expect(g.board.cells[webbed]!.item, const ItemRef('gem', 3));
    });

    test('items hidden in fog cannot be merged onto', () {
      final g = newController();
      clearBoard(g);
      final hidden = put(g, 3, 3, 'gem:2');
      g.board.locks[hidden] = CellLock('fog', 1);
      final a = put(g, 0, 0, 'gem:2');
      expect(g.drop(Slot.board(a), Slot.board(hidden)), isFalse);
    });

    test('merging two cracking eggs hatches a dragon', () {
      final g = newController();
      clearBoard(g);
      final a = put(g, 0, 0, 'egg:3');
      final b = put(g, 1, 1, 'egg:3');
      final hatched = <HatchEvent>[];
      g.events.listen((e) {
        if (e is HatchEvent) hatched.add(e);
      });
      g.drop(Slot.board(a), Slot.board(b));
      expect(g.board.cells[a], isNull);
      expect(g.board.cells[b], isNull);
      expect(g.state.dragons, hasLength(1));
      expect(hatched.single.dragons.single.level, 1);
      expect(g.coinsPerMinute, greaterThan(0));
    });
  });

  group('storage & selling', () {
    test('items move to storage and back', () {
      final g = newController();
      clearBoard(g);
      final a = put(g, 0, 0, 'plant:2');
      expect(g.drop(Slot.board(a), const Slot.storage(0)), isTrue);
      expect(g.board.cells[a], isNull);
      expect(g.state.storage[0]!.item, const ItemRef('plant', 2));
      expect(
        g.drop(const Slot.storage(0), Slot.board(g.board.index(5, 5))),
        isTrue,
      );
      expect(g.state.storage[0], isNull);
    });

    test('generators cannot be stored', () {
      final g = newController();
      final gen = g.board.indicesWhere((p) => p.isGenerator).first;
      expect(g.drop(Slot.board(gen), const Slot.storage(0)), isFalse);
    });

    test('selling gives coins', () {
      final g = newController();
      clearBoard(g);
      final a = put(g, 0, 0, 'gem:5');
      final coins = g.state.coins;
      g.sell(Slot.board(a));
      expect(g.state.coins, coins + config.item(const ItemRef('gem', 5)).sell);
      expect(g.board.cells[a], isNull);
    });

    test('buying a storage slot costs gems', () {
      final g = newController();
      g.state.gems = 100;
      final slots = g.state.storage.length;
      expect(g.buyStorageSlot(), isTrue);
      expect(g.state.storage.length, slots + 1);
      expect(g.state.gems, 100 - config.economy.storageSlotCostsGems.first);
    });
  });

  group('orders & levels', () {
    test('starts with the scripted tutorial orders', () {
      final g = newController();
      expect(g.state.orders.first.lines.single.item, const ItemRef('gem', 2));
      expect(g.state.orders, hasLength(config.orders.maxActive(1)));
    });

    test('delivering consumes items and pays out', () {
      final g = newController();
      clearBoard(g);
      final order = g.state.orders.first;
      expect(g.findOrderItems(order), isNull);
      put(g, 1, 1, 'gem:2');
      expect(g.findOrderItems(order), isNotNull);
      final coins = g.state.coins;
      expect(g.deliverOrder(order.id), isTrue);
      expect(g.state.coins, coins + order.coins);
      expect(g.board.indicesWhere((p) => p.isItem), isEmpty);
      expect(g.state.orders.any((o) => o.id == order.id), isFalse);
    });

    test('stored items count towards orders', () {
      final g = newController();
      clearBoard(g);
      g.state.storage[0] = Piece.item(g.state.newId(), const ItemRef('gem', 2));
      expect(g.deliverOrder(g.state.orders.first.id), isTrue);
      expect(g.state.storage[0], isNull);
    });

    test(
      'levelling up refills energy, gives gems and unlocks the Seed Basket',
      () {
        final g = newController();
        g.state.energy = 3;
        final gems = g.state.gems;
        final events = <LevelUpEvent>[];
        g.events.listen((e) {
          if (e is LevelUpEvent) events.add(e);
        });
        clearBoard(g);
        put(g, 1, 1, 'gem:2');
        g.state.xp = config.xpToNext(1) - 1;
        g.deliverOrder(g.state.orders.first.id);
        expect(g.state.level, 2);
        expect(g.energy, g.energyMax);
        expect(g.state.gems, gems + config.economy.levelUpGems);
        expect(events.single.unlocks, contains('Seed Basket'));
        expect(
          g.board.indicesWhere((p) => p.generatorId == 'seed_basket'),
          hasLength(1),
        );
      },
    );

    test('generated orders only ask for unlocked, valid items', () {
      for (var level = 1; level <= 20; level++) {
        for (var seed = 0; seed < 30; seed++) {
          final g = newController(seed: seed);
          g.state.level = level;
          g.state.scriptedOrderIndex = 99;
          final gen = OrderGenerator(config, Random(seed));
          final o = gen.next(g.state);
          expect(o.lines, isNotEmpty);
          for (final l in o.lines) {
            expect(config.isValidItem(l.item), isTrue);
            expect(
              config.chain(l.item.chain).unlockLevel,
              lessThanOrEqualTo(level),
            );
            expect(config.chain(l.item.chain).orderable, isTrue);
          }
          expect(o.coins, greaterThan(0));
        }
      }
    });
  });

  group('idle dragons', () {
    test('dragons earn while away, capped by the offline limit', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      g.state.dragons.add(Dragon(id: g.state.newId(), type: 'earth', level: 1));
      g.tick();
      g.onPause();
      clock.advance(const Duration(hours: 1));
      final wb = g.checkWelcomeBack()!;
      expect(wb.coins, closeTo(g.coinsPerMinute * 60, 1));
      clock.advance(const Duration(days: 3));
      g.tick();
      expect(g.state.idleCoins, closeTo(g.idleCoinCap, .01));
      final coins = g.state.coins;
      g.collectIdle(multiplier: 2);
      expect(g.state.coins, coins + g.idleCoinCap.floor() * 2);
    });

    test('turning the clock back and forward again earns nothing extra', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      g.state.dragons.add(Dragon(id: g.state.newId(), type: 'earth', level: 1));
      g.tick();
      clock.advance(const Duration(hours: -6));
      g.tick();
      clock.advance(const Duration(hours: 6, minutes: 10));
      g.tick();
      expect(g.state.idleCoins, closeTo(g.coinsPerMinute * 10, .01));
    });

    test('no welcome back after a short absence', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      g.state.dragons.add(Dragon(id: g.state.newId(), type: 'earth', level: 1));
      g.onPause();
      clock.advance(const Duration(seconds: 20));
      expect(g.checkWelcomeBack(), isNull);
    });

    test('matching dragons merge into the next level', () {
      final g = newController();
      final a = Dragon(id: g.state.newId(), type: 'fire', level: 1);
      final b = Dragon(id: g.state.newId(), type: 'fire', level: 1);
      final c = Dragon(id: g.state.newId(), type: 'water', level: 1);
      g.state.dragons.addAll([a, b, c]);
      expect(g.mergeDragons(a.id, c.id), isFalse);
      expect(g.mergeDragons(a.id, b.id), isTrue);
      expect(g.state.dragons.where((d) => d.type == 'fire').single.level, 2);
    });
  });

  group('island', () {
    test('tasks cost coins, respect requirements and apply perks', () {
      final g = newController();
      g.state.coins = 10000;
      g.state.level = 10;
      expect(g.completeTask('fix_bridge'), isFalse); // needs clear_vines
      expect(g.completeTask('clear_vines'), isTrue);
      expect(g.state.coins, 10000 - 25);
      final slots = g.state.storage.length;
      for (final id in ['fix_bridge', 'restore_well', 'storage_shed']) {
        expect(g.completeTask(id), isTrue, reason: id);
      }
      expect(g.state.storage.length, slots + 1);
      expect(g.energyMax, config.economy.energyMax + 10);
    });

    test('all 10 tasks restore the island', () {
      final g = newController();
      g.state.coins = 100000;
      g.state.level = 20;
      for (var pass = 0; pass < 10; pass++) {
        for (final t in g.currentIsland.tasks) {
          if (g.taskAvailable(t)) g.completeTask(t.id);
        }
      }
      expect(g.islandComplete, isTrue);
      expect(g.offlineCapHours, config.economy.offlineCapHours + 4);
    });
  });

  group('tutorial', () {
    test('advances through events and taps', () {
      final g = newController(skipTutorial: false);
      expect(g.tutorialStep!.id, 'welcome');
      g.tapTutorial();
      expect(g.tutorialStep!.id, 'tap_generator');
      final gen = g.board.indicesWhere((p) => p.isGenerator).first;
      g.produce(gen);
      g.produce(gen);
      expect(g.tutorialStep!.id, 'first_merge');
      final pebbles = g.board
          .indicesWhere((p) => p.item == const ItemRef('gem', 1))
          .where((i) => !g.board.isLocked(i))
          .toList();
      expect(pebbles, hasLength(2), reason: 'tutorial drops are deterministic');
      g.drop(Slot.board(pebbles[0]), Slot.board(pebbles[1]));
      expect(g.tutorialStep!.id, 'first_order');
      expect(g.deliverOrder(g.state.orders.first.id), isTrue);
      expect(g.tutorialStep!.id, 'island_tab');
      g.tutorialEvent('tab_island');
      expect(
        g.completeTask('clear_vines'),
        isTrue,
        reason: 'first order pays for the first task',
      );
      expect(g.tutorialStep!.id, 'dragons');
      g.tapTutorial();
      g.tutorialEvent('tab_board');
      expect(g.tutorialActive, isFalse);
    });
  });

  group('saving', () {
    test('state survives a save/load round trip', () async {
      final store = MemorySaveStore();
      final clock = FakeClock();
      final g = newController(clock: clock, store: store);
      final gen = g.board.indicesWhere((p) => p.isGenerator).first;
      g.produce(gen);
      g.state.dragons.add(
        Dragon(id: g.state.newId(), type: 'crystal', level: 3),
      );
      g.state.completedTasks.add('clear_vines');
      await g.save(immediate: true);
      final json = jsonEncode(g.state.toJson());

      final loaded = await GameController.load(
        config: config,
        saveStore: store,
        clock: clock.call,
      );
      // Loading bumps the session counter; everything else is identical.
      loaded.state.stats.remove('sessions');
      expect(jsonEncode(loaded.state.toJson()), json);
    });

    test('a corrupt save starts a new game instead of crashing', () async {
      final store = MemorySaveStore()..data = {'nonsense': true};
      final g = await GameController.load(config: config, saveStore: store);
      expect(g.state.level, 1);
      expect(g.board.indicesWhere((p) => p.isGenerator), isNotEmpty);
    });
  });

  group('islands 2-5', () {
    GameController finishIsland(GameController g) {
      g.state.coins = 1 << 30;
      g.state.level = 40;
      for (var pass = 0; pass < 10; pass++) {
        for (final t in g.currentIsland.tasks) {
          if (g.taskAvailable(t)) g.completeTask(t.id);
        }
      }
      return g;
    }

    test('cannot travel before the island is restored', () {
      final g = newController();
      expect(g.travelToNextIsland(), isFalse);
      expect(g.state.island, 0);
    });

    test('travel unlocks the next island, its chain and generator', () {
      final g = finishIsland(newController());
      expect(g.chainUnlocked('tool'), isFalse);
      final events = <IslandTravelEvent>[];
      g.events.listen((e) {
        if (e is IslandTravelEvent) events.add(e);
      });
      expect(g.travelToNextIsland(), isTrue);
      expect(g.state.island, 1);
      expect(g.currentIsland.id, 'volcano');
      expect(g.chainUnlocked('tool'), isTrue);
      final forge = g.board.indicesWhere((p) => p.generatorId == 'forge');
      final pending = g.state.pending.contains('gen:forge');
      expect(forge.isNotEmpty || pending, isTrue);
      expect(events.single.unlocks, contains('Ember Forge'));
      expect(g.state.orders, isNotEmpty);
    });

    test('perks from earlier islands keep applying', () {
      final g = finishIsland(newController());
      final max0 = g.energyMax;
      g.travelToNextIsland();
      expect(g.energyMax, max0);
      finishIsland(g);
      expect(g.energyMax, max0 + 10);
    });

    test('all five islands can be restored in order', () {
      final g = newController();
      for (var i = 0; i < 5; i++) {
        finishIsland(g);
        expect(g.islandComplete, isTrue, reason: g.currentIsland.id);
        if (i < 4) expect(g.travelToNextIsland(), isTrue);
      }
      expect(g.hasNextIsland, isFalse);
      expect(g.travelToNextIsland(), isFalse);
      for (final gen in ['forge', 'tide_pool', 'geode_cavern', 'star_well']) {
        final owned =
            g.board.indicesWhere((p) => p.generatorId == gen).isNotEmpty ||
            g.state.pending.contains('gen:$gen');
        expect(owned, isTrue, reason: gen);
      }
    });

    test('eggs hatch using the current island odds', () {
      final g = newController();
      g.state.island = 4;
      final table = g.hatchTableFor(config.chain('egg'));
      expect(table.map((e) => e.type), contains('shadow'));
      final legend = g.hatchTableFor(config.chain('legend'));
      expect(legend.first.type, 'shadow');
    });

    test('merging two eclipse eggs hatches a legendary-table dragon', () {
      final g = newController(seed: 3);
      g.state.island = 4;
      clearBoard(g);
      final a = put(g, 0, 0, 'legend:3');
      final b = put(g, 1, 1, 'legend:3');
      g.drop(Slot.board(a), Slot.board(b));
      expect(g.state.dragons, hasLength(1));
      final types = config.dragons.specialHatchTables['legendary']!.map(
        (e) => e.type,
      );
      expect(types, contains(g.state.dragons.single.type));
    });

    test('orders only ask for chains unlocked on reached islands', () {
      final g = newController();
      g.state.level = 30;
      g.state.scriptedOrderIndex = 99;
      for (var i = 0; i < 200; i++) {
        final o = OrderGenerator(config, Random(i)).next(g.state);
        for (final l in o.lines) {
          expect(['gem', 'plant'], contains(l.item.chain));
        }
      }
      g.state.island = 2;
      final seen = <String>{};
      for (var i = 0; i < 300; i++) {
        final o = OrderGenerator(config, Random(i)).next(g.state);
        seen.addAll(o.lines.map((l) => l.item.chain));
        for (final l in o.lines) {
          expect([
            'geode',
            'star',
            'legend',
            'blossom',
            'lantern',
          ], isNot(contains(l.item.chain)));
        }
      }
      expect(seen, containsAll(['tool', 'shell']));
    });

    test('opening a treasure chest grants its loot', () {
      final g = newController(seed: 5);
      clearBoard(g);
      final chest = put(g, 3, 3, 'treasure:4');
      expect(g.canOpen(Slot.board(chest)), isTrue);
      final before = (g.state.coins, g.state.gems, g.energy);
      final rewards = g.openChest(Slot.board(chest));
      expect(rewards, hasLength(config.chain('treasure').loot!.rolls));
      expect(g.board.cells[chest]?.item, isNot(const ItemRef('treasure', 4)));
      final coins = rewards.fold(0, (s, e) => s + e.coins);
      final gems = rewards.fold(0, (s, e) => s + e.gems);
      expect(g.state.coins, before.$1 + coins);
      expect(g.state.gems, before.$2 + gems);
      final items = rewards.where((e) => e.item != null).length;
      expect(g.board.indicesWhere((p) => p.isItem).length, items);
    });

    test('lower treasure is not openable but sells for coins', () {
      final g = newController();
      clearBoard(g);
      final bag = put(g, 3, 3, 'treasure:3');
      expect(g.canOpen(Slot.board(bag)), isFalse);
      final coins = g.state.coins;
      g.sell(Slot.board(bag));
      expect(
        g.state.coins,
        coins + config.item(const ItemRef('treasure', 3)).sell,
      );
    });

    test('island progress survives saving', () async {
      final store = MemorySaveStore();
      final g = finishIsland(newController(store: store));
      g.travelToNextIsland();
      await g.save(immediate: true);
      final loaded = await GameController.load(
        config: config,
        saveStore: store,
      );
      expect(loaded.state.island, 1);
      expect(loaded.currentIsland.id, 'volcano');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/logic/game_events.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/model/item_ref.dart';
import 'package:gemdrake_isles/services/notification_service.dart';

import 'helpers.dart';

void main() {
  group('daily tasks and login', () {
    test('tasks roll once the feature unlocks, progress counts from then', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      expect(g.state.dailyTasks, isEmpty); // level 1
      g.state.level = 3;
      g.state.addStat('merges', 100);
      g.tick();
      expect(g.state.dailyTasks.length, g.config.meta.dailyCount);
      final ids = g.state.dailyTasks.map((t) => t.id).toSet();
      expect(ids.length, g.state.dailyTasks.length);
      for (final t in g.state.dailyTasks) {
        expect(g.dailyProgress(t), 0);
        expect(g.claimDaily(g.state.dailyTasks.indexOf(t)), isFalse);
      }
    });

    test('completing a task pays out once; all done pays the bonus', () {
      final g = newController();
      g.state.level = 3;
      g.tick();
      final gems0 = g.state.gems;
      for (final t in g.state.dailyTasks) {
        g.state.addStat(g.dailyDef(t).stat, t.target);
      }
      expect(g.dailyBadge, greaterThanOrEqualTo(g.state.dailyTasks.length));
      for (var i = 0; i < g.state.dailyTasks.length; i++) {
        expect(g.claimDaily(i), isTrue);
        expect(g.claimDaily(i), isFalse);
      }
      expect(g.dailyBonusReady, isTrue);
      expect(g.claimDailyBonus(), isTrue);
      expect(g.claimDailyBonus(), isFalse);
      expect(g.state.gems, greaterThan(gems0));
    });

    test('new day re-rolls tasks; the streak grows and resets', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      g.state.level = 3;
      g.tick();
      expect(g.state.loginStreak, 1);
      final day = g.state.dailyDay;
      clock.advance(const Duration(days: 1));
      g.tick();
      expect(g.state.dailyDay, day + 1);
      expect(g.state.loginStreak, 2);
      expect(g.state.dailyBonusClaimed, isFalse);
      clock.advance(const Duration(days: 3));
      g.tick();
      expect(g.state.loginStreak, 1);
    });

    test(
      'login reward once per day and turning the clock back gives nothing',
      () {
        final clock = FakeClock();
        final g = newController(clock: clock);
        expect(g.loginRewardReady, isTrue);
        expect(g.claimLogin(), isTrue);
        expect(g.claimLogin(), isFalse);
        clock.advance(const Duration(days: -3));
        g.tick();
        expect(g.loginRewardReady, isFalse);
        clock.advance(const Duration(days: 4));
        g.tick();
        expect(g.loginRewardReady, isTrue);
        expect(g.loginCalendarDay, 1); // day 2 of the calendar
      },
    );

    test('daily state survives save and load', () {
      final g = newController();
      g.state.level = 3;
      g.tick();
      g.claimLogin();
      final copy = GameState.fromJson(g.state.toJson());
      expect(
        copy.dailyTasks.map((t) => t.id),
        g.state.dailyTasks.map((t) => t.id),
      );
      expect(copy.loginClaimedDay, g.state.loginClaimedDay);
      expect(copy.loginStreak, g.state.loginStreak);
    });
  });

  group('dragon book', () {
    test('raising a type to every level unlocks its reward', () {
      final g = newController();
      final type = g.config.dragons.types.first;
      String key(int l) => 'dragon:${type.id}:$l';
      for (var l = 1; l < g.config.dragons.maxLevel; l++) {
        g.state.discovered.add(key(l));
      }
      expect(g.claimBook('type:${type.id}'), isFalse);
      g.state.discovered.add(key(g.config.dragons.maxLevel));
      final gems = g.state.gems;
      expect(g.bookBadge, 1);
      expect(g.claimBook('type:${type.id}'), isTrue);
      expect(
        g.state.gems - gems,
        g.config.dragons.typeCompleteGems[type.rarity],
      );
      expect(g.claimBook('type:${type.id}'), isFalse);
    });

    test('hatching one of each basic type', () {
      final g = newController();
      for (final t in g.config.dragons.allBabiesTypes) {
        g.state.discovered.add('dragon:$t:1');
      }
      expect(g.claimBook('babies'), isTrue);
    });
  });

  group('gem shop', () {
    test('buying a chest spends gems and hands out its loot', () {
      final g = newController();
      final events = <ChestOpenedEvent>[];
      g.events.listen((e) {
        if (e is ChestOpenedEvent) events.add(e);
      });
      final item = g.config.meta.shopItems.firstWhere(
        (s) => s.id == 'egg_pack',
      );
      g.state.gems = item.costGems - 1;
      expect(g.buyShopItem(item.id), isFalse);
      g.state.gems = item.costGems;
      final eggs0 = g.state.board
          .indicesWhere((p) => p.item?.chain == 'egg')
          .length;
      final pending0 = g.state.pending.length;
      expect(g.buyShopItem(item.id), isTrue);
      expect(g.state.gems, 0);
      expect(events.single.rewards.length, item.loot.rolls);
      final eggs = g.state.board.indicesWhere((p) => p.item?.chain == 'egg');
      expect(
        eggs.length - eggs0 + g.state.pending.length - pending0,
        item.loot.rolls,
      );
    });

    test('island-locked items cannot be bought early', () {
      final g = newController();
      g.state.gems = 1000;
      expect(g.buyShopItem('legend_pack'), isFalse);
      g.state.island = 2;
      expect(g.buyShopItem('legend_pack'), isTrue);
    });

    test('hoard upgrades raise the offline cap', () {
      final g = newController();
      final base = g.offlineCapHours;
      g.state.gems = 1000;
      expect(g.buyHoardUpgrade(), isTrue);
      expect(g.offlineCapHours, base - g.eco.offlineCapHours + 12);
      expect(g.buyHoardUpgrade(), isTrue);
      expect(g.offlineCapHours, base - g.eco.offlineCapHours + 24);
      expect(g.buyHoardUpgrade(), isFalse);
    });
  });

  group('festival events', () {
    GameController eventReady([FakeClock? clock]) {
      final g = newController(clock: clock);
      g.state.level = g.config.events.unlockLevel;
      g.tick();
      return g;
    }

    test('events start at the unlock level with their own board', () {
      final g = newController();
      g.tick();
      expect(g.state.event, isNull);
      g.state.level = g.config.events.unlockLevel;
      g.tick();
      final e = g.state.event!;
      expect(e.id, g.scheduledEvent.id);
      final gen = e.board.indicesWhere(
        (p) => p.generatorId == g.scheduledEvent.generator,
      );
      expect(gen.length, 1);
    });

    test('the event board is separate and merges earn points', () {
      final g = eventReady();
      final main = g.state.board.cells.toList();
      g.setEventMode(true);
      expect(g.eventMode, isTrue);
      expect(identical(g.board, g.state.event!.board), isTrue);
      final chain = g.scheduledEvent.chain;
      final a = g.board.index(1, 4);
      final b = g.board.index(2, 4);
      g.board.cells[a] = Piece.item(g.state.newId(), ItemRef(chain, 2));
      g.board.cells[b] = Piece.item(g.state.newId(), ItemRef(chain, 2));
      expect(g.drop(Slot.board(a), Slot.board(b)), isTrue);
      expect(g.state.event!.points, g.config.events.pointsForMerge(3));
      g.setEventMode(false);
      expect(g.state.board.cells, main);
    });

    test(
      'producing on the event board spends energy and drops festival items',
      () {
        final g = eventReady();
        g.setEventMode(true);
        final gen = g.board
            .indicesWhere((p) => p.generatorId == g.scheduledEvent.generator)
            .single;
        final energy = g.energy;
        expect(g.produce(gen), ProduceResult.ok);
        expect(g.energy, energy - g.config.energyPerTap);
        final items = g.board.indicesWhere((p) => p.isItem).toList();
        expect(items.length, 1);
        expect(
          g.board.cells[items.single]!.item!.chain,
          g.scheduledEvent.chain,
        );
      },
    );

    test('storage is off limits on the event board', () {
      final g = eventReady();
      g.setEventMode(true);
      final i = g.board.index(2, 4);
      g.board.cells[i] = Piece.item(
        g.state.newId(),
        ItemRef(g.scheduledEvent.chain, 1),
      );
      expect(g.drop(Slot.board(i), const Slot.storage(0)), isFalse);
    });

    test('offering a max-level item gives points', () {
      final g = eventReady();
      g.setEventMode(true);
      final chain = g.config.chain(g.scheduledEvent.chain);
      final i = g.board.index(2, 4);
      g.board.cells[i] = Piece.item(
        g.state.newId(),
        ItemRef(chain.id, chain.maxLevel),
      );
      expect(g.canOffer(Slot.board(i)), isTrue);
      expect(g.offer(Slot.board(i)), isTrue);
      expect(g.state.event!.points, g.config.events.offerPoints);
      expect(g.board.cells[i], isNull);
    });

    test('milestones: free track, premium unlocked with gems', () {
      final g = eventReady();
      final ms = g.config.events.milestones;
      g.state.event!.points = ms.last.points;
      final dragons = g.state.dragons.length;
      for (var i = 0; i < ms.length; i++) {
        expect(g.claimMilestone(i), isTrue);
        expect(g.claimMilestone(i, premium: true), isFalse);
      }
      // The free track ends with the exclusive dragon.
      expect(g.state.dragons.length, dragons + 1);
      expect(g.state.dragons.last.type, g.scheduledEvent.dragon);
      g.state.gems = g.config.events.premiumCostGems;
      expect(g.unlockPremium(), isTrue);
      expect(g.state.gems, 0);
      expect(g.claimMilestone(0, premium: true), isTrue);
    });

    test('next week: unclaimed rewards are sent and a new event starts', () {
      final clock = FakeClock();
      final g = eventReady(clock);
      final first = g.state.event!.id;
      g.state.event!.points = 5000;
      final dragons = g.state.dragons.length;
      clock.advance(const Duration(days: 7));
      g.tick();
      expect(g.state.event!.id, isNot(first));
      expect(g.state.event!.points, 0);
      expect(g.state.dragons.length, dragons + 1); // unclaimed dragon sent
    });

    test('event state survives save and load', () {
      final g = eventReady();
      g.state.event!.points = 42;
      g.state.event!.claimedFree.add(0);
      final copy = GameState.fromJson(g.state.toJson());
      expect(copy.event!.points, 42);
      expect(copy.event!.claimedFree, {0});
      expect(copy.event!.board.size, g.state.event!.board.size);
    });
  });

  group('reminders', () {
    test('energy, hoard and daily reminders are scheduled on pause', () {
      final notes = NoopNotificationService();
      final g = newController(notifications: notes);
      g.state.level = 3;
      g.state.energy = 10;
      g.state.dragons.add(Dragon(id: 900, type: 'earth', level: 1));
      g.onPause();
      final ids = notes.scheduled.map((r) => r.id).toSet();
      expect(ids, containsAll([1, 2, 3]));
      for (final r in notes.scheduled) {
        expect(r.at.isAfter(g.clock()), isTrue);
      }
      g.checkWelcomeBack();
      expect(notes.scheduled, isEmpty);
    });

    test('turning reminders off schedules nothing', () async {
      final notes = NoopNotificationService();
      final g = newController(notifications: notes);
      await g.setReminders(false);
      g.onPause();
      expect(notes.scheduled, isEmpty);
    });
  });

  group('backup codes', () {
    test('a code restores the exact game', () async {
      final g = newController();
      g.state.level = 7;
      g.state.gems = 123;
      g.state.dragons.add(Dragon(id: 900, type: 'fire', level: 2));
      final code = g.exportBackup();
      expect(code, startsWith('GDI1.'));

      final other = newController(seed: 5);
      expect(await other.importBackup(code), isTrue);
      expect(other.state.level, 7);
      expect(other.state.gems, 123);
      expect(other.state.dragons.any((d) => d.id == 900), isTrue);
    });

    test('damaged codes are rejected', () async {
      final g = newController();
      final code = g.exportBackup();
      final broken = code.replaceRange(20, 21, code[20] == 'A' ? 'B' : 'A');
      expect(g.parseBackup(broken), isNull);
      expect(g.parseBackup('hello'), isNull);
      expect(await g.importBackup('GDI1.x.y'), isFalse);
    });
  });
}

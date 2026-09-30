import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/logic/game_events.dart';
import 'package:gemdrake_isles/model/game_state.dart';

import 'helpers.dart';

void main() {
  group('purchases', () {
    test('gem pack is granted once per transaction', () {
      final g = newController();
      final gems0 = g.state.gems;
      final events = <GameEvent>[];
      g.events.listen(events.add);
      expect(g.grantPurchase('gems_80', 'GPA.1'), isTrue);
      expect(g.state.gems, gems0 + 80);
      // The store sends the same payment again (e.g. after a restart).
      expect(g.grantPurchase('gems_80', 'GPA.1'), isFalse);
      expect(g.state.gems, gems0 + 80);
      expect(g.grantPurchase('gems_80', 'GPA.2'), isTrue);
      expect(g.state.gems, gems0 + 160);
      expect(g.grantPurchase('no_such_product', 'GPA.3'), isFalse);
    });

    test('purchase event is emitted for the thank-you popup', () async {
      final g = newController();
      final events = <GameEvent>[];
      g.events.listen(events.add);
      g.grantPurchase('energy_400', 'tx');
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<PurchaseEvent>().single.product.id, 'energy_400');
      expect(g.energy, greaterThanOrEqualTo(400));
    });

    test('starter pack is offered from its level, and only once', () {
      final g = newController();
      final starter = g.storeConfig.product('starter_pack')!;
      g.state.level = starter.minLevel - 1;
      expect(g.productOffered(starter), isFalse);
      g.state.level = starter.minLevel;
      expect(g.productOffered(starter), isTrue);
      final coins0 = g.state.coins;
      g.grantPurchase('starter_pack', 'tx1');
      expect(g.state.coins, coins0 + starter.coins);
      expect(g.productOffered(starter), isFalse);
      expect(
        g.productsIn('offer').map((p) => p.id),
        isNot(contains('starter_pack')),
      );
    });

    test('festival pass unlocks the premium track, or refunds gems', () {
      final g = newController();
      final pass = g.storeConfig.product('festival_pass')!;
      expect(g.productOffered(pass), isFalse); // no festival yet
      g.state.level = 20;
      g.tick();
      expect(g.state.event, isNotNull);
      expect(g.productOffered(pass), isTrue);
      g.grantPurchase('festival_pass', 'tx1');
      expect(g.state.event!.premium, isTrue);
      expect(g.productOffered(pass), isFalse);
      // Paid again after the track was unlocked: gems instead.
      final gems0 = g.state.gems;
      g.grantPurchase('festival_pass', 'tx2');
      expect(g.state.gems, gems0 + g.config.events.premiumCostGems);
    });

    test('Dragon Club: perks, daily gems, and it runs out', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      final vip = g.storeConfig.vip;
      final energyMax0 = g.energyMax;
      final hoard0 = g.offlineCapHours;
      expect(g.vipActive, isFalse);
      g.grantPurchase('vip_monthly', 'sub1', at: clock.now);
      expect(g.vipActive, isTrue);
      expect(g.energyMax, energyMax0 + vip.energyMax);
      expect(g.offlineCapHours, hoard0 + vip.offlineHours);
      final gems0 = g.state.gems;
      expect(g.claimVipGems(), isTrue);
      expect(g.claimVipGems(), isFalse);
      expect(g.state.gems, gems0 + vip.dailyGems);
      clock.advance(const Duration(days: 1));
      g.tick();
      expect(g.vipGemsReady, isTrue);
      clock.advance(const Duration(days: 31));
      expect(g.vipActive, isFalse);
      expect(g.energyMax, energyMax0);
      expect(g.claimVipGems(), isFalse);
    });

    test('an old restored subscription payment gives no new days', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      g.grantPurchase(
        'vip_monthly',
        'old',
        at: clock.now.subtract(const Duration(days: 60)),
      );
      expect(g.vipActive, isFalse);
      // A renewal 10 days ago runs until 21 days from now.
      g.grantPurchase(
        'vip_monthly',
        'renewal',
        at: clock.now.subtract(const Duration(days: 10)),
      );
      expect(g.vipActive, isTrue);
      clock.advance(const Duration(days: 22));
      expect(g.vipActive, isFalse);
      g.confirmVip(const Duration(days: 3));
      expect(g.vipActive, isTrue);
    });

    test('purchase state survives a save round trip', () {
      final g = newController();
      g.state.level = 5;
      g.grantPurchase('starter_pack', 'tx1');
      g.grantPurchase('vip_monthly', 'sub1');
      final json = jsonDecode(jsonEncode(g.state.toJson()));
      final s = GameState.fromJson(json as Map<String, dynamic>);
      expect(s.boughtOnce, contains('starter_pack'));
      expect(s.purchaseTx, containsAll(['tx1', 'sub1']));
      expect(s.vipUntil, g.state.vipUntil);
    });
  });

  group('shop extras', () {
    test('free chest: once a day, rewards from its table', () {
      final clock = FakeClock();
      final g = newController(clock: clock);
      expect(g.adsLeftToday(AdReward.freeChest), 1);
      final pending0 = g.state.pending.length;
      final chests0 = g.state.stat('chests');
      g.grantAdReward(AdReward.freeChest);
      expect(g.adsLeftToday(AdReward.freeChest), 0);
      expect(g.state.stat('chests'), chests0 + 1);
      expect(g.state.pending.length, greaterThanOrEqualTo(pending0));
      clock.advance(const Duration(days: 1));
      expect(g.adsLeftToday(AdReward.freeChest), 1);
    });

    test('species egg gives that dragon', () {
      final g = newController();
      g.state.gems = 1000;
      final dragons0 = g.state.dragons.length;
      expect(g.buyShopItem('fire_egg'), isTrue);
      expect(g.state.dragons.length, dragons0 + 1);
      expect(g.state.dragons.last.type, 'fire');
      // Locked until its island.
      expect(g.buyShopItem('shadow_egg'), isFalse);
    });

    test('board rows: each adds an empty row, keeping the pieces', () {
      final g = newController();
      g.state.gems = 1000;
      final b0 = g.state.board;
      final cells0 = [...b0.cells];
      final costs = g.config.meta.boardRowCosts;
      for (var i = 0; i < costs.length; i++) {
        expect(g.nextBoardRowCost, costs[i]);
        expect(g.buyBoardRow(), isTrue);
      }
      expect(g.nextBoardRowCost, isNull);
      expect(g.buyBoardRow(), isFalse);
      final b = g.state.board;
      expect(b.rows, b0.rows + costs.length);
      for (var i = 0; i < b0.size; i++) {
        expect(b.cells[i], same(cells0[i]));
      }
      for (var i = b0.size; i < b.size; i++) {
        expect(b.isFree(i), isTrue);
      }
      final json = jsonDecode(jsonEncode(g.state.toJson()));
      final s = GameState.fromJson(json as Map<String, dynamic>);
      expect(s.board.rows, b.rows);
      expect(s.extraRows, costs.length);
    });
  });
}

// Renders the shop with a fake store, and a board with extra rows
// (visual check only).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/services/ads_service.dart';
import 'package:gemdrake_isles/services/purchase_service.dart';
import 'package:gemdrake_isles/ui/app.dart';
import 'package:gemdrake_isles/ui/dialogs/meta_dialogs.dart';
import 'package:gemdrake_isles/ui/screens/home_shell.dart';

import '../test/helpers.dart';
import 'fx_shot_test.dart' show loadFonts, snap;

/// A store that sells everything at made-up prices.
class FakeStore extends PurchaseService {
  final _messages = StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  bool get available => true;

  @override
  String? price(String productId) => const {
    'gems_80': '0,99 €',
    'gems_450': '4,99 €',
    'gems_1000': '9,99 €',
    'gems_2200': '19,99 €',
    'gems_6000': '49,99 €',
    'starter_pack': '2,99 €',
    'vip_monthly': '4,99 €',
    'energy_400': '1,99 €',
    'dragon_bundle': '7,99 €',
    'festival_pass': '4,99 €',
  }[productId];

  @override
  bool pending(String productId) => false;

  @override
  Future<void> buy(String productId) async {}

  @override
  Future<void> restore() async {}

  @override
  Stream<String> get messages => _messages.stream;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('shop', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    final game = newController();
    game.state.loginClaimedDay = game.today;
    game.state.level = 6;
    game.state.gems = 240;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: GemdrakeApp(
          game: game,
          ads: SimulatedAdsService(seconds: 0),
          store: FakeStore(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final ctx = tester.element(find.byType(HomeShell));
    showShop(ctx);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await snap(tester, key, 'shop_top');
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, key, 'shop_mid');
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -1400),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, key, 'shop_end');
    Navigator.of(ctx).pop();
    await tester.pump(const Duration(milliseconds: 400));
    // VIP active + bigger board
    game.grantPurchase('vip_monthly', 'sub');
    game.state.gems = 1000;
    game.buyBoardRow();
    game.buyBoardRow();
    await tester.pump(const Duration(seconds: 2));
    Navigator.of(ctx).pop(); // thank-you popup
    await tester.pump(const Duration(milliseconds: 600));
    await snap(tester, key, 'board_rows');
    showShop(ctx);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await snap(tester, key, 'shop_vip');
    Navigator.of(ctx).pop();
    await tester.pump(const Duration(milliseconds: 400));
    game.state.level = 20;
    game.tick();
    await tester.tap(find.text('Festival').last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await snap(tester, key, 'festival');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}

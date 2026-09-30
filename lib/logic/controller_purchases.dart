part of 'game_controller.dart';

/// Real-money purchases and the Dragon Club subscription. The store service
/// reports finished payments here; everything a product gives is decided by
/// `store.json`.
extension Purchases on GameController {
  StoreConfig get storeConfig => config.store;

  bool get vipActive => state.vipUntil > nowMs;

  DateTime get vipEnds => DateTime.fromMillisecondsSinceEpoch(state.vipUntil);

  /// Whether [p] should be offered right now.
  bool productOffered(StoreProductDef p) {
    if (!storeConfig.enabled) return false;
    if (p.once && state.boughtOnce.contains(p.id)) return false;
    if (state.level < p.minLevel) return false;
    if (p.festivalPass) {
      final e = state.event;
      return e != null && !e.premium;
    }
    return true;
  }

  List<StoreProductDef> productsIn(String section) => [
    for (final p in storeConfig.products)
      if (p.section == section && productOffered(p)) p,
  ];

  /// Whether a store transaction was already handed out.
  bool purchaseGranted(String transactionId) =>
      transactionId.isNotEmpty && state.purchaseTx.contains(transactionId);

  /// Hands out a paid product. [transactionId] makes this safe to call
  /// more than once for the same payment; [at] is when it was paid (used
  /// for subscriptions). Returns false if nothing was granted.
  bool grantPurchase(String productId, String transactionId, {DateTime? at}) {
    final p = storeConfig.product(productId);
    if (p == null || purchaseGranted(transactionId)) return false;
    if (transactionId.isNotEmpty) {
      state.purchaseTx.add(transactionId);
      if (state.purchaseTx.length > 200) state.purchaseTx.removeAt(0);
    }
    if (p.vipDays > 0) {
      _accrueIdle(nowMs); // bank earnings under the old hoard size
      // Counted from the payment date, so an old restored payment doesn't
      // give new days.
      final from = (at ?? clock()).millisecondsSinceEpoch;
      final until = from + p.vipDays * Duration.millisecondsPerDay;
      state.vipUntil = max(state.vipUntil, until);
    }
    final rewards = p.rewards;
    if (p.festivalPass) {
      final e = state.event;
      if (e != null && !e.premium) {
        e.premium = true;
      } else {
        // The festival ended before the payment went through.
        rewards.add(LootEntry(weight: 1, gems: ev.premiumCostGems));
      }
    }
    grantLoot(rewards);
    if (p.once) state.boughtOnce.add(p.id);
    state.addStat('purchases');
    feedback.play(Sfx.levelUp);
    feedback.haptic(heavy: true);
    analytics.log('purchase', {'product': p.id});
    _emit(PurchaseEvent(p, rewards));
    _notify();
    save(immediate: true);
    return true;
  }

  /// Keeps the Dragon Club active while the store reports the subscription
  /// as current (Google Play lists only active subscriptions).
  void confirmVip(Duration grace) {
    final until = nowMs + grace.inMilliseconds;
    if (until <= state.vipUntil) return;
    _accrueIdle(nowMs);
    state.vipUntil = until;
    _commit();
  }

  bool get vipGemsReady => vipActive && state.vipClaimDay != today;

  bool claimVipGems() {
    if (!vipGemsReady) return false;
    state.vipClaimDay = today;
    state.gems += storeConfig.vip.dailyGems;
    feedback.play(Sfx.coin);
    analytics.log('vip_claim', {'gems': storeConfig.vip.dailyGems});
    _commit();
    return true;
  }
}

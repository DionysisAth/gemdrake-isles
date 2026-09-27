part of 'game_controller.dart';

/// Island travel and treasure chests.
extension IslandTravel on GameController {
  /// Moves on to the next island once the current one is fully restored.
  bool travelToNextIsland() {
    if (!islandComplete || !hasNextIsland) return false;
    state.island += 1;
    final island = currentIsland;
    final unlocks = [
      ..._giveMissingGenerators(),
      for (final c in config.chains)
        if (c.unlockIsland == state.island + 1 && chainUnlocked(c.id))
          '${c.name} in orders',
      for (final c in config.orders.characters)
        if (c.unlockIsland == state.island + 1) '${c.name}, ${c.title}',
    ];
    // Fresh orders featuring the new island's items.
    state.orders.clear();
    _refillOrders();
    feedback.play(Sfx.levelUp);
    feedback.haptic(heavy: true);
    analytics.log('island_travel', {'island': island.id});
    _emit(IslandTravelEvent(island, unlocks));
    _commit();
    return true;
  }

  /// Whether the item in [s] can be opened (a max-level treasure chest).
  bool canOpen(Slot s) {
    final ref = pieceAt(s)?.item;
    if (ref == null) return false;
    final chain = config.chain(ref.chain);
    return chain.loot != null && ref.level == chain.maxLevel;
  }

  /// Opens the chest in [s], handing out its random rewards.
  List<LootEntry> openChest(Slot s) {
    if (!canOpen(s)) return const [];
    if (!s.storage && board.isLocked(s.index)) return const [];
    final ref = pieceAt(s)!.item!;
    final loot = config.chain(ref.chain).loot!;
    _setPiece(s, null);
    if (_selected == s) _selected = null;
    final rewards = rollLoot(loot);
    grantLoot(rewards, near: s.storage ? null : s.index);
    state.addStat('chests');
    feedback.play(Sfx.collect);
    feedback.haptic(heavy: true);
    analytics.log('chest_open', {'item': ref.key});
    _emit(
      ChestOpenedEvent(
        config.item(ref).name,
        rewards,
        cell: s.storage ? null : s.index,
      ),
    );
    _commit();
    return rewards;
  }

  /// Rolls a loot table.
  List<LootEntry> rollLoot(LootDef loot) {
    final total = loot.totalWeight;
    return [
      for (var i = 0; i < loot.rolls; i++)
        () {
          var r = random.nextInt(total);
          for (final e in loot.table) {
            r -= e.weight;
            if (r < 0) return e;
          }
          return loot.table.last;
        }(),
    ];
  }

  /// Applies rolled rewards: currencies immediately, items onto the board.
  void grantLoot(List<LootEntry> rewards, {int? near}) {
    for (final e in rewards) {
      state.coins += e.coins;
      state.gems += e.gems;
      if (e.energy > 0) _addEnergy(e.energy);
      final item = e.item;
      if (item != null) _giveReward(item.key, near: near);
      final type = e.dragon;
      if (type != null) {
        _accrueIdle(nowMs);
        final d = Dragon(id: state.newId(), type: type, level: 1);
        state.dragons.add(d);
        state.discovered.add(d.key);
      }
    }
  }
}

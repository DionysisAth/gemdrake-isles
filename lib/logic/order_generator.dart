import 'dart:math';

import '../config/game_config.dart';
import '../model/game_state.dart';
import '../model/item_ref.dart';

/// Builds orders: first the scripted tutorial orders, then random orders
/// scaled to the player's level using the bands in `orders.json`.
class OrderGenerator {
  OrderGenerator(this.config, this.random);

  final GameConfig config;
  final Random random;

  Order next(GameState state) {
    final oc = config.orders;
    if (state.scriptedOrderIndex < oc.scripted.length) {
      final s = oc.scripted[state.scriptedOrderIndex++];
      return Order(
        id: state.newId(),
        character: s.character,
        lines: [for (final l in s.lines) OrderLine(l.item, l.count)],
        coins: s.coins,
        xp: s.xp,
      );
    }
    return _random(state);
  }

  Order _random(GameState state) {
    final oc = config.orders;
    final level = state.level;
    final band = oc.band(level);
    final chains = config.chains
        .where(
          (c) => c.orderable && config.chainAvailable(c, level, state.island),
        )
        .toList();
    final characters = oc.characters
        .where(
          (c) => c.unlockLevel <= level && c.unlockIsland <= state.island + 1,
        )
        .toList();

    // Avoid asking for exactly what another active order asks for.
    final taken = {
      for (final o in state.orders)
        for (final l in o.lines) l.item,
    };

    final lineCount = 1 + random.nextInt(band.maxLines);
    final lines = <ItemRef, int>{};
    for (var n = 0; n < lineCount * 4 && lines.length < lineCount; n++) {
      final chain = chains[random.nextInt(chains.length)];
      final maxL = min(band.maxItemLevel, chain.maxLevel);
      final minL = min(band.minItemLevel, maxL);
      final lvl = minL + random.nextInt(maxL - minL + 1);
      final ref = ItemRef(chain.id, lvl);
      if (lines.containsKey(ref)) continue;
      if (taken.contains(ref) && n < lineCount * 3) continue;
      final count = lvl <= 2 ? 1 + random.nextInt(band.maxCount) : 1;
      lines[ref] = count;
    }
    if (lines.isEmpty) lines[ItemRef(chains.first.id, band.minItemLevel)] = 1;

    var value = 0, xp = 0;
    lines.forEach((ref, count) {
      final def = config.item(ref);
      value += def.value * count;
      xp += def.xp * count;
    });

    var gems = 0, energy = 0;
    final items = <ItemRef>[];
    final eggChain = config.chain(oc.eggItem.chain);
    if (level >= eggChain.unlockLevel && random.nextDouble() < oc.eggChance) {
      items.add(oc.eggItem);
    } else if (random.nextDouble() < oc.gemChance) {
      gems = _between(oc.gemAmount);
    } else if (random.nextDouble() < oc.energyChance) {
      energy = _between(oc.energyAmount);
    }

    return Order(
      id: state.newId(),
      character: characters[random.nextInt(characters.length)].id,
      lines: [for (final e in lines.entries) OrderLine(e.key, e.value)],
      coins: max(1, (value * oc.coinMultiplier).round()),
      xp: max(1, (xp * oc.xpMultiplier).round()),
      gems: gems,
      energy: energy,
      items: items,
    );
  }

  int _between(List<int> range) =>
      range[0] + random.nextInt(range[1] - range[0] + 1);
}

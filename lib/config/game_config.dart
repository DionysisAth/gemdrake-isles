import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show AssetBundle;

import '../model/item_ref.dart';

/// All game content and economy numbers, loaded from `assets/config/*.json`.
///
/// Nothing about balancing is hardcoded in the game logic: chains, drop
/// tables, orders, prices, energy rates and dragon stats all live here so
/// they can later be swapped for remote config without an app update.
class GameConfig {
  GameConfig({
    required this.chains,
    required this.generators,
    required this.energyPerTap,
    required this.dragons,
    required this.economy,
    required this.orders,
    required this.islands,
    required this.board,
    required this.tutorial,
  });

  static const files = [
    'items',
    'generators',
    'dragons',
    'economy',
    'orders',
    'island',
    'board',
    'tutorial',
  ];

  static Future<GameConfig> load(AssetBundle bundle) async {
    final json = <String, Map<String, dynamic>>{};
    for (final name in files) {
      final raw = await bundle.loadString('assets/config/$name.json');
      json[name] = jsonDecode(raw) as Map<String, dynamic>;
    }
    return GameConfig.fromJson(json);
  }

  factory GameConfig.fromJson(Map<String, Map<String, dynamic>> j) {
    final gens = j['generators']!;
    return GameConfig(
      chains: [
        for (final c in j['items']!['chains'] as List) ChainDef.fromJson(c),
      ],
      generators: [
        for (final g in gens['generators'] as List) GeneratorDef.fromJson(g),
      ],
      energyPerTap: gens['energyPerTap'] as int? ?? 1,
      dragons: DragonsConfig.fromJson(j['dragons']!),
      economy: EconomyConfig.fromJson(j['economy']!),
      orders: OrdersConfig.fromJson(j['orders']!),
      islands: [
        for (final i in j['island']!['islands'] as List) IslandDef.fromJson(i),
      ],
      board: BoardConfig.fromJson(j['board']!),
      tutorial: [
        for (final s in j['tutorial']!['steps'] as List)
          TutorialStepDef.fromJson(s),
      ],
    );
  }

  final List<ChainDef> chains;
  final List<GeneratorDef> generators;
  final int energyPerTap;
  final DragonsConfig dragons;
  final EconomyConfig economy;
  final OrdersConfig orders;
  final List<IslandDef> islands;
  final BoardConfig board;
  final List<TutorialStepDef> tutorial;

  ChainDef chain(String id) => chains.firstWhere((c) => c.id == id);
  ItemDef item(ItemRef ref) => chain(ref.chain).items[ref.level - 1];
  GeneratorDef generator(String id) => generators.firstWhere((g) => g.id == id);
  DragonTypeDef dragonType(String id) =>
      dragons.types.firstWhere((t) => t.id == id);
  RarityDef rarity(String id) => dragons.rarities.firstWhere((r) => r.id == id);
  IslandDef get currentIsland => islands.first;

  bool isValidItem(ItemRef ref) {
    final c = chains.where((c) => c.id == ref.chain).firstOrNull;
    return c != null && ref.level >= 1 && ref.level <= c.maxLevel;
  }

  /// XP needed to go from [level] to [level] + 1.
  int xpToNext(int level) {
    final table = economy.xpToNext;
    if (level <= table.length) return table[level - 1];
    return table.last + (level - table.length) * economy.xpGrowthAfter;
  }
}

Color parseColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

class ItemDef {
  ItemDef({
    required this.name,
    required this.desc,
    required this.value,
    required this.sell,
    required this.xp,
  });

  factory ItemDef.fromJson(Map<String, dynamic> j) => ItemDef(
    name: j['name'] as String,
    desc: j['desc'] as String? ?? '',
    value: j['value'] as int,
    sell: j['sell'] as int,
    xp: j['xp'] as int,
  );

  final String name;
  final String desc;

  /// Coin value used when pricing orders.
  final int value;
  final int sell;
  final int xp;
}

class ChainDef {
  ChainDef({
    required this.id,
    required this.name,
    required this.unlockLevel,
    required this.orderable,
    required this.hatchOnMaxMerge,
    required this.items,
  });

  factory ChainDef.fromJson(Map<String, dynamic> j) => ChainDef(
    id: j['id'] as String,
    name: j['name'] as String,
    unlockLevel: j['unlockLevel'] as int? ?? 1,
    orderable: j['orderable'] as bool? ?? true,
    hatchOnMaxMerge: j['hatchOnMaxMerge'] as bool? ?? false,
    items: [for (final i in j['items'] as List) ItemDef.fromJson(i)],
  );

  final String id;
  final String name;
  final int unlockLevel;
  final bool orderable;

  /// When true, merging two max-level items hatches a dragon.
  final bool hatchOnMaxMerge;
  final List<ItemDef> items;

  int get maxLevel => items.length;
}

class DropDef {
  DropDef({required this.item, required this.weight, this.minPlayerLevel = 1});

  factory DropDef.fromJson(Map<String, dynamic> j) => DropDef(
    item: ItemRef.parse(j['item'] as String),
    weight: j['weight'] as int,
    minPlayerLevel: j['minPlayerLevel'] as int? ?? 1,
  );

  final ItemRef item;
  final int weight;
  final int minPlayerLevel;
}

class GeneratorLevelDef {
  GeneratorLevelDef({
    required this.charges,
    required this.cooldownSeconds,
    required this.upgradeCost,
    required this.drops,
  });

  factory GeneratorLevelDef.fromJson(Map<String, dynamic> j) =>
      GeneratorLevelDef(
        charges: j['charges'] as int,
        cooldownSeconds: j['cooldownSeconds'] as int,
        upgradeCost: j['upgradeCost'] as int? ?? 0,
        drops: [for (final d in j['drops'] as List) DropDef.fromJson(d)],
      );

  final int charges;
  final int cooldownSeconds;

  /// Coins to upgrade *to* this level.
  final int upgradeCost;
  final List<DropDef> drops;

  List<DropDef> dropsFor(int playerLevel) =>
      drops.where((d) => playerLevel >= d.minPlayerLevel).toList();
}

class GeneratorDef {
  GeneratorDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.unlockLevel,
    required this.spawnCell,
    required this.style,
    required this.levels,
  });

  factory GeneratorDef.fromJson(Map<String, dynamic> j) {
    final cell = j['spawnCell'] as List;
    return GeneratorDef(
      id: j['id'] as String,
      name: j['name'] as String,
      desc: j['desc'] as String? ?? '',
      unlockLevel: j['unlockLevel'] as int? ?? 1,
      spawnCell: Point(cell[0] as int, cell[1] as int),
      style: j['style'] as String? ?? 'mine',
      levels: [
        for (final l in j['levels'] as List) GeneratorLevelDef.fromJson(l),
      ],
    );
  }

  final String id;
  final String name;
  final String desc;
  final int unlockLevel;
  final Point<int> spawnCell;
  final String style;
  final List<GeneratorLevelDef> levels;

  int get maxLevel => levels.length;
  GeneratorLevelDef level(int l) => levels[l.clamp(1, levels.length) - 1];
}

class RarityDef {
  RarityDef({
    required this.id,
    required this.name,
    required this.color,
    required this.coinsPerMinute,
  });

  factory RarityDef.fromJson(Map<String, dynamic> j) => RarityDef(
    id: j['id'] as String,
    name: j['name'] as String,
    color: parseColor(j['color'] as String),
    coinsPerMinute: (j['coinsPerMinute'] as num).toDouble(),
  );

  final String id;
  final String name;
  final Color color;
  final double coinsPerMinute;
}

class DragonLevelDef {
  DragonLevelDef({
    required this.name,
    required this.multiplier,
    required this.gemsPerHour,
  });

  factory DragonLevelDef.fromJson(Map<String, dynamic> j) => DragonLevelDef(
    name: j['name'] as String,
    multiplier: (j['multiplier'] as num).toDouble(),
    gemsPerHour: (j['gemsPerHour'] as num? ?? 0).toDouble(),
  );

  final String name;
  final double multiplier;
  final double gemsPerHour;
}

class DragonTypeDef {
  DragonTypeDef({
    required this.id,
    required this.name,
    required this.rarity,
    required this.desc,
    required this.body,
    required this.belly,
    required this.wing,
    required this.accent,
  });

  factory DragonTypeDef.fromJson(Map<String, dynamic> j) => DragonTypeDef(
    id: j['id'] as String,
    name: j['name'] as String,
    rarity: j['rarity'] as String,
    desc: j['desc'] as String? ?? '',
    body: parseColor(j['body'] as String),
    belly: parseColor(j['belly'] as String),
    wing: parseColor(j['wing'] as String),
    accent: parseColor(j['accent'] as String),
  );

  final String id;
  final String name;
  final String rarity;
  final String desc;
  final Color body;
  final Color belly;
  final Color wing;
  final Color accent;
}

class WeightedType {
  WeightedType(this.type, this.weight);
  final String type;
  final int weight;
}

class DragonsConfig {
  DragonsConfig({
    required this.rarities,
    required this.levels,
    required this.types,
    required this.hatchTable,
  });

  factory DragonsConfig.fromJson(Map<String, dynamic> j) => DragonsConfig(
    rarities: [for (final r in j['rarities'] as List) RarityDef.fromJson(r)],
    levels: [for (final l in j['levels'] as List) DragonLevelDef.fromJson(l)],
    types: [for (final t in j['types'] as List) DragonTypeDef.fromJson(t)],
    hatchTable: [
      for (final h in j['hatchTable'] as List)
        WeightedType(h['type'] as String, h['weight'] as int),
    ],
  );

  final List<RarityDef> rarities;
  final List<DragonLevelDef> levels;
  final List<DragonTypeDef> types;
  final List<WeightedType> hatchTable;

  int get maxLevel => levels.length;
  DragonLevelDef level(int l) => levels[l - 1];
}

class EconomyConfig {
  EconomyConfig(Map<String, dynamic> j)
    : startCoins = j['start']['coins'] as int,
      startGems = j['start']['gems'] as int,
      startEnergy = j['start']['energy'] as int,
      energyMax = j['energy']['max'] as int,
      energyRefillSeconds = j['energy']['refillSeconds'] as int,
      energyOverflowCap = j['energy']['overflowCap'] as int? ?? 999,
      standardConsume = j['merge']['standardConsume'] as int,
      standardYield = j['merge']['standardYield'] as int,
      bonusEnabled = j['merge']['bonusEnabled'] as bool,
      bonusConsume = j['merge']['bonusConsume'] as int,
      bonusYield = j['merge']['bonusYield'] as int,
      freeStorageSlots = j['storage']['freeSlots'] as int,
      storageSlotCostsGems = (j['storage']['slotCostsGems'] as List)
          .cast<int>(),
      offlineCapHours = (j['offline']['capHours'] as num).toDouble(),
      welcomeBackMinSeconds = j['offline']['welcomeBackMinSeconds'] as int,
      xpToNext = (j['levels']['xpToNext'] as List).cast<int>(),
      xpGrowthAfter = j['levels']['xpGrowthAfter'] as int,
      levelUpGems = j['levels']['rewardGems'] as int,
      levelUpRefillsEnergy = j['levels']['refillEnergy'] as bool,
      energyRefillGemCost = j['gems']['energyRefillCost'] as int,
      cooldownSkipMinutesPerGem = j['gems']['cooldownSkipMinutesPerGem'] as int,
      confirmGemsAbove = j['gems']['confirmAbove'] as int,
      adFreeEnergyAmount = j['ads']['freeEnergyAmount'] as int,
      adFreeEnergyPerDay = j['ads']['freeEnergyPerDay'] as int,
      adGeneratorSkipPerDay = j['ads']['generatorSkipPerDay'] as int,
      adsFallbackToSimulated = j['ads']['fallbackToSimulated'] as bool,
      simulatedAdSeconds = j['ads']['simulatedAdSeconds'] as int,
      rewardedUnitIds = (j['ads']['rewardedUnitIds'] as Map)
          .cast<String, String>();

  factory EconomyConfig.fromJson(Map<String, dynamic> j) => EconomyConfig(j);

  final int startCoins;
  final int startGems;
  final int startEnergy;
  final int energyMax;
  final int energyRefillSeconds;
  final int energyOverflowCap;
  final int standardConsume;
  final int standardYield;
  final bool bonusEnabled;
  final int bonusConsume;
  final int bonusYield;
  final int freeStorageSlots;
  final List<int> storageSlotCostsGems;
  final double offlineCapHours;
  final int welcomeBackMinSeconds;
  final List<int> xpToNext;
  final int xpGrowthAfter;
  final int levelUpGems;
  final bool levelUpRefillsEnergy;
  final int energyRefillGemCost;
  final int cooldownSkipMinutesPerGem;
  final int confirmGemsAbove;
  final int adFreeEnergyAmount;
  final int adFreeEnergyPerDay;
  final int adGeneratorSkipPerDay;
  final bool adsFallbackToSimulated;
  final int simulatedAdSeconds;
  final Map<String, String> rewardedUnitIds;
}

class CharacterDef {
  CharacterDef({
    required this.id,
    required this.name,
    required this.title,
    required this.unlockLevel,
    required this.skin,
    required this.hat,
    required this.hatColor,
    required this.lines,
  });

  factory CharacterDef.fromJson(Map<String, dynamic> j) => CharacterDef(
    id: j['id'] as String,
    name: j['name'] as String,
    title: j['title'] as String? ?? '',
    unlockLevel: j['unlockLevel'] as int? ?? 1,
    skin: parseColor(j['skin'] as String),
    hat: j['hat'] as String,
    hatColor: parseColor(j['hatColor'] as String),
    lines: (j['lines'] as List).cast<String>(),
  );

  final String id;
  final String name;
  final String title;
  final int unlockLevel;
  final Color skin;
  final String hat;
  final Color hatColor;
  final List<String> lines;
}

class OrderLineDef {
  OrderLineDef(this.item, this.count);

  factory OrderLineDef.fromJson(Map<String, dynamic> j) =>
      OrderLineDef(ItemRef.parse(j['item'] as String), j['count'] as int? ?? 1);

  final ItemRef item;
  final int count;
}

class ScriptedOrderDef {
  ScriptedOrderDef({
    required this.character,
    required this.lines,
    required this.coins,
    required this.xp,
  });

  factory ScriptedOrderDef.fromJson(Map<String, dynamic> j) => ScriptedOrderDef(
    character: j['character'] as String,
    lines: [for (final l in j['lines'] as List) OrderLineDef.fromJson(l)],
    coins: j['coins'] as int,
    xp: j['xp'] as int,
  );

  final String character;
  final List<OrderLineDef> lines;
  final int coins;
  final int xp;
}

class OrderBand {
  OrderBand({
    required this.fromLevel,
    required this.minItemLevel,
    required this.maxItemLevel,
    required this.maxLines,
    required this.maxCount,
  });

  factory OrderBand.fromJson(Map<String, dynamic> j) => OrderBand(
    fromLevel: j['fromLevel'] as int,
    minItemLevel: j['minItemLevel'] as int,
    maxItemLevel: j['maxItemLevel'] as int,
    maxLines: j['maxLines'] as int,
    maxCount: j['maxCount'] as int,
  );

  final int fromLevel;
  final int minItemLevel;
  final int maxItemLevel;
  final int maxLines;
  final int maxCount;
}

class OrdersConfig {
  OrdersConfig(Map<String, dynamic> j)
    : characters = [
        for (final c in j['characters'] as List) CharacterDef.fromJson(c),
      ],
      maxActiveByLevel = [
        for (final m in j['maxActiveByLevel'] as List)
          (m['fromLevel'] as int, m['count'] as int),
      ],
      scripted = [
        for (final s in j['scripted'] as List) ScriptedOrderDef.fromJson(s),
      ],
      bands = [for (final b in j['bands'] as List) OrderBand.fromJson(b)],
      coinMultiplier = (j['coinMultiplier'] as num).toDouble(),
      xpMultiplier = (j['xpMultiplier'] as num).toDouble(),
      eggChance = (j['bonus']['eggChance'] as num).toDouble(),
      eggItem = ItemRef.parse(j['bonus']['eggItem'] as String),
      gemChance = (j['bonus']['gemChance'] as num).toDouble(),
      gemAmount = (j['bonus']['gemAmount'] as List).cast<int>(),
      energyChance = (j['bonus']['energyChance'] as num).toDouble(),
      energyAmount = (j['bonus']['energyAmount'] as List).cast<int>();

  factory OrdersConfig.fromJson(Map<String, dynamic> j) => OrdersConfig(j);

  final List<CharacterDef> characters;
  final List<(int, int)> maxActiveByLevel;
  final List<ScriptedOrderDef> scripted;
  final List<OrderBand> bands;
  final double coinMultiplier;
  final double xpMultiplier;
  final double eggChance;
  final ItemRef eggItem;
  final double gemChance;
  final List<int> gemAmount;
  final double energyChance;
  final List<int> energyAmount;

  CharacterDef character(String id) => characters.firstWhere((c) => c.id == id);

  int maxActive(int level) {
    var n = maxActiveByLevel.first.$2;
    for (final (from, count) in maxActiveByLevel) {
      if (level >= from) n = count;
    }
    return n;
  }

  OrderBand band(int level) =>
      bands.lastWhere((b) => level >= b.fromLevel, orElse: () => bands.first);
}

class PerkDef {
  PerkDef({required this.type, required this.value, required this.text});

  factory PerkDef.fromJson(Map<String, dynamic> j) => PerkDef(
    type: j['type'] as String,
    value: (j['value'] as num).toDouble(),
    text: j['text'] as String? ?? '',
  );

  /// One of: energyMax, storageSlots, offlineHours, dragonBoost.
  final String type;
  final double value;
  final String text;
}

class IslandTaskDef {
  IslandTaskDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.cost,
    required this.xp,
    required this.requiresLevel,
    required this.requires,
    required this.element,
    this.perk,
  });

  factory IslandTaskDef.fromJson(Map<String, dynamic> j) => IslandTaskDef(
    id: j['id'] as String,
    name: j['name'] as String,
    desc: j['desc'] as String? ?? '',
    cost: j['cost'] as int,
    xp: j['xp'] as int? ?? 0,
    requiresLevel: j['requiresLevel'] as int? ?? 1,
    requires: (j['requires'] as List? ?? const []).cast<String>(),
    element: j['element'] as String,
    perk: j['perk'] == null ? null : PerkDef.fromJson(j['perk']),
  );

  final String id;
  final String name;
  final String desc;
  final int cost;
  final int xp;
  final int requiresLevel;
  final List<String> requires;
  final String element;
  final PerkDef? perk;
}

class IslandDef {
  IslandDef({
    required this.id,
    required this.name,
    required this.theme,
    required this.completeText,
    required this.tasks,
  });

  factory IslandDef.fromJson(Map<String, dynamic> j) => IslandDef(
    id: j['id'] as String,
    name: j['name'] as String,
    theme: j['theme'] as String,
    completeText: j['completeText'] as String? ?? '',
    tasks: [for (final t in j['tasks'] as List) IslandTaskDef.fromJson(t)],
  );

  final String id;
  final String name;
  final String theme;
  final String completeText;
  final List<IslandTaskDef> tasks;
}

class LockTypeDef {
  LockTypeDef({
    required this.symbol,
    required this.id,
    required this.name,
    required this.hits,
    required this.hidesContent,
  });

  factory LockTypeDef.fromJson(Map<String, dynamic> j) => LockTypeDef(
    symbol: j['symbol'] as String,
    id: j['id'] as String,
    name: j['name'] as String,
    hits: j['hits'] as int,
    hidesContent: j['hidesContent'] as bool,
  );

  final String symbol;
  final String id;
  final String name;
  final int hits;

  /// Hidden contents can't be merged onto until the lock is cleared.
  final bool hidesContent;
}

class BoardContentDef {
  BoardContentDef({required this.cell, this.item, this.generator});

  factory BoardContentDef.fromJson(Map<String, dynamic> j) {
    final c = j['cell'] as List;
    return BoardContentDef(
      cell: Point(c[0] as int, c[1] as int),
      item: j['item'] == null ? null : ItemRef.parse(j['item'] as String),
      generator: j['generator'] as String?,
    );
  }

  final Point<int> cell;
  final ItemRef? item;
  final String? generator;
}

class BoardConfig {
  BoardConfig({
    required this.cols,
    required this.rows,
    required this.lockTypes,
    required this.locks,
    required this.contents,
  });

  factory BoardConfig.fromJson(Map<String, dynamic> j) => BoardConfig(
    cols: j['cols'] as int,
    rows: j['rows'] as int,
    lockTypes: [
      for (final l in j['lockTypes'] as List) LockTypeDef.fromJson(l),
    ],
    locks: (j['locks'] as List).cast<String>(),
    contents: [
      for (final c in j['contents'] as List) BoardContentDef.fromJson(c),
    ],
  );

  final int cols;
  final int rows;
  final List<LockTypeDef> lockTypes;
  final List<String> locks;
  final List<BoardContentDef> contents;

  LockTypeDef? lockForSymbol(String s) =>
      lockTypes.where((l) => l.symbol == s).firstOrNull;
  LockTypeDef lockType(String id) => lockTypes.firstWhere((l) => l.id == id);
}

class TutorialStepDef {
  TutorialStepDef({
    required this.id,
    required this.speaker,
    required this.text,
    required this.advance,
    this.target,
    this.count = 1,
  });

  factory TutorialStepDef.fromJson(Map<String, dynamic> j) => TutorialStepDef(
    id: j['id'] as String,
    speaker: j['speaker'] as String,
    text: j['text'] as String,
    advance: j['advance'] as String,
    target: j['target'] as String?,
    count: j['count'] as int? ?? 1,
  );

  final String id;
  final String speaker;
  final String text;

  /// `tap` (player taps the bubble) or `event:<name>`.
  final String advance;

  /// What the pointer highlights, e.g. `generator:crystal_mine`, `order:0`.
  final String? target;
  final int count;

  bool get advancesOnTap => advance == 'tap';
  String? get eventName =>
      advance.startsWith('event:') ? advance.substring(6) : null;
}

import 'dart:math';

import 'item_ref.dart';

/// Something that occupies a board cell or storage slot: an item or a
/// generator. Each piece has a stable [id] so the UI can animate it as it
/// moves around.
class Piece {
  Piece.item(this.id, ItemRef this.item)
    : generatorId = null,
      genLevel = 0,
      charges = 0,
      cooldownUntil = 0;

  Piece.generator(
    this.id,
    String this.generatorId, {
    this.genLevel = 1,
    required this.charges,
    this.cooldownUntil = 0,
  }) : item = null;

  factory Piece.fromJson(Map<String, dynamic> j) {
    if (j['g'] != null) {
      return Piece.generator(
        j['id'] as int,
        j['g'] as String,
        genLevel: j['gl'] as int? ?? 1,
        charges: j['c'] as int? ?? 0,
        cooldownUntil: j['cd'] as int? ?? 0,
      );
    }
    return Piece.item(j['id'] as int, ItemRef.parse(j['i'] as String));
  }

  final int id;
  final ItemRef? item;
  final String? generatorId;

  // Generator-only state.
  int genLevel;
  int charges;

  /// Epoch ms when the generator finishes recharging; 0 when not recharging.
  int cooldownUntil;

  bool get isGenerator => generatorId != null;
  bool get isItem => item != null;

  Map<String, dynamic> toJson() => isGenerator
      ? {
          'id': id,
          'g': generatorId,
          'gl': genLevel,
          'c': charges,
          'cd': cooldownUntil,
        }
      : {'id': id, 'i': item!.key};
}

class CellLock {
  CellLock(this.type, this.hits);

  factory CellLock.fromJson(Map<String, dynamic> j) =>
      CellLock(j['t'] as String, j['h'] as int);

  /// Lock type id from board config (fog, web, rubble).
  final String type;
  int hits;

  Map<String, dynamic> toJson() => {'t': type, 'h': hits};
}

class Board {
  Board(this.cols, this.rows)
    : cells = List<Piece?>.filled(cols * rows, null),
      locks = List<CellLock?>.filled(cols * rows, null);

  factory Board.fromJson(Map<String, dynamic> j) {
    final b = Board(j['cols'] as int, j['rows'] as int);
    final cells = j['cells'] as List;
    final locks = j['locks'] as List;
    for (var i = 0; i < b.size; i++) {
      final c = cells[i];
      if (c != null) b.cells[i] = Piece.fromJson(c as Map<String, dynamic>);
      final l = locks[i];
      if (l != null) b.locks[i] = CellLock.fromJson(l as Map<String, dynamic>);
    }
    return b;
  }

  final int cols;
  final int rows;
  final List<Piece?> cells;
  final List<CellLock?> locks;

  int get size => cols * rows;
  int index(int x, int y) => y * cols + x;
  int xOf(int i) => i % cols;
  int yOf(int i) => i ~/ cols;
  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;
  bool isLocked(int i) => locks[i] != null;
  bool isFree(int i) => cells[i] == null && locks[i] == null;

  /// Orthogonal neighbours.
  List<int> neighbors(int i) {
    final x = xOf(i), y = yOf(i);
    return [
      if (x > 0) i - 1,
      if (x < cols - 1) i + 1,
      if (y > 0) i - cols,
      if (y < rows - 1) i + cols,
    ];
  }

  /// The closest empty, unlocked cell to [from] (by distance), or null when
  /// the board is full.
  int? nearestFree(int from) {
    int? best;
    var bestD = 1 << 30;
    final fx = xOf(from), fy = yOf(from);
    for (var i = 0; i < size; i++) {
      if (!isFree(i)) continue;
      final dx = xOf(i) - fx, dy = yOf(i) - fy;
      // Slight preference for cells below/around rather than far above.
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  int get freeCount => [for (var i = 0; i < size; i++) i].where(isFree).length;

  Iterable<int> indicesWhere(bool Function(Piece p) test) sync* {
    for (var i = 0; i < size; i++) {
      final p = cells[i];
      if (p != null && test(p)) yield i;
    }
  }

  Map<String, dynamic> toJson() => {
    'cols': cols,
    'rows': rows,
    'cells': [for (final c in cells) c?.toJson()],
    'locks': [for (final l in locks) l?.toJson()],
  };
}

class OrderLine {
  OrderLine(this.item, this.count);

  factory OrderLine.fromJson(Map<String, dynamic> j) =>
      OrderLine(ItemRef.parse(j['i'] as String), j['n'] as int);

  final ItemRef item;
  final int count;

  Map<String, dynamic> toJson() => {'i': item.key, 'n': count};
}

class Order {
  Order({
    required this.id,
    required this.character,
    required this.lines,
    required this.coins,
    required this.xp,
    this.gems = 0,
    this.energy = 0,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as int,
    character: j['ch'] as String,
    lines: [for (final l in j['l'] as List) OrderLine.fromJson(l)],
    coins: j['c'] as int,
    xp: j['x'] as int,
    gems: j['g'] as int? ?? 0,
    energy: j['e'] as int? ?? 0,
    items: [for (final i in j['it'] as List? ?? const []) ItemRef.parse(i)],
  );

  final int id;
  final String character;
  final List<OrderLine> lines;
  final int coins;
  final int xp;
  final int gems;
  final int energy;

  /// Bonus items (e.g. a dragon egg) given on completion.
  final List<ItemRef> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ch': character,
    'l': [for (final l in lines) l.toJson()],
    'c': coins,
    'x': xp,
    'g': gems,
    'e': energy,
    'it': [for (final i in items) i.key],
  };
}

class Dragon {
  Dragon({required this.id, required this.type, required this.level});

  factory Dragon.fromJson(Map<String, dynamic> j) =>
      Dragon(id: j['id'] as int, type: j['t'] as String, level: j['l'] as int);

  final int id;
  final String type;
  final int level;

  String get key => 'dragon:$type:$level';

  Map<String, dynamic> toJson() => {'id': id, 't': type, 'l': level};
}

class Settings {
  Settings({
    this.musicVolume = 0.6,
    this.sfxVolume = 0.9,
    this.muted = false,
    this.haptics = true,
  });

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    musicVolume: (j['mv'] as num? ?? 0.6).toDouble(),
    sfxVolume: (j['sv'] as num? ?? 0.9).toDouble(),
    muted: j['m'] as bool? ?? false,
    haptics: j['h'] as bool? ?? true,
  );

  double musicVolume;
  double sfxVolume;
  bool muted;
  bool haptics;

  Map<String, dynamic> toJson() => {
    'mv': musicVolume,
    'sv': sfxVolume,
    'm': muted,
    'h': haptics,
  };
}

/// Everything that is saved. Plain mutable data; all rules live in
/// `GameController`.
class GameState {
  GameState({
    required this.board,
    required this.storage,
    this.version = currentVersion,
    this.nextId = 1,
    this.coins = 0,
    this.gems = 0,
    this.xp = 0,
    this.level = 1,
    this.energy = 0,
    this.energyUpdatedAt = 0,
    this.purchasedSlots = 0,
    List<String>? pending,
    List<Order>? orders,
    this.scriptedOrderIndex = 0,
    List<Dragon>? dragons,
    this.idleCoins = 0,
    this.idleGems = 0,
    this.idleUpdatedAt = 0,
    this.lastSeen = 0,
    Set<String>? completedTasks,
    this.tutorialStep = 0,
    this.tutorialProgress = 0,
    Settings? settings,
    Map<String, int>? stats,
    this.adDay = '',
    Map<String, int>? adCounts,
    Set<String>? discovered,
  }) : pending = pending ?? [],
       orders = orders ?? [],
       dragons = dragons ?? [],
       completedTasks = completedTasks ?? {},
       settings = settings ?? Settings(),
       stats = stats ?? {},
       adCounts = adCounts ?? {},
       discovered = discovered ?? {};

  static const currentVersion = 1;

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
    version: j['v'] as int? ?? 1,
    board: Board.fromJson(j['board'] as Map<String, dynamic>),
    storage: [
      for (final s in j['storage'] as List)
        s == null ? null : Piece.fromJson(s as Map<String, dynamic>),
    ],
    nextId: j['nextId'] as int,
    coins: j['coins'] as int,
    gems: j['gems'] as int,
    xp: j['xp'] as int,
    level: j['level'] as int,
    energy: j['energy'] as int,
    energyUpdatedAt: j['energyAt'] as int,
    purchasedSlots: j['slots'] as int? ?? 0,
    pending: (j['pending'] as List? ?? const []).cast<String>(),
    orders: [for (final o in j['orders'] as List) Order.fromJson(o)],
    scriptedOrderIndex: j['scripted'] as int? ?? 0,
    dragons: [for (final d in j['dragons'] as List) Dragon.fromJson(d)],
    idleCoins: (j['idleCoins'] as num? ?? 0).toDouble(),
    idleGems: (j['idleGems'] as num? ?? 0).toDouble(),
    idleUpdatedAt: j['idleAt'] as int? ?? 0,
    lastSeen: j['lastSeen'] as int? ?? 0,
    completedTasks: (j['tasks'] as List? ?? const []).cast<String>().toSet(),
    tutorialStep: j['tut'] as int? ?? 0,
    tutorialProgress: j['tutP'] as int? ?? 0,
    settings: Settings.fromJson(
      (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    stats: (j['stats'] as Map? ?? const {}).cast<String, int>(),
    adDay: j['adDay'] as String? ?? '',
    adCounts: (j['adCounts'] as Map? ?? const {}).cast<String, int>(),
    discovered: (j['disc'] as List? ?? const []).cast<String>().toSet(),
  );

  int version;
  Board board;
  List<Piece?> storage;
  int nextId;
  int coins;
  int gems;
  int xp;
  int level;

  /// Energy as of [energyUpdatedAt]; regeneration is computed lazily.
  int energy;
  int energyUpdatedAt;
  int purchasedSlots;

  /// Rewards waiting for a free board cell: item keys or `gen:<id>`.
  List<String> pending;
  List<Order> orders;
  int scriptedOrderIndex;
  List<Dragon> dragons;

  /// Idle production accumulated but not yet collected.
  double idleCoins;
  double idleGems;
  int idleUpdatedAt;
  int lastSeen;
  Set<String> completedTasks;
  int tutorialStep;
  int tutorialProgress;
  Settings settings;
  Map<String, int> stats;

  /// Rewarded-ad usage per day (limits reset daily).
  String adDay;
  Map<String, int> adCounts;

  /// Item keys and dragon keys the player has seen.
  Set<String> discovered;

  int newId() => nextId++;

  int stat(String key) => stats[key] ?? 0;
  void addStat(String key, [int n = 1]) => stats[key] = stat(key) + n;

  Map<String, dynamic> toJson() => {
    'v': version,
    'board': board.toJson(),
    'storage': [for (final s in storage) s?.toJson()],
    'nextId': nextId,
    'coins': coins,
    'gems': gems,
    'xp': xp,
    'level': level,
    'energy': energy,
    'energyAt': energyUpdatedAt,
    'slots': purchasedSlots,
    'pending': pending,
    'orders': [for (final o in orders) o.toJson()],
    'scripted': scriptedOrderIndex,
    'dragons': [for (final d in dragons) d.toJson()],
    'idleCoins': idleCoins,
    'idleGems': idleGems,
    'idleAt': idleUpdatedAt,
    'lastSeen': lastSeen,
    'tasks': completedTasks.toList(),
    'tut': tutorialStep,
    'tutP': tutorialProgress,
    'settings': settings.toJson(),
    'stats': stats,
    'adDay': adDay,
    'adCounts': adCounts,
    'disc': discovered.toList(),
  };
}

/// A location a piece can be dragged from/to.
class Slot {
  const Slot.board(this.index) : storage = false;
  const Slot.storage(this.index) : storage = true;

  final int index;
  final bool storage;

  @override
  bool operator ==(Object other) =>
      other is Slot && other.index == index && other.storage == storage;

  @override
  int get hashCode => Object.hash(index, storage);

  @override
  String toString() => storage ? 'storage[$index]' : 'board[$index]';
}

extension PointIndex on Point<int> {
  int toIndex(int cols) => y * cols + x;
}

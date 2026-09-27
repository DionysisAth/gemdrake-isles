import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../model/game_state.dart';
import '../model/item_ref.dart';
import '../services/analytics.dart';
import '../services/feedback.dart';
import '../services/save_store.dart';
import 'game_events.dart';
import 'merge_logic.dart';
import 'new_game.dart';
import 'order_generator.dart';

part 'controller_islands.dart';
part 'controller_meta.dart';
part 'controller_events.dart';

typedef Clock = DateTime Function();

enum ProduceResult { ok, noEnergy, boardFull, recharging }

enum AdReward { freeEnergy, doubleIdle, generatorSkip }

class WelcomeBack {
  WelcomeBack(this.away, this.coins, this.gems);
  final Duration away;
  final int coins;
  final int gems;
}

/// Owns the [GameState] and implements every game rule. The UI calls
/// methods here and listens for changes ([ChangeNotifier]) and one-shot
/// [events] for effects.
///
/// Time: all timers (energy, generator cooldowns, idle production) are
/// computed from timestamps via [clock]. For release, [clock] should be
/// backed by server/verified time to stop clock-change cheating; going
/// backwards in time is already ignored here.
class GameController extends ChangeNotifier {
  GameController({
    required this.config,
    required this.state,
    this.saveStore,
    GameFeedback? feedback,
    Analytics? analytics,
    Clock? clock,
    Random? random,
  }) : feedback = feedback ?? SilentFeedback(),
       analytics = analytics ?? LocalAnalytics(),
       clock = clock ?? DateTime.now,
       random = random ?? Random() {
    orderGen = OrderGenerator(config, this.random);
    _repair();
    _refillOrders();
    refreshDay();
    applyFeedbackSettings();
  }

  /// Loads the saved game or starts a new one.
  static Future<GameController> load({
    required GameConfig config,
    required SaveStore saveStore,
    GameFeedback? feedback,
    Analytics? analytics,
    Clock? clock,
    Random? random,
  }) async {
    final now = (clock ?? DateTime.now)().millisecondsSinceEpoch;
    GameState? state;
    try {
      final data = await saveStore.load();
      if (data != null) state = GameState.fromJson(data);
    } catch (e) {
      debugPrint('Save could not be read, starting fresh: $e');
    }
    final isNew = state == null;
    state ??= createNewGame(config, now);
    final c = GameController(
      config: config,
      state: state,
      saveStore: saveStore,
      feedback: feedback,
      analytics: analytics,
      clock: clock,
      random: random,
    );
    c.state.addStat('sessions');
    c.analytics.log(isNew ? 'first_open' : 'session_start', {
      'level': c.state.level,
      'sessions': c.state.stat('sessions'),
    });
    c.save();
    return c;
  }

  final GameConfig config;
  GameState state;
  final SaveStore? saveStore;
  final GameFeedback feedback;
  final Analytics analytics;
  final Clock clock;
  final Random random;
  late final OrderGenerator orderGen;

  final _events = StreamController<GameEvent>.broadcast(sync: true);
  Stream<GameEvent> get events => _events.stream;

  /// Ticks once per second for countdown displays.
  final ValueNotifier<int> clockTick = ValueNotifier(0);

  Slot? _selected;
  Slot? get selected => _selected;

  Timer? _saveTimer;
  int _lastTickSave = 0;

  EconomyConfig get eco => config.economy;
  int get nowMs => clock().millisecondsSinceEpoch;
  bool _eventMode = false;

  /// The board being played: the island board, or the event board while
  /// [FestivalEvents.eventMode] is on.
  Board get board =>
      _eventMode && state.event != null ? state.event!.board : state.board;

  // ---------------------------------------------------------------------
  // Derived values
  // ---------------------------------------------------------------------

  /// Sum of a perk from restoration tasks completed on every island.
  double perk(String type) {
    var total = 0.0;
    for (final island in config.islands) {
      for (final t in island.tasks) {
        if (t.perk?.type == type && state.completedTasks.contains(t.id)) {
          total += t.perk!.value;
        }
      }
    }
    return total;
  }

  IslandDef get currentIsland => config.island(state.island);
  bool get hasNextIsland => state.island < config.islands.length - 1;

  int get energyMax => eco.energyMax + perk('energyMax').round();
  int get storageSlotCount =>
      eco.freeStorageSlots +
      state.purchasedSlots +
      perk('storageSlots').round();
  int? get nextStorageSlotCost =>
      state.purchasedSlots < eco.storageSlotCostsGems.length
      ? eco.storageSlotCostsGems[state.purchasedSlots]
      : null;
  double get offlineCapHours =>
      (state.hoardLevel > 0
          ? config
                .meta
                .hoardUpgrades[min(
                      state.hoardLevel,
                      config.meta.hoardUpgrades.length,
                    ) -
                    1]
                .hours
          : eco.offlineCapHours) +
      perk('offlineHours');
  double get dragonBoost => 1 + perk('dragonBoost');

  double dragonCoinsPerMinute(Dragon d) {
    final type = config.dragonType(d.type);
    return config.rarity(type.rarity).coinsPerMinute *
        config.dragons.level(d.level).multiplier *
        dragonBoost;
  }

  double get coinsPerMinute =>
      state.dragons.fold(0.0, (s, d) => s + dragonCoinsPerMinute(d));
  double get gemsPerHour => state.dragons.fold(
    0.0,
    (s, d) => s + config.dragons.level(d.level).gemsPerHour,
  );
  double get idleCoinCap => coinsPerMinute * 60 * offlineCapHours;
  double get idleGemCap => gemsPerHour * offlineCapHours;
  bool get idleFull => idleCoinCap > 0 && state.idleCoins >= idleCoinCap - 0.01;

  int get xpToNext => config.xpToNext(state.level);

  bool chainUnlocked(String chainId) =>
      config.chainAvailable(config.chain(chainId), state.level, state.island);

  bool generatorUnlocked(GeneratorDef g) =>
      config.generatorAvailable(g, state.level, state.island);

  // ---------------------------------------------------------------------
  // Energy
  // ---------------------------------------------------------------------

  int get energy {
    _settleEnergy(nowMs);
    return state.energy;
  }

  /// Time until the next energy point, or null when full.
  Duration? get nextEnergyIn {
    final now = nowMs;
    _settleEnergy(now);
    if (state.energy >= energyMax) return null;
    final ms = eco.energyRefillSeconds * 1000 - (now - state.energyUpdatedAt);
    return Duration(milliseconds: max(0, ms));
  }

  /// Time until energy is completely refilled.
  Duration? get fullEnergyIn {
    final next = nextEnergyIn;
    if (next == null) return null;
    final missing = energyMax - state.energy - 1;
    return next + Duration(seconds: missing * eco.energyRefillSeconds);
  }

  // Timestamps never move backwards: turning the device clock back and
  // then forward again must not grant extra energy or coins.
  void _settleEnergy(int now) {
    final cap = energyMax;
    if (now < state.energyUpdatedAt) return;
    if (state.energy >= cap) {
      state.energyUpdatedAt = now;
      return;
    }
    final refillMs = eco.energyRefillSeconds * 1000;
    final gained = (now - state.energyUpdatedAt) ~/ refillMs;
    if (gained <= 0) return;
    state.energy = min(cap, state.energy + gained);
    state.energyUpdatedAt = state.energy >= cap
        ? now
        : state.energyUpdatedAt + gained * refillMs;
  }

  void _addEnergy(int amount) {
    final now = nowMs;
    _settleEnergy(now);
    state.energy = min(eco.energyOverflowCap, state.energy + amount);
    if (state.energy >= energyMax) {
      state.energyUpdatedAt = max(now, state.energyUpdatedAt);
    }
  }

  bool _spendEnergy(int amount) {
    _settleEnergy(nowMs);
    if (state.energy < amount) return false;
    state.energy -= amount;
    return true;
  }

  // ---------------------------------------------------------------------
  // Clock / idle
  // ---------------------------------------------------------------------

  /// Called once per second while the app is in the foreground.
  void tick() {
    final now = nowMs;
    _accrueIdle(now);
    _settleEnergy(now);
    var changed = refreshDay();
    for (final p in [
      ...state.board.cells,
      ...?state.event?.board.cells,
      ...state.storage,
    ]) {
      if (p != null && p.isGenerator && _refreshGenerator(p, now)) {
        changed = true;
      }
    }
    state.lastSeen = now;
    clockTick.value = now;
    if (changed) notifyListeners();
    if (now - _lastTickSave > 30000) {
      _lastTickSave = now;
      save();
    }
  }

  void _accrueIdle(int now) {
    final last = state.idleUpdatedAt;
    if (now <= last) return;
    state.idleUpdatedAt = now;
    if (last == 0) return;
    final minutes = (now - last) / 60000.0;
    final cap = idleCoinCap;
    if (state.idleCoins < cap) {
      state.idleCoins = min(cap, state.idleCoins + coinsPerMinute * minutes);
    }
    final gemCap = idleGemCap;
    if (state.idleGems < gemCap) {
      state.idleGems = min(gemCap, state.idleGems + gemsPerHour * minutes / 60);
    }
  }

  /// Call when the app goes to the background.
  void onPause() {
    // Silence first, so nothing can keep playing in the background.
    feedback.pauseMusic();
    final now = nowMs;
    _accrueIdle(now);
    state.lastSeen = now;
    save(immediate: true);
  }

  /// Call on launch and when returning to the app. Returns what was earned
  /// while away, if it's worth a "Welcome back" popup.
  WelcomeBack? checkWelcomeBack() {
    final now = nowMs;
    final away = now - state.lastSeen;
    _accrueIdle(now);
    state.lastSeen = now;
    if (away < eco.welcomeBackMinSeconds * 1000) return null;
    final coins = state.idleCoins.floor();
    if (coins < 1) return null;
    analytics.log('welcome_back', {'away_min': away ~/ 60000, 'coins': coins});
    return WelcomeBack(
      Duration(milliseconds: away),
      coins,
      state.idleGems.floor(),
    );
  }

  /// Moves banked idle production into the wallet.
  void collectIdle({int multiplier = 1}) {
    _accrueIdle(nowMs);
    final coins = state.idleCoins.floor();
    final gems = state.idleGems.floor();
    if (coins <= 0 && gems <= 0) return;
    state.idleCoins -= coins;
    state.idleGems -= gems;
    state.coins += coins * multiplier;
    state.gems += gems * multiplier;
    state.addStat('idleCollected', coins * multiplier);
    state.addStat('idleCollects');
    feedback.play(Sfx.collect);
    _emit(IdleCollectedEvent(coins * multiplier, gems * multiplier));
    analytics.log('idle_collect', {'coins': coins, 'x': multiplier});
    _commit();
  }

  // ---------------------------------------------------------------------
  // Board interaction
  // ---------------------------------------------------------------------

  Piece? pieceAt(Slot s) {
    if (s.storage) {
      return s.index < state.storage.length ? state.storage[s.index] : null;
    }
    return board.cells[s.index];
  }

  void _setPiece(Slot s, Piece? p) {
    if (s.storage) {
      state.storage[s.index] = p;
    } else {
      board.cells[s.index] = p;
    }
  }

  /// Whether a locked cell hides its content (fog, rubble).
  bool hidesContent(int i) {
    final l = board.locks[i];
    return l != null && config.board.lockType(l.type).hidesContent;
  }

  void select(Slot? s) {
    _selected = s;
    notifyListeners();
  }

  /// Tap on a board cell or storage slot: generators produce, anything else
  /// is selected so the info bar can describe it.
  void tap(Slot s) {
    final p = pieceAt(s);
    if (!s.storage && p != null && p.isGenerator && !board.isLocked(s.index)) {
      _selected = s;
      produce(s.index);
      return;
    }
    feedback.play(Sfx.tap);
    select(p == null && !(!s.storage && board.isLocked(s.index)) ? null : s);
  }

  int generatorSecondsLeft(Piece p) => p.cooldownUntil == 0
      ? 0
      : max(0, ((p.cooldownUntil - nowMs) / 1000).ceil());

  bool _refreshGenerator(Piece p, int now) {
    if (p.cooldownUntil != 0 && now >= p.cooldownUntil) {
      p.charges = config.generator(p.generatorId!).level(p.genLevel).charges;
      p.cooldownUntil = 0;
      return true;
    }
    return false;
  }

  ProduceResult produce(int cell) {
    final gen = board.cells[cell];
    if (gen == null || !gen.isGenerator) return ProduceResult.recharging;
    final now = nowMs;
    _refreshGenerator(gen, now);
    final def = config.generator(gen.generatorId!);
    if (gen.cooldownUntil != 0) {
      feedback.play(Sfx.error);
      _emit(ToastEvent('${def.name} is recharging', cell: cell));
      notifyListeners();
      return ProduceResult.recharging;
    }
    final target = board.nearestFree(cell);
    if (target == null) {
      feedback.play(Sfx.error);
      _emit(
        ToastEvent('Board is full! Merge, sell or store items.', cell: cell),
      );
      notifyListeners();
      return ProduceResult.boardFull;
    }
    if (!_spendEnergy(config.energyPerTap)) {
      feedback.play(Sfx.error);
      state.addStat('outOfEnergy');
      analytics.log('out_of_energy', {'level': state.level});
      _emit(OutOfEnergyEvent());
      notifyListeners();
      return ProduceResult.noEnergy;
    }

    final lvl = def.level(gen.genLevel);
    final all = lvl.dropsFor(state.level);
    final allowed = all.where((d) {
      final c = config.chain(d.item.chain);
      return c.event || chainUnlocked(c.id);
    }).toList();
    final drops = allowed.isEmpty ? all : allowed;
    // The tutorial needs predictable drops.
    final ref = tutorialActive ? drops.first.item : _weighted(drops).item;
    final piece = Piece.item(state.newId(), ref);
    board.cells[target] = piece;
    state.discovered.add(ref.key);

    gen.charges -= 1;
    if (gen.charges <= 0) {
      gen.charges = 0;
      gen.cooldownUntil = now + lvl.cooldownSeconds * 1000;
    }
    state.addStat('generated');
    feedback.play(Sfx.pop);
    feedback.haptic();
    _emit(SpawnEvent(piece.id, cell, target));
    tutorialEvent('generate');
    _commit();
    return ProduceResult.ok;
  }

  DropDef _weighted(List<DropDef> drops) {
    final total = drops.fold(0, (s, d) => s + d.weight);
    var r = random.nextInt(total);
    for (final d in drops) {
      r -= d.weight;
      if (r < 0) return d;
    }
    return drops.last;
  }

  /// Whether dropping the piece at [from] onto [to] would merge.
  bool wouldMerge(Slot from, Slot to) {
    if (to.storage || from == to) return false;
    final src = pieceAt(from);
    final dst = board.cells[to.index];
    if (src?.item == null || dst?.item != src!.item) return false;
    return _plan(from, to.index) != null;
  }

  MergePlan? _plan(Slot from, int to) => planMerge(
    board: board,
    dragged: pieceAt(from)!.item!,
    to: to,
    fromBoardIndex: from.storage ? null : from.index,
    chain: config.chain(pieceAt(from)!.item!.chain),
    economy: eco,
    lockType: config.board.lockType,
  );

  /// Drag-and-drop. Returns true if anything changed.
  bool drop(Slot from, Slot to) {
    if (from == to) return false;
    final src = pieceAt(from);
    if (src == null) return false;
    if (!from.storage && board.isLocked(from.index)) return false;

    if ((to.storage || from.storage) && eventMode) {
      _emit(ToastEvent('Storage is for the island board'));
      feedback.play(Sfx.error);
      return false;
    }
    if (to.storage) {
      if (to.index >= state.storage.length) return false;
      if (src.isGenerator) {
        _emit(ToastEvent("Generators can't go in storage"));
        feedback.play(Sfx.error);
        return false;
      }
      final dst = state.storage[to.index];
      _setPiece(to, src);
      _setPiece(from, dst);
      if (dst == null && !from.storage) state.addStat('stored');
      _selected = to;
      feedback.play(Sfx.tap);
      _commit();
      return true;
    }

    final lock = board.locks[to.index];
    final dst = board.cells[to.index];
    if (src.isItem && dst != null && dst.item == src.item) {
      final plan = _plan(from, to.index);
      if (plan != null) {
        _applyMerge(plan, from, to.index);
        return true;
      }
      if (!isMergeable(config.chain(src.item!.chain), src.item!)) {
        _emit(
          ToastEvent(
            '${config.item(src.item!).name} is max level!',
            cell: to.index,
          ),
        );
        feedback.play(Sfx.error);
      }
      return false;
    }
    if (lock != null) return false;

    if (dst == null) {
      _setPiece(to, src);
      _setPiece(from, null);
    } else {
      // Swap. Generators can't be swapped into storage.
      if (from.storage && dst.isGenerator) return false;
      _setPiece(to, src);
      _setPiece(from, dst);
    }
    _selected = to;
    feedback.play(Sfx.tap);
    _commit();
    return true;
  }

  void _applyMerge(MergePlan plan, Slot from, int to) {
    _setPiece(from, null);
    for (final c in plan.consumed) {
      board.cells[c] = null;
    }
    // Merging onto a cobwebbed item frees it.
    if (board.locks[to] != null) {
      board.locks[to] = null;
      _emit(LockHitEvent(to, cleared: true));
    }

    final affected = <int>[];
    if (plan.hatch) {
      _accrueIdle(nowMs);
      final chain = config.chain(plan.input.chain);
      final dragons = [
        for (var i = 0; i < plan.yieldCount; i++) _hatchDragon(chain),
      ];
      affected.add(to);
      _selected = null;
      feedback.play(Sfx.hatch);
      feedback.haptic(heavy: true);
      _emit(HatchEvent(dragons, to));
    } else {
      final out = plan.output;
      final cells = [...plan.outputCells];
      while (cells.length < plan.yieldCount) {
        final free = board.nearestFree(to);
        if (free == null) break;
        cells.add(free);
        board.cells[free] = Piece.item(-1, out); // reserve
      }
      for (final c in cells) {
        board.cells[c] = Piece.item(state.newId(), out);
      }
      for (var i = cells.length; i < plan.yieldCount; i++) {
        state.pending.add(out.key);
      }
      affected.addAll(cells);
      state.discovered.add(out.key);
      _eventMergePoints(out, plan.yieldCount, to);
      _selected = Slot.board(to);
      feedback.play(plan.bonus ? Sfx.bonus : Sfx.merge, level: out.level);
      feedback.haptic(heavy: plan.bonus);
      _emit(MergeEvent(cells, out, bonus: plan.bonus));
    }

    // Merging next to locked cells chips away at them.
    final hit = <int>{};
    for (final c in affected) {
      hit.addAll(board.neighbors(c).where(board.isLocked));
    }
    for (final n in hit) {
      _hitLock(n);
    }

    state.addStat('merges');
    if (plan.bonus) state.addStat('bonusMerges');
    analytics.log('merge', {
      'item': plan.input.key,
      'bonus': plan.bonus,
      'hatch': plan.hatch,
    });
    tutorialEvent('merge');
    _commit();
  }

  void _hitLock(int cell) {
    final lock = board.locks[cell];
    if (lock == null) return;
    lock.hits -= 1;
    if (lock.hits <= 0) {
      board.locks[cell] = null;
      final p = board.cells[cell];
      if (p?.item != null) state.discovered.add(p!.item!.key);
      state.addStat('unlocked');
      feedback.play(Sfx.unlock);
      _emit(LockHitEvent(cell, cleared: true));
    } else {
      _emit(LockHitEvent(cell, cleared: false));
    }
  }

  /// Hatch odds for eggs of [chain] right now (shown to the player).
  List<WeightedType> hatchTableFor(ChainDef chain) =>
      config.hatchTableFor(chain, state.island);

  Dragon _hatchDragon(ChainDef chain) {
    final table = hatchTableFor(chain);
    final total = table.fold(0, (s, e) => s + e.weight);
    var r = random.nextInt(total);
    var type = table.last.type;
    for (final e in table) {
      r -= e.weight;
      if (r < 0) {
        type = e.type;
        break;
      }
    }
    final d = Dragon(id: state.newId(), type: type, level: 1);
    state.dragons.add(d);
    state.discovered.add(d.key);
    state.addStat('hatches');
    analytics.log('hatch', {'type': type});
    tutorialEvent('hatch');
    return d;
  }

  /// Sells the item in [s] for coins.
  void sell(Slot s) {
    final p = pieceAt(s);
    if (p == null || !p.isItem) return;
    if (!s.storage && board.isLocked(s.index)) return;
    final coins = config.item(p.item!).sell;
    _setPiece(s, null);
    state.coins += coins;
    state.addStat('sold');
    if (_selected == s) _selected = null;
    feedback.play(Sfx.coin);
    _emit(SoldEvent(coins, s));
    analytics.log('sell', {'item': p.item!.key});
    _commit();
  }

  // ---------------------------------------------------------------------
  // Rewards waiting for space
  // ---------------------------------------------------------------------

  /// Puts a reward on the island board (or in the waiting list when full).
  void _giveReward(String key, {int? near}) {
    final b = state.board;
    final onScreen = identical(b, board);
    final origin = near != null && onScreen
        ? near
        : b.index(b.cols ~/ 2, b.rows ~/ 2);
    final cell = b.nearestFree(origin);
    if (cell == null) {
      state.pending.add(key);
      return;
    }
    final piece = _pieceForKey(key);
    b.cells[cell] = piece;
    if (onScreen) _emit(SpawnEvent(piece.id, null, cell));
  }

  Piece _pieceForKey(String key) {
    if (key.startsWith('gen:')) {
      final def = config.generator(key.substring(4));
      return Piece.generator(
        state.newId(),
        def.id,
        charges: def.level(1).charges,
      );
    }
    final ref = ItemRef.parse(key);
    state.discovered.add(ref.key);
    return Piece.item(state.newId(), ref);
  }

  /// Places the next waiting reward on the board, if there's room.
  bool placePending() {
    if (state.pending.isEmpty || eventMode) return false;
    final board = state.board;
    final cell = board.nearestFree(
      board.index(board.cols ~/ 2, board.rows - 1),
    );
    if (cell == null) {
      feedback.play(Sfx.error);
      _emit(ToastEvent('No free space on the board'));
      return false;
    }
    final piece = _pieceForKey(state.pending.removeAt(0));
    board.cells[cell] = piece;
    feedback.play(Sfx.pop);
    _emit(SpawnEvent(piece.id, null, cell));
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------

  void _refillOrders() {
    final target = config.orders.maxActive(state.level);
    while (state.orders.length < target) {
      state.orders.add(orderGen.next(state));
    }
  }

  /// Cells/slots that would be used to fulfil [order], or null if the
  /// player doesn't have everything yet. Board items are used before
  /// stored ones.
  List<Slot>? findOrderItems(Order order) {
    if (eventMode) return null;
    final used = <Slot>{};
    for (final line in order.lines) {
      var need = line.count;
      for (var i = 0; i < board.size && need > 0; i++) {
        final s = Slot.board(i);
        if (!used.contains(s) &&
            !board.isLocked(i) &&
            board.cells[i]?.item == line.item) {
          used.add(s);
          need--;
        }
      }
      for (var i = 0; i < state.storage.length && need > 0; i++) {
        final s = Slot.storage(i);
        if (!used.contains(s) && state.storage[i]?.item == line.item) {
          used.add(s);
          need--;
        }
      }
      if (need > 0) return null;
    }
    return used.toList();
  }

  /// How many of [ref] the player has available (board + storage).
  int countAvailable(ItemRef ref) {
    final board = state.board;
    var n = 0;
    for (var i = 0; i < board.size; i++) {
      if (!board.isLocked(i) && board.cells[i]?.item == ref) n++;
    }
    for (final p in state.storage) {
      if (p?.item == ref) n++;
    }
    return n;
  }

  /// Item types currently requested by any order (for board badges).
  Set<ItemRef> get requestedItems => {
    for (final o in state.orders)
      for (final l in o.lines) l.item,
  };

  bool deliverOrder(int orderId) {
    final idx = state.orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return false;
    final order = state.orders[idx];
    final slots = findOrderItems(order);
    if (slots == null) {
      feedback.play(Sfx.error);
      return false;
    }
    for (final s in slots) {
      _setPiece(s, null);
      if (_selected == s) _selected = null;
    }
    state.coins += order.coins;
    state.gems += order.gems;
    if (order.energy > 0) _addEnergy(order.energy);
    for (final item in order.items) {
      _giveReward(item.key);
    }
    state.orders.removeAt(idx);
    state.orders.insert(idx, orderGen.next(state));
    state.addStat('orders');

    final ch = config.orders.character(order.character);
    final line = ch.lines[random.nextInt(ch.lines.length)];
    feedback.play(Sfx.order);
    feedback.haptic();
    _emit(OrderCompletedEvent(order, idx, line));
    analytics.log('order_complete', {
      'coins': order.coins,
      'level': state.level,
    });
    _addXp(order.xp);
    _refillOrders();
    tutorialEvent('order_complete');
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // XP & levels
  // ---------------------------------------------------------------------

  void _addXp(int amount) {
    state.xp += amount;
    while (state.xp >= config.xpToNext(state.level)) {
      state.xp -= config.xpToNext(state.level);
      state.level += 1;
      state.gems += eco.levelUpGems;
      if (eco.levelUpRefillsEnergy) {
        _settleEnergy(nowMs);
        state.energy = max(state.energy, energyMax);
        state.energyUpdatedAt = max(nowMs, state.energyUpdatedAt);
      }
      final unlocks = _giveMissingGenerators();
      for (final c in config.chains) {
        if (c.unlockLevel == state.level &&
            c.unlockLevel > 1 &&
            chainUnlocked(c.id)) {
          unlocks.add('${c.name} in orders');
        }
      }
      for (final c in config.orders.characters) {
        if (c.unlockLevel == state.level &&
            c.unlockLevel > 1 &&
            c.unlockIsland <= state.island + 1) {
          unlocks.add('${c.name}, ${c.title}');
        }
      }
      feedback.play(Sfx.levelUp);
      analytics.log('level_up', {'level': state.level});
      _emit(LevelUpEvent(state.level, eco.levelUpGems, unlocks));
    }
    _refillOrders();
  }

  /// Generator ids the player owns (main board, storage, pending).
  Set<String> get _ownedGenerators => {
    for (final p in [...state.board.cells, ...state.storage])
      if (p?.generatorId != null) p!.generatorId!,
    for (final k in state.pending)
      if (k.startsWith('gen:')) k.substring(4),
  };

  /// Hands out every generator that is unlocked but not owned yet.
  /// Returns their names.
  List<String> _giveMissingGenerators() {
    final owned = _ownedGenerators;
    final given = <String>[];
    for (final g in config.generators) {
      if (generatorUnlocked(g) && !owned.contains(g.id)) {
        _giveGenerator(g);
        given.add(g.name);
      }
    }
    return given;
  }

  void _giveGenerator(GeneratorDef g) {
    final b = state.board;
    final spawn = b.index(g.spawnCell.x, g.spawnCell.y);
    final cell = b.isFree(spawn) ? spawn : b.nearestFree(spawn);
    if (cell == null) {
      state.pending.add('gen:${g.id}');
      return;
    }
    final piece = _pieceForKey('gen:${g.id}');
    b.cells[cell] = piece;
    if (identical(b, board)) _emit(SpawnEvent(piece.id, null, cell));
  }

  // ---------------------------------------------------------------------
  // Generators: upgrades and speed-ups
  // ---------------------------------------------------------------------

  int? upgradeCost(Piece gen) {
    final def = config.generator(gen.generatorId!);
    if (gen.genLevel >= def.maxLevel) return null;
    return def.level(gen.genLevel + 1).upgradeCost;
  }

  bool upgradeGenerator(Slot s) {
    final gen = pieceAt(s);
    if (gen == null || !gen.isGenerator) return false;
    final cost = upgradeCost(gen);
    if (cost == null || state.coins < cost) return false;
    state.coins -= cost;
    gen.genLevel += 1;
    gen.charges = config
        .generator(gen.generatorId!)
        .level(gen.genLevel)
        .charges;
    gen.cooldownUntil = 0;
    feedback.play(Sfx.restore);
    analytics.log('generator_upgrade', {
      'id': gen.generatorId,
      'level': gen.genLevel,
    });
    _commit();
    return true;
  }

  int skipCooldownGemCost(Piece gen) {
    final minutes = generatorSecondsLeft(gen) / 60.0;
    return max(1, (minutes / eco.cooldownSkipMinutesPerGem).ceil());
  }

  bool skipCooldownWithGems(Slot s) {
    final gen = pieceAt(s);
    if (gen == null || !gen.isGenerator || gen.cooldownUntil == 0) return false;
    final cost = skipCooldownGemCost(gen);
    if (state.gems < cost) return false;
    state.gems -= cost;
    _finishCooldown(gen);
    analytics.log('gem_spend', {'on': 'cooldown', 'gems': cost});
    _commit();
    return true;
  }

  void _finishCooldown(Piece gen) {
    gen.cooldownUntil = 1; // anything in the past
    _refreshGenerator(gen, nowMs);
    feedback.play(Sfx.restore);
  }

  bool buyEnergyRefill() {
    final cost = eco.energyRefillGemCost;
    if (state.gems < cost) return false;
    state.gems -= cost;
    _addEnergy(max(0, energyMax - energy));
    feedback.play(Sfx.restore);
    analytics.log('gem_spend', {'on': 'energy', 'gems': cost});
    _commit();
    return true;
  }

  bool buyStorageSlot() {
    final cost = nextStorageSlotCost;
    if (cost == null || state.gems < cost) return false;
    state.gems -= cost;
    state.purchasedSlots += 1;
    _ensureStorage();
    feedback.play(Sfx.restore);
    analytics.log('gem_spend', {'on': 'storage', 'gems': cost});
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Rewarded ads
  // ---------------------------------------------------------------------

  String _today() {
    final d = clock();
    return '${d.year}-${d.month}-${d.day}';
  }

  int adsUsedToday(AdReward r) {
    if (state.adDay != _today()) return 0;
    return state.adCounts[r.name] ?? 0;
  }

  int adsLeftToday(AdReward r) => switch (r) {
    AdReward.freeEnergy => eco.adFreeEnergyPerDay - adsUsedToday(r),
    AdReward.generatorSkip => eco.adGeneratorSkipPerDay - adsUsedToday(r),
    AdReward.doubleIdle => 1 << 20,
  };

  /// Grants the reward for a rewarded ad the player finished watching.
  void grantAdReward(AdReward r, {Slot? generator}) {
    if (state.adDay != _today()) {
      state.adDay = _today();
      state.adCounts.clear();
    }
    state.adCounts[r.name] = (state.adCounts[r.name] ?? 0) + 1;
    state.addStat('adsWatched');
    analytics.log('ad_reward', {'placement': r.name});
    switch (r) {
      case AdReward.freeEnergy:
        _addEnergy(eco.adFreeEnergyAmount);
        feedback.play(Sfx.restore);
      case AdReward.doubleIdle:
        collectIdle(multiplier: 2);
      case AdReward.generatorSkip:
        final gen = generator == null ? null : pieceAt(generator);
        if (gen != null && gen.isGenerator) _finishCooldown(gen);
    }
    _commit();
  }

  // ---------------------------------------------------------------------
  // Island restoration
  // ---------------------------------------------------------------------

  bool taskDone(String id) => state.completedTasks.contains(id);

  bool taskAvailable(IslandTaskDef t) =>
      !taskDone(t.id) &&
      state.level >= t.requiresLevel &&
      t.requires.every(taskDone);

  bool get islandComplete => currentIsland.tasks.every((t) => taskDone(t.id));

  bool completeTask(String id) {
    final t = currentIsland.tasks.where((t) => t.id == id).firstOrNull;
    if (t == null) return false;
    if (!taskAvailable(t) || state.coins < t.cost) return false;
    _accrueIdle(nowMs); // bank production before a boost changes rates
    state.coins -= t.cost;
    state.completedTasks.add(t.id);
    _ensureStorage();
    feedback.play(Sfx.restore);
    feedback.haptic(heavy: true);
    analytics.log('island_task', {'id': t.id});
    _emit(TaskCompletedEvent(t, islandComplete: islandComplete));
    _addXp(t.xp);
    tutorialEvent('task_complete');
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Dragons
  // ---------------------------------------------------------------------

  bool canMergeDragons(Dragon a, Dragon b) =>
      a.id != b.id &&
      a.type == b.type &&
      a.level == b.level &&
      a.level < config.dragons.maxLevel;

  bool mergeDragons(int aId, int bId) {
    final a = state.dragons.where((d) => d.id == aId).firstOrNull;
    final b = state.dragons.where((d) => d.id == bId).firstOrNull;
    if (a == null || b == null || !canMergeDragons(a, b)) return false;
    _accrueIdle(nowMs);
    final idx = state.dragons.indexOf(b);
    state.dragons.remove(a);
    state.dragons.remove(b);
    final grown = Dragon(id: state.newId(), type: a.type, level: a.level + 1);
    state.dragons.insert(min(idx, state.dragons.length), grown);
    state.discovered.add(grown.key);
    state.addStat('dragonMerges');
    feedback.play(Sfx.hatch);
    feedback.haptic(heavy: true);
    analytics.log('dragon_merge', {'type': a.type, 'level': grown.level});
    _emit(DragonMergedEvent(grown));
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Tutorial
  // ---------------------------------------------------------------------

  TutorialStepDef? get tutorialStep =>
      state.tutorialStep < config.tutorial.length
      ? config.tutorial[state.tutorialStep]
      : null;

  bool get tutorialActive => tutorialStep != null;

  void tutorialEvent(String name) {
    final step = tutorialStep;
    if (step == null || step.eventName != name) return;
    state.tutorialProgress += 1;
    if (state.tutorialProgress >= step.count) _advanceTutorial();
  }

  void tapTutorial() {
    if (tutorialStep?.advancesOnTap ?? false) _advanceTutorial();
  }

  void skipTutorial() {
    state.tutorialStep = config.tutorial.length;
    analytics.log('tutorial_skip');
    _commit();
  }

  void _advanceTutorial() {
    analytics.log('tutorial_step', {'step': tutorialStep?.id});
    state.tutorialStep += 1;
    state.tutorialProgress = 0;
    if (!tutorialActive) analytics.log('tutorial_complete');
    _commit();
  }

  // ---------------------------------------------------------------------
  // Settings & persistence
  // ---------------------------------------------------------------------

  void updateSettings(void Function(Settings s) change) {
    change(state.settings);
    applyFeedbackSettings();
    _commit();
  }

  void applyFeedbackSettings() {
    final s = state.settings;
    feedback.applySettings(
      musicVolume: s.musicVolume,
      sfxVolume: s.sfxVolume,
      muted: s.muted,
      haptics: s.haptics,
    );
  }

  Future<void> resetProgress() async {
    final settings = state.settings;
    _eventMode = false;
    state = createNewGame(config, nowMs)..settings = settings;
    _selected = null;
    _repair();
    _refillOrders();
    analytics.log('reset_progress');
    await save(immediate: true);
    notifyListeners();
  }

  void _ensureStorage() {
    while (state.storage.length < storageSlotCount) {
      state.storage.add(null);
    }
  }

  /// Makes a loaded save consistent with the current config (items that no
  /// longer exist are dropped, newly added generators are handed out).
  void _repair() {
    state.storage = [...state.storage];
    _ensureStorage();
    bool valid(Piece? p) {
      if (p == null) return true;
      if (p.isItem) return config.isValidItem(p.item!);
      return config.generators.any(
        (g) => g.id == p.generatorId && !g.eventOnly,
      );
    }

    final main = state.board;
    for (var i = 0; i < main.size; i++) {
      if (!valid(main.cells[i])) main.cells[i] = null;
    }
    final e = state.event;
    if (e != null) {
      final def = config.events.events.where((d) => d.id == e.id).firstOrNull;
      if (def == null || e.board.size != main.size) {
        state.event = null;
      } else {
        for (var i = 0; i < e.board.size; i++) {
          final p = e.board.cells[i];
          if (p == null) continue;
          final ok = p.isItem
              ? p.item!.chain == def.chain && config.isValidItem(p.item!)
              : p.generatorId == def.generator;
          if (!ok) e.board.cells[i] = null;
        }
      }
    }
    for (var i = 0; i < state.storage.length; i++) {
      if (!valid(state.storage[i])) state.storage[i] = null;
    }
    state.dragons.removeWhere(
      (d) =>
          !config.dragons.types.any((t) => t.id == d.type) ||
          d.level > config.dragons.maxLevel,
    );

    state.island = state.island.clamp(0, config.islands.length - 1);
    _giveMissingGenerators();
    for (var i = 0; i < board.size; i++) {
      final p = board.cells[i];
      if (p?.item != null && !hidesContent(i)) {
        state.discovered.add(p!.item!.key);
      }
    }
  }

  void _emit(GameEvent e) => _events.add(e);

  void _notify() => notifyListeners();

  void _commit() {
    notifyListeners();
    save();
  }

  /// Saves shortly after a change (coalescing bursts of taps).
  Future<void> save({bool immediate = false}) async {
    final store = saveStore;
    if (store == null) return;
    _saveTimer?.cancel();
    if (immediate) {
      await store.save(state.toJson());
      return;
    }
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      store.save(state.toJson());
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _events.close();
    clockTick.dispose();
    super.dispose();
  }
}

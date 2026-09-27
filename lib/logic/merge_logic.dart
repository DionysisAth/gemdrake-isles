import '../config/game_config.dart';
import '../model/game_state.dart';
import '../model/item_ref.dart';

/// The result of planning a merge: which cells are consumed and where the
/// resulting items go. Pure data so the rules can be unit-tested.
class MergePlan {
  MergePlan({
    required this.input,
    required this.consumed,
    required this.outputCells,
    required this.yieldCount,
    required this.hatch,
    required this.bonus,
  });

  final ItemRef input;

  /// Board cells whose pieces are consumed (not including the dragged piece).
  final List<int> consumed;

  /// Board cells that receive the merged items, target cell first. May be
  /// shorter than [yieldCount]; the controller places the rest nearby.
  final List<int> outputCells;
  final int yieldCount;

  /// Merging max-level eggs hatches dragons instead of producing an item.
  final bool hatch;

  /// True when the 5-item bonus rule applied.
  final bool bonus;

  ItemRef get output => input.next;
}

/// Whether an item of [ref] can be merged at all.
bool isMergeable(ChainDef chain, ItemRef ref) =>
    ref.level < chain.maxLevel ||
    (chain.hatchOnMaxMerge && ref.level == chain.maxLevel);

/// Plans dropping an item of type [dragged] onto board cell [to].
///
/// [fromBoardIndex] is the cell the dragged piece came from (null when it
/// was dragged out of storage) so it isn't counted twice.
///
/// Rules (all tunable in `economy.json`):
/// * standard: `standardConsume` identical items -> `standardYield` items
/// * bonus: when the target is part of a connected group so that
///   `bonusConsume` items (including the dragged one) are available, they
///   merge into `bonusYield` items instead.
MergePlan? planMerge({
  required Board board,
  required ItemRef dragged,
  required int to,
  required int? fromBoardIndex,
  required ChainDef chain,
  required EconomyConfig economy,
  required LockTypeDef Function(String id) lockType,
}) {
  final target = board.cells[to];
  if (target == null || target.item != dragged) return null;
  if (!isMergeable(chain, dragged)) return null;
  final targetLock = board.locks[to];
  if (targetLock != null && lockType(targetLock.type).hidesContent) {
    return null;
  }

  // Connected group of identical, unlocked items around the target (BFS so
  // the closest ones are consumed first).
  final cluster = <int>[to];
  final seen = <int>{to};
  if (fromBoardIndex != null) seen.add(fromBoardIndex);
  for (var qi = 0; qi < cluster.length; qi++) {
    // A locked (cobwebbed) target only merges on its own.
    if (targetLock != null) break;
    for (final n in board.neighbors(cluster[qi])) {
      if (seen.contains(n)) continue;
      seen.add(n);
      final p = board.cells[n];
      if (p != null && p.item == dragged && !board.isLocked(n)) {
        cluster.add(n);
      }
    }
  }

  final available = cluster.length + 1; // + the dragged piece
  int consume;
  int yieldCount;
  var bonus = false;
  if (economy.bonusEnabled && available >= economy.bonusConsume) {
    consume = economy.bonusConsume;
    yieldCount = economy.bonusYield;
    bonus = true;
  } else if (available >= economy.standardConsume) {
    consume = economy.standardConsume;
    yieldCount = economy.standardYield;
  } else {
    return null;
  }

  final consumed = cluster.take(consume - 1).toList();
  final hatch = chain.hatchOnMaxMerge && dragged.level == chain.maxLevel;
  final outputs = hatch ? <int>[] : consumed.take(yieldCount).toList();
  if (!hatch && outputs.length < yieldCount && fromBoardIndex != null) {
    outputs.add(fromBoardIndex);
  }
  return MergePlan(
    input: dragged,
    consumed: consumed,
    outputCells: outputs,
    yieldCount: yieldCount,
    hatch: hatch,
    bonus: bonus,
  );
}

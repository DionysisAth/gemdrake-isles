import '../config/game_config.dart';
import '../model/game_state.dart';
import '../model/item_ref.dart';

/// One-shot things that happened, for the UI to animate (particles,
/// popups, flying coins). Emitted synchronously before listeners rebuild.
sealed class GameEvent {}

class SpawnEvent extends GameEvent {
  SpawnEvent(this.pieceId, this.fromCell, this.toCell);
  final int pieceId;

  /// Board cell it came from (a generator), or null for rewards.
  final int? fromCell;
  final int toCell;
}

class MergeEvent extends GameEvent {
  MergeEvent(this.cells, this.result, {required this.bonus});
  final List<int> cells;
  final ItemRef result;
  final bool bonus;
}

class HatchEvent extends GameEvent {
  HatchEvent(this.dragons, this.cell);
  final List<Dragon> dragons;
  final int cell;
}

class LockHitEvent extends GameEvent {
  LockHitEvent(this.cell, {required this.cleared});
  final int cell;
  final bool cleared;
}

class OrderCompletedEvent extends GameEvent {
  OrderCompletedEvent(this.order, this.index, this.line);
  final Order order;
  final int index;
  final String line;
}

class LevelUpEvent extends GameEvent {
  LevelUpEvent(this.level, this.gems, this.unlocks);
  final int level;
  final int gems;
  final List<String> unlocks;
}

class ToastEvent extends GameEvent {
  ToastEvent(this.message, {this.cell});
  final String message;
  final int? cell;
}

class OutOfEnergyEvent extends GameEvent {}

class SoldEvent extends GameEvent {
  SoldEvent(this.coins, this.slot);
  final int coins;
  final Slot slot;
}

class TaskCompletedEvent extends GameEvent {
  TaskCompletedEvent(this.task, {required this.islandComplete});
  final IslandTaskDef task;
  final bool islandComplete;
}

class DragonMergedEvent extends GameEvent {
  DragonMergedEvent(this.dragon);
  final Dragon dragon;
}

class IdleCollectedEvent extends GameEvent {
  IdleCollectedEvent(this.coins, this.gems);
  final int coins;
  final int gems;
}

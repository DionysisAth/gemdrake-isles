import '../config/game_config.dart';
import '../model/game_state.dart';

/// Builds a fresh save from `board.json` and the starting economy.
GameState createNewGame(GameConfig config, int nowMs) {
  final bc = config.board;
  final board = Board(bc.cols, bc.rows);
  for (var y = 0; y < bc.rows && y < bc.locks.length; y++) {
    final row = bc.locks[y];
    for (var x = 0; x < bc.cols && x < row.length; x++) {
      final lt = bc.lockForSymbol(row[x]);
      if (lt != null) board.locks[board.index(x, y)] = CellLock(lt.id, lt.hits);
    }
  }

  final eco = config.economy;
  final state = GameState(
    board: board,
    storage: List<Piece?>.filled(eco.freeStorageSlots, null, growable: true),
    coins: eco.startCoins,
    gems: eco.startGems,
    energy: eco.startEnergy,
    energyUpdatedAt: nowMs,
    idleUpdatedAt: nowMs,
    lastSeen: nowMs,
  );

  for (final c in bc.contents) {
    final i = board.index(c.cell.x, c.cell.y);
    if (c.generator != null) {
      final def = config.generator(c.generator!);
      board.cells[i] = Piece.generator(
        state.newId(),
        def.id,
        charges: def.level(1).charges,
      );
    } else if (c.item != null) {
      board.cells[i] = Piece.item(state.newId(), c.item!);
    }
  }
  return state;
}

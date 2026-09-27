import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../logic/game_controller.dart';
import '../../logic/game_events.dart';
import '../../model/game_state.dart';
import '../../model/item_ref.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../painters/item_painter.dart';
import '../theme.dart';
import 'info_bar.dart';
import 'piece_view.dart';

/// The merge board, the info bar and the storage row. One gesture
/// detector covers all of it so pieces can be dragged between the board
/// and storage, and every piece is keyed by id so moves animate.
class BoardArea extends StatefulWidget {
  const BoardArea({super.key});

  @override
  State<BoardArea> createState() => _BoardAreaState();
}

class _Layout {
  _Layout(
    this.size,
    this.cell,
    this.boardRect,
    this.infoRect,
    this.storageRect,
    this.slotSize,
    this.slotCount,
  );

  final Size size;
  final double cell;
  final Rect boardRect;
  final Rect infoRect;
  final Rect storageRect;
  final double slotSize;
  final int slotCount;

  static const gap = 8.0;
  static const slotGap = 6.0;

  Rect cellRect(int cols, int i) => Rect.fromLTWH(
    boardRect.left + (i % cols) * cell,
    boardRect.top + (i ~/ cols) * cell,
    cell,
    cell,
  );

  /// Storage slots are centered, leaving room for the gift button on the left.
  Rect slotRect(int j) {
    final total = (slotCount + 2) * (slotSize + slotGap) - slotGap;
    final left = storageRect.center.dx - total / 2 + (slotSize + slotGap);
    return Rect.fromLTWH(
      left + j * (slotSize + slotGap),
      storageRect.center.dy - slotSize / 2,
      slotSize,
      slotSize,
    );
  }

  Rect get giftRect => slotRect(-1);
  Rect get buyRect => slotRect(slotCount);
}

class _BoardAreaState extends State<BoardArea> {
  _Layout? _layout;
  StreamSubscription<GameEvent>? _sub;
  final _spawnFrom = <int, Offset>{};

  Slot? _dragFrom;
  int? _dragPieceId;
  Offset _dragPos = Offset.zero;
  Slot? _hover;

  GameController get game => context.game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= game.events.listen(_onEvent);
    final targets = context.targets;
    targets.register('generator', (id) {
      final l = _layout;
      if (l == null) return const [];
      final i = game.board.indicesWhere((p) => p.generatorId == id).firstOrNull;
      return i == null ? const [] : [_global(l.cellRect(game.board.cols, i))];
    });
    targets.register('merge', (key) {
      final l = _layout;
      if (l == null) return const [];
      final ref = ItemRef.parse(key);
      return [
        for (final i
            in game.board
                .indicesWhere((p) => p.item == ref)
                .where((i) => !game.board.isLocked(i))
                .take(2))
          _global(l.cellRect(game.board.cols, i)),
      ];
    });
    targets.register('cell', (i) {
      final l = _layout;
      return l == null
          ? const []
          : [_global(l.cellRect(game.board.cols, int.parse(i)))];
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Rect _global(Rect local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return local;
    return local.shift(box.localToGlobal(Offset.zero));
  }

  Rect? _slotRect(Slot s) {
    final l = _layout;
    if (l == null) return null;
    return s.storage
        ? l.slotRect(s.index)
        : l.cellRect(game.board.cols, s.index);
  }

  void _onEvent(GameEvent e) {
    final l = _layout;
    if (l == null || !mounted) return;
    final fx = context.fx;
    final cols = game.board.cols;
    switch (e) {
      case SpawnEvent(:final pieceId, :final fromCell, :final toCell):
        final to = l.cellRect(cols, toCell).topLeft;
        final from = fromCell == null
            ? l.giftRect.topLeft
            : l.cellRect(cols, fromCell).topLeft;
        _spawnFrom[pieceId] = from - to;
      case MergeEvent(:final cells, :final result, :final bonus):
        for (final c in cells) {
          final center = _global(l.cellRect(cols, c)).center;
          fx.burst(
            center,
            color: _chainColor(result),
            count: bonus ? 22 : 12,
            spread: bonus ? 90 : 60,
          );
        }
        if (bonus) {
          fx.floatText(
            _global(l.cellRect(cols, cells.first)).center,
            'BONUS x${cells.length}!',
            color: Palette.gold,
          );
        }
      case LockHitEvent(:final cell, :final cleared):
        fx.burst(
          _global(l.cellRect(cols, cell)).center,
          color: Colors.white,
          count: cleared ? 16 : 6,
          spread: cleared ? 55 : 30,
        );
      case HatchEvent(:final cell?):
        fx.burst(
          _global(l.cellRect(cols, cell)).center,
          color: Palette.gold,
          count: 26,
          spread: 110,
        );
      case SoldEvent(:final coins, :final slot):
        final r = _slotRect(slot);
        if (r != null) {
          final g = _global(r).center;
          fx.floatText(g, '+$coins', color: Palette.gold);
          final hud = context.targets.rect('hud:coins');
          if (hud != null) {
            fx.fly(
              from: g,
              to: hud.center,
              icon: const CurrencyIcon(CurrencyKind.coin),
              count: min(5, coins + 1),
            );
          }
        }
      default:
        break;
    }
  }

  Color _chainColor(ItemRef ref) => switch (ref.chain) {
    'gem' => const Color(0xFF9FE6FF),
    'plant' => const Color(0xFFA6F07A),
    'egg' => const Color(0xFFFFD27A),
    _ => Colors.white,
  };

  // --------------------------------------------------------------------------
  // Hit testing & gestures
  // --------------------------------------------------------------------------

  Slot? _hit(Offset p) {
    final l = _layout;
    if (l == null) return null;
    if (l.boardRect.contains(p)) {
      final x = ((p.dx - l.boardRect.left) / l.cell).floor().clamp(
        0,
        game.board.cols - 1,
      );
      final y = ((p.dy - l.boardRect.top) / l.cell).floor().clamp(
        0,
        game.board.rows - 1,
      );
      return Slot.board(game.board.index(x, y));
    }
    for (var j = 0; j < l.slotCount; j++) {
      if (l.slotRect(j).inflate(_Layout.slotGap / 2).contains(p)) {
        return Slot.storage(j);
      }
    }
    return null;
  }

  void _onTapUp(TapUpDetails d) {
    final l = _layout;
    if (l == null) return;
    if (l.giftRect.contains(d.localPosition) && game.state.pending.isNotEmpty) {
      game.placePending();
      return;
    }
    if (l.buyRect.contains(d.localPosition) &&
        game.nextStorageSlotCost != null) {
      InfoBar.buyStorageSlot(context);
      return;
    }
    final s = _hit(d.localPosition);
    if (s == null) {
      game.select(null);
      return;
    }
    game.tap(s);
  }

  void _onPanStart(DragStartDetails d) {
    final s = _hit(d.localPosition);
    if (s == null) return;
    final p = game.pieceAt(s);
    if (p == null || (!s.storage && game.board.isLocked(s.index))) return;
    setState(() {
      _dragFrom = s;
      _dragPieceId = p.id;
      _dragPos = d.localPosition;
      _hover = null;
    });
    game.select(s);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragFrom == null) return;
    setState(() {
      _dragPos = d.localPosition;
      final h = _hit(_dragPos - Offset(0, (_layout?.cell ?? 40) * .25));
      _hover = h == _dragFrom ? null : h;
    });
  }

  void _onPanEnd([DragEndDetails? _]) {
    final from = _dragFrom;
    final to = _hover;
    setState(() {
      _dragFrom = null;
      _dragPieceId = null;
      _hover = null;
    });
    if (from != null && to != null) game.drop(from, to);
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  _Layout _computeLayout(Size size, int slotCount) {
    final board = game.board;
    const infoH = 70.0;
    const storageH = 60.0;
    const frame = 8.0;
    final availH = size.height - infoH - storageH - _Layout.gap * 2 - frame * 2;
    final cell = min(
      (size.width - 20 - frame * 2) / board.cols,
      availH / board.rows,
    ).floorToDouble();
    final boardW = cell * board.cols, boardH = cell * board.rows;
    final boardRect = Rect.fromLTWH(
      (size.width - boardW) / 2,
      frame,
      boardW,
      boardH,
    );
    final infoRect = Rect.fromLTWH(
      10,
      boardRect.bottom + frame + _Layout.gap,
      size.width - 20,
      infoH,
    );
    final storageRect = Rect.fromLTWH(
      10,
      infoRect.bottom + _Layout.gap,
      size.width - 20,
      storageH,
    );
    final maxSlot =
        (storageRect.width - _Layout.slotGap * (slotCount + 1)) /
        (slotCount + 2);
    final slotSize = min(52.0, min(maxSlot, storageH - 6));
    return _Layout(
      size,
      cell,
      boardRect,
      infoRect,
      storageRect,
      slotSize,
      slotCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            final l = _layout = _computeLayout(
              constraints.biggest,
              game.state.storage.length,
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: _onTapUp,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onPanCancel: _onPanEnd,
              child: SizedBox.fromSize(
                size: constraints.biggest,
                child: Stack(clipBehavior: Clip.none, children: _children(l)),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _children(_Layout l) {
    final board = game.board;
    final cols = board.cols;
    final requested = game.requestedItems;
    final selected = game.selected;
    final children = <Widget>[];

    // Frame + tiles
    children.add(
      Positioned.fromRect(
        rect: l.boardRect.inflate(10),
        child: const RepaintBoundary(
          child: CustomPaint(painter: BoardFramePainter()),
        ),
      ),
    );
    children.add(
      Positioned.fromRect(
        rect: l.boardRect,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: BoardBackgroundPainter(cols, board.rows, l.cell),
          ),
        ),
      ),
    );

    // Drop target highlight
    final hover = _hover;
    if (hover != null && _dragFrom != null) {
      final r = _slotRect(hover)!;
      final merge = game.wouldMerge(_dragFrom!, hover);
      children.add(
        Positioned.fromRect(
          rect: r.deflate(1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: merge ? const Color(0x66FFF176) : const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(l.cell * .2),
              border: Border.all(
                color: merge ? const Color(0xFFFFD54F) : Colors.white70,
                width: merge ? 3 : 2,
              ),
            ),
          ),
        ),
      );
    }

    // Selection
    if (selected != null && _dragFrom == null) {
      final r = _slotRect(selected);
      if (r != null) {
        children.add(
          Positioned.fromRect(
            rect: r.deflate(1),
            child: const _SelectionRing(),
          ),
        );
      }
    }

    // Info bar + storage frame
    children.add(Positioned.fromRect(rect: l.infoRect, child: const InfoBar()));
    children.add(
      Positioned.fromRect(
        rect: Rect.fromLTRB(
          l.giftRect.left - 6,
          l.storageRect.top + 2,
          l.buyRect.right + 6,
          l.storageRect.bottom - 2,
        ),
        child: DecoratedBox(
          decoration: panelDecoration(
            color: const Color(0xFFF3E6D3),
            radius: 16,
          ),
        ),
      ),
    );
    children.add(
      Positioned.fromRect(
        rect: l.giftRect,
        child: _GiftButton(count: game.state.pending.length),
      ),
    );
    for (var j = 0; j < l.slotCount; j++) {
      children.add(
        Positioned.fromRect(
          rect: l.slotRect(j),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE6D4BC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1BA9C), width: 2),
            ),
          ),
        ),
      );
    }
    children.add(
      Positioned.fromRect(
        rect: l.buyRect,
        child: _BuySlotButton(cost: game.nextStorageSlotCost),
      ),
    );

    // Pieces (board then storage); the dragged piece is drawn last.
    Widget? dragged;
    void addPiece(
      Piece p,
      Rect rect, {
      required bool hidden,
      bool locked = false,
    }) {
      final isDragged = p.id == _dragPieceId;
      final size = isDragged ? max(rect.width, l.cell) * 1.15 : rect.width;
      final pos = isDragged
          ? _dragPos - Offset(size / 2, size * .8)
          : rect.topLeft;
      Widget view = PieceView(
        piece: p,
        config: game.config,
        size: size,
        requested: !locked && p.isItem && requested.contains(p.item),
      );
      if (p.isGenerator) {
        view = ListenableBuilder(
          listenable: game.clockTick,
          builder: (context, _) {
            final left = game.generatorSecondsLeft(p);
            final total = game.config
                .generator(p.generatorId!)
                .level(p.genLevel)
                .cooldownSeconds;
            return PieceView(
              piece: p,
              config: game.config,
              size: size,
              cooldownFraction: left > 0 ? left / total : null,
            );
          },
        );
      }
      final w = AnimatedPositioned(
        key: ValueKey(p.id),
        duration: isDragged ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        left: pos.dx,
        top: pos.dy,
        width: size,
        height: size,
        child: PopIn(
          from: _spawnFrom.remove(p.id) ?? Offset.zero,
          child: Opacity(opacity: hidden ? 0 : 1, child: view),
        ),
      );
      if (isDragged) {
        dragged = w;
      } else {
        children.add(w);
      }
    }

    for (var i = 0; i < board.size; i++) {
      final p = board.cells[i];
      if (p != null) {
        addPiece(
          p,
          l.cellRect(cols, i),
          hidden: game.hidesContent(i),
          locked: board.isLocked(i),
        );
      }
    }
    for (var j = 0; j < game.state.storage.length; j++) {
      final p = game.state.storage[j];
      if (p != null) addPiece(p, l.slotRect(j), hidden: false);
    }

    // Locks
    for (var i = 0; i < board.size; i++) {
      final lock = board.locks[i];
      children.add(
        Positioned.fromRect(
          key: ValueKey('lock$i'),
          rect: l.cellRect(cols, i).deflate(1.5),
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 1.4, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: lock == null
                  ? const SizedBox.expand()
                  : CustomPaint(
                      key: ValueKey('${lock.type}${lock.hits}'),
                      painter: LockPainter(lock.type, lock.hits),
                      size: Size.infinite,
                    ),
            ),
          ),
        ),
      );
    }

    if (dragged != null) children.add(dragged!);
    return children;
  }
}

class _SelectionRing extends StatefulWidget {
  const _SelectionRing();

  @override
  State<_SelectionRing> createState() => _SelectionRingState();
}

class _SelectionRingState extends State<_SelectionRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color.lerp(Colors.white, Palette.gold, _c.value)!,
            width: 2.5,
          ),
        ),
      ),
    ),
  );
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFE08A) : const Color(0xFFE6D4BC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? Palette.gold : const Color(0xFFD1BA9C),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.card_giftcard,
              color: active ? const Color(0xFFD9534F) : const Color(0xFFBBA88E),
            ),
          ),
        ),
        if (active)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Palette.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BuySlotButton extends StatelessWidget {
  const _BuySlotButton({required this.cost});

  final int? cost;

  @override
  Widget build(BuildContext context) {
    if (cost == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFE3D2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1BA9C), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, size: 18, color: Palette.inkSoft),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CurrencyIcon(CurrencyKind.gem, size: 11),
              Text(
                '$cost',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small sparkle decoration used by other widgets.
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, this.size = 12, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SparklePainter(color));
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintSparkle(
    canvas,
    size.center(Offset.zero),
    size.shortestSide / 2,
    color,
  );

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

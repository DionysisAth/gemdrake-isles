import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../logic/game_controller.dart';
import '../../logic/game_events.dart';
import '../../model/game_state.dart';
import '../dialogs/dialogs.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../painters/dragon_painter.dart';
import '../theme.dart';
import 'piece_view.dart';

/// Orders from island characters, shown above the board.
class OrdersBar extends StatefulWidget {
  const OrdersBar({super.key});

  @override
  State<OrdersBar> createState() => _OrdersBarState();
}

class _OrdersBarState extends State<OrdersBar> {
  StreamSubscription<GameEvent>? _sub;
  String? _speech;
  int _speechIndex = 0;
  Timer? _speechTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.game.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _speechTimer?.cancel();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    if (e is! OrderCompletedEvent || !mounted) return;
    final targets = context.targets;
    final fx = context.fx;
    final card = targets.rect('order:${e.index}');
    if (card != null) {
      final coins = targets.rect('hud:coins');
      if (coins != null) {
        fx.fly(
          from: card.center,
          to: coins.center,
          icon: const CurrencyIcon(CurrencyKind.coin),
          count: min(8, 3 + e.order.coins ~/ 10),
        );
      }
      final xp = targets.rect('hud:xp');
      if (xp != null) {
        fx.fly(
          from: card.center,
          to: xp.center,
          icon: const CurrencyIcon(CurrencyKind.xp),
          count: 3,
        );
      }
      if (e.order.gems > 0) {
        final gems = targets.rect('hud:gems');
        if (gems != null) {
          fx.fly(
            from: card.center,
            to: gems.center,
            icon: const CurrencyIcon(CurrencyKind.gem),
            count: e.order.gems + 1,
          );
        }
      }
      fx.burst(card.center, color: Palette.gold, count: 16, spread: 60);
      fx.floatText(card.center, '+${e.order.coins}', color: Palette.gold);
    }
    _speechTimer?.cancel();
    setState(() {
      _speech = e.line;
      _speechIndex = e.index;
    });
    _speechTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _speech = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return SizedBox(
      height: 104,
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          final orders = game.state.orders;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  for (var i = 0; i < orders.length; i++)
                    Expanded(
                      child: Padding(
                        // The target key lives outside the switcher so old and
                        // new cards never share it mid-transition.
                        key: context.targets.keyFor('order:$i'),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutBack,
                            ),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: _OrderCard(
                            key: ValueKey(orders[i].id),
                            order: orders[i],
                            game: game,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_speech != null && _speechIndex < orders.length)
                Positioned(
                  top: 70,
                  left: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: panelDecoration(
                          color: Colors.white,
                          radius: 14,
                        ),
                        child: Text(
                          _speech!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({super.key, required this.order, required this.game});

  final Order order;
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final ready = game.findOrderItems(order) != null;
    final character = game.config.orders.character(order.character);
    return GestureDetector(
      onTap: () {
        if (!game.deliverOrder(order.id)) {
          final missing = order.lines
              .where((l) => game.countAvailable(l.item) < l.count)
              .map((l) => game.config.item(l.item).name)
              .join(', ');
          showToast(context, '${character.name} still needs: $missing');
        }
      },
      child: _Glow(
        active: ready,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          decoration:
              panelDecoration(
                color: ready ? const Color(0xFFEFFFF0) : Palette.panel,
                radius: 16,
              ).copyWith(
                border: Border.all(
                  color: ready ? Palette.green : Palette.panelEdge,
                  width: ready ? 3 : 2,
                ),
              ),
          child: Column(
            children: [
              Row(
                children: [
                  CustomPaint(
                    size: const Size.square(24),
                    painter: CharacterPainter(character),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      // First name only: cards are narrow with 4 orders.
                      character.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final line in order.lines)
                      Flexible(
                        child: _Requirement(
                          line: line,
                          have: game.countAvailable(line.item),
                        ),
                      ),
                  ],
                ),
              ),
              if (ready)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Deliver!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                FittedBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CurrencyIcon(CurrencyKind.coin, size: 13),
                      Text(
                        ' ${order.coins} ',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const CurrencyIcon(CurrencyKind.xp, size: 13),
                      Text(
                        ' ${order.xp}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (order.gems > 0) ...[
                        const Text(' '),
                        const CurrencyIcon(CurrencyKind.gem, size: 13),
                        Text(
                          '${order.gems}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (order.energy > 0) ...[
                        const Text(' '),
                        const CurrencyIcon(CurrencyKind.energy, size: 13),
                        Text(
                          '${order.energy}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      for (final item in order.items) ...[
                        const Text(' '),
                        ItemIcon(item, size: 16),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.line, required this.have});

  final OrderLine line;
  final int have;

  @override
  Widget build(BuildContext context) {
    final done = have >= line.count;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ItemIcon(line.item, size: 36),
        Positioned(
          right: -2,
          bottom: -2,
          child: done
              ? Container(
                  decoration: const BoxDecoration(
                    color: Palette.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                )
              : line.count > 1 || have > 0
              ? OutlinedText(
                  '${min(have, line.count)}/${line.count}',
                  size: 11,
                  strokeWidth: 2.5,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Gently pulsing glow around ready orders.
class _Glow extends StatefulWidget {
  const _Glow({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Glow old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.scale(scale: 1 + _c.value * .04, child: child),
      child: widget.child,
    );
  }
}

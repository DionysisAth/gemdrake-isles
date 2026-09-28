import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../../logic/game_events.dart';
import '../../model/game_state.dart';
import '../../services/feedback.dart';
import '../dialogs/dialogs.dart';
import '../dialogs/meta_dialogs.dart';
import '../game_scope.dart';
import '../targets.dart';
import '../painters/board_painters.dart';
import '../painters/dragon_painter.dart';
import '../painters/island_painter.dart';
import '../theme.dart';
import '../widgets/piece_view.dart';

/// The floating island: restoration tasks, the dragons living there and
/// their treasure hoard (idle earnings).
class IslandScreen extends StatefulWidget {
  const IslandScreen({super.key});

  @override
  State<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends State<IslandScreen> {
  int _tab = 0;

  /// Island being looked at; null = the one being restored.
  int? _viewing;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final viewing = (_viewing ?? game.state.island).clamp(0, game.state.island);
    return Column(
      children: [
        Expanded(
          flex: 11,
          child: IslandView(
            islandIndex: viewing,
            onBrowse: (i) =>
                setState(() => _viewing = i == game.state.island ? null : i),
          ),
        ),
        Expanded(
          flex: 10,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            decoration: panelDecoration(radius: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _Tabs(
                  index: _tab,
                  labels: [
                    'Restore',
                    'Dragons (${context.game.state.dragons.length})',
                  ],
                  onChanged: (i) => setState(() => _tab = i),
                ),
                Expanded(
                  child: _tab == 0
                      ? _TaskList(islandIndex: viewing)
                      : const _DragonList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEADCC8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: i == index ? Palette.ink : Palette.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Island view
// ---------------------------------------------------------------------------

class IslandView extends StatefulWidget {
  const IslandView({super.key, required this.islandIndex, this.onBrowse});

  final int islandIndex;

  /// Called with another reached island's index when the arrows are used.
  final ValueChanged<int>? onBrowse;

  @override
  State<IslandView> createState() => _IslandViewState();
}

class _IslandViewState extends State<IslandView> with TickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();
  late final AnimationController _restore = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  String? _restoring;
  StreamSubscription<GameEvent>? _sub;
  final _islandKey = GlobalKey();
  final _sceneKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.game.events.listen((e) {
      if (!mounted) return;
      if (e is TaskCompletedEvent) {
        setState(() => _restoring = e.task.element);
        _restore.forward(from: 0);
        final r = TargetRegistry.rectOfKey(_islandKey);
        if (r != null) {
          for (var i = 0; i < 4; i++) {
            context.fx.burst(
              r.center + Offset((i - 1.5) * 40, (i.isEven ? -1 : 1) * 20.0),
              color: Palette.gold,
              count: 14,
              spread: 70,
            );
          }
        }
      }
      if (e is IdleCollectedEvent) {
        final from = TargetRegistry.rectOfKey(context.targets.keyFor('hoard'));
        final to = context.targets.rect('hud:coins');
        if (from != null && to != null && e.coins > 0) {
          context.fx.fly(
            from: from.center,
            to: to.center,
            icon: const CurrencyIcon(CurrencyKind.coin),
            count: min(10, 3 + e.coins ~/ 20),
          );
        }
        if (from != null) {
          context.fx.floatText(
            from.center,
            '+${formatNumber(e.coins)}',
            color: Palette.gold,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ambient.dispose();
    _restore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final index = widget.islandIndex;
        final island = game.config.island(index);
        final reached = game.state.island;
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                key: _sceneKey,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_ambient, _restore]),
                  builder: (context, _) {
                    final time = _ambient.value * 60;
                    final progress = {
                      for (final t in island.tasks)
                        t.element: !game.taskDone(t.id)
                            ? 0.0
                            : t.element == _restoring
                            ? Curves.easeOutBack
                                  .transform(_restore.value)
                                  .clamp(0.0, 1.0)
                            : 1.0,
                    };
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _CloudsPainter(time)),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 30, 8, 0),
                            child: CustomPaint(
                              key: _islandKey,
                              painter: IslandPainter(
                                progress: progress,
                                time: time,
                                theme: island.theme,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: _FlyingDragons(
                            time: time,
                            dragons: game.state.dragons,
                            config: game.config,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedText(island.name, size: 22),
                  const SizedBox(height: 2),
                  _RestoreProgress(
                    done: island.tasks.where((t) => game.taskDone(t.id)).length,
                    total: island.tasks.length,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 6,
              child: _HoardButton(key: context.targets.keyFor('hoard')),
            ),
            Positioned(
              right: 8,
              top: 6,
              child: Builder(
                builder: (context) => _ShareButton(
                  onTap: () =>
                      shareIslandPicture(context, _sceneKey, island.name),
                ),
              ),
            ),
            if (widget.onBrowse != null && index > 0)
              Positioned(
                left: 4,
                top: 0,
                bottom: 40,
                child: Center(
                  child: _BrowseArrow(
                    icon: Icons.chevron_left_rounded,
                    label: game.config.island(index - 1).name,
                    onTap: () => widget.onBrowse!(index - 1),
                  ),
                ),
              ),
            if (widget.onBrowse != null && index < reached)
              Positioned(
                right: 4,
                top: 0,
                bottom: 40,
                child: Center(
                  child: _BrowseArrow(
                    icon: Icons.chevron_right_rounded,
                    label: game.config.island(index + 1).name,
                    onTap: () => widget.onBrowse!(index + 1),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Share',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40301E4F),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.ios_share_rounded, color: Palette.accent),
        ),
      ),
    );
  }
}

class _RestoreProgress extends StatelessWidget {
  const _RestoreProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    height: 16,
    decoration: BoxDecoration(
      color: const Color(0x663B2A5A),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Stack(
      children: [
        FractionallySizedBox(
          widthFactor: total == 0 ? 0 : done / total,
          child: Container(
            decoration: BoxDecoration(
              color: Palette.green,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Center(
          child: Text(
            '$done / $total restored',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CloudsPainter extends CustomPainter {
  _CloudsPainter(this.time);

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .7);
    for (final (y, speed, scale, offset) in [
      (.12, 6.0, 1.0, 0.0),
      (.3, 4.0, .7, .5),
      (.8, 5.0, .9, .2),
      (.62, 3.0, .6, .75),
    ]) {
      final x = ((time * speed / size.width + offset) % 1.3 - .15) * size.width;
      final c = Offset(x, size.height * y);
      final r = 18.0 * scale;
      canvas.drawCircle(c, r, paint);
      canvas.drawCircle(c + Offset(r * 1.1, r * .2), r * .8, paint);
      canvas.drawCircle(c + Offset(-r * 1.1, r * .3), r * .7, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(c.dx - r * 1.7, c.dy, c.dx + r * 1.8, c.dy + r * .9),
          Radius.circular(r * .45),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CloudsPainter old) => old.time != time;
}

/// Dragons lazily fly loops around the island (Pillar 4: the island feels
/// alive).
class _FlyingDragons extends StatelessWidget {
  const _FlyingDragons({
    required this.time,
    required this.dragons,
    required this.config,
  });

  final double time;
  final List<Dragon> dragons;
  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final shown = dragons.take(10).toList();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < shown.length; i++)
              Builder(
                builder: (context) {
                  final d = shown[i];
                  final rnd = Random(d.id);
                  final type = config.dragonType(d.type);
                  final size = 34.0 + d.level * 8;
                  // Most dragons fly laps; some nap or play on the island.
                  final mode = i < 2 ? 0 : rnd.nextInt(5);
                  if (mode >= 3) {
                    final gx = w * (.28 + rnd.nextDouble() * .44);
                    final gy = h * (.56 + rnd.nextDouble() * .08);
                    if (mode == 3) {
                      return _SleepingDragon(
                        key: ValueKey('sleep${d.id}'),
                        dragon: d,
                        at: Offset(gx, gy),
                        size: size * .9,
                        time: time + i * 1.7,
                        type: type,
                        level: d.level,
                      );
                    }
                    final t = time * (.8 + rnd.nextDouble() * .4) + i;
                    final x = gx + sin(t * .5) * w * .08;
                    final hop = (sin(t * 3)).abs();
                    return Positioned(
                      left: x - size / 2,
                      top: gy - size / 2 - hop * 16,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          cos(t * .5) > 0 ? 1 : -1,
                          1 + (1 - hop) * .06,
                          1,
                        ),
                        child: _Pokeable(
                          dragon: d,
                          child: DragonIcon(
                            type: type,
                            level: d.level,
                            size: size,
                            flap: hop > .3 ? (sin(t * 14) + 1) / 2 : 0,
                          ),
                        ),
                      ),
                    );
                  }
                  final speed = .12 + rnd.nextDouble() * .12;
                  final phase = rnd.nextDouble() * pi * 2;
                  final a = time * speed + phase;
                  final rx = w * (.28 + rnd.nextDouble() * .14);
                  final ry = h * (.08 + rnd.nextDouble() * .1);
                  final cy = h * (.3 + rnd.nextDouble() * .2);
                  final x = w / 2 + cos(a) * rx;
                  final y = cy + sin(a) * ry + sin(time * 2 + i) * 4;
                  final facingRight = -sin(a) > 0;
                  final flap = (sin(time * (7 + d.level) + i) + 1) / 2;
                  return Positioned(
                    left: x - size / 2,
                    top: y - size / 2,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        facingRight ? 1 : -1,
                        1,
                        1,
                      ),
                      child: _Pokeable(
                        dragon: d,
                        child: DragonIcon(
                          type: type,
                          level: d.level,
                          size: size,
                          flap: flap,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Tapping a dragon on the island: it chirps (babies) or roars (grown).
class _Pokeable extends StatelessWidget {
  const _Pokeable({required this.dragon, required this.child});

  final Dragon dragon;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (d) {
      final game = context.game;
      game.feedback.play(dragon.level >= 3 ? Sfx.roar : Sfx.chirp);
      game.feedback.haptic(heavy: dragon.level >= 3);
      context.fx.burst(
        d.globalPosition,
        color: const Color(0xFFFF8AC4),
        count: 6 + dragon.level * 2,
        spread: 30.0 + dragon.level * 8,
      );
      context.fx.floatText(
        d.globalPosition,
        dragon.level >= 3 ? 'ROAR!' : 'chirp!',
        color: const Color(0xFFFFD1EC),
      );
    },
    child: child,
  );
}

/// A dragon napping on the island: slow breathing and drifting "z"s.
class _SleepingDragon extends StatelessWidget {
  const _SleepingDragon({
    super.key,
    required this.dragon,
    required this.at,
    required this.size,
    required this.time,
    required this.type,
    required this.level,
  });

  final Dragon dragon;
  final Offset at;
  final double size;
  final double time;
  final DragonTypeDef type;
  final int level;

  @override
  Widget build(BuildContext context) {
    final breathe = 1 + sin(time * 1.6) * .035;
    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - size / 2,
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1, breathe, 1),
            child: _Pokeable(
              dragon: dragon,
              child: CustomPaint(
                size: Size.square(size),
                painter: DragonPainter(type: type, level: level, blink: true),
              ),
            ),
          ),
          for (var k = 0; k < 3; k++)
            Builder(
              builder: (context) {
                final u = ((time * .35 + k / 3) % 1);
                return Positioned(
                  left: size * (.62 + u * .3),
                  top: size * (.1 - u * .55),
                  child: Opacity(
                    opacity: (1 - u) * (u < .1 ? u / .1 : 1),
                    child: Text(
                      'z',
                      style: TextStyle(
                        fontSize: 10 + u * 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0xFF3B2A5A), blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HoardButton extends StatelessWidget {
  const _HoardButton({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: game.clockTick,
      builder: (context, _) {
        final coins = game.state.idleCoins.floor();
        final cap = game.idleCoinCap;
        final full = game.idleFull;
        final rate = game.coinsPerMinute;
        return GestureDetector(
          onTap: () {
            if (coins > 0) {
              game.collectIdle();
            } else if (rate == 0) {
              showToast(
                context,
                'Hatch dragons to fill the hoard! Merge two Cracking Eggs.',
              );
            } else {
              showToast(context, 'Your dragons are still gathering coins...');
            }
          },
          child: Container(
            width: 150,
            padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
            decoration:
                panelDecoration(
                  color: full ? const Color(0xFFFFF1B8) : Palette.panel,
                  radius: 16,
                ).copyWith(
                  border: Border.all(
                    color: full ? Palette.gold : Palette.panelEdge,
                    width: 2,
                  ),
                ),
            child: Row(
              children: [
                const Icon(
                  Icons.savings_rounded,
                  color: Color(0xFFD99A0B),
                  size: 30,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const CurrencyIcon(CurrencyKind.coin, size: 15),
                          const SizedBox(width: 3),
                          Text(
                            formatNumber(coins),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          if (game.state.idleGems >= 1) ...[
                            const SizedBox(width: 4),
                            const CurrencyIcon(CurrencyKind.gem, size: 13),
                            Text(
                              '${game.state.idleGems.floor()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: cap <= 0
                              ? 0
                              : (game.state.idleCoins / cap).clamp(0, 1),
                          minHeight: 5,
                          color: full ? Palette.danger : Palette.gold,
                          backgroundColor: const Color(0xFFEADCC8),
                        ),
                      ),
                      Text(
                        full
                            ? 'Full! Tap to collect'
                            : '${rate.toStringAsFixed(1)}/min',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Palette.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

const _elementIcons = {
  'vines': Icons.grass,
  'bridge': Icons.water,
  'well': Icons.water_drop,
  'garden': Icons.local_florist,
  'nest': Icons.egg,
  'shed': Icons.warehouse,
  'tower': Icons.fort,
  'windmill': Icons.wind_power,
  'lanterns': Icons.light,
  'shrine': Icons.diamond,
};

class _TaskList extends StatelessWidget {
  const _TaskList({required this.islandIndex});

  final int islandIndex;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final island = game.config.island(islandIndex);
        final isCurrent = islandIndex == game.state.island;
        final tasks = [...island.tasks];
        // Available first, then locked, then done.
        int rank(IslandTaskDef t) =>
            game.taskDone(t.id) ? 2 : (game.taskAvailable(t) ? 0 : 1);
        tasks.sort((a, b) => rank(a).compareTo(rank(b)));
        final showTravel =
            isCurrent && game.islandComplete && game.hasNextIsland;
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          children: [
            if (showTravel) const _TravelCard(),
            if (isCurrent && game.islandComplete && !game.hasNextIsland)
              const _AllDoneCard(),
            for (final t in tasks)
              _TaskTile(key: context.targets.keyFor('task:${t.id}'), task: t),
          ],
        );
      },
    );
  }
}

class _TravelCard extends StatelessWidget {
  const _TravelCard();

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final next = game.config.island(game.state.island + 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1B8), Color(0xFFFFD6A5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.gold, width: 2.5),
      ),
      child: Column(
        children: [
          Text(
            game.currentIsland.completeText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          GameButton(
            shine: true,
            color: Palette.accent,
            onTap: game.travelToNextIsland,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sailing_rounded),
                const SizedBox(width: 6),
                Text('Travel to ${next.name}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE3F7E6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Palette.green, width: 2),
    ),
    child: Text(
      context.game.currentIsland.completeText,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

class _BrowseArrow extends StatelessWidget {
  const _BrowseArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .85),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x33301E4F), blurRadius: 4)],
        ),
        child: Icon(icon, color: Palette.ink, size: 28),
      ),
    ),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({super.key, required this.task});

  final IslandTaskDef task;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final done = game.taskDone(task.id);
    final available = game.taskAvailable(task);
    final affordable = game.state.coins >= task.cost;
    String? lockText;
    if (!done && !available) {
      if (game.state.level < task.requiresLevel) {
        lockText = 'Reach level ${task.requiresLevel}';
      } else {
        final missing = task.requires
            .where((r) => !game.taskDone(r))
            .map((r) => game.config.task(r)?.name ?? r);
        lockText = 'First: ${missing.join(', ')}';
      }
    }
    void complete() {
      if (!game.completeTask(task.id)) {
        showToast(
          context,
          'You need ${task.cost - game.state.coins} more coins. Complete orders to earn more!',
        );
      }
    }

    return GestureDetector(
      onTap: available ? complete : null,
      child: Opacity(
        opacity: done ? .6 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: available ? Colors.white : const Color(0xFFF6EEE3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: available && affordable
                  ? Palette.green
                  : Palette.panelEdge,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFFD8F3DC)
                      : const Color(0xFFEADCC8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _elementIcons[task.element] ?? Icons.build,
                  color: done ? Palette.greenDark : Palette.wood,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      lockText ?? task.desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.inkSoft,
                      ),
                    ),
                    if (task.perk != null)
                      Text(
                        task.perk!.text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.greenDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (done)
                const Icon(Icons.check_circle, color: Palette.green, size: 30)
              else if (available)
                GameButton(
                  color: affordable ? Palette.green : const Color(0xFFBDB6C8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  onTap: complete,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CurrencyIcon(CurrencyKind.coin, size: 16),
                      const SizedBox(width: 4),
                      Text(formatNumber(task.cost)),
                    ],
                  ),
                )
              else
                const Icon(Icons.lock, color: Palette.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dragons
// ---------------------------------------------------------------------------

class _DragonList extends StatefulWidget {
  const _DragonList();

  @override
  State<_DragonList> createState() => _DragonListState();
}

class _DragonListState extends State<_DragonList> {
  int? _selected;

  void _tapDragon(GameController game, Dragon d) {
    final sel = _selected == null
        ? null
        : game.state.dragons.where((x) => x.id == _selected).firstOrNull;
    if (sel != null && game.canMergeDragons(sel, d)) {
      setState(() => _selected = null);
      game.mergeDragons(sel.id, d.id);
      return;
    }
    setState(() => _selected = _selected == d.id ? null : d.id);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final dragons = [...game.state.dragons]
          ..sort(
            (a, b) => a.type == b.type
                ? b.level.compareTo(a.level)
                : a.type.compareTo(b.type),
          );
        final discovered = game.config.dragons.types.where(
          (t) =>
              game.state.dragons.any((d) => d.type == t.id) ||
              game.state.discovered.any((k) => k.startsWith('dragon:${t.id}:')),
        );
        final selected = dragons.where((d) => d.id == _selected).firstOrNull;
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          children: [
            Row(
              children: [
                const CurrencyIcon(CurrencyKind.coin, size: 16),
                Expanded(
                  child: Text(
                    ' ${game.coinsPerMinute.toStringAsFixed(1)} coins/min  -  hoard holds ${game.offlineCapHours.toStringAsFixed(0)}h',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dragons.isEmpty
                  ? 'No dragons yet! Merge Dragon Eggs on the board: two Cracking Eggs hatch a dragon.'
                  : selected != null
                  ? 'Now tap another ${game.config.dragons.level(selected.level).name} ${game.config.dragonType(selected.type).name} dragon to merge!'
                  : 'Tap two matching dragons (or drag one onto another) to grow them.',
              style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in dragons)
                  _DragonCard(
                    dragon: d,
                    selected: d.id == _selected,
                    mergeable:
                        selected != null && game.canMergeDragons(selected, d),
                    hasPair: dragons.any((o) => game.canMergeDragons(o, d)),
                    onTap: () => _tapDragon(game, d),
                    onDropped: (other) => game.mergeDragons(other, d.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Collection  ${discovered.length}/${game.config.dragons.types.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final t in game.config.dragons.types)
                  Expanded(
                    child: Column(
                      children: [
                        DragonIcon(
                          type: t,
                          level: 1,
                          size: 44,
                          silhouette: !discovered.contains(t),
                        ),
                        Text(
                          discovered.contains(t) ? t.name : '???',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          game.config.rarity(t.rarity).name,
                          style: TextStyle(
                            fontSize: 10,
                            color: game.config.rarity(t.rarity).color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DragonCard extends StatelessWidget {
  const _DragonCard({
    required this.dragon,
    required this.selected,
    required this.mergeable,
    required this.hasPair,
    required this.onTap,
    required this.onDropped,
  });

  final Dragon dragon;
  final bool selected;
  final bool mergeable;
  final bool hasPair;
  final VoidCallback onTap;
  final ValueChanged<int> onDropped;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final type = game.config.dragonType(dragon.type);
    final rarity = game.config.rarity(type.rarity);
    Widget card(bool hover) => Container(
      width: 84,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: selected || hover ? const Color(0xFFFFF1B8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? Palette.gold
              : (mergeable || hover
                    ? Palette.green
                    : rarity.color.withValues(alpha: .6)),
          width: selected || mergeable ? 3 : 2,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DragonIcon(type: type, level: dragon.level, size: 60),
              if (hasPair)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: Icon(
                    Icons.auto_awesome,
                    color: Palette.gold,
                    size: 16,
                  ),
                ),
            ],
          ),
          Text(
            game.config.dragons.level(dragon.level).name,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          Text(
            type.name,
            style: TextStyle(
              fontSize: 10.5,
              color: rarity.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${game.dragonCoinsPerMinute(dragon).toStringAsFixed(1)}/min',
            style: const TextStyle(fontSize: 10, color: Palette.inkSoft),
          ),
        ],
      ),
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) {
        final other = game.state.dragons
            .where((x) => x.id == d.data)
            .firstOrNull;
        return other != null && game.canMergeDragons(other, dragon);
      },
      onAcceptWithDetails: (d) => onDropped(d.data),
      builder: (context, candidates, _) => LongPressDraggable<int>(
        data: dragon.id,
        delay: const Duration(milliseconds: 180),
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.1, child: card(false)),
        ),
        childWhenDragging: Opacity(opacity: .3, child: card(false)),
        child: GestureDetector(
          onTap: onTap,
          child: card(candidates.isNotEmpty),
        ),
      ),
    );
  }
}

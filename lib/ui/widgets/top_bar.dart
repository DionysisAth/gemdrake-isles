import 'package:flutter/material.dart';

import '../dialogs/dialogs.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../theme.dart';

/// Level/XP, energy, coins and gems.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final targets = context.targets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
      child: ListenableBuilder(
        listenable: Listenable.merge([game, game.clockTick]),
        builder: (context, _) {
          final s = game.state;
          final next = game.nextEnergyIn;
          return Row(
            children: [
              _LevelBadge(
                key: targets.keyFor('hud:xp'),
                level: s.level,
                progress: s.xp / game.xpToNext,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Chip(
                  key: targets.keyFor('hud:energy'),
                  icon: const CurrencyIcon(CurrencyKind.energy),
                  value: '${game.energy}/${game.energyMax}',
                  sub: next == null ? null : formatDuration(next),
                  onTap: () => showOutOfEnergy(context),
                  plus: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Chip(
                  key: targets.keyFor('hud:coins'),
                  icon: const CurrencyIcon(CurrencyKind.coin),
                  value: s.coins,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Chip(
                  key: targets.keyFor('hud:gems'),
                  icon: const CurrencyIcon(CurrencyKind.gem),
                  value: s.gems,
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                visualDensity: VisualDensity.compact,
                onPressed: () => showSettings(context),
                icon: const Icon(Icons.settings_rounded, color: Palette.ink),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({super.key, required this.level, required this.progress});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 500),
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                backgroundColor: Colors.white70,
                color: const Color(0xFF9C6BFF),
              ),
            ),
          ),
          const CurrencyIcon(CurrencyKind.xp, size: 34),
          OutlinedText('$level', size: 15, strokeWidth: 3),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.icon,
    required this.value,
    this.sub,
    this.onTap,
    this.plus = false,
  });

  final Widget icon;

  /// An int animates (counts up/down); a string is shown as is.
  final Object value;
  final String? sub;
  final VoidCallback? onTap;

  /// Shows a small "+" to hint that tapping gets more.
  final bool plus;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final text = v is int
        ? TweenAnimationBuilder<double>(
            tween: Tween(end: v.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, x, _) => _label(formatNumber(x.round())),
          )
        : _label('$v');
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            // Glossy pill
            Positioned.fill(
              left: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF5B4486), Color(0xFF34255A)],
                  ),
                  border: Border.all(color: const Color(0xCCFFFFFF), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40301E4F),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: 22, right: plus ? 13 : 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: text,
                      ),
                      if (sub != null)
                        Text(
                          sub!,
                          style: const TextStyle(
                            color: Color(0xFFD9CCF5),
                            fontSize: 9.5,
                            height: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Icon badge overlapping the left edge
            Positioned(
              left: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55301E4F),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Transform.scale(scale: 1.45, child: icon),
              ),
            ),
            if (plus)
              Positioned(
                right: -5,
                bottom: -3,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: Palette.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.add, size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) => Text(
    s,
    maxLines: 1,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 15,
      height: 1.1,
    ),
  );
}

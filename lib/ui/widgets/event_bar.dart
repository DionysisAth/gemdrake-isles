import 'package:flutter/material.dart';

import '../../logic/game_controller.dart';
import '../dialogs/meta_dialogs.dart';
import '../game_scope.dart';
import '../theme.dart';

/// Toggle between the island board and this week's festival board.
class BoardModeSwitch extends StatelessWidget {
  const BoardModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final def = game.currentEventDef;
    if (def == null) return const SizedBox.shrink();
    final festival = game.eventMode;
    Widget pill(String label, IconData icon, bool active, bool value) =>
        Expanded(
          child: GestureDetector(
            onTap: () => game.setEventMode(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 30,
              decoration: BoxDecoration(
                color: active
                    ? (value ? def.colors.first : Palette.accent)
                    : Colors.white.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: active ? Colors.white : Palette.inkSoft,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : Palette.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: Row(
        children: [
          pill('Island board', Icons.landscape_rounded, !festival, false),
          const SizedBox(width: 8),
          pill(def.name, Icons.celebration_rounded, festival, true),
        ],
      ),
    );
  }
}

/// Shown instead of the orders on the festival board: points and progress
/// to the next reward.
class EventBar extends StatelessWidget {
  const EventBar({super.key, required this.onOpenTrack});

  final VoidCallback onOpenTrack;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final def = game.currentEventDef!;
    final e = game.state.event!;
    final ms = game.config.events.milestones;
    final nextIndex = ms.indexWhere((m) => m.points > e.points);
    final prev = nextIndex <= 0 ? 0 : ms[nextIndex - 1].points;
    final next = nextIndex < 0 ? null : ms[nextIndex].points;
    final badge = game.eventBadge;
    return Container(
      height: 104,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [def.colors.last, def.colors.first]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB300),
                      size: 22,
                    ),
                    Text(
                      ' ${e.points} pts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ends in ${formatDuration(game.eventTimeLeft)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: next == null ? 1 : (e.points - prev) / (next - prev),
                    minHeight: 10,
                    color: const Color(0xFFFFB300),
                    backgroundColor: Colors.white.withValues(alpha: .7),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        next == null
                            ? 'Every reward reached!'
                            : 'Next reward at $next pts.\n'
                                  'Merge festival items and offer the top one!',
                        style: const TextStyle(fontSize: 11, height: 1.2),
                      ),
                    ),
                    if (nextIndex >= 0)
                      RewardTile(
                        reward: splitReward(game.milestoneReward(nextIndex))
                            .first,
                        size: 26,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              GameButton(
                color: Palette.pink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onTap: onOpenTrack,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.card_giftcard_rounded, size: 22),
                    Text('Rewards', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              if (badge > 0)
                Positioned(right: -4, top: -6, child: _Dot(count: badge)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Palette.danger,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  );
}

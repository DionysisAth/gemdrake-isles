import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../dialogs/dialogs.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../theme.dart';
import '../widgets/piece_view.dart';

/// The Dragon Book: every dragon type at every level, with rewards for
/// completing sets.
class BookScreen extends StatelessWidget {
  const BookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final goals = game.bookGoals;
        final babies = goals.where((g) => g.key == 'babies').firstOrNull;
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: panelDecoration(color: const Color(0xFFEBDDFF)),
              child: Column(
                children: [
                  const OutlinedText('Dragon Book', size: 24),
                  const SizedBox(height: 4),
                  Text(
                    '${game.bookDiscovered} / ${game.bookTotal} discovered',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: game.bookDiscovered / game.bookTotal,
                      minHeight: 10,
                      color: Palette.accent,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  if (babies != null) ...[
                    const SizedBox(height: 8),
                    _GoalRow(goal: babies),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final t in game.config.dragons.types)
              _TypeCard(
                type: t,
                goal: goals.firstWhere((g) => g.key == 'type:${t.id}'),
              ),
          ],
        );
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.goal});

  final DragonTypeDef type;
  final BookGoal goal;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final rarity = game.config.rarity(type.rarity);
    final owned = game.state.dragons.where((d) => d.type == type.id).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                type.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: rarity.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rarity.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (type.event) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.pink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Festival',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Owned: $owned',
                style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var l = 1; l <= game.config.dragons.maxLevel; l++)
                Expanded(
                  child: _DragonCell(
                    type: type,
                    level: l,
                    seen: game.dragonSeen(type.id, l),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _GoalRow(goal: goal),
        ],
      ),
    );
  }
}

class _DragonCell extends StatelessWidget {
  const _DragonCell({
    required this.type,
    required this.level,
    required this.seen,
  });

  final DragonTypeDef type;
  final int level;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final lv = context.game.config.dragons.level(level);
    return GestureDetector(
      onTap: () => showToast(
        context,
        seen
            ? '${lv.name} ${type.name}: ${type.desc}'
            : 'Not discovered yet. '
                  '${level == 1 ? 'Hatch one from an egg.' : 'Merge two ${type.name} dragons of the level below.'}',
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: seen ? const Color(0xFFF6EEFF) : const Color(0xFFEDE8F2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: FittedBox(
                child: DragonIcon(
                  type: type,
                  level: level,
                  size: 56,
                  silhouette: !seen,
                ),
              ),
            ),
            Text(
              seen ? lv.name : '?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final BookGoal goal;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return Row(
      children: [
        Icon(
          goal.claimed ? Icons.check_circle_rounded : Icons.flag_rounded,
          size: 18,
          color: goal.claimed ? Palette.green : Palette.inkSoft,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(goal.title, style: const TextStyle(fontSize: 12.5)),
        ),
        if (goal.claimable)
          GameButton(
            color: Palette.pink,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            onTap: () => game.claimBook(goal.key),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Claim ${goal.gems} ',
                  style: const TextStyle(fontSize: 13),
                ),
                const CurrencyIcon(CurrencyKind.gem, size: 15),
              ],
            ),
          )
        else if (!goal.claimed)
          Row(
            children: [
              Text('${goal.gems} ', style: const TextStyle(fontSize: 12)),
              const CurrencyIcon(CurrencyKind.gem, size: 15),
            ],
          ),
      ],
    );
  }
}

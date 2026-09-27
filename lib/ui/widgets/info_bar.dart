import 'package:flutter/material.dart';

import '../../logic/game_controller.dart';
import '../../logic/merge_logic.dart';
import '../dialogs/dialogs.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../theme.dart';
import 'piece_view.dart';

/// Describes whatever is selected on the board: what an item merges into,
/// a generator's charges, a locked cell... with context actions (sell,
/// speed up, upgrade, odds).
class InfoBar extends StatelessWidget {
  const InfoBar({super.key});

  static Future<void> buyStorageSlot(BuildContext context) async {
    final game = context.game;
    final cost = game.nextStorageSlotCost;
    if (cost == null) return;
    if (await confirmGems(context, cost, 'Buy an extra storage slot')) {
      game.buyStorageSlot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return Container(
      decoration: panelDecoration(radius: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListenableBuilder(
        listenable: Listenable.merge([game, game.clockTick]),
        builder: (context, _) => _content(context, game),
      ),
    );
  }

  Widget _content(BuildContext context, GameController game) {
    final slot = game.selected;
    final piece = slot == null ? null : game.pieceAt(slot);
    final config = game.config;

    if (slot != null && !slot.storage && game.board.isLocked(slot.index)) {
      final lock = game.board.locks[slot.index]!;
      final lt = config.board.lockType(lock.type);
      final visible = !lt.hidesContent && piece?.item != null;
      return _row(
        icon: visible
            ? ItemIcon(piece!.item!, size: 46)
            : const Icon(Icons.cloud, size: 40, color: Color(0xFFB9B1D9)),
        title: visible
            ? '${config.item(piece!.item!).name} (${lt.name})'
            : lt.name,
        subtitle: visible
            ? 'Merge a matching item onto it, or merge next to it to free it.'
            : lock.hits > 1
            ? 'Merge next to it ${lock.hits} times to clear it.'
            : 'Merge next to it to clear it. Something may be hiding inside!',
      );
    }

    if (piece == null) {
      final tips = [
        'Tap a generator to make items. Drag matching items together to merge!',
        'Merge 5 at once (drop onto a group of 4) for a bonus item!',
        'Drag items into storage below to keep them safe.',
        'Items with a green check are wanted by an order.',
      ];
      return _row(
        icon: const Icon(Icons.lightbulb, color: Palette.gold, size: 36),
        title: 'Tip',
        subtitle: tips[(game.state.stat('merges') ~/ 5) % tips.length],
      );
    }

    if (piece.isGenerator) {
      final def = config.generator(piece.generatorId!);
      final lvl = def.level(piece.genLevel);
      final left = game.generatorSecondsLeft(piece);
      final upgrade = game.upgradeCost(piece);
      return _row(
        icon: SizedBox(
          width: 46,
          height: 46,
          child: PieceView(piece: piece, config: config, size: 46),
        ),
        title: '${def.name}  Lv ${piece.genLevel}',
        subtitle: left > 0
            ? 'Recharging: ready in ${formatDuration(Duration(seconds: left))}'
            : '${piece.charges}/${lvl.charges} taps left. Tap it to make items!',
        actions: [
          _iconButton(
            Icons.info_outline,
            () => showGeneratorInfo(context, slot!),
          ),
          if (left > 0) ...[
            _smallButton(
              color: Palette.accent,
              onTap: game.adsLeftToday(AdReward.generatorSkip) > 0
                  ? () => watchAdFor(
                      context,
                      AdReward.generatorSkip,
                      generator: slot,
                    )
                  : null,
              child: const Icon(Icons.play_circle_fill, size: 18),
            ),
            _smallButton(
              color: Palette.pink,
              onTap: () async {
                final cost = game.skipCooldownGemCost(piece);
                if (await confirmGems(
                  context,
                  cost,
                  'Recharge ${def.name} now',
                )) {
                  game.skipCooldownWithGems(slot!);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CurrencyIcon(CurrencyKind.gem, size: 14),
                  Text('${game.skipCooldownGemCost(piece)}'),
                ],
              ),
            ),
          ] else if (upgrade != null)
            _smallButton(
              color: Palette.green,
              onTap: game.state.coins >= upgrade
                  ? () => game.upgradeGenerator(slot!)
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upgrade, size: 16),
                  const CurrencyIcon(CurrencyKind.coin, size: 14),
                  Text(formatNumber(upgrade)),
                ],
              ),
            ),
        ],
      );
    }

    final ref = piece.item!;
    final def = config.item(ref);
    final chain = config.chain(ref.chain);
    final String next;
    if (chain.hatchOnMaxMerge && ref.level == chain.maxLevel) {
      next = 'Merge 2 to hatch a dragon!';
    } else if (chain.loot != null && ref.level == chain.maxLevel) {
      next = 'Open it to see what treasure is inside!';
    } else if (chain.event && ref.level == chain.maxLevel) {
      next = 'Offer it to the festival for points!';
    } else if (!isMergeable(chain, ref)) {
      next = 'Max level! Great for orders.';
    } else {
      final nextRef = ref.next;
      final known = game.state.discovered.contains(nextRef.key);
      next =
          'Merge ${game.eco.standardConsume} to make ${known ? config.item(nextRef).name : '???'}';
    }
    return _row(
      icon: ItemIcon(ref, size: 46),
      title: '${def.name}  Lv ${ref.level}',
      subtitle: next,
      actions: [
        _iconButton(Icons.info_outline, () => showChainInfo(context, ref)),
        if (game.canOffer(slot!))
          _smallButton(
            color: Palette.pink,
            onTap: () => game.offer(slot),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16),
                Text(' Offer +${config.events.offerPoints}'),
              ],
            ),
          )
        else if (game.canOpen(slot))
          _smallButton(
            color: Palette.accent,
            onTap: () => game.openChest(slot),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_open_rounded, size: 16),
                Text(' Open!'),
              ],
            ),
          )
        else if (def.sell == 0)
          _smallButton(
            color: const Color(0xFFB0A4C4),
            onTap: () => game.sell(slot),
            child: const Text('Remove'),
          )
        else
          _smallButton(
            color: const Color(0xFFE0A21A),
            onTap: () => game.sell(slot),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sell '),
                const CurrencyIcon(CurrencyKind.coin, size: 14),
                Text('${def.sell}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row({
    required Widget icon,
    required String title,
    required String subtitle,
    List<Widget> actions = const [],
  }) {
    return Row(
      children: [
        SizedBox(width: 48, height: 48, child: Center(child: icon)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Palette.inkSoft,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        for (final a in actions)
          Padding(padding: const EdgeInsets.only(left: 4), child: a),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(icon, color: Palette.inkSoft, size: 24),
    ),
  );

  Widget _smallButton({
    required Color color,
    required VoidCallback? onTap,
    required Widget child,
  }) => GameButton(
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    radius: 11,
    onTap: onTap,
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 13),
      child: child,
    ),
  );
}

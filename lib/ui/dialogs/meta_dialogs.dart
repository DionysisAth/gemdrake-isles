import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../../model/item_ref.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../theme.dart';
import '../widgets/piece_view.dart';
import 'dialogs.dart';

/// A small reward tile: icon plus label.
class RewardTile extends StatelessWidget {
  const RewardTile({
    super.key,
    required this.reward,
    this.size = 34,
    this.dim = false,
  });

  final LootEntry reward;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final config = context.game.config;
    return Opacity(
      opacity: dim ? .45 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: FittedBox(child: lootIcon(reward, config: config)),
          ),
          Text(
            _short(config, reward),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static String _short(GameConfig c, LootEntry e) {
    if (e.dragon != null) return 'Dragon';
    if (e.item != null) return 'x1';
    if (e.gems > 0) return '${e.gems}';
    if (e.energy > 0) return '${e.energy}';
    return formatNumber(e.coins);
  }
}

/// Everything a reward entry gives, as chips (a login day can give both
/// gems and an item).
List<LootEntry> splitReward(LootEntry e) => [
  if (e.coins > 0) LootEntry(weight: 1, coins: e.coins),
  if (e.gems > 0) LootEntry(weight: 1, gems: e.gems),
  if (e.energy > 0) LootEntry(weight: 1, energy: e.energy),
  if (e.item != null) LootEntry(weight: 1, item: e.item),
  if (e.dragon != null) LootEntry(weight: 1, dragon: e.dragon),
];

// ---------------------------------------------------------------------------
// Daily: login calendar + daily tasks
// ---------------------------------------------------------------------------

Future<void> showDaily(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: 'Daily',
      titleColor: const Color(0xFF3FA7E0),
      onClose: () => Navigator.pop(ctx),
      child: const _DailyBody(),
    ),
  );
}

class _DailyBody extends StatelessWidget {
  const _DailyBody();

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: Listenable.merge([game, game.clockTick]),
      builder: (context, _) {
        final meta = game.config.meta;
        final s = game.state;
        final left = game.nextDayStart.difference(game.clock());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF7A2F),
                ),
                const SizedBox(width: 4),
                Text(
                  'Streak: ${s.loginStreak} day${s.loginStreak == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  'New day in ${formatDuration(left)}',
                  style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 7-day calendar
            Row(
              children: [
                for (var i = 0; i < meta.login.length; i++)
                  Expanded(
                    child: _CalendarDay(
                      day: i + 1,
                      reward: meta.login[i],
                      state: i < game.loginCalendarDay
                          ? _DayState.past
                          : i == game.loginCalendarDay
                          ? (game.loginRewardReady
                                ? _DayState.ready
                                : _DayState.claimed)
                          : _DayState.future,
                    ),
                  ),
              ],
            ),
            if (game.loginRewardReady) ...[
              const SizedBox(height: 8),
              Center(
                child: GameButton(
                  color: Palette.pink,
                  onTap: game.claimLogin,
                  child: const Text("Collect today's gift"),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Daily tasks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (!game.dailyUnlocked)
              Text(
                'Daily tasks unlock at level ${meta.dailyUnlockLevel}.',
                style: const TextStyle(color: Palette.inkSoft),
              )
            else ...[
              for (var i = 0; i < s.dailyTasks.length; i++)
                _DailyTaskRow(index: i),
              const SizedBox(height: 8),
              _DailyBonusCard(game: game),
            ],
          ],
        );
      },
    );
  }
}

enum _DayState { past, ready, claimed, future }

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.reward,
    required this.state,
  });

  final int day;
  final LootEntry reward;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    final ready = state == _DayState.ready;
    final done = state == _DayState.past || state == _DayState.claimed;
    final parts = splitReward(reward);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: ready
            ? const Color(0xFFFFE9A8)
            : done
            ? const Color(0xFFDDF3DD)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ready ? Palette.gold : const Color(0xFFE6DACB),
          width: ready ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Day $day',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              RewardTile(reward: parts.last, size: 26, dim: done),
              if (done)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Palette.green,
                  size: 20,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyTaskRow extends StatelessWidget {
  const _DailyTaskRow({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final t = game.state.dailyTasks[index];
    final def = game.dailyDef(t);
    final progress = game.dailyProgress(t);
    final done = game.dailyDone(t);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.describe(t.target),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress / t.target,
                    minHeight: 8,
                    color: done ? Palette.green : Palette.accent,
                    backgroundColor: const Color(0xFFEDE5F7),
                  ),
                ),
                Text(
                  '$progress / ${t.target}',
                  style: const TextStyle(fontSize: 11, color: Palette.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          for (final r in splitReward(def.reward))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: RewardTile(reward: r, size: 24, dim: t.claimed),
            ),
          const SizedBox(width: 4),
          if (t.claimed)
            const Icon(Icons.check_circle_rounded, color: Palette.green)
          else
            GameButton(
              color: done ? Palette.green : const Color(0xFFBDB3CC),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onTap: done ? () => game.claimDaily(index) : null,
              child: const Text('Claim', style: TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }
}

class _DailyBonusCard extends StatelessWidget {
  const _DailyBonusCard({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    final done = s.dailyTasks.where((t) => t.claimed).length;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1C1), Color(0xFFFFD98A)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.gold, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All-done bonus',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  s.dailyBonusClaimed
                      ? 'Collected! New tasks tomorrow.'
                      : 'Claim all $done/${s.dailyTasks.length} tasks. '
                            'Streak bonus: +${game.streakBonusGems} gems',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          for (final r in game.dailyBonusRewards.expand(splitReward))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: RewardTile(reward: r, size: 26, dim: s.dailyBonusClaimed),
            ),
          if (game.dailyBonusReady)
            GameButton(
              color: Palette.pink,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onTap: game.claimDailyBonus,
              child: const Text('Claim', style: TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gem shop
// ---------------------------------------------------------------------------

Future<void> showShop(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: 'Gem Shop',
      titleColor: Palette.pink,
      onClose: () => Navigator.pop(ctx),
      child: const _ShopBody(),
    ),
  );
}

class _ShopBody extends StatelessWidget {
  const _ShopBody();

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final hoard = game.nextHoardUpgrade;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have '),
                const CurrencyIcon(CurrencyKind.gem, size: 18),
                Text(
                  ' ${game.state.gems}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Text(
              'Gems come from orders, level-ups, daily tasks, chests and '
              'dragons. There are no real-money purchases.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Palette.inkSoft),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .82,
              children: [
                for (final item in game.config.meta.shopItems)
                  _ShopCard(item: item),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.savings_rounded,
                    color: Color(0xFFE0A21A),
                    size: 34,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bigger dragon hoard',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          hoard == null
                              ? 'Maxed! Holds '
                                    '${game.offlineCapHours.toStringAsFixed(0)}h of earnings.'
                              : 'Holds ${game.offlineCapHours.toStringAsFixed(0)}h of '
                                    'earnings. Upgrade to hold '
                                    '${(game.offlineCapHours - game.hoardBaseHours + hoard.hours).toStringAsFixed(0)}h.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hoard != null)
                    _GemButton(
                      cost: hoard.costGems,
                      onTap: () async {
                        if (await confirmGems(
                              context,
                              hoard.costGems,
                              'Upgrade the dragon hoard',
                            ) &&
                            context.mounted) {
                          game.buyHoardUpgrade();
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.item});

  final ShopItemDef item;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final available = game.shopItemAvailable(item);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1D9E6), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: () => _showOdds(context),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: Palette.inkSoft,
                ),
              ),
            ],
          ),
          Expanded(
            child: item.icon == 'energy'
                ? const Center(
                    child: CurrencyIcon(CurrencyKind.energy, size: 50),
                  )
                : ItemIcon(ItemRef.parse(item.icon), size: 58),
          ),
          Text(
            item.desc,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 11, height: 1.15),
          ),
          const SizedBox(height: 4),
          if (available)
            _GemButton(
              cost: item.costGems,
              onTap: () async {
                if (await confirmGems(
                      context,
                      item.costGems,
                      'Buy ${item.name}',
                    ) &&
                    context.mounted) {
                  Navigator.pop(context);
                  game.buyShopItem(item.id);
                }
              },
            )
          else
            Text(
              'Unlocks on island ${item.unlockIsland}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Palette.inkSoft,
              ),
            ),
        ],
      ),
    );
  }

  void _showOdds(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => GameDialog(
        title: item.name,
        onClose: () => Navigator.pop(ctx),
        child: Column(
          children: [
            Text(
              item.loot.rolls == 1
                  ? 'You get 1 reward. Odds:'
                  : 'You get ${item.loot.rolls} rewards, each rolled with these odds:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            LootOddsTable(loot: item.loot),
          ],
        ),
      ),
    );
  }
}

class _GemButton extends StatelessWidget {
  const _GemButton({required this.cost, required this.onTap});

  final int cost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final afford = context.game.state.gems >= cost;
    return GameButton(
      color: afford ? Palette.pink : const Color(0xFFBDB3CC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CurrencyIcon(CurrencyKind.gem, size: 18),
          const SizedBox(width: 4),
          Text('$cost', style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// League result
// ---------------------------------------------------------------------------

Future<void> showLeagueResult(BuildContext context) {
  final game = context.game;
  final r = game.state.leagueResult;
  if (r == null) return Future.value();
  final tiers = game.config.events.league.tiers;
  final moved = r.tierAfter > r.tierBefore
      ? 'Promoted to ${tiers[r.tierAfter].name} League!'
      : r.tierAfter < r.tierBefore
      ? 'Moved down to ${tiers[r.tierAfter].name} League.'
      : 'You stay in ${tiers[r.tierAfter].name} League.';
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => GameDialog(
      title: 'League results',
      titleColor: const Color(0xFFE0A21A),
      actions: [
        GameButton(
          onTap: () {
            game.claimLeagueResult();
            Navigator.pop(ctx);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Collect ${r.gems} '),
              const CurrencyIcon(CurrencyKind.gem, size: 18),
            ],
          ),
        ),
      ],
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            size: 60,
            color: r.rank == 1
                ? Palette.gold
                : r.rank <= 3
                ? const Color(0xFFB0BEC5)
                : Palette.inkSoft,
          ),
          Text(
            'You finished #${r.rank} last week',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(moved),
          const SizedBox(height: 6),
          Text(
            game.config.events.league.note,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
          ),
        ],
      ),
    ),
  );
}

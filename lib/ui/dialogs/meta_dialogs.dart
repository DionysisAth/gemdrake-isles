import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../../model/item_ref.dart';
import '../../model/game_state.dart';
import '../game_scope.dart';
import '../painters/dragon_painter.dart';
import '../painters/item_painter.dart';
import '../painters/board_painters.dart';
import '../theme.dart';
import '../widgets/piece_view.dart';
import 'dialogs.dart';
import 'store_widgets.dart';

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
                  shine: true,
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
              'dragons.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Palette.inkSoft),
            ),
            const SizedBox(height: 8),
            if (game.eco.adFreeChest != null) const _FreeChestCard(),
            const StoreSection(),
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
            const SizedBox(height: 8),
            const _BoardRowCard(),
          ],
        );
      },
    );
  }
}

/// Buys an extra row for the main board.
class _BoardRowCard extends StatelessWidget {
  const _BoardRowCard();

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final cost = game.nextBoardRowCost;
    final b = game.state.board;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.grid_on_rounded, color: Color(0xFF4CBF6B), size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bigger board',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  cost == null
                      ? 'Maxed! Your board is ${b.cols} x ${b.rows}.'
                      : 'Add a row of ${b.cols} free cells '
                            '(${b.cols} x ${b.rows} to ${b.cols} x ${b.rows + 1}).',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (cost != null)
            _GemButton(
              cost: cost,
              onTap: () async {
                if (await confirmGems(context, cost, 'Add a board row') &&
                    context.mounted) {
                  game.buyBoardRow();
                }
              },
            ),
        ],
      ),
    );
  }
}

/// A free chest for watching a video, once a day.
class _FreeChestCard extends StatelessWidget {
  const _FreeChestCard();

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final left = game.adsLeftToday(AdReward.freeChest);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFE8C8), width: 2),
      ),
      child: Row(
        children: [
          ItemIcon(ItemRef.parse('treasure:3'), size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free Chest',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                ),
                Text(
                  left > 0
                      ? 'Watch a short video for '
                            '${game.eco.adFreeChest!.rolls} random rewards.'
                      : 'Come back tomorrow for another one.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (left > 0)
            GameButton(
              color: Palette.green,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onTap: () => watchAdFor(context, AdReward.freeChest),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill_rounded, size: 18),
                  Text(' Free', style: TextStyle(fontSize: 14)),
                ],
              ),
            )
          else
            const Icon(Icons.check_circle_rounded, color: Palette.green),
        ],
      ),
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
                : item.icon.startsWith('dragon:')
                ? Center(
                    child: DragonIcon(
                      type: game.config.dragonType(item.icon.substring(7)),
                      level: 1,
                      size: 56,
                    ),
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
// Sharing
// ---------------------------------------------------------------------------

Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Shares a picture of the island (the scene inside [sceneKey]) on a sky
/// background with a caption.
Future<void> shareIslandPicture(
  BuildContext context,
  GlobalKey sceneKey,
  String islandName,
) async {
  final game = context.game;
  final origin = _originOf(context);
  try {
    final boundary =
        sceneKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    const scale = 2.0;
    final scene = await boundary.toImage(pixelRatio: scale);
    final w = scene.width.toDouble();
    final h = scene.height.toDouble();
    const banner = 70.0 * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final full = Rect.fromLTWH(0, 0, w, h + banner);
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.sky1, Palette.sky2],
        ).createShader(full),
    );
    canvas.drawImage(scene, Offset.zero, Paint());
    final dragons = game.state.dragons.length;
    final text = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Fredoka',
          color: Palette.ink,
          fontSize: 17 * scale,
          fontWeight: FontWeight.w700,
        ),
        text: '$islandName - Level ${game.state.level}\n',
        children: [
          TextSpan(
            text: '$dragons dragon${dragons == 1 ? '' : 's'} - Gemdrake Isles',
            style: const TextStyle(
              fontSize: 13 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    )..layout(maxWidth: w);
    text.paint(
      canvas,
      Offset((w - text.width) / 2, h + (banner - text.height) / 2),
    );
    final image = await recorder.endRecording().toImage(
      w.round(),
      (h + banner).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'gemdrake-isles.png',
          ),
        ],
        text: 'Look at my $islandName in Gemdrake Isles!',
        sharePositionOrigin: origin,
      ),
    );
    game.analytics.log('share', {'what': 'island'});
  } catch (e) {
    if (context.mounted) showToast(context, "Couldn't share right now");
  }
}

/// Shares a vertical 9:16 card of a freshly hatched (or grown) dragon.
Future<void> shareDragonCard(
  BuildContext context,
  Dragon dragon, {
  bool grown = false,
}) async {
  final game = context.game;
  final origin = _originOf(context);
  try {
    final type = game.config.dragonType(dragon.type);
    final rarity = game.config.rarity(type.rarity);
    final image = await renderDragonCard(game.config, dragon, grown: grown);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'gemdrake-${type.id}.png',
          ),
        ],
        text:
            'I ${grown ? 'raised' : 'hatched'} a ${rarity.name} ${type.name} Dragon in Gemdrake Isles!',
        sharePositionOrigin: origin,
      ),
    );
    game.analytics.log('share', {'what': 'dragon', 'type': type.id});
  } catch (e) {
    if (context.mounted) showToast(context, "Couldn't share right now");
  }
}

/// Draws the 1080x1920 share card for [dragon].
Future<ui.Image> renderDragonCard(
  GameConfig config,
  Dragon dragon, {
  bool grown = false,
}) async {
  {
    final type = config.dragonType(dragon.type);
    final rarity = config.rarity(type.rarity);
    final level = config.dragons.level(dragon.level).name;
    const w = 1080.0, h = 1920.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const full = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.15),
          radius: 1.1,
          colors: [
            Color.lerp(rarity.color, Colors.white, .7)!,
            rarity.color,
            const Color(0xFF2A1B6E),
          ],
          stops: const [0, .45, 1],
        ).createShader(full),
    );
    // Rays
    final c = const Offset(w / 2, h * .42);
    final rays = Paint()..color = Colors.white.withValues(alpha: .13);
    for (var i = 0; i < 16; i++) {
      final a = i * pi / 8;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a - .09) * 1500, c.dy + sin(a - .09) * 1500)
          ..lineTo(c.dx + cos(a + .09) * 1500, c.dy + sin(a + .09) * 1500)
          ..close(),
        rays,
      );
    }
    canvas.drawCircle(
      c,
      420,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .85),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: 420)),
    );
    for (final (x, y, r) in [
      (.15, .12, 26.0),
      (.85, .18, 34.0),
      (.2, .6, 22.0),
      (.82, .62, 28.0),
      (.5, .08, 18.0),
      (.1, .38, 16.0),
      (.9, .42, 18.0),
    ]) {
      paintSparkle(canvas, Offset(w * x, h * y), r);
    }
    // The dragon
    canvas.save();
    canvas.translate(c.dx - 380, c.dy - 380);
    DragonPainter(
      type: type,
      level: dragon.level,
    ).paint(canvas, const Size(760, 760));
    canvas.restore();
    void text(
      String t,
      double y,
      double size, {
      Color color = Colors.white,
      FontWeight weight = FontWeight.w700,
    }) {
      final stroke = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: size,
            fontWeight: weight,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * .16
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF2B1648),
          ),
        ),
      )..layout(maxWidth: w - 80);
      final fill = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: size,
            fontWeight: weight,
            color: color,
          ),
        ),
      )..layout(maxWidth: w - 80);
      final o = Offset((w - fill.width) / 2, y);
      stroke.paint(canvas, o);
      fill.paint(canvas, o);
    }

    text(grown ? 'My dragon grew into a' : 'I hatched a', h * .08, 64);
    text(
      rarity.name.toUpperCase(),
      h * .72,
      84,
      color: const Color(0xFFFFF1A8),
    );
    text('$level ${type.name} Dragon!', h * .78, 76);
    text('Gemdrake Isles', h * .9, 70, color: const Color(0xFFFFD1EC));
    return recorder.endRecording().toImage(w.toInt(), h.toInt());
  }
}

// ---------------------------------------------------------------------------
// Backup codes
// ---------------------------------------------------------------------------

Future<void> showBackup(BuildContext context) {
  final game = context.game;
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: 'Backup',
      onClose: () => Navigator.pop(ctx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your progress is saved on this device only. Keep a backup code '
            'somewhere safe (notes, email to yourself) to move your game to '
            'a new phone or recover it.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GameButton(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: game.exportBackup()));
              if (ctx.mounted) showToast(ctx, 'Backup code copied');
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy_rounded, size: 20),
                Text(' Copy backup code'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (bctx) => GameButton(
              color: Palette.accent,
              onTap: () async {
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      text: game.exportBackup(),
                      subject: 'Gemdrake Isles backup code',
                      sharePositionOrigin: _originOf(bctx),
                    ),
                  );
                } catch (_) {
                  if (bctx.mounted) showToast(bctx, "Couldn't share right now");
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ios_share_rounded, size: 20),
                  Text(' Save code elsewhere'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GameButton(
            color: const Color(0xFFE0A21A),
            onTap: () => _restoreBackup(ctx),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restore_rounded, size: 20),
                Text(' Restore from a code'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _restoreBackup(BuildContext context) async {
  final game = context.game;
  final controller = TextEditingController();
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (clip?.text != null && game.parseBackup(clip!.text!) != null) {
    controller.text = clip.text!;
  }
  if (!context.mounted) return;
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => GameDialog(
      title: 'Restore',
      actions: [
        GameButton(
          color: Colors.grey,
          onTap: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        GameButton(
          color: const Color(0xFFE0A21A),
          onTap: () => Navigator.pop(ctx, controller.text),
          child: const Text('Restore'),
        ),
      ],
      child: Column(
        children: [
          const Text('Paste your backup code:'),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              hintText: 'GDI1...',
            ),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (code == null || !context.mounted) return;
  final backup = game.parseBackup(code);
  if (backup == null) {
    showToast(context, "That code doesn't look right");
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => GameDialog(
      title: 'Replace this game?',
      actions: [
        GameButton(
          color: Colors.grey,
          onTap: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        GameButton(
          color: Palette.danger,
          onTap: () => Navigator.pop(ctx, true),
          child: const Text('Replace'),
        ),
      ],
      child: Text(
        'The backup is level ${backup.level} on island ${backup.island + 1} '
        'with ${backup.dragons.length} dragons. Your current game on this '
        'device (level ${game.state.level}) will be replaced.',
        textAlign: TextAlign.center,
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  await game.importBackup(code);
  if (context.mounted) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    showToast(context, 'Game restored!');
  }
}

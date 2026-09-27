import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../../model/game_state.dart';
import '../../model/item_ref.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../painters/item_painter.dart';
import '../theme.dart';
import '../widgets/piece_view.dart';

/// Shared cozy dialog frame with a ribbon title.
class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.titleColor = Palette.accent,
    this.onClose,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Color titleColor;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 22),
              padding: const EdgeInsets.fromLTRB(18, 34, 18, 16),
              decoration: panelDecoration(radius: 24),
              // Transparent Material so list tiles and ink splashes show.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: SingleChildScrollView(child: child)),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 40,
              right: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: titleColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      bottom: BorderSide(
                        color: Color.lerp(titleColor, Colors.black, .3)!,
                        width: 4,
                      ),
                    ),
                  ),
                  child: OutlinedText(
                    title,
                    size: 20,
                    strokeWidth: 3,
                    stroke: Color.lerp(titleColor, Colors.black, .45)!,
                  ),
                ),
              ),
            ),
            if (onClose != null)
              Positioned(
                top: 28,
                right: 6,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Palette.inkSoft),
                  tooltip: 'Close',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget rewardChip(CurrencyKind kind, String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CurrencyIcon(kind, size: 20),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ],
  ),
);

/// Shows a rewarded ad with the game's music and sounds paused.
Future<bool> showRewardedAd(BuildContext context, String placement) async {
  final feedback = context.game.feedback;
  final ads = context.ads;
  feedback.setSuppressed(true);
  try {
    return await ads.showRewarded(context, placement);
  } finally {
    feedback.setSuppressed(false);
  }
}

/// Watches a rewarded ad and grants [reward] if it was completed.
Future<bool> watchAdFor(
  BuildContext context,
  AdReward reward, {
  Slot? generator,
}) async {
  final game = context.game;
  if (game.adsLeftToday(reward) <= 0) {
    showToast(context, 'No more of those today. Come back tomorrow!');
    return false;
  }
  final ok = await showRewardedAd(context, reward.name);
  if (ok) game.grantAdReward(reward, generator: generator);
  return ok;
}

/// Asks before spending gems above the configured threshold.
Future<bool> confirmGems(BuildContext context, int cost, String what) async {
  final game = context.game;
  if (game.state.gems < cost) {
    showToast(context, 'Not enough gems');
    return false;
  }
  if (cost <= game.eco.confirmGemsAbove) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => GameDialog(
      title: 'Spend gems?',
      actions: [
        GameButton(
          color: Colors.grey,
          onTap: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        GameButton(
          color: Palette.pink,
          onTap: () => Navigator.pop(ctx, true),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Spend $cost '),
              const CurrencyIcon(CurrencyKind.gem, size: 18),
            ],
          ),
        ),
      ],
      child: Text(
        '$what for $cost gems?',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17),
      ),
    ),
  );
  return ok ?? false;
}

void showToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      top: MediaQuery.paddingOf(context).top + 110,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            final o = t < .1 ? t / .1 : (t > .85 ? (1 - t) / .15 : 1.0);
            return Opacity(
              opacity: o,
              child: Transform.translate(
                offset: Offset(0, (1 - min(1, t / .1)) * -12),
                child: child,
              ),
            );
          },
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEE3B2A5A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Popups
// ---------------------------------------------------------------------------

Future<void> showWelcomeBack(BuildContext context, WelcomeBack wb) {
  final game = context.game;
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => GameDialog(
      title: 'Welcome back!',
      actions: [
        GameButton(
          color: Palette.green,
          onTap: () {
            Navigator.pop(ctx);
            game.collectIdle();
          },
          child: const Text('Collect'),
        ),
        GameButton(
          color: Palette.accent,
          onTap: () async {
            final ok = await showRewardedAd(ctx, AdReward.doubleIdle.name);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (ok) {
              game.grantAdReward(AdReward.doubleIdle);
            } else {
              game.collectIdle();
            }
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill),
              SizedBox(width: 6),
              Text('Collect x2'),
            ],
          ),
        ),
      ],
      child: Column(
        children: [
          Text(
            'Your dragons kept busy for ${formatDuration(wb.away)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 6),
          const _DragonParade(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              rewardChip(CurrencyKind.coin, formatNumber(wb.coins)),
              if (wb.gems > 0) rewardChip(CurrencyKind.gem, '${wb.gems}'),
            ],
          ),
          if (game.idleFull) ...[
            const SizedBox(height: 8),
            Text(
              'The hoard was full! It holds ${game.offlineCapHours.toStringAsFixed(0)}h of earnings.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.inkSoft, fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DragonParade extends StatelessWidget {
  const _DragonParade();

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final dragons = [...game.state.dragons]
      ..sort((a, b) => b.level.compareTo(a.level));
    return SizedBox(
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final d in dragons.take(4))
            DragonIcon(
              type: game.config.dragonType(d.type),
              level: d.level,
              size: 64,
            ),
        ],
      ),
    );
  }
}

Future<void> showLevelUp(
  BuildContext context,
  int level,
  int gems,
  List<String> unlocks,
) {
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: 'Level $level!',
      titleColor: const Color(0xFF9C6BFF),
      actions: [
        GameButton(
          onTap: () => Navigator.pop(ctx),
          child: const Text('Hooray!'),
        ),
      ],
      child: Column(
        children: [
          const SizedBox(height: 4),
          const CurrencyIcon(CurrencyKind.xp, size: 64),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              rewardChip(CurrencyKind.gem, '+$gems'),
              rewardChip(CurrencyKind.energy, 'Refilled!'),
            ],
          ),
          if (unlocks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'New!',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            for (final u in unlocks)
              Text(u, style: const TextStyle(fontSize: 15)),
          ],
        ],
      ),
    ),
  );
}

/// Big dragon reveal with a rarity banner. Rarer dragons get bigger moments.
Future<void> showHatch(
  BuildContext context,
  List<Dragon> dragons, {
  bool grown = false,
}) {
  final game = context.game;
  final best = dragons.reduce(
    (a, b) =>
        _rarityRank(game.config, a) >= _rarityRank(game.config, b) ? a : b,
  );
  final type = game.config.dragonType(best.type);
  final rarity = game.config.rarity(type.rarity);
  final rank = _rarityRank(game.config, best);
  if (rank >= 2) context.fx.flash(rarity.color.withValues(alpha: .6));
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: grown
          ? 'Your dragon grew!'
          : (dragons.length > 1
                ? '${dragons.length} dragons hatched!'
                : 'A dragon hatched!'),
      titleColor: rarity.color,
      actions: [
        GameButton(
          onTap: () => Navigator.pop(ctx),
          child: const Text('Welcome home!'),
        ),
      ],
      child: Column(
        children: [
          _HatchReveal(dragons: dragons, rare: rank >= 1),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: rarity.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rarity.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${game.config.dragons.level(best.level).name} ${type.name} Dragon',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            type.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.inkSoft),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CurrencyIcon(CurrencyKind.coin, size: 18),
              Text(
                ' ${game.dragonCoinsPerMinute(best).toStringAsFixed(1)} / min',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

int _rarityRank(GameConfig c, Dragon d) =>
    c.dragons.rarities.indexWhere((r) => r.id == c.dragonType(d.type).rarity);

class _HatchReveal extends StatefulWidget {
  const _HatchReveal({required this.dragons, required this.rare});

  final List<Dragon> dragons;
  final bool rare;

  @override
  State<_HatchReveal> createState() => _HatchRevealState();
}

class _HatchRevealState extends State<_HatchReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return SizedBox(
      height: 150,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: t * pi * 2 / 3,
                child: CustomPaint(
                  size: const Size(170, 170),
                  painter: _RaysPainter(widget.rare),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final d in widget.dragons)
                    Transform.translate(
                      offset: Offset(0, sin(t * pi * 4) * 4),
                      child: DragonIcon(
                        type: game.config.dragonType(d.type),
                        level: d.level,
                        size: widget.dragons.length > 1 ? 90 : 130,
                        flap: (sin(t * pi * 8) + 1) / 2,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.rare);

  final bool rare;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    paintGlow(
      canvas,
      c,
      size.width * .5,
      rare ? const Color(0xFFFFD54F) : const Color(0xFFFFF3C4),
      .9,
    );
    final ray = Paint()..color = Colors.white.withValues(alpha: .45);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(
          c.dx + cos(a - .1) * size.width * .5,
          c.dy + sin(a - .1) * size.width * .5,
        )
        ..lineTo(
          c.dx + cos(a + .1) * size.width * .5,
          c.dy + sin(a + .1) * size.width * .5,
        )
        ..close();
      canvas.drawPath(p, ray);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}

Future<void> showOutOfEnergy(BuildContext context) {
  final game = context.game;
  return showDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([game, game.clockTick]),
      builder: (ctx, _) {
        final next = game.nextEnergyIn;
        final adsLeft = game.adsLeftToday(AdReward.freeEnergy);
        return GameDialog(
          title: 'Out of energy',
          onClose: () => Navigator.pop(ctx),
          actions: [
            GameButton(
              color: Palette.accent,
              onTap: adsLeft > 0
                  ? () async {
                      final ok = await watchAdFor(ctx, AdReward.freeEnergy);
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill),
                  const SizedBox(width: 6),
                  Text('+${game.eco.adFreeEnergyAmount} free ($adsLeft left)'),
                ],
              ),
            ),
            GameButton(
              color: Palette.pink,
              onTap: () async {
                if (await confirmGems(
                      ctx,
                      game.eco.energyRefillGemCost,
                      'Refill your energy',
                    ) &&
                    game.buyEnergyRefill() &&
                    ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Refill '),
                  const CurrencyIcon(CurrencyKind.gem, size: 18),
                  Text(' ${game.eco.energyRefillGemCost}'),
                ],
              ),
            ),
          ],
          child: Column(
            children: [
              const CurrencyIcon(CurrencyKind.energy, size: 56),
              const SizedBox(height: 8),
              Text(
                next == null
                    ? 'Energy is full!'
                    : 'Next energy in ${formatDuration(next)}.\nFull in ${formatDuration(game.fullEnergyIn!)}.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tip: level ups refill your energy, and some orders give energy too.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.inkSoft, fontSize: 13),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Shows every item in a chain, with silhouettes for undiscovered ones and
/// hatch odds for eggs (loot box odds disclosure).
Future<void> showChainInfo(BuildContext context, ItemRef ref) {
  final game = context.game;
  final chain = game.config.chain(ref.chain);
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: chain.name,
      onClose: () => Navigator.pop(ctx),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var l = 1; l <= chain.maxLevel; l++)
                _ChainTile(
                  ref: ItemRef(chain.id, l),
                  name: chain.items[l - 1].name,
                  known: game.state.discovered.contains(
                    ItemRef(chain.id, l).key,
                  ),
                  current: l == ref.level,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            game.config.item(ref).desc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.inkSoft),
          ),
          if (chain.hatchOnMaxMerge) ...[
            const SizedBox(height: 12),
            const Text(
              'Hatch odds',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            HatchOddsTable(config: game.config),
          ],
        ],
      ),
    ),
  );
}

class HatchOddsTable extends StatelessWidget {
  const HatchOddsTable({super.key, required this.config});

  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    final total = config.dragons.hatchTable.fold(0, (s, e) => s + e.weight);
    return Column(
      children: [
        for (final e in config.dragons.hatchTable)
          Builder(
            builder: (context) {
              final type = config.dragonType(e.type);
              final rarity = config.rarity(type.rarity);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    DragonIcon(type: type, level: 1, size: 28),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${type.name} (${rarity.name})')),
                    Text(
                      '${(e.weight * 100 / total).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ChainTile extends StatelessWidget {
  const _ChainTile({
    required this.ref,
    required this.name,
    required this.known,
    required this.current,
  });

  final ItemRef ref;
  final String name;
  final bool known;
  final bool current;

  @override
  Widget build(BuildContext context) => Container(
    width: 74,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: current ? const Color(0xFFFFF1B8) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: current ? Palette.gold : Palette.panelEdge,
        width: 2,
      ),
    ),
    child: Column(
      children: [
        ItemIcon(ref, size: 48, silhouette: !known),
        Text(
          known ? name : '???',
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        Text(
          'Lv ${ref.level}',
          style: const TextStyle(fontSize: 10, color: Palette.inkSoft),
        ),
      ],
    ),
  );
}

/// Generator details, including exact drop odds.
Future<void> showGeneratorInfo(BuildContext context, Slot slot) {
  final game = context.game;
  final piece = game.pieceAt(slot)!;
  final def = game.config.generator(piece.generatorId!);
  final lvl = def.level(piece.genLevel);
  final drops = lvl.dropsFor(game.state.level);
  final total = drops.fold(0, (s, d) => s + d.weight);
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: def.name,
      onClose: () => Navigator.pop(ctx),
      child: Column(
        children: [
          Text(def.desc, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Level ${piece.genLevel}/${def.maxLevel} - ${lvl.charges} taps, then recharges for ${formatDuration(Duration(seconds: lvl.cooldownSeconds))}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 10),
          const Text(
            'Drop odds',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          for (final d in drops)
            Row(
              children: [
                ItemIcon(d.item, size: 30),
                const SizedBox(width: 6),
                Expanded(child: Text(game.config.item(d.item).name)),
                Text(
                  '${(d.weight * 100 / total).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

Future<void> showTaskComplete(
  BuildContext context,
  IslandTaskDef task,
  bool islandComplete,
) {
  final game = context.game;
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      title: islandComplete ? 'Island restored!' : 'Restored!',
      titleColor: Palette.green,
      actions: [
        GameButton(
          onTap: () => Navigator.pop(ctx),
          child: const Text('Lovely!'),
        ),
      ],
      child: Column(
        children: [
          Text(
            task.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (task.perk != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F7E6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Bonus: ${task.perk!.text}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Palette.greenDark,
                ),
              ),
            ),
          ],
          if (islandComplete) ...[
            const SizedBox(height: 10),
            Text(
              game.config.currentIsland.completeText,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> showSettings(BuildContext context) {
  final game = context.game;
  return showDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: game,
      builder: (ctx, _) {
        final s = game.state.settings;
        return GameDialog(
          title: 'Settings',
          onClose: () => Navigator.pop(ctx),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sound'),
                value: !s.muted,
                onChanged: (v) => game.updateSettings((s) => s.muted = !v),
              ),
              const Text('Music'),
              Slider(
                value: s.musicVolume,
                onChanged: (v) => game.updateSettings((s) => s.musicVolume = v),
              ),
              const Text('Effects'),
              Slider(
                value: s.sfxVolume,
                onChanged: (v) => game.updateSettings((s) => s.sfxVolume = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibration'),
                value: s.haptics,
                onChanged: (v) => game.updateSettings((s) => s.haptics = v),
              ),
              if (context.ads.privacyOptionsRequired)
                TextButton(
                  onPressed: () => context.ads.showPrivacyOptions(),
                  child: const Text('Privacy options'),
                ),
              TextButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (c) => GameDialog(
                    title: 'Odds',
                    onClose: () => Navigator.pop(c),
                    child: Column(
                      children: [
                        const Text('Dragon eggs hatch into:'),
                        const SizedBox(height: 6),
                        HatchOddsTable(config: game.config),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap any generator to see its exact drop odds.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Palette.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('Reward odds'),
              ),
              if (game.tutorialActive)
                TextButton(
                  onPressed: () {
                    game.skipTutorial();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Skip tutorial'),
                ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Palette.danger),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => GameDialog(
                      title: 'Start over?',
                      actions: [
                        GameButton(
                          color: Colors.grey,
                          onTap: () => Navigator.pop(c, false),
                          child: const Text('Keep playing'),
                        ),
                        GameButton(
                          color: Palette.danger,
                          onTap: () => Navigator.pop(c, true),
                          child: const Text('Reset'),
                        ),
                      ],
                      child: const Text(
                        'This erases all progress on this device.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                  if (ok == true) {
                    await game.resetProgress();
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Reset progress'),
              ),
              const SizedBox(height: 4),
              Text(
                'Gemdrake Isles - Level ${game.state.level} - ${game.state.stat('merges')} merges',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.inkSoft, fontSize: 12),
              ),
            ],
          ),
        );
      },
    ),
  );
}

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
import '../widgets/fancy.dart';
import '../widgets/online_widgets.dart';
import '../widgets/piece_view.dart';
import 'meta_dialogs.dart';

/// Shared cozy dialog frame: pops in with a bounce, gem-studded border,
/// a ribbon title with a light sweep, and optional celebration rays.
class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.titleColor = Palette.accent,
    this.onClose,
    this.celebrate = false,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Color titleColor;
  final VoidCallback? onClose;

  /// Turning light rays and twinkles behind the popup (rewards, level ups).
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final edge = Color.lerp(titleColor, Colors.white, .35)!;
    final panel = Container(
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [edge, Colors.white, edge],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(
              titleColor,
              Colors.black,
              .5,
            )!.withValues(alpha: .45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 36, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF7), Palette.panel, Color(0xFFFBEEDC)],
          ),
          border: Border.all(color: Palette.panelEdge, width: 1.5),
        ),
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
    );
    // Passthrough so the panel itself takes the dialog's minimum width;
    // with a loose fit a narrow panel sat at the left of a wider stack
    // while the ribbon and corner gems were placed on the stack.
    final body = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        if (celebrate)
          const Positioned(
            left: -80,
            right: -80,
            top: -110,
            height: 320,
            child: RotatingRays(),
          ),
        panel,
        for (final (l, t) in [
          (true, true),
          (false, true),
          (true, false),
          (false, false),
        ])
          Positioned(
            left: l ? -2 : null,
            right: l ? null : -2,
            top: t ? 20 : null,
            bottom: t ? null : -6,
            child: CornerGem(color: titleColor),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RibbonBanner(title: title, color: titleColor),
                const Positioned(
                  left: -16,
                  right: -16,
                  top: -14,
                  bottom: -6,
                  child: Twinkles(count: 6),
                ),
              ],
            ),
          ),
        ),
        if (onClose != null)
          Positioned(top: 36, right: 8, child: _CloseButton(onTap: onClose!)),
      ],
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 290, maxWidth: 380),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          builder: (context, t, child) {
            final pop = Curves.elasticOut.transform(t);
            return Opacity(
              opacity: (t * 4).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - Curves.easeOut.transform(t))),
                child: Transform.scale(scale: .75 + .25 * pop, child: child),
              ),
            );
          },
          child: body,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Close',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF8A8E), Palette.danger],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ),
    ),
  );
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
                child: Transform.scale(
                  scale:
                      .85 + .15 * Curves.elasticOut.transform(min(1, t / .25)),
                  child: child,
                ),
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
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF26B4BA8), Color(0xF23B2A5A)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0x99FFFFFF),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55301E4F),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CornerGem(size: 14, color: Palette.gold),
                    const SizedBox(width: 8),
                    Flexible(
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
                  ],
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
      celebrate: true,
      title: 'Welcome back!',
      actions: [
        GameButton(
          shine: true,
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
      celebrate: true,
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.elasticOut,
            builder: (context, t, child) => Transform.rotate(
              angle: (1 - t) * pi,
              child: Transform.scale(scale: .4 + .6 * t, child: child),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CurrencyIcon(CurrencyKind.xp, size: 104),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedText('$level', size: 30, strokeWidth: 5),
                ),
              ],
            ),
          ),
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
      celebrate: rank >= 1,
      actions: [
        if (rank >= 1)
          Builder(
            builder: (bctx) => GameButton(
              color: Palette.accent,
              onTap: () => shareDragonCard(bctx, best, grown: grown),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ios_share_rounded, size: 18),
                  Text(' Share'),
                ],
              ),
            ),
          ),
        GameButton(
          shine: true,
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
            HatchOddsTable(
              config: game.config,
              table: game.hatchTableFor(chain),
            ),
          ],
          if (chain.loot != null) ...[
            const SizedBox(height: 12),
            Text(
              'Chest contents (${chain.loot!.rolls} rewards)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            LootOddsTable(loot: chain.loot!),
          ],
        ],
      ),
    ),
  );
}

/// Exact odds for a random reward table (chests, packs).
class LootOddsTable extends StatelessWidget {
  const LootOddsTable({super.key, required this.loot});

  final LootDef loot;

  @override
  Widget build(BuildContext context) {
    final config = context.game.config;
    final total = loot.totalWeight;
    return Column(
      children: [
        for (final e in loot.table)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: lootIcon(e, config: config),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(lootLabel(config, e))),
                Text(
                  '${(e.weight * 100 / total).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Widget lootIcon(LootEntry e, {GameConfig? config}) {
  final item = e.item;
  if (item != null) return ItemIcon(item, size: 28);
  final dragon = e.dragon;
  if (dragon != null && config != null) {
    return FittedBox(
      child: DragonIcon(type: config.dragonType(dragon), level: 1, size: 40),
    );
  }
  if (dragon != null) {
    return const Icon(Icons.pets_rounded, color: Palette.accent);
  }
  if (e.gems > 0) return const CurrencyIcon(CurrencyKind.gem, size: 24);
  if (e.energy > 0) return const CurrencyIcon(CurrencyKind.energy, size: 24);
  return const CurrencyIcon(CurrencyKind.coin, size: 24);
}

String lootLabel(GameConfig config, LootEntry e) {
  final item = e.item;
  if (item != null) return config.item(item).name;
  final dragon = e.dragon;
  if (dragon != null) return '${config.dragonType(dragon).name} Dragon';
  if (e.gems > 0) return '${e.gems} gems';
  if (e.energy > 0) return '${e.energy} energy';
  return '${e.coins} coins';
}

/// Shows what came out of a chest.
Future<void> showChestRewards(
  BuildContext context,
  String title,
  List<LootEntry> rewards,
) {
  final config = context.game.config;
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      celebrate: true,
      title: title,
      titleColor: const Color(0xFFE0A21A),
      actions: [
        GameButton(
          onTap: () => Navigator.pop(ctx),
          child: const Text('Awesome!'),
        ),
      ],
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final e in rewards)
            Container(
              width: 86,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.gold, width: 2),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: lootIcon(e, config: config),
                  ),
                  Text(
                    lootLabel(config, e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Celebrates arriving on a new island.
Future<void> showIslandArrival(
  BuildContext context,
  IslandDef island,
  List<String> unlocks,
) {
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      celebrate: true,
      title: island.name,
      titleColor: Palette.accent,
      actions: [
        GameButton(
          onTap: () => Navigator.pop(ctx),
          child: const Text("Let's go!"),
        ),
      ],
      child: Column(
        children: [
          const Icon(Icons.sailing_rounded, size: 56, color: Palette.accent),
          const SizedBox(height: 6),
          const Text(
            'A new island to restore!',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (unlocks.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('New!', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final u in unlocks) Text(u, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}

class HatchOddsTable extends StatelessWidget {
  const HatchOddsTable({super.key, required this.config, required this.table});

  final GameConfig config;
  final List<WeightedType> table;

  @override
  Widget build(BuildContext context) {
    final total = table.fold(0, (s, e) => s + e.weight);
    return Column(
      children: [
        for (final e in table)
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
      celebrate: true,
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
            Text(game.currentIsland.completeText, textAlign: TextAlign.center),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminders'),
                subtitle: const Text(
                  'Energy full, hoard full, daily gift',
                  style: TextStyle(fontSize: 12),
                ),
                value: game.state.notifications,
                onChanged: (v) => game.setReminders(v),
              ),
              const OnlineSettings(),
              TextButton(
                onPressed: () => showBackup(ctx),
                child: const Text('Backup & restore'),
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
                        Text(
                          'Dragon eggs on ${game.currentIsland.name} hatch into:',
                        ),
                        const SizedBox(height: 6),
                        HatchOddsTable(
                          config: game.config,
                          table: game.hatchTableFor(game.config.chain('egg')),
                        ),
                        const SizedBox(height: 8),
                        const Text('Legendary eggs hatch into:'),
                        const SizedBox(height: 6),
                        HatchOddsTable(
                          config: game.config,
                          table: game.hatchTableFor(
                            game.config.chain('legend'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Treasure chests contain:'),
                        const SizedBox(height: 6),
                        LootOddsTable(
                          loot: game.config.chain('treasure').loot!,
                        ),
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

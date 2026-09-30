import 'dart:math';

import 'package:flutter/material.dart';

import '../game_scope.dart';
import '../painters/dragon_painter.dart';
import '../theme.dart';

/// Guided first-session tutorial: a character speech bubble plus a pointing
/// hand on whatever the player should touch next. Steps come from
/// `tutorial.json`; the game controller advances them on events.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.tab});

  /// Current bottom tab: 0 = board, 1 = island.
  final int tab;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Which tab a target lives on, so we don't point at hidden widgets.
  int? _tabFor(String target) {
    if (target.startsWith('task:')) return 1;
    if (target.startsWith('generator:') ||
        target.startsWith('merge:') ||
        target.startsWith('order:')) {
      return 0;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final step = game.tutorialStep;
        if (step == null) return const SizedBox.shrink();
        final character = game.config.orders.character(step.speaker);
        var target = step.target;
        var text = step.text;
        final needTab = target == null ? null : _tabFor(target);
        if (needTab != null && needTab != widget.tab) {
          target = needTab == 1 ? 'tab:island' : 'tab:board';
          text = needTab == 1
              ? "Let's go to the Island!"
              : "Let's head back to the board!";
        }
        final box = context.findRenderObject() as RenderBox?;
        Offset toLocal(Offset g) =>
            box?.hasSize == true ? box!.globalToLocal(g) : g;

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final rects = target == null
                ? const <Rect>[]
                : context.targets
                      .rects(target)
                      .map(
                        (r) => Rect.fromPoints(
                          toLocal(r.topLeft),
                          toLocal(r.bottomRight),
                        ),
                      )
                      .toList();
            final size = MediaQuery.sizeOf(context);
            final focus = rects.isEmpty ? null : rects.first;
            final bubbleAtTop =
                focus != null && focus.center.dy > size.height * .5;
            final children = <Widget>[];

            if (step.advancesOnTap) {
              children.add(
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: game.tapTutorial,
                    child: const ColoredBox(color: Color(0x66231A35)),
                  ),
                ),
              );
            }

            for (final r in rects.take(2)) {
              final pulse = (sin(_c.value * pi * 2) + 1) / 2;
              children.add(
                Positioned.fromRect(
                  rect: r.inflate(4 + pulse * 4),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: .6 + .4 * pulse,
                          ),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.gold.withValues(alpha: .5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            if (focus != null) {
              // Hand either taps the target or drags from the first to the second.
              final Offset handAt;
              if (rects.length >= 2) {
                final t = Curves.easeInOut.transform(
                  (_c.value * 1.4).clamp(0.0, 1.0),
                );
                handAt = Offset.lerp(rects[0].center, rects[1].center, t)!;
              } else {
                handAt = focus.center + Offset(0, sin(_c.value * pi * 2) * 6);
              }
              children.add(
                Positioned(
                  left: handAt.dx - 6,
                  top: handAt.dy - 2,
                  child: const IgnorePointer(
                    child: Icon(
                      Icons.touch_app,
                      size: 48,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0xAA231A35),
                          blurRadius: 6,
                          offset: Offset(1, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            children.add(
              Positioned(
                left: 12,
                right: 12,
                top: bubbleAtTop
                    ? MediaQuery.paddingOf(context).top + 150
                    : null,
                bottom: bubbleAtTop
                    ? null
                    : MediaQuery.paddingOf(context).bottom + 96,
                child: Center(
                  child: ConstrainedBox(
                    // Stay within the phone-width game column on tablets.
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: _Bubble(
                      name: character.name,
                      text: text,
                      portrait: CustomPaint(
                        size: const Size.square(52),
                        painter: CharacterPainter(character),
                      ),
                      tapHint: step.advancesOnTap,
                      onTap: step.advancesOnTap ? game.tapTutorial : null,
                    ),
                  ),
                ),
              ),
            );

            return Stack(children: children);
          },
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.name,
    required this.text,
    required this.portrait,
    required this.tapHint,
    this.onTap,
  });

  final String name;
  final String text;
  final Widget portrait;
  final bool tapHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.all(12),
      decoration: panelDecoration(
        color: Colors.white,
        radius: 18,
      ).copyWith(border: Border.all(color: Palette.accent, width: 2.5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          portrait,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Palette.accent,
                  ),
                ),
                Text(text, style: const TextStyle(fontSize: 15, height: 1.25)),
                if (tapHint)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tap to continue',
                      style: TextStyle(fontSize: 12, color: Palette.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return IgnorePointer(child: bubble);
    return GestureDetector(onTap: onTap, child: bubble);
  }
}

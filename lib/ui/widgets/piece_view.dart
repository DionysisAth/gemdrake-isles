import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../model/game_state.dart';
import '../../model/item_ref.dart';
import '../painters/board_painters.dart';
import '../painters/dragon_painter.dart';
import '../painters/item_painter.dart';

class ItemIcon extends StatelessWidget {
  const ItemIcon(
    this.ref, {
    super.key,
    this.size = 40,
    this.silhouette = false,
  });

  final ItemRef ref;
  final double size;
  final bool silhouette;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: ItemPainter(ref, silhouette: silhouette),
    ),
  );
}

class DragonIcon extends StatelessWidget {
  const DragonIcon({
    super.key,
    required this.type,
    required this.level,
    this.size = 56,
    this.flap = 0,
    this.silhouette = false,
  });

  final DragonTypeDef type;
  final int level;
  final double size;
  final double flap;
  final bool silhouette;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: DragonPainter(
      type: type,
      level: level,
      flap: flap,
      silhouette: silhouette,
    ),
  );
}

/// A piece as drawn on the board: item art, or a generator with its charge
/// ring / cooldown overlay.
class PieceView extends StatelessWidget {
  const PieceView({
    super.key,
    required this.piece,
    required this.config,
    required this.size,
    this.cooldownFraction,
    this.requested = false,
  });

  final Piece piece;
  final GameConfig config;
  final double size;

  /// For generators: fraction of cooldown remaining (null when charged).
  final double? cooldownFraction;

  /// Shows a check badge when an order wants this item.
  final bool requested;

  @override
  Widget build(BuildContext context) {
    if (piece.isGenerator) {
      final def = config.generator(piece.generatorId!);
      final max_ = def.level(piece.genLevel).charges;
      return SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: GeneratorPainter(
                    def.style,
                    piece.genLevel,
                    dim: cooldownFraction != null,
                  ),
                ),
              ),
            ),
            if (cooldownFraction != null)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(size * .18),
                  child: CircularProgressIndicator(
                    value: 1 - cooldownFraction!,
                    strokeWidth: 4,
                    backgroundColor: Colors.white54,
                    color: const Color(0xFF8E5CF7),
                  ),
                ),
              )
            else
              Positioned(
                right: -2,
                bottom: -2,
                child: _Badge(
                  text: '${piece.charges}',
                  color: piece.charges <= max(2, max_ ~/ 5)
                      ? const Color(0xFFFF8A3D)
                      : const Color(0xFF3FA7F5),
                  size: size,
                ),
              ),
          ],
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * .04),
              child: ItemIcon(piece.item!, size: size),
            ),
          ),
          if (requested)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: size * .3,
                height: size * .3,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CBF6B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(Icons.check, size: size * .22, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.size});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: max(9, size * .2),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Makes a newly created piece pop in (and optionally fly in from a
/// generator).
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.from = Offset.zero});

  final Widget child;

  /// Start offset relative to the final position.
  final Offset from;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  // Captured once: later rebuilds must not restart or cut the fly-in.
  late final Offset _from = widget.from;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _from == Offset.zero ? 380 : 420),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = _c.value;
      final move = Curves.easeOutCubic.transform(t);
      final pos = Offset.lerp(_from, Offset.zero, move)!;
      // Arc upward while flying out of a generator.
      final arc = _from == Offset.zero ? 0.0 : -sin(t * pi) * 24;
      final scale = Curves.elasticOut.transform(t);
      return Transform.translate(
        offset: pos + Offset(0, arc),
        child: Transform.scale(scale: .2 + .8 * scale, child: child),
      );
    },
    child: widget.child,
  );
}

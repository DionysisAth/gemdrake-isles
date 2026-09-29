import 'dart:math';

import 'package:flutter/material.dart';

import 'extra_generator_painters.dart';
import 'item_painter.dart';
import 'nature_shapes.dart';

/// Generators: the Crystal Mine and the Seed Basket. Higher generator
/// levels get a golden rim.
class GeneratorPainter extends CustomPainter {
  GeneratorPainter(this.style, this.level, {this.dim = false});

  final String style;
  final int level;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, s * .025)
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0x66301E4F);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * .5, s * .88),
        width: s * .8,
        height: s * .12,
      ),
      Paint()..color = Colors.black.withValues(alpha: .18),
    );
    switch (style) {
      case 'basket':
        _basket(canvas, s, stroke);
      case 'forge':
        paintForge(canvas, s, stroke);
      case 'tidepool':
        paintTidePool(canvas, s, stroke);
      case 'cavern':
        paintCavern(canvas, s, stroke);
      case 'starwell':
        paintStarWell(canvas, s, stroke);
      case 'blossomtree':
        paintBlossomTree(canvas, s, stroke);
      case 'lanternstall':
        paintLanternStall(canvas, s, stroke);
      default:
        _mine(canvas, s, stroke);
    }
    if (level > 1) {
      for (var i = 0; i < level - 1; i++) {
        final o = Offset(s * (.14 + i * .12), s * .14);
        paintSparkle(canvas, o, s * .06, const Color(0xFFFFD54F));
      }
    }
    if (dim) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, s, s),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..blendMode = BlendMode.srcATop,
      );
    }
    canvas.restore();
  }

  void _mine(Canvas c, double s, Paint stroke) {
    // Rocky mound with a cave mouth and crystals.
    final rock = Path()
      ..moveTo(s * .08, s * .88)
      ..quadraticBezierTo(s * .06, s * .5, s * .28, s * .3)
      ..quadraticBezierTo(s * .5, s * .12, s * .72, s * .3)
      ..quadraticBezierTo(s * .94, s * .5, s * .92, s * .88)
      ..close();
    c.drawPath(
      rock,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9A7C9), Color(0xFF6E5B83)],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
    );
    c.drawPath(rock, stroke);
    final cave = Path()
      ..moveTo(s * .34, s * .88)
      ..quadraticBezierTo(s * .34, s * .52, s * .5, s * .52)
      ..quadraticBezierTo(s * .66, s * .52, s * .66, s * .88)
      ..close();
    c.drawPath(cave, Paint()..color = const Color(0xFF2E2340));
    paintGlow(c, Offset(s * .5, s * .8), s * .18, const Color(0xFF7FE7FF), .6);
    // Crystals poking out of the rock
    void crystal(Offset base, double h, double tilt, Color col) {
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(tilt);
      final p = Path()
        ..moveTo(0, -h)
        ..lineTo(h * .25, -h * .7)
        ..lineTo(h * .2, 0)
        ..lineTo(-h * .2, 0)
        ..lineTo(-h * .25, -h * .7)
        ..close();
      c.drawPath(p, Paint()..color = col);
      c.drawPath(p, stroke);
      c.restore();
    }

    crystal(Offset(s * .24, s * .5), s * .2, -.5, const Color(0xFF8FE3FF));
    crystal(Offset(s * .74, s * .44), s * .24, .45, const Color(0xFFD7A6FF));
    crystal(Offset(s * .52, s * .32), s * .18, .1, const Color(0xFF9DF5C4));
    // Wooden beams
    final beam = Paint()
      ..strokeWidth = s * .05
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9C6B3F);
    c.drawLine(Offset(s * .32, s * .88), Offset(s * .36, s * .54), beam);
    c.drawLine(Offset(s * .68, s * .88), Offset(s * .64, s * .54), beam);
    c.drawLine(Offset(s * .32, s * .54), Offset(s * .68, s * .54), beam);
  }

  void _basket(Canvas c, double s, Paint stroke) {
    // Sprouts peeking out
    final leaf = Paint()..color = const Color(0xFF5DBB63);
    for (final (x, a) in [(.34, -.5), (.5, 0.0), (.66, .5)]) {
      c.save();
      c.translate(s * x, s * .42);
      c.rotate(a);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(0, -s * .12),
          width: s * .12,
          height: s * .26,
        ),
        leaf,
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(0, -s * .12),
          width: s * .12,
          height: s * .26,
        ),
        stroke,
      );
      c.restore();
    }
    // Basket body
    final body = Path()
      ..moveTo(s * .14, s * .42)
      ..lineTo(s * .86, s * .42)
      ..lineTo(s * .76, s * .86)
      ..lineTo(s * .24, s * .86)
      ..close();
    c.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3C27A), Color(0xFFB9783A)],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
    );
    final weave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .02
      ..color = const Color(0x55603A10);
    for (var i = 1; i < 4; i++) {
      final y = s * (.42 + i * .11);
      c.drawLine(
        Offset(s * (.14 + i * .025), y),
        Offset(s * (.86 - i * .025), y),
        weave,
      );
    }
    for (var i = 1; i < 6; i++) {
      final x = s * (.14 + i * .12);
      c.drawLine(
        Offset(x, s * .42),
        Offset(s * .5 + (x - s * .5) * .8, s * .86),
        weave,
      );
    }
    c.drawPath(body, stroke);
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * .1, s * .36, s * .9, s * .46),
      Radius.circular(s * .05),
    );
    c.drawRRect(rim, Paint()..color = const Color(0xFFD89B55));
    c.drawRRect(rim, stroke);
    // Seeds
    for (final o in [Offset(s * .3, s * .38), Offset(s * .7, s * .37)]) {
      c.drawOval(
        Rect.fromCenter(center: o, width: s * .07, height: s * .1),
        Paint()..color = const Color(0xFF8D5A2B),
      );
    }
  }

  @override
  bool shouldRepaint(GeneratorPainter old) =>
      old.style != style || old.level != level || old.dim != dim;
}

/// Fog, cobwebs and rubble covering locked cells.
class LockPainter extends CustomPainter {
  LockPainter(this.type, this.hits);

  final String type;
  final int hits;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    switch (type) {
      case 'web':
        _web(canvas, size);
      case 'rubble':
        _rubble(canvas, size, s);
      default:
        _fog(canvas, size, s);
    }
  }

  void _fog(Canvas c, Size size, double s) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s * .2),
    );
    c.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1EEFF), Color(0xFFC9C0EA)],
        ).createShader(Offset.zero & size),
    );
    // Shaded puffs: a darker underside, then the bright top.
    final shade = Paint()..color = const Color(0xFFB7AEDD);
    final puff = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.3, -.4),
        radius: .9,
        colors: [Colors.white, Color(0xFFE7E2FA)],
      ).createShader(Offset.zero & size);
    const puffs = [
      (.3, .46, .22),
      (.62, .38, .25),
      (.48, .64, .24),
      (.76, .66, .17),
      (.22, .7, .15),
    ];
    for (final (x, y, rad) in puffs) {
      c.drawCircle(
        Offset(size.width * x, size.height * y + s * .04),
        s * rad,
        shade,
      );
    }
    for (final (x, y, rad) in puffs) {
      c.drawCircle(Offset(size.width * x, size.height * y), s * rad, puff);
    }
    paintSparkle(
      c,
      Offset(size.width * .78, size.height * .22),
      s * .07,
      Colors.white,
    );
  }

  void _web(Canvas c, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    c.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: .18),
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: .85);
    final rad = size.shortestSide * .62;
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + .2;
      c.drawLine(center, center + Offset(cos(a), sin(a)) * rad, p);
    }
    for (var ring = 1; ring <= 3; ring++) {
      final path = Path();
      for (var i = 0; i <= 8; i++) {
        final a = i * pi / 4 + .2;
        final pt = center + Offset(cos(a), sin(a)) * (rad * ring / 3.2);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      c.drawPath(path, p);
    }
  }

  void _rubble(Canvas c, Size size, double s) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s * .16),
    );
    c.drawRRect(r, Paint()..color = const Color(0xFFB9A58F));
    final rock1 = Paint()..color = const Color(0xFF8D7B69);
    final rock2 = Paint()..color = const Color(0xFFA8957F);
    final hl = Paint()..color = Colors.white.withValues(alpha: .25);
    for (final (x, y, w, h, paint) in [
      (.3, .62, .42, .3, rock1),
      (.68, .66, .4, .34, rock2),
      (.5, .36, .46, .34, rock2),
      (.24, .28, .26, .2, rock1),
    ]) {
      final o = Rect.fromCenter(
        center: Offset(size.width * x, size.height * y),
        width: s * w,
        height: s * h,
      );
      c.drawOval(o, paint);
      c.drawOval(
        Rect.fromLTWH(
          o.left + o.width * .2,
          o.top + o.height * .15,
          o.width * .35,
          o.height * .25,
        ),
        hl,
      );
    }
    if (hits > 1) {
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x88443322);
      c.drawPath(
        Path()
          ..moveTo(size.width * .4, size.height * .2)
          ..lineTo(size.width * .48, size.height * .4)
          ..lineTo(size.width * .42, size.height * .55),
        crack,
      );
    }
  }

  @override
  bool shouldRepaint(LockPainter old) => old.type != type || old.hits != hits;
}

/// Colors and decorations for the board, matching the island being
/// restored (meadow, volcano, lagoon, crystal peaks, shadow sky).
class BoardTheme {
  const BoardTheme({
    required this.style,
    required this.soil,
    required this.tileA,
    required this.tileB,
    required this.edge,
    required this.frame,
    required this.frameEdge,
    required this.accent,
    required this.decoLight,
    required this.decoDark,
    required this.blooms,
  });

  /// meadow, volcano, lagoon, crystal, shadow: picks the decorations.
  final String style;

  /// The groove between tiles.
  final Color soil;

  /// Tile face gradients (top, bottom) for the two checker colors.
  final List<Color> tileA;
  final List<Color> tileB;

  /// Bevel under each tile.
  final Color edge;

  /// Frame face gradient (top, middle, bottom) and its outline.
  final List<Color> frame;
  final Color frameEdge;

  /// Corner jewels and highlights.
  final List<Color> accent;
  final Color decoLight;
  final Color decoDark;
  final List<Color> blooms;

  static BoardTheme of(String id) => switch (id) {
    'volcano' => volcano,
    'lagoon' => lagoon,
    'crystal' => crystal,
    'shadow' => shadow,
    _ => meadow,
  };

  static const meadow = BoardTheme(
    style: 'meadow',
    soil: Color(0xFF79A85C),
    tileA: [Color(0xFFE6F7D2), Color(0xFFCBEAAD)],
    tileB: [Color(0xFFD2EDB7), Color(0xFFB5DE95)],
    edge: Color(0xFF8CBD6C),
    frame: [Color(0xFFDDA86C), Color(0xFFB07443), Color(0xFF85532F)],
    frameEdge: Color(0xFF5E3A22),
    accent: [Color(0xFFFFE9A8), Color(0xFFFFB52E), Color(0xFFC77D05)],
    decoLight: Color(0xFF9ED67C),
    decoDark: Color(0xFF6DB352),
    blooms: [Color(0xFFFFFFFF), Color(0xFFFF9EC6), Color(0xFFFFE066)],
  );

  static const volcano = BoardTheme(
    style: 'volcano',
    soil: Color(0xFF5A3A31),
    tileA: [Color(0xFFF6E0CC), Color(0xFFE8C6A8)],
    tileB: [Color(0xFFEDD0B6), Color(0xFFDDB493)],
    edge: Color(0xFFBF8E6E),
    frame: [Color(0xFF8A6358), Color(0xFF5C3D36), Color(0xFF3A2521)],
    frameEdge: Color(0xFF24150F),
    accent: [Color(0xFFFFF1A8), Color(0xFFFF9A2E), Color(0xFFD9481A)],
    decoLight: Color(0xFFC9A48C),
    decoDark: Color(0xFFA67D65),
    blooms: [Color(0xFFFF8A3D), Color(0xFFFFD166), Color(0xFFFF6A4D)],
  );

  static const lagoon = BoardTheme(
    style: 'lagoon',
    soil: Color(0xFFD9B77A),
    tileA: [Color(0xFFFFF7E0), Color(0xFFF6E4B8)],
    tileB: [Color(0xFFE2F7F1), Color(0xFFC4EDE3)],
    edge: Color(0xFFCCAA70),
    frame: [Color(0xFFEBD6B2), Color(0xFFC9A77A), Color(0xFF9E7D55)],
    frameEdge: Color(0xFF6E5436),
    accent: [Color(0xFFFFE3EC), Color(0xFFFF8FAB), Color(0xFFD9577A)],
    decoLight: Color(0xFFFFC7A8),
    decoDark: Color(0xFF7FD6CB),
    blooms: [Color(0xFFFF8FAB), Color(0xFFFFB74D), Color(0xFF80DEEA)],
  );

  static const crystal = BoardTheme(
    style: 'crystal',
    soil: Color(0xFF97A2D4),
    tileA: [Color(0xFFF7FAFF), Color(0xFFE2EBFB)],
    tileB: [Color(0xFFE9EEFF), Color(0xFFD2DCF7)],
    edge: Color(0xFFAAB5E0),
    frame: [Color(0xFFE3E1F7), Color(0xFFAEA8D6), Color(0xFF7A73A8)],
    frameEdge: Color(0xFF4F4880),
    accent: [Color(0xFFE8FDFF), Color(0xFF80DEEA), Color(0xFF3F8FD1)],
    decoLight: Color(0xFFFFFFFF),
    decoDark: Color(0xFFB6C6F0),
    blooms: [Color(0xFFD7A6FF), Color(0xFF80DEEA), Color(0xFFFFFFFF)],
  );

  static const shadow = BoardTheme(
    style: 'shadow',
    soil: Color(0xFF3A2D68),
    tileA: [Color(0xFFEAE2FF), Color(0xFFD3C7F7)],
    tileB: [Color(0xFFDCD0FA), Color(0xFFC2B3EF)],
    edge: Color(0xFF9483CF),
    frame: [Color(0xFF7A67C2), Color(0xFF4E3F96), Color(0xFF2E2360)],
    frameEdge: Color(0xFF1A1236),
    accent: [Color(0xFFD8FFF6), Color(0xFF80F5E0), Color(0xFF2EA895)],
    decoLight: Color(0xFFFFFFFF),
    decoDark: Color(0xFFA592E6),
    blooms: [Color(0xFF80F5E0), Color(0xFFFF8AD8), Color(0xFFFFF59D)],
  );
}

/// Bevelled checkerboard tiles behind the board, with small painted
/// touches (grass and flowers, pebbles, shells, frost, stars) that match
/// the island.
class BoardBackgroundPainter extends CustomPainter {
  BoardBackgroundPainter(
    this.cols,
    this.rows,
    this.cell, [
    this.theme = 'meadow',
  ]) : th = BoardTheme.of(theme);

  final int cols;
  final int rows;
  final double cell;
  final String theme;
  final BoardTheme th;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    // Groove between tiles
    canvas.drawRRect(
      RRect.fromRectAndRadius(all, Radius.circular(cell * .22)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(th.soil, Colors.black, .12)!, th.soil],
        ).createShader(all),
    );
    final rnd = Random(3);
    final gap = max(1.5, cell * .035);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final even = (x + y).isEven;
        final r = Rect.fromLTWH(
          x * cell + gap,
          y * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
        final radius = Radius.circular(cell * .2);
        final colors = even ? th.tileA : th.tileB;
        // Bevel: a darker base peeking out below the face
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, radius),
          Paint()..color = th.edge,
        );
        final face = RRect.fromRectAndRadius(
          Rect.fromLTRB(r.left, r.top, r.right, r.bottom - cell * .065),
          radius,
        );
        canvas.drawRRect(
          face,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ).createShader(r),
        );
        // Soft sheen on the upper left
        canvas.drawRRect(
          face,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.6, -.7),
              radius: .9,
              colors: [
                Colors.white.withValues(alpha: .45),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(r),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              r.left + cell * .14,
              r.top + cell * .04,
              r.width - cell * .28,
              cell * .05,
            ),
            Radius.circular(cell * .025),
          ),
          Paint()..color = Colors.white.withValues(alpha: .55),
        );
        if (rnd.nextDouble() < .5) {
          // Tuck the decoration into a lower corner, clear of the item.
          final left = rnd.nextBool();
          final o = Offset(
            left
                ? r.left + r.width * (.16 + rnd.nextDouble() * .08)
                : r.right - r.width * (.16 + rnd.nextDouble() * .08),
            r.top + r.height * (.74 + rnd.nextDouble() * .08),
          );
          _decorate(canvas, o, cell, rnd);
        }
      }
    }
    // Gentle vignette pulls the eye to the middle of the board
    canvas.drawRRect(
      RRect.fromRectAndRadius(all, Radius.circular(cell * .22)),
      Paint()
        ..shader = RadialGradient(
          radius: .75,
          colors: [
            Colors.transparent,
            Color.lerp(th.soil, Colors.black, .3)!.withValues(alpha: .16),
          ],
          stops: const [.6, 1],
        ).createShader(all),
    );
  }

  void _decorate(Canvas c, Offset o, double cell, Random rnd) {
    final s = cell * (.16 + rnd.nextDouble() * .05);
    final kind = rnd.nextInt(3);
    final bloom = th.blooms[rnd.nextInt(th.blooms.length)];
    switch (th.style) {
      case 'volcano':
        if (kind == 0) {
          // Glowing ember speck
          paintGlow(c, o, s * 1.3, const Color(0xFFFF8A3D), .45);
          c.drawCircle(o, s * .22, Paint()..color = const Color(0xFFFFC76B));
        } else {
          _pebbles(c, o, s);
        }
      case 'lagoon':
        if (kind == 0) {
          _starfish(c, o, s * .9, th.decoLight);
        } else if (kind == 1) {
          _shell(c, o, s, bloom);
        } else {
          _pebbles(c, o, s * .8);
        }
      case 'crystal':
        if (kind == 0) {
          _shards(c, o, s);
        } else {
          paintSparkle(c, o, s * .7, th.decoLight);
          paintSparkle(c, o + Offset(s * .8, -s * .6), s * .35, th.decoDark);
        }
      case 'shadow':
        if (kind == 0) {
          _mushroom(c, o, s, th.blooms[kind]);
        } else {
          paintSparkle(c, o, s * .6, th.decoDark);
          c.drawCircle(
            o + Offset(s * .7, -s * .5),
            s * .12,
            Paint()..color = th.decoLight.withValues(alpha: .8),
          );
        }
      default:
        if (kind == 0) {
          paintFlower(c, o, s * .6, bloom, const Color(0xFFFFC43D), o.dx);
        } else if (kind == 1) {
          paintTuft(c, o, s * 1.1, th.decoLight, th.decoDark, blades: 3);
        } else {
          // Clover
          for (var i = 0; i < 3; i++) {
            final a = -pi / 2 + i * pi * 2 / 3;
            c.drawCircle(
              o + Offset(cos(a), sin(a)) * s * .22,
              s * .22,
              Paint()..color = th.decoDark.withValues(alpha: .7),
            );
          }
        }
    }
  }

  void _pebbles(Canvas c, Offset o, double s) {
    for (final (dx, dy, r) in [(0.0, 0.0, .34), (.55, .12, .22)]) {
      final p = o + Offset(dx * s, dy * s);
      c.drawOval(
        Rect.fromCenter(center: p, width: s * r * 2.2, height: s * r * 1.5),
        Paint()..color = th.decoDark,
      );
      c.drawOval(
        Rect.fromCenter(
          center: p - Offset(s * r * .25, s * r * .25),
          width: s * r * 1.1,
          height: s * r * .6,
        ),
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
    }
  }

  void _starfish(Canvas c, Offset o, double s, Color col) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? s * .5 : s * .2;
      final a = -pi / 2 + i * pi / 5;
      final p = o + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), Paint()..color = col);
    c.drawCircle(
      o,
      s * .08,
      Paint()..color = Colors.white.withValues(alpha: .6),
    );
  }

  void _shell(Canvas c, Offset o, double s, Color col) {
    final shell = Path()
      ..moveTo(o.dx - s * .4, o.dy + s * .15)
      ..quadraticBezierTo(o.dx, o.dy - s * .75, o.dx + s * .4, o.dy + s * .15)
      ..quadraticBezierTo(o.dx, o.dy + s * .3, o.dx - s * .4, o.dy + s * .15)
      ..close();
    c.drawPath(shell, Paint()..color = col.withValues(alpha: .75));
    for (final dx in [-.18, 0.0, .18]) {
      c.drawOval(
        Rect.fromCenter(
          center: o + Offset(dx * s, -s * .1),
          width: s * .07,
          height: s * .4,
        ),
        Paint()..color = Colors.white.withValues(alpha: .45),
      );
    }
  }

  void _shards(Canvas c, Offset o, double s) {
    for (final (dx, hgt, lean) in [
      (-.25, .8, -.3),
      (0.0, 1.1, 0.0),
      (.25, .6, .35),
    ]) {
      final base = o + Offset(dx * s, 0);
      final tip = base + Offset(lean * s * .4, -s * hgt);
      final shard = Path()
        ..moveTo(base.dx - s * .12, base.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base.dx + s * .12, base.dy)
        ..close();
      c.drawPath(shard, Paint()..color = th.decoDark);
      c.drawPath(
        Path()
          ..moveTo(base.dx - s * .12, base.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(base.dx, base.dy)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: .8),
      );
    }
  }

  void _mushroom(Canvas c, Offset o, double s, Color glow) {
    paintGlow(c, o - Offset(0, s * .4), s * 1.1, glow, .35);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: o - Offset(0, s * .15),
          width: s * .2,
          height: s * .4,
        ),
        Radius.circular(s * .1),
      ),
      Paint()..color = th.decoLight.withValues(alpha: .9),
    );
    c.drawPath(
      Path()
        ..moveTo(o.dx - s * .4, o.dy - s * .3)
        ..quadraticBezierTo(o.dx, o.dy - s * .9, o.dx + s * .4, o.dy - s * .3)
        ..close(),
      Paint()..color = th.decoDark,
    );
    c.drawCircle(
      o + Offset(-s * .1, -s * .5),
      s * .07,
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
  }

  @override
  bool shouldRepaint(BoardBackgroundPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.cell != cell ||
      old.theme != theme;
}

/// The board's frame: a bevelled rim in the island's material (wood,
/// basalt, driftwood, frosted stone, twilight stone) with jewelled corners.
class BoardFramePainter extends CustomPainter {
  BoardFramePainter([this.theme = 'meadow']) : th = BoardTheme.of(theme);

  final String theme;
  final BoardTheme th;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(r, const Radius.circular(22));
    canvas.drawRRect(
      outer.shift(const Offset(0, 5)),
      Paint()
        ..color = const Color(0x55301E4F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(outer, Paint()..color = th.frameEdge);
    final face = outer.deflate(2);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: th.frame,
        ).createShader(r),
    );
    canvas.save();
    canvas.clipRRect(face);
    // Material texture
    final rnd = Random(9);
    if (th.style == 'meadow' || th.style == 'lagoon') {
      // Soft wood grain streaks
      for (var i = 0; i < 18; i++) {
        final y = size.height * rnd.nextDouble();
        final x0 = size.width * (rnd.nextDouble() - .2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x0,
              y,
              size.width * (.25 + rnd.nextDouble() * .4),
              1.6,
            ),
            const Radius.circular(1),
          ),
          Paint()..color = Colors.black.withValues(alpha: .1),
        );
      }
    } else {
      // Speckled stone
      for (var i = 0; i < 90; i++) {
        final o = Offset(
          size.width * rnd.nextDouble(),
          size.height * rnd.nextDouble(),
        );
        canvas.drawCircle(
          o,
          .8 + rnd.nextDouble() * 1.6,
          Paint()
            ..color = (rnd.nextBool() ? Colors.white : Colors.black).withValues(
              alpha: .12,
            ),
        );
      }
    }
    // Top bevel highlight and bottom shade
    canvas.drawRRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .5),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: .18),
          ],
          stops: const [0, .4, 1],
        ).createShader(r),
    );
    canvas.restore();
    // Inner recess with a soft inner shadow
    final inner = RRect.fromRectAndRadius(
      r.deflate(11),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      inner.inflate(2),
      Paint()..color = Color.lerp(th.frameEdge, th.frame[2], .4)!,
    );
    canvas.drawRRect(
      inner.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .25),
    );
    // Studs along the long sides
    final studs = max(1, (size.height / 130).floor());
    for (var i = 1; i <= studs; i++) {
      final y = size.height * i / (studs + 1);
      for (final x in [5.5, size.width - 5.5]) {
        _stud(canvas, Offset(x, y), 3);
      }
    }
    // Jewelled corners
    for (final (i, c) in [
      const Offset(8, 8),
      Offset(size.width - 8, 8),
      Offset(8, size.height - 8),
      Offset(size.width - 8, size.height - 8),
    ].indexed) {
      _corner(canvas, c, i);
    }
    // A garland of little themed touches along the top and bottom rails
    final count = max(2, (size.width / 70).floor());
    for (var i = 0; i < count; i++) {
      final x = size.width * (i + .5) / count;
      _garland(canvas, Offset(x, 5.5), i);
      _garland(canvas, Offset(x, size.height - 5.5), i + 1);
    }
  }

  void _garland(Canvas c, Offset o, int i) {
    switch (th.style) {
      case 'meadow':
        paintLeaf(
          c,
          o,
          pi + .25,
          11,
          const Color(0xFF9EDB6E),
          const Color(0xFF4F9E43),
        );
        paintLeaf(
          c,
          o,
          -.25,
          11,
          const Color(0xFF9EDB6E),
          const Color(0xFF4F9E43),
        );
        paintFlower(
          c,
          o,
          4.6,
          th.blooms[i % th.blooms.length],
          const Color(0xFFFFC43D),
          i * .6,
        );
      case 'lagoon':
        if (i.isEven) {
          final star = Path();
          for (var k = 0; k < 10; k++) {
            final r = k.isEven ? 6.0 : 2.6;
            final a = -pi / 2 + k * pi / 5 + i;
            final p = o + Offset(cos(a), sin(a)) * r;
            k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
          }
          c.drawPath(star..close(), Paint()..color = const Color(0xFFFF9E7A));
          c.drawCircle(
            o,
            1.3,
            Paint()..color = Colors.white.withValues(alpha: .7),
          );
        } else {
          c.drawCircle(o, 4, Paint()..color = const Color(0xFFFFF4F7));
          c.drawCircle(
            o - const Offset(1.2, 1.2),
            1.4,
            Paint()..color = Colors.white,
          );
          c.drawCircle(
            o,
            4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8
              ..color = const Color(0x55A07050),
          );
        }
      case 'crystal':
        for (final (dx, hgt, lean) in [
          (-3.0, 7.0, -.35),
          (0.0, 10.0, 0.0),
          (3.0, 6.0, .35),
        ]) {
          final base = o + Offset(dx, 3);
          final tip = base + Offset(lean * 6, -hgt);
          c.drawPath(
            Path()
              ..moveTo(base.dx - 2, base.dy)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(base.dx + 2, base.dy)
              ..close(),
            Paint()..color = const Color(0xFFBDEBFF),
          );
          c.drawPath(
            Path()
              ..moveTo(base.dx - 2, base.dy)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(base.dx, base.dy)
              ..close(),
            Paint()..color = Colors.white,
          );
        }
      case 'volcano':
        paintGlow(c, o, 9, const Color(0xFFFF8A3D), .7);
        c.drawPath(
          blobPath(o, 3.4, 2.2, 700 + i, lobes: 6),
          Paint()..color = const Color(0xFFFFC76B),
        );
      case 'shadow':
        paintGlow(c, o, 8, th.accent[1], .45);
        paintSparkle(
          c,
          o,
          5,
          i.isEven ? th.accent[0] : const Color(0xFFFFF59D),
        );
    }
  }

  void _stud(Canvas c, Offset o, double r) {
    c.drawCircle(
      o + const Offset(0, .8),
      r,
      Paint()..color = const Color(0x55000000),
    );
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.4),
          colors: th.accent,
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void _corner(Canvas c, Offset o, int i) {
    final left = i.isEven, top = i < 2;
    final out = Offset(left ? -1 : 1, top ? -1 : 1);
    switch (th.style) {
      case 'meadow':
        // A sprig of leaves behind the jewel
        for (final a in [-.5, .5]) {
          final dir = atan2(out.dy, out.dx) + pi + a;
          paintLeaf(
            c,
            o,
            dir,
            15,
            const Color(0xFF9EDB6E),
            const Color(0xFF4F9E43),
          );
        }
      case 'lagoon':
        paintLeaf(
          c,
          o,
          atan2(-out.dy, -out.dx) + .5,
          13,
          const Color(0xFF7FE0C8),
          const Color(0xFF2E9E8B),
        );
      case 'crystal':
        for (final a in [-.45, .45]) {
          final dir = atan2(-out.dy, -out.dx) + a;
          final d = Offset(cos(dir), sin(dir));
          final n = Offset(-d.dy, d.dx);
          c.drawPath(
            Path()
              ..moveTo(o.dx + n.dx * 3, o.dy + n.dy * 3)
              ..lineTo(o.dx + d.dx * 16, o.dy + d.dy * 16)
              ..lineTo(o.dx - n.dx * 3, o.dy - n.dy * 3)
              ..close(),
            Paint()..color = const Color(0xFFD7F4FF),
          );
        }
      case 'volcano':
        paintGlow(c, o, 16, const Color(0xFFFF8A3D), .6);
      case 'shadow':
        paintGlow(c, o, 14, th.accent[1], .5);
    }
    c.drawCircle(
      o + const Offset(0, 1.2),
      6.5,
      Paint()..color = const Color(0x66000000),
    );
    c.drawCircle(
      o,
      6.5,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.45),
          colors: th.accent,
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: o, radius: 6.5)),
    );
    c.drawCircle(
      o,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = th.frameEdge,
    );
    c.drawCircle(
      o + const Offset(-2, -2),
      1.8,
      Paint()..color = Colors.white.withValues(alpha: .85),
    );
  }

  @override
  bool shouldRepaint(BoardFramePainter old) => old.theme != theme;
}

enum CurrencyKind { coin, gem, energy, xp }

class CurrencyPainter extends CustomPainter {
  CurrencyPainter(this.kind);

  final CurrencyKind kind;

  static Path _star(Offset c, double outer, double inner, [int points = 5]) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / points;
      final pt = c + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;
    Paint line(Color color, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(.8, s * w)
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    switch (kind) {
      case CurrencyKind.coin:
        // Rim
        canvas.drawCircle(
          c,
          s * .47,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE27A), Color(0xFFC77D05)],
            ).createShader(rect),
        );
        // Face
        canvas.drawCircle(
          c,
          s * .38,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.35, -.4),
              radius: .9,
              colors: const [
                Color(0xFFFFF4B8),
                Color(0xFFFFCB2E),
                Color(0xFFE39A0C),
              ],
              stops: const [0, .5, 1],
            ).createShader(Rect.fromCircle(center: c, radius: s * .38)),
        );
        canvas.drawCircle(c, s * .38, line(const Color(0xFFB36B00), .035));
        // Embossed star
        final star = _star(c + Offset(0, s * .01), s * .21, s * .09);
        canvas.drawPath(
          star.shift(Offset(0, s * .025)),
          Paint()..color = const Color(0xFFC77D05),
        );
        canvas.drawPath(star, Paint()..color = const Color(0xFFFFE680));
        // Shine
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: s * .31),
          pi * 1.1,
          pi * .45,
          false,
          line(Colors.white.withValues(alpha: .8), .05)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(c, s * .47, line(const Color(0xFF8A5200), .04));
      case CurrencyKind.gem:
        final top = c.dy - s * .3, mid = c.dy - s * .07, bot = c.dy + s * .45;
        final l = c.dx - s * .47, r = c.dx + s * .47;
        final tl = c.dx - s * .25, tr = c.dx + s * .25;
        final outline = Path()
          ..moveTo(tl, top)
          ..lineTo(tr, top)
          ..lineTo(r, mid)
          ..lineTo(c.dx, bot)
          ..lineTo(l, mid)
          ..close();
        canvas.drawPath(
          outline,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFA8DA), Color(0xFFE0247A), Color(0xFF8E0F4F)],
            ).createShader(rect),
        );
        // Crown facets
        void facet(List<Offset> pts, Color color) => canvas.drawPath(
          Path()..addPolygon(pts, true),
          Paint()..color = color,
        );
        final a = c.dx - s * .1, b = c.dx + s * .1;
        facet([
          Offset(tl, top),
          Offset(a, top),
          Offset(c.dx - s * .2, mid),
          Offset(l, mid),
        ], const Color(0xFFFFC9E6));
        facet([
          Offset(a, top),
          Offset(b, top),
          Offset(c.dx + s * .2, mid),
          Offset(c.dx - s * .2, mid),
        ], const Color(0xFFFFE6F3));
        facet([
          Offset(b, top),
          Offset(tr, top),
          Offset(r, mid),
          Offset(c.dx + s * .2, mid),
        ], const Color(0xFFFF7CC0));
        // Pavilion facets
        facet([
          Offset(l, mid),
          Offset(c.dx - s * .2, mid),
          Offset(c.dx, bot),
        ], const Color(0xFFFF6FB5));
        facet([
          Offset(c.dx + s * .2, mid),
          Offset(r, mid),
          Offset(c.dx, bot),
        ], const Color(0xFFB5145F));
        canvas.drawPath(outline, line(const Color(0xFF6B0A3A), .045));
        canvas.drawLine(
          Offset(l, mid),
          Offset(r, mid),
          line(const Color(0x886B0A3A), .025),
        );
        paintSparkle(canvas, Offset(c.dx - s * .2, top + s * .08), s * .13);
      case CurrencyKind.energy:
        canvas.drawCircle(
          c,
          s * .47,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.3, -.4),
              colors: const [
                Color(0xFF9ED8FF),
                Color(0xFF3FA7F5),
                Color(0xFF1666C4),
              ],
              stops: const [0, .55, 1],
            ).createShader(rect),
        );
        canvas.drawCircle(
          c,
          s * .47,
          line(Colors.white.withValues(alpha: .9), .05),
        );
        final bolt = Path()
          ..moveTo(c.dx + s * .08, c.dy - s * .37)
          ..lineTo(c.dx - s * .22, c.dy + s * .05)
          ..lineTo(c.dx - s * .01, c.dy + s * .05)
          ..lineTo(c.dx - s * .1, c.dy + s * .37)
          ..lineTo(c.dx + s * .22, c.dy - s * .07)
          ..lineTo(c.dx + s * .01, c.dy - s * .07)
          ..close();
        canvas.drawPath(
          bolt.shift(Offset(0, s * .03)),
          Paint()..color = const Color(0x55002A66),
        );
        canvas.drawPath(
          bolt,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF7B0), Color(0xFFFFD21F), Color(0xFFFFA000)],
            ).createShader(rect),
        );
        canvas.drawPath(bolt, line(const Color(0xFF9A5B00), .035));
      case CurrencyKind.xp:
        final star = _star(c, s * .5, s * .23);
        canvas.drawPath(
          star,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD6BDFF), Color(0xFF9C6BFF), Color(0xFF6A3FD0)],
            ).createShader(rect),
        );
        canvas.drawPath(
          _star(c + Offset(0, -s * .03), s * .3, s * .14),
          Paint()..color = Colors.white.withValues(alpha: .25),
        );
        canvas.drawPath(star, line(const Color(0xFF45208F), .05));
    }
  }

  @override
  bool shouldRepaint(CurrencyPainter old) => old.kind != kind;
}

class CurrencyIcon extends StatelessWidget {
  const CurrencyIcon(this.kind, {super.key, this.size = 22});

  final CurrencyKind kind;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: CurrencyPainter(kind));
}

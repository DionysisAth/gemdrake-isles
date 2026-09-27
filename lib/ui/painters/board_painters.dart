import 'dart:math';

import 'package:flutter/material.dart';

import 'item_painter.dart';

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
    if (style == 'basket') {
      _basket(canvas, s, stroke);
    } else {
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

/// Soft checkerboard grass tiles behind the board.
class BoardBackgroundPainter extends CustomPainter {
  BoardBackgroundPainter(this.cols, this.rows, this.cell);

  final int cols;
  final int rows;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    // Soil between tiles
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * .22)),
      Paint()..color = const Color(0xFF8FB872),
    );
    final rnd = Random(3);
    final tuft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.0, cell * .03)
      ..color = const Color(0x5539802F);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final even = (x + y).isEven;
        final r = Rect.fromLTWH(
          x * cell + 1.5,
          y * cell + 1.5,
          cell - 3,
          cell - 3,
        );
        final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * .2));
        // Darker bottom edge = bevel
        canvas.drawRRect(
          rr,
          Paint()
            ..color = even ? const Color(0xFFA9D48A) : const Color(0xFF9BCB7C),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(r.left, r.top, r.right, r.bottom - cell * .06),
            Radius.circular(cell * .2),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: even
                  ? const [Color(0xFFE6F6D2), Color(0xFFCDEBB1)]
                  : const [Color(0xFFD9F0C0), Color(0xFFBFE3A0)],
            ).createShader(r),
        );
        // Occasional grass tuft
        if (rnd.nextDouble() < .35) {
          final o = Offset(
            r.left + r.width * (.2 + rnd.nextDouble() * .6),
            r.top + r.height * (.55 + rnd.nextDouble() * .3),
          );
          final h = cell * .08;
          canvas.drawLine(o, o + Offset(-h * .5, -h), tuft);
          canvas.drawLine(o, o + Offset(0, -h * 1.3), tuft);
          canvas.drawLine(o, o + Offset(h * .5, -h), tuft);
        }
      }
    }
  }

  @override
  bool shouldRepaint(BoardBackgroundPainter old) =>
      old.cols != cols || old.rows != rows || old.cell != cell;
}

/// Wooden frame around the board with grain, a soft inner shadow and
/// corner studs.
class BoardFramePainter extends CustomPainter {
  const BoardFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(r, const Radius.circular(22));
    canvas.drawRRect(
      outer.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0x55301E4F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(outer, Paint()..color = const Color(0xFF6E4A33));
    final face = outer.deflate(2.5);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC9955F), Color(0xFFA06A40), Color(0xFF8A5A36)],
        ).createShader(r),
    );
    // Grain
    canvas.save();
    canvas.clipRRect(face);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x22000000);
    for (var i = 0; i < 14; i++) {
      final y = size.height * (i + .5) / 14;
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..quadraticBezierTo(size.width * .3, y + 4, size.width * .55, y - 2)
          ..quadraticBezierTo(size.width * .8, y - 6, size.width, y + 1),
        grain,
      );
    }
    // Top highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 3, size.width - 12, 5),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: .25),
    );
    canvas.restore();
    // Inner recess
    final inner = RRect.fromRectAndRadius(
      r.deflate(8),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      inner.inflate(1.5),
      Paint()..color = const Color(0xFF5A3A26),
    );
    // Corner studs
    for (final c in [
      const Offset(6, 6),
      Offset(size.width - 6, 6),
      Offset(6, size.height - 6),
      Offset(size.width - 6, size.height - 6),
    ]) {
      canvas.drawCircle(c, 5, Paint()..color = const Color(0xFFFFD166));
      canvas.drawCircle(
        c,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFB07A12),
      );
      canvas.drawCircle(
        c + const Offset(-1.3, -1.3),
        1.6,
        Paint()..color = Colors.white.withValues(alpha: .8),
      );
    }
  }

  @override
  bool shouldRepaint(BoardFramePainter old) => false;
}

enum CurrencyKind { coin, gem, energy, xp }

class CurrencyPainter extends CustomPainter {
  CurrencyPainter(this.kind);

  final CurrencyKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, s * .07)
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case CurrencyKind.coin:
        canvas.drawCircle(c, s * .46, Paint()..color = const Color(0xFFD99A0B));
        canvas.drawCircle(c, s * .4, Paint()..color = const Color(0xFFFFCB2E));
        canvas.drawCircle(c, s * .27, stroke..color = const Color(0xFFE8A70F));
        canvas.drawOval(
          Rect.fromCenter(
            center: c + Offset(-s * .12, -s * .16),
            width: s * .2,
            height: s * .12,
          ),
          Paint()..color = Colors.white.withValues(alpha: .6),
        );
      case CurrencyKind.gem:
        final p = Path()
          ..moveTo(c.dx - s * .26, c.dy - s * .3)
          ..lineTo(c.dx + s * .26, c.dy - s * .3)
          ..lineTo(c.dx + s * .46, c.dy - s * .08)
          ..lineTo(c.dx, c.dy + s * .44)
          ..lineTo(c.dx - s * .46, c.dy - s * .08)
          ..close();
        canvas.drawPath(
          p,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFFF9AD5), Color(0xFFE0247A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(Offset.zero & size),
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s * .26, c.dy - s * .3)
            ..lineTo(c.dx, c.dy - s * .08)
            ..lineTo(c.dx - s * .46, c.dy - s * .08)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: .4),
        );
        canvas.drawPath(p, stroke..color = const Color(0x66570030));
      case CurrencyKind.energy:
        canvas.drawCircle(c, s * .46, Paint()..color = const Color(0xFF3FA7F5));
        final bolt = Path()
          ..moveTo(c.dx + s * .06, c.dy - s * .34)
          ..lineTo(c.dx - s * .2, c.dy + s * .04)
          ..lineTo(c.dx - s * .01, c.dy + s * .04)
          ..lineTo(c.dx - s * .08, c.dy + s * .34)
          ..lineTo(c.dx + s * .2, c.dy - s * .06)
          ..lineTo(c.dx + s * .01, c.dy - s * .06)
          ..close();
        canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFE45C));
        canvas.drawPath(
          bolt,
          stroke
            ..strokeWidth = s * .04
            ..color = const Color(0x88A0660A),
        );
      case CurrencyKind.xp:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? s * .48 : s * .22;
          final a = -pi / 2 + i * pi / 5;
          final pt = c + Offset(cos(a), sin(a)) * r;
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF9C6BFF));
        canvas.drawPath(path, stroke..color = const Color(0xFF6A3FD0));
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

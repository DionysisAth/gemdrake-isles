import 'dart:math';

import 'package:flutter/material.dart';

import 'item_painter.dart';

/// The floating Meadow island. Every restoration task has an element with a
/// ruined and a restored look; [progress] (0 = ruined, 1 = restored) lets
/// the view animate the transformation.
class IslandPainter extends CustomPainter {
  IslandPainter({required this.progress, required this.time});

  final Map<String, double> progress;

  /// Seconds, for ambient animation (windmill, lanterns, shrine glow).
  final double time;

  double p(String element) => progress[element] ?? 0;

  late double w, h, u;
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x66301E4F);

  Offset at(double x, double y) => Offset(w * x, h * y);

  @override
  void paint(Canvas canvas, Size size) {
    w = size.width;
    h = size.height;
    u = min(w, h * 1.3) * .1;
    _stroke.strokeWidth = max(1.0, u * .05);

    _island(canvas);
    _river(canvas);
    _tower(canvas, at(.6, .42));
    _windmill(canvas, at(.82, .44));
    _shrine(canvas, at(.44, .47));
    _well(canvas, at(.2, .52));
    _shed(canvas, at(.74, .55));
    _bridge(canvas, at(.33, .6));
    _garden(canvas, at(.2, .64));
    _nest(canvas, at(.56, .66));
    _lanterns(canvas);
    _vines(canvas);
  }

  // ---------------------------------------------------------------------------

  void _island(Canvas c) {
    // Rocky underside
    final under = Path()
      ..moveTo(w * .04, h * .54)
      ..quadraticBezierTo(w * .12, h * .78, w * .34, h * .86)
      ..quadraticBezierTo(w * .46, h * .99, w * .54, h * .93)
      ..quadraticBezierTo(w * .74, h * .86, w * .86, h * .74)
      ..quadraticBezierTo(w * .96, h * .64, w * .96, h * .54)
      ..close();
    c.drawPath(
      under,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9C7A5B), Color(0xFF5E4638)],
        ).createShader(Rect.fromLTWH(0, h * .5, w, h * .5)),
    );
    // Strata lines
    final strata = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .06
      ..color = const Color(0x33000000);
    c.drawPath(
      Path()
        ..moveTo(w * .12, h * .66)
        ..quadraticBezierTo(w * .5, h * .78, w * .88, h * .66),
      strata,
    );
    c.drawPath(
      Path()
        ..moveTo(w * .3, h * .8)
        ..quadraticBezierTo(w * .5, h * .87, w * .72, h * .8),
      strata,
    );
    // Hanging roots & crystals
    final root = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .07
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6B8E4E);
    c.drawPath(
      Path()
        ..moveTo(w * .22, h * .76)
        ..quadraticBezierTo(w * .2, h * .84, w * .24, h * .9),
      root,
    );
    c.drawPath(
      Path()
        ..moveTo(w * .78, h * .76)
        ..quadraticBezierTo(w * .82, h * .82, w * .79, h * .88),
      root,
    );
    for (final (x, y, col) in [
      (.42, .9, const Color(0xFF8FE3FF)),
      (.62, .86, const Color(0xFFD7A6FF)),
    ]) {
      final o = at(x, y);
      final gem = Path()
        ..moveTo(o.dx - u * .15, o.dy)
        ..lineTo(o.dx + u * .15, o.dy)
        ..lineTo(o.dx, o.dy + u * .45)
        ..close();
      c.drawPath(gem, Paint()..color = col);
      c.drawPath(gem, _stroke);
    }
    c.drawPath(under, _stroke);

    // Grassy top
    final top = Rect.fromLTRB(w * .03, h * .34, w * .97, h * .72);
    final grass = Path()..addOval(top);
    final healthy = (progress.values.fold(0.0, (a, b) => a + b) / 10).clamp(
      0.0,
      1.0,
    );
    c.drawPath(
      grass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              const Color(0xFFC7C98A),
              const Color(0xFFA6E07A),
              healthy,
            )!,
            Color.lerp(
              const Color(0xFF9B9D5E),
              const Color(0xFF6FBF57),
              healthy,
            )!,
          ],
        ).createShader(top),
    );
    // Grass rim (kept inside the top surface)
    c.save();
    c.clipPath(grass);
    c.drawOval(
      Rect.fromLTRB(w * .03, h * .5, w * .97, h * .74),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .12
        ..color = Color.lerp(
          const Color(0xFF8C8A55),
          const Color(0xFF5AAE4A),
          healthy,
        )!,
    );
    c.restore();
    c.drawPath(grass, _stroke);
    // Tufts
    final tuft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .05
      ..color = Color.lerp(
        const Color(0xFF8E8C58),
        const Color(0xFF4F9E43),
        healthy,
      )!;
    for (final (x, y) in [
      (.12, .48),
      (.3, .42),
      (.52, .58),
      (.7, .4),
      (.88, .5),
      (.4, .66),
      (.8, .62),
    ]) {
      final o = at(x, y);
      c.drawLine(o, o + Offset(-u * .08, -u * .16), tuft);
      c.drawLine(o, o + Offset(0, -u * .2), tuft);
      c.drawLine(o, o + Offset(u * .08, -u * .16), tuft);
    }
  }

  void _river(Canvas c) {
    final river = Path()
      ..moveTo(w * .36, h * .36)
      ..quadraticBezierTo(w * .3, h * .5, w * .36, h * .58)
      ..quadraticBezierTo(w * .4, h * .66, w * .34, h * .72);
    c.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .55
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6CC7F0),
    );
    c.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .18
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .35),
    );
    // Waterfall off the edge
    final fall = at(.34, .72);
    c.drawRect(
      Rect.fromLTWH(fall.dx - u * .2, fall.dy, u * .4, h * .1),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF6CC7F0),
            const Color(0xFF6CC7F0).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(fall.dx, fall.dy, u, h * .1)),
    );
  }

  void _ruinStones(Canvas c, Offset base, double spread, double fade) {
    if (fade <= 0) return;
    final stone = Paint()
      ..color = const Color(0xFF9E9A94).withValues(alpha: fade);
    final dark = Paint()
      ..color = const Color(0xFF7A756E).withValues(alpha: fade);
    for (final (dx, dy, r) in [
      (-.5, 0.0, .2),
      (.3, .05, .24),
      (0.0, -.1, .18),
      (.6, -.05, .14),
      (-.2, .1, .12),
    ]) {
      c.drawOval(
        Rect.fromCenter(
          center: base + Offset(dx * u * spread, dy * u),
          width: r * u * 2.4,
          height: r * u * 1.6,
        ),
        dx > 0 ? stone : dark,
      );
    }
  }

  Paint _fade(Color color, double a) =>
      Paint()..color = color.withValues(alpha: color.a * a);

  void _tower(Canvas c, Offset b) {
    final t = p('tower');
    final height = u * (1.2 + 1.6 * t);
    final body = Rect.fromLTRB(
      b.dx - u * .45,
      b.dy - height,
      b.dx + u * .45,
      b.dy,
    );
    c.drawRect(
      body,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF9E9A94),
          const Color(0xFFE8DCC8),
          t,
        )!,
    );
    // Bricks
    final brick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .03
      ..color = const Color(0x33000000);
    for (var y = b.dy - u * .3; y > b.dy - height; y -= u * .3) {
      c.drawLine(Offset(body.left, y), Offset(body.right, y), brick);
    }
    // Door
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(b.dx - u * .15, b.dy - u * .45, b.dx + u * .15, b.dy),
        topLeft: Radius.circular(u * .15),
        topRight: Radius.circular(u * .15),
      ),
      Paint()..color = const Color(0xFF6D4C33),
    );
    if (t < 1) {
      // Broken jagged top
      final jag = Path()
        ..moveTo(body.left, body.top)
        ..lineTo(body.left + u * .2, body.top - u * .2)
        ..lineTo(body.left + u * .4, body.top + u * .05)
        ..lineTo(body.left + u * .65, body.top - u * .25)
        ..lineTo(body.right, body.top)
        ..close();
      c.drawPath(jag, _fade(const Color(0xFF9E9A94), 1 - t));
    }
    c.drawRect(body, _stroke);
    if (t > 0) {
      // Roof + window + flag
      final roof = Path()
        ..moveTo(body.left - u * .15, body.top)
        ..lineTo(b.dx, body.top - u * .7)
        ..lineTo(body.right + u * .15, body.top)
        ..close();
      c.drawPath(roof, _fade(const Color(0xFF5C7CFA), t));
      c.drawPath(
        roof,
        _fade(const Color(0x66301E4F), t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke.strokeWidth,
      );
      c.drawCircle(
        Offset(b.dx, body.top + u * .4),
        u * .14,
        _fade(const Color(0xFFFFE082), t),
      );
      final pole = Offset(b.dx, body.top - u * .7);
      c.drawLine(
        pole,
        pole - Offset(0, u * .4),
        _fade(const Color(0xFF6D4C33), t)..strokeWidth = u * .05,
      );
      final wave = sin(time * 3) * u * .05;
      c.drawPath(
        Path()
          ..moveTo(pole.dx, pole.dy - u * .4)
          ..quadraticBezierTo(
            pole.dx + u * .2,
            pole.dy - u * .35 + wave,
            pole.dx + u * .4,
            pole.dy - u * .32,
          )
          ..lineTo(pole.dx, pole.dy - u * .22)
          ..close(),
        _fade(const Color(0xFFFF6B8B), t),
      );
    }
  }

  void _windmill(Canvas c, Offset b) {
    final t = p('windmill');
    final body = Path()
      ..moveTo(b.dx - u * .4, b.dy)
      ..lineTo(b.dx - u * .25, b.dy - u * 1.4)
      ..lineTo(b.dx + u * .25, b.dy - u * 1.4)
      ..lineTo(b.dx + u * .4, b.dy)
      ..close();
    c.drawPath(
      body,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFA1887F),
          const Color(0xFFFFF3E0),
          t,
        )!,
    );
    c.drawPath(body, _stroke);
    final hub = Offset(b.dx, b.dy - u * 1.3);
    final angle = t * time * 0.8;
    final blade = Paint()
      ..color = Color.lerp(
        const Color(0xFF8D6E63),
        const Color(0xFFFFFFFF),
        t,
      )!;
    final blades = t > 0 ? 4 : 2; // ruined: two broken sails
    for (var i = 0; i < blades; i++) {
      final a = angle + i * pi / 2 + .3;
      final len = t > 0 ? u * .95 : u * .5;
      c.save();
      c.translate(hub.dx, hub.dy);
      c.rotate(a);
      final r = Rect.fromLTWH(u * .05, -u * .1, len, u * .2);
      c.drawRect(r, blade);
      c.drawRect(r, _stroke);
      c.restore();
    }
    c.drawCircle(hub, u * .1, Paint()..color = const Color(0xFF6D4C33));
  }

  void _shrine(Canvas c, Offset b) {
    final t = p('shrine');
    final ped = Rect.fromLTRB(
      b.dx - u * .45,
      b.dy - u * .35,
      b.dx + u * .45,
      b.dy,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(ped, Radius.circular(u * .08)),
      Paint()..color = const Color(0xFFBDB5C9),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(ped, Radius.circular(u * .08)),
      _stroke,
    );
    if (t <= 0) {
      // Cracked stub
      final stub = Path()
        ..moveTo(b.dx - u * .15, ped.top)
        ..lineTo(b.dx - u * .1, ped.top - u * .3)
        ..lineTo(b.dx + u * .05, ped.top - u * .18)
        ..lineTo(b.dx + u * .15, ped.top)
        ..close();
      c.drawPath(stub, Paint()..color = const Color(0xFF8E8699));
      c.drawPath(stub, _stroke);
      return;
    }
    final pulse = .6 + .25 * sin(time * 2);
    paintGlow(
      c,
      Offset(b.dx, ped.top - u * .6),
      u * (1.1 * t),
      const Color(0xFF9CF6FF),
      pulse * t,
    );
    final crystalH = u * 1.3 * t;
    final crystal = Path()
      ..moveTo(b.dx, ped.top - crystalH)
      ..lineTo(b.dx + u * .28, ped.top - crystalH * .7)
      ..lineTo(b.dx + u * .2, ped.top)
      ..lineTo(b.dx - u * .2, ped.top)
      ..lineTo(b.dx - u * .28, ped.top - crystalH * .7)
      ..close();
    c.drawPath(
      crystal,
      Paint()
        ..shader =
            const LinearGradient(
              colors: [Color(0xFFE0FDFF), Color(0xFF7C9CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(
              Rect.fromLTWH(
                b.dx - u * .3,
                ped.top - crystalH,
                u * .6,
                crystalH,
              ),
            ),
    );
    c.drawPath(crystal, _stroke);
    paintSparkle(c, Offset(b.dx + u * .35, ped.top - crystalH), u * .12 * t);
  }

  void _well(Canvas c, Offset b) {
    final t = p('well');
    _ruinStones(c, b, 1.2, 1 - t);
    if (t <= 0) return;
    final base = Rect.fromCenter(
      center: b - Offset(0, u * .2),
      width: u * .9,
      height: u * .45,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(u * .1)),
      _fade(const Color(0xFFB0A89C), t),
    );
    c.drawOval(
      Rect.fromCenter(center: base.topCenter, width: u * .9, height: u * .25),
      _fade(const Color(0xFF4FC3F7), t),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(u * .1)),
      _stroke,
    );
    final post = _fade(const Color(0xFF8D6E63), t)..strokeWidth = u * .07;
    c.drawLine(
      base.topLeft + Offset(u * .08, 0),
      base.topLeft + Offset(u * .08, -u * .6),
      post,
    );
    c.drawLine(
      base.topRight - Offset(u * .08, 0),
      base.topRight + Offset(-u * .08, -u * .6),
      post,
    );
    final roof = Path()
      ..moveTo(base.left - u * .1, base.top - u * .55)
      ..lineTo(b.dx, base.top - u * .95)
      ..lineTo(base.right + u * .1, base.top - u * .55)
      ..close();
    c.drawPath(roof, _fade(const Color(0xFFE57373), t));
  }

  void _shed(Canvas c, Offset b) {
    final t = p('shed');
    if (t < 1) {
      final plank = _fade(const Color(0xFF8D6E63), 1 - t)
        ..strokeWidth = u * .1
        ..strokeCap = StrokeCap.round;
      c.drawLine(b + Offset(-u * .5, 0), b + Offset(u * .3, -u * .2), plank);
      c.drawLine(
        b + Offset(-u * .2, -u * .05),
        b + Offset(u * .5, u * .02),
        plank,
      );
      c.drawLine(
        b + Offset(-u * .1, -u * .3),
        b + Offset(u * .2, u * .05),
        plank,
      );
    }
    if (t <= 0) return;
    final body = Rect.fromLTRB(
      b.dx - u * .5,
      b.dy - u * .65 * t,
      b.dx + u * .5,
      b.dy,
    );
    c.drawRect(body, _fade(const Color(0xFFD7A86E), t));
    c.drawRect(
      Rect.fromLTRB(b.dx - u * .15, b.dy - u * .4 * t, b.dx + u * .15, b.dy),
      _fade(const Color(0xFF8D5A2B), t),
    );
    final roof = Path()
      ..moveTo(body.left - u * .12, body.top)
      ..lineTo(b.dx, body.top - u * .45 * t)
      ..lineTo(body.right + u * .12, body.top)
      ..close();
    c.drawPath(roof, _fade(const Color(0xFFD9534F), t));
    c.drawRect(body, _stroke);
  }

  void _bridge(Canvas c, Offset b) {
    final t = p('bridge');
    final plank = Paint()..color = const Color(0xFFB0835A);
    final span = u * 1.3;
    if (t < 1) {
      // Broken plank stubs on both banks
      final broken = _fade(const Color(0xFF8D6E63), 1 - t);
      c.drawRect(
        Rect.fromLTWH(b.dx - span / 2, b.dy - u * .08, u * .3, u * .16),
        broken,
      );
      c.drawRect(
        Rect.fromLTWH(
          b.dx + span / 2 - u * .3,
          b.dy - u * .08,
          u * .25,
          u * .16,
        ),
        broken,
      );
    }
    if (t <= 0) return;
    final arch = Path()
      ..moveTo(b.dx - span / 2, b.dy)
      ..quadraticBezierTo(b.dx, b.dy - u * .5 * t, b.dx + span / 2, b.dy);
    c.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .25
        ..color = plank.color.withValues(alpha: t),
    );
    c.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .04
        ..color = const Color(0x55301E4F).withValues(alpha: .4 * t),
    );
    final rail = Path()
      ..moveTo(b.dx - span / 2, b.dy - u * .3)
      ..quadraticBezierTo(
        b.dx,
        b.dy - u * .8 * t,
        b.dx + span / 2,
        b.dy - u * .3,
      );
    c.drawPath(
      rail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .06
        ..color = const Color(0xFF7A4B2A).withValues(alpha: t),
    );
  }

  void _garden(Canvas c, Offset b) {
    final t = p('garden');
    final bed = Rect.fromCenter(center: b, width: u * 1.5, height: u * .6);
    c.drawOval(
      bed,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFA1887F),
          const Color(0xFF8D6E63),
          t,
        )!,
    );
    if (t <= 0) {
      // Dry twigs
      final twig = Paint()
        ..strokeWidth = u * .04
        ..color = const Color(0xFF6D4C41);
      c.drawLine(b + Offset(-u * .3, 0), b + Offset(-u * .2, -u * .25), twig);
      c.drawLine(
        b + Offset(u * .2, u * .05),
        b + Offset(u * .3, -u * .2),
        twig,
      );
      return;
    }
    final colors = [
      const Color(0xFFFF6B8B),
      const Color(0xFFFFD54F),
      const Color(0xFFBA68C8),
      const Color(0xFF4FC3F7),
    ];
    var i = 0;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 4; col++) {
        final o = b + Offset((col - 1.5) * u * .32, (row - .5) * u * .25);
        final sway = sin(time * 2 + i) * u * .02;
        c.drawLine(
          o,
          o + Offset(sway, -u * .25 * t),
          Paint()
            ..strokeWidth = u * .04
            ..color = const Color(0xFF4F9E43),
        );
        c.drawCircle(
          o + Offset(sway, -u * .28 * t),
          u * .1 * t,
          Paint()..color = colors[i % colors.length],
        );
        c.drawCircle(
          o + Offset(sway, -u * .28 * t),
          u * .04 * t,
          Paint()..color = const Color(0xFFFFF59D),
        );
        i++;
      }
    }
  }

  void _nest(Canvas c, Offset b) {
    final t = p('nest');
    final stick = Paint()
      ..strokeWidth = u * .07
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8D6E63);
    if (t < 1) {
      stick.color = stick.color.withValues(alpha: 1 - t);
      c.drawLine(b + Offset(-u * .5, 0), b + Offset(-u * .1, -u * .1), stick);
      c.drawLine(
        b + Offset(u * .1, u * .05),
        b + Offset(u * .45, -u * .05),
        stick,
      );
      c.drawLine(
        b + Offset(-u * .2, u * .1),
        b + Offset(u * .2, u * .12),
        stick,
      );
    }
    if (t <= 0) return;
    final nest = Rect.fromCenter(
      center: b,
      width: u * 1.4 * t,
      height: u * .6 * t,
    );
    c.drawOval(nest, Paint()..color = const Color(0xFF9C7A54));
    c.drawOval(
      nest.deflate(u * .12 * t),
      Paint()..color = const Color(0xFF6D5238),
    );
    c.drawOval(nest, _stroke);
    for (final (dx, col) in [
      (-.25, const Color(0xFFFFF4DC)),
      (.05, const Color(0xFFD7FFF3)),
      (.3, const Color(0xFFFFE9B0)),
    ]) {
      c.drawOval(
        Rect.fromCenter(
          center: b + Offset(dx * u, -u * .12 * t),
          width: u * .25 * t,
          height: u * .32 * t,
        ),
        Paint()..color = col,
      );
    }
  }

  void _lanterns(Canvas c) {
    final t = p('lanterns');
    for (final (x, y) in [(.1, .56), (.47, .62), (.9, .56), (.66, .5)]) {
      final base = at(x, y);
      c.drawLine(
        base,
        base - Offset(0, u * .8),
        Paint()
          ..strokeWidth = u * .06
          ..color = const Color(0xFF5D4037),
      );
      final lamp = base - Offset(0, u * .85);
      if (t > 0) {
        final flicker = .75 + .2 * sin(time * 5 + x * 10);
        paintGlow(c, lamp, u * .6, const Color(0xFFFFD54F), flicker * t);
      }
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: lamp, width: u * .22, height: u * .28),
          Radius.circular(u * .06),
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF616161),
            const Color(0xFFFFE082),
            t,
          )!,
      );
    }
  }

  void _vines(Canvas c) {
    final t = 1 - p('vines');
    if (t <= 0) return;
    final vine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4E5F2E).withValues(alpha: t);
    final thorn = Paint()..color = const Color(0xFF3B4A22).withValues(alpha: t);
    for (final pts in [
      [(.08, .5), (.2, .42), (.3, .56), (.42, .46), (.5, .6)],
      [(.5, .4), (.62, .56), (.74, .46), (.86, .6), (.94, .5)],
      [(.2, .66), (.36, .6), (.5, .7), (.66, .62), (.8, .68)],
    ]) {
      final path = Path()..moveTo(w * pts[0].$1, h * pts[0].$2);
      for (var i = 1; i < pts.length; i++) {
        final prev = at(pts[i - 1].$1, pts[i - 1].$2);
        final cur = at(pts[i].$1, pts[i].$2);
        final mid = (prev + cur) / 2 + Offset(0, -u * .4);
        path.quadraticBezierTo(mid.dx, mid.dy, cur.dx, cur.dy);
        c.drawCircle(mid + Offset(0, u * .2), u * .08, thorn);
      }
      c.drawPath(path, vine);
    }
  }

  @override
  bool shouldRepaint(IslandPainter old) => true;
}

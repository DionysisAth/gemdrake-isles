import 'dart:math';

import 'package:flutter/material.dart';

import 'island_theme.dart';
import 'item_painter.dart';

/// A floating island. Every restoration task has an element with a ruined
/// and a restored look; [progress] (0 = ruined, 1 = restored) lets the view
/// animate the transformation. [theme] picks the island's palette/style.
class IslandPainter extends CustomPainter {
  IslandPainter({
    required this.progress,
    required this.time,
    this.theme = 'meadow',
  }) : th = IslandTheme.of(theme);

  final String theme;
  final IslandTheme th;

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

  /// Overall restoration, 0..1: drives greenery, flowers and trees.
  late double healthy;

  @override
  void paint(Canvas canvas, Size size) {
    w = size.width;
    h = size.height;
    u = min(w, h * 1.3) * .1;
    _stroke.strokeWidth = max(1.0, u * .05);
    healthy = (progress.values.fold(0.0, (a, b) => a + b) / 10).clamp(0.0, 1.0);

    _backdrop(canvas);
    canvas.save();
    // The whole island gently floats up and down.
    canvas.translate(0, sin(time * .9) * h * .01);
    _floatingRocks(canvas, back: true);
    _island(canvas);
    _river(canvas);
    _path(canvas);
    _trees(canvas, back: true);
    _tower(canvas, at(.6, .42));
    _windmill(canvas, at(.82, .44));
    _shrine(canvas, at(.44, .47));
    _well(canvas, at(.2, .52));
    _shed(canvas, at(.74, .55));
    _bridge(canvas, at(.33, .6));
    _garden(canvas, at(.2, .64));
    _nest(canvas, at(.56, .66));
    _trees(canvas, back: false);
    _lanterns(canvas);
    _vines(canvas);
    _ambient(canvas);
    _themeAmbient(canvas);
    _floatingRocks(canvas, back: false);
    canvas.restore();
  }

  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Backdrop, island body, water and scenery

  void _backdrop(Canvas c) {
    if (th.sky.first.a > 0) {
      final r = Rect.fromLTWH(-w, -h, w * 3, h * 3);
      c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: th.sky,
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
    }
    final center = at(.5, .5);
    // Slowly turning sun rays behind the island.
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(time * .02);
    final ray = Paint()..color = Colors.white.withValues(alpha: .09);
    final r = max(w, h) * .9;
    for (var i = 0; i < 14; i++) {
      final a = i * pi * 2 / 14;
      c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(cos(a - .09) * r, sin(a - .09) * r)
          ..lineTo(cos(a + .09) * r, sin(a + .09) * r)
          ..close(),
        ray,
      );
    }
    c.restore();
    paintGlow(c, at(.5, .52), w * .62, th.glow, .55);
  }

  bool _insideTop(Offset p) {
    final cx = w * .5, cy = h * .52, rx = w * .47, ry = h * .19;
    final dx = (p.dx - cx) / rx, dy = (p.dy - cy) / ry;
    return dx * dx + dy * dy < .82;
  }

  void _island(Canvas c) {
    // Rocky underside
    final under = Path()
      ..moveTo(w * .04, h * .54)
      ..quadraticBezierTo(w * .1, h * .8, w * .32, h * .87)
      ..quadraticBezierTo(w * .44, h * 1.0, w * .52, h * .95)
      ..quadraticBezierTo(w * .74, h * .88, w * .87, h * .74)
      ..quadraticBezierTo(w * .97, h * .64, w * .96, h * .54)
      ..close();
    final underBox = Rect.fromLTWH(0, h * .5, w, h * .5);
    c.drawPath(
      under,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: th.rock,
          stops: const [0, .45, 1],
        ).createShader(underBox),
    );
    c.save();
    c.clipPath(under);
    // Layered strata
    for (final (y, dark, amp) in [
      (.6, false, .02),
      (.68, true, .03),
      (.76, false, .025),
      (.84, true, .02),
    ]) {
      final band = Path()
        ..moveTo(0, h * y)
        ..quadraticBezierTo(w * .25, h * (y + amp), w * .5, h * y)
        ..quadraticBezierTo(w * .75, h * (y - amp), w, h * y)
        ..lineTo(w, h * (y + .03))
        ..quadraticBezierTo(w * .75, h * (y + .03 - amp), w * .5, h * (y + .03))
        ..quadraticBezierTo(w * .25, h * (y + .03 + amp), 0, h * (y + .03))
        ..close();
      c.drawPath(
        band,
        Paint()
          ..color = dark ? const Color(0x22000000) : const Color(0x33FFE2BD),
      );
    }
    // Lit left faces
    c.drawPath(
      Path()
        ..moveTo(w * .06, h * .56)
        ..lineTo(w * .2, h * .6)
        ..lineTo(w * .26, h * .8)
        ..lineTo(w * .14, h * .74)
        ..close(),
      Paint()..color = const Color(0x22FFFFFF),
    );
    c.restore();

    // Glowing crystal clusters in the rock
    void cluster(Offset o, double s, Color col, double tilt) {
      paintGlow(c, o, u * s * 1.4, col, .55 + .15 * sin(time * 2 + o.dx));
      for (final (dx, hgt, t) in [
        (-.18, .7, -.35),
        (0.0, 1.0, 0.0),
        (.18, .6, .35),
      ]) {
        c.save();
        c.translate(o.dx + dx * u * s, o.dy);
        c.rotate(tilt + t);
        final hh = u * s * hgt;
        final crystal = Path()
          ..moveTo(0, hh)
          ..lineTo(u * s * .12, hh * .3)
          ..lineTo(0, -u * s * .05)
          ..lineTo(-u * s * .12, hh * .3)
          ..close();
        c.drawPath(crystal, Paint()..color = col);
        c.drawPath(
          Path()
            ..moveTo(0, hh)
            ..lineTo(-u * s * .12, hh * .3)
            ..lineTo(0, -u * s * .05)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: .35),
        );
        c.drawPath(crystal, _stroke);
        c.restore();
      }
    }

    cluster(at(.47, .93), 1.0, th.crystals[0], 0);
    cluster(at(.66, .86), .7, th.crystals[1], -.2);
    cluster(at(.25, .8), .55, th.crystals[2], .25);

    // Hanging vines with leaves
    final vine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .05
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(th.leafRuined[1], th.leafHealthy[1], healthy)!;
    final leaf = Paint()
      ..color = Color.lerp(th.leafRuined[0], th.leafHealthy[0], healthy)!;
    for (final (x, y, len) in [
      (.16, .7, .14),
      (.3, .8, .1),
      (.72, .8, .12),
      (.84, .72, .15),
    ]) {
      final sway = sin(time * 1.4 + x * 9) * u * .12;
      final start = at(x, y);
      final end = start + Offset(sway, h * len);
      c.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            start.dx - u * .1,
            (start.dy + end.dy) / 2,
            end.dx,
            end.dy,
          ),
        vine,
      );
      for (var k = 1; k <= 3; k++) {
        final t = k / 4;
        final p = Offset.lerp(start, end, t)! + Offset(-u * .05 * (1 - t), 0);
        c.drawOval(
          Rect.fromCenter(
            center: p + Offset((k.isEven ? 1 : -1) * u * .07, 0),
            width: u * .16,
            height: u * .09,
          ),
          leaf,
        );
      }
    }
    c.drawPath(under, _stroke);

    // Earth lip visible below the grass at the front edge
    final lip = Rect.fromLTRB(w * .03, h * .365, w * .97, h * .745);
    c.drawOval(
      lip,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: th.lip,
        ).createShader(lip),
    );

    // Grassy top
    final top = Rect.fromLTRB(w * .03, h * .34, w * .97, h * .71);
    final grass = Path()..addOval(top);
    c.drawPath(
      grass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(th.groundRuined[0], th.groundHealthy[0], healthy)!,
            Color.lerp(th.groundRuined[1], th.groundHealthy[1], healthy)!,
          ],
        ).createShader(top),
    );
    c.save();
    c.clipPath(grass);
    // Sunlit patch and texture
    paintGlow(c, at(.36, .42), w * .3, Colors.white, .22);
    final rnd = Random(11);
    for (var i = 0; i < 26; i++) {
      final o = at(.08 + rnd.nextDouble() * .84, .38 + rnd.nextDouble() * .3);
      final light = rnd.nextBool();
      c.drawOval(
        Rect.fromCenter(
          center: o,
          width: u * (.4 + rnd.nextDouble() * .6),
          height: u * (.14 + rnd.nextDouble() * .16),
        ),
        Paint()
          ..color = light ? const Color(0x22FFFFFF) : const Color(0x14003300),
      );
    }
    // Front rim shading
    c.drawOval(
      Rect.fromLTRB(w * .03, h * .5, w * .97, h * .73),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .14
        ..color = Color.lerp(th.rimRuined, th.rimHealthy, healthy)!,
    );
    c.restore();
    c.drawPath(grass, _stroke);

    // Flowers bloom as the island is restored
    final flowerColors = th.flowers;
    final frnd = Random(5);
    final flowers = (36 * healthy).round();
    for (var i = 0, placed = 0; i < 200 && placed < flowers; i++) {
      final o = at(
        .06 + frnd.nextDouble() * .88,
        .37 + frnd.nextDouble() * .32,
      );
      final col = flowerColors[frnd.nextInt(flowerColors.length)];
      if (!_insideTop(o)) continue;
      placed++;
      c.drawCircle(o, u * .055, Paint()..color = col);
      c.drawCircle(o, u * .022, Paint()..color = const Color(0xFFFFB300));
    }

    // Tufts
    final tuft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .05
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        th.rimRuined,
        th.rimHealthy,
        healthy,
      )!.withValues(alpha: .8);
    for (final (x, y) in [
      (.12, .48),
      (.3, .42),
      (.52, .58),
      (.7, .4),
      (.88, .5),
      (.4, .66),
      (.8, .62),
      (.62, .64),
      (.16, .58),
    ]) {
      final o = at(x, y);
      c.drawLine(o, o + Offset(-u * .08, -u * .16), tuft);
      c.drawLine(o, o + Offset(0, -u * .2), tuft);
      c.drawLine(o, o + Offset(u * .08, -u * .16), tuft);
    }
  }

  void _river(Canvas c) {
    final river = Path()
      ..moveTo(w * .36, h * .37)
      ..quadraticBezierTo(w * .3, h * .5, w * .36, h * .58)
      ..quadraticBezierTo(w * .4, h * .66, w * .34, h * .71);
    // Banks
    c.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .72
        ..strokeCap = StrokeCap.round
        ..color = th.bank,
    );
    c.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .55
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: th.river)
            .createShader(Rect.fromLTWH(w * .28, 0, w * .14, h)),
    );
    if (th.lavaRiver) {
      // Molten glow along the lava river.
      for (var k = 0; k < 5; k++) {
        final o = at(.33 + (k.isEven ? .02 : -.01), .4 + k * .07);
        paintGlow(c, o, u * .9, th.river[0], .35 + .15 * sin(time * 2 + k));
      }
    }
    // Moving glints on the water
    final metrics = river.computeMetrics().first;
    final glint = Paint()
      ..strokeWidth = u * .07
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .7);
    for (var k = 0; k < 4; k++) {
      final d = ((time * u * .8 + k * metrics.length / 4) % metrics.length);
      final tan = metrics.getTangentForOffset(d);
      if (tan == null) continue;
      final side =
          Offset(-tan.vector.dy, tan.vector.dx) * u * (k.isEven ? .1 : -.1);
      c.drawLine(
        tan.position + side,
        tan.position + side + tan.vector * u * .18,
        glint,
      );
    }

    // Waterfall off the edge, with flowing streaks and mist
    final fall = at(.34, .71);
    final fallH = h * .16;
    final fallRect = Rect.fromLTWH(fall.dx - u * .22, fall.dy, u * .44, fallH);
    c.drawRRect(
      RRect.fromRectAndRadius(fallRect, Radius.circular(u * .1)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [th.river[1], th.river[1].withValues(alpha: 0)],
        ).createShader(fallRect),
    );
    final streak = Paint()
      ..strokeWidth = u * .05
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .6);
    for (var k = 0; k < 3; k++) {
      final x = fall.dx + (k - 1) * u * .12;
      final y = fall.dy + ((time * u * 2.2 + k * fallH / 3) % fallH);
      c.drawLine(Offset(x, y), Offset(x, y + u * .25), streak);
    }
    for (var k = 0; k < 4; k++) {
      final t = (time * .5 + k / 4) % 1;
      c.drawCircle(
        Offset(
          fall.dx + (k - 1.5) * u * .18,
          fall.dy + fallH * .8 - t * u * .4,
        ),
        u * (.1 + t * .12),
        Paint()..color = Colors.white.withValues(alpha: .35 * (1 - t)),
      );
    }
  }

  void _path(Canvas c) {
    final p0 = at(.13, .6), p1 = at(.5, .72), p2 = at(.88, .57);
    final stone = Paint()..color = th.path;
    final shadow = Paint()..color = const Color(0x33000000);
    for (var i = 0; i <= 16; i++) {
      final t = i / 16;
      final o = Offset(
        (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx,
        (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy,
      );
      if ((o.dx - w * .35).abs() < u * .5) continue; // the bridge crosses here
      final r = Rect.fromCenter(center: o, width: u * .3, height: u * .16);
      c.drawOval(r.shift(Offset(0, u * .03)), shadow);
      c.drawOval(r, stone);
    }
  }

  void _trees(Canvas c, {required bool back}) {
    final spots = back
        ? [
            (.08, .5, 1.0, false),
            (.2, .4, .9, true),
            (.49, .37, .8, false),
            (.73, .36, .85, true),
            (.93, .49, 1.0, false),
          ]
        : [(.1, .66, .75, false), (.9, .63, .8, false), (.7, .7, .6, false)];
    final leafLight = Color.lerp(th.leafRuined[0], th.leafHealthy[0], healthy)!;
    final leafDark = Color.lerp(th.leafRuined[1], th.leafHealthy[1], healthy)!;
    for (final (x, y, scale, pine) in spots) {
      final b = at(x, y);
      final s = u * scale;
      if (!back) {
        // Bushes along the rim
        for (final (dx, dy, r) in [
          (-.3, 0.0, .3),
          (.3, 0.0, .28),
          (0.0, -.15, .34),
        ]) {
          c.drawCircle(
            b + Offset(dx * s, dy * s),
            r * s,
            Paint()..color = leafDark,
          );
        }
        c.drawCircle(
          b + Offset(-.08 * s, -.22 * s),
          .2 * s,
          Paint()..color = leafLight,
        );
        if (healthy > .3) {
          for (final (dx, dy) in [(-.25, -.05), (.2, -.2), (.05, .05)]) {
            c.drawCircle(
              b + Offset(dx * s, dy * s),
              .06 * s,
              Paint()..color = const Color(0xFFFF6B8B),
            );
          }
        }
        continue;
      }
      c.drawOval(
        Rect.fromCenter(
          center: b + Offset(0, s * .05),
          width: s * .8,
          height: s * .18,
        ),
        Paint()..color = const Color(0x33000000),
      );
      final trunk = Paint()
        ..strokeWidth = s * .14
        ..strokeCap = StrokeCap.round
        ..color = th.trunk;
      if (th.treeStyle == 'crystal') {
        _crystalSpire(c, b, s, x);
        continue;
      }
      if (th.treeStyle == 'palm') {
        _palm(c, b, s, x, trunk);
        continue;
      }
      c.drawLine(b, b - Offset(0, s * .75), trunk);
      if (healthy < .12) {
        // Bare, ruined tree
        final branch = Paint()
          ..strokeWidth = s * .06
          ..strokeCap = StrokeCap.round
          ..color = th.trunk;
        c.drawLine(
          b - Offset(0, s * .55),
          b + Offset(-s * .3, -s * .9),
          branch,
        );
        c.drawLine(
          b - Offset(0, s * .45),
          b + Offset(s * .28, -s * .8),
          branch,
        );
        continue;
      }
      final grow = .55 + .45 * healthy;
      final sway = sin(time * 1.2 + x * 10) * s * .03;
      if (pine) {
        for (var k = 0; k < 3; k++) {
          final ty = b.dy - s * (.5 + k * .32) * grow;
          final half = s * (.5 - k * .12) * grow;
          final tri = Path()
            ..moveTo(b.dx + sway, ty - s * .45 * grow)
            ..lineTo(b.dx + half, ty)
            ..lineTo(b.dx - half, ty)
            ..close();
          c.drawPath(tri, Paint()..color = k.isEven ? leafDark : leafLight);
          c.drawPath(tri, _stroke);
        }
      } else {
        final center = b - Offset(-sway, s * 1.0 * grow);
        final canopy = Path();
        for (final (dx, dy, r) in [
          (-.3, .12, .34),
          (.3, .12, .34),
          (0.0, -.15, .4),
          (0.0, .1, .36),
        ]) {
          canopy.addOval(
            Rect.fromCircle(
              center: center + Offset(dx * s * grow, dy * s * grow),
              radius: r * s * grow,
            ),
          );
        }
        c.drawPath(
          canopy,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [leafLight, leafDark],
            ).createShader(Rect.fromCircle(center: center, radius: s * .7)),
        );
        c.drawPath(canopy, _stroke);
        if (healthy > .5) {
          for (final (dx, dy) in [(-.2, 0.0), (.18, -.12), (.05, .15)]) {
            c.drawCircle(
              center + Offset(dx * s, dy * s),
              s * .06,
              Paint()..color = const Color(0xFFFFB347),
            );
          }
        }
      }
    }
  }

  void _palm(Canvas c, Offset b, double s, double x, Paint trunk) {
    final lean = (x < .5 ? -1 : 1) * s * .25;
    final top = b + Offset(lean, -s * 1.15);
    c.drawPath(
      Path()
        ..moveTo(b.dx, b.dy)
        ..quadraticBezierTo(b.dx + lean * .1, b.dy - s * .6, top.dx, top.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .13
        ..strokeCap = StrokeCap.round
        ..color = trunk.color,
    );
    final grow = .4 + .6 * healthy;
    final sway = sin(time * 1.3 + x * 7) * .08;
    final leaf = Paint()
      ..color = Color.lerp(th.leafRuined[1], th.leafHealthy[1], healthy)!;
    for (var k = 0; k < 6; k++) {
      final a = -pi / 2 + (k - 2.5) * .55 + sway;
      c.save();
      c.translate(top.dx, top.dy);
      c.rotate(a);
      final len = s * .75 * grow;
      final frond = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * .5, -s * .18, len, s * .12)
        ..quadraticBezierTo(len * .5, s * .02, 0, 0)
        ..close();
      c.drawPath(frond, leaf);
      c.drawPath(frond, _stroke);
      c.restore();
    }
    if (healthy > .4) {
      for (final dx in [-.06, .06]) {
        c.drawCircle(
          top + Offset(dx * s, s * .08),
          s * .07,
          Paint()..color = const Color(0xFF8D6E63),
        );
      }
    }
  }

  void _crystalSpire(Canvas c, Offset b, double s, double x) {
    final grow = .5 + .5 * healthy;
    final col = Color.lerp(th.leafRuined[0], th.leafHealthy[0], healthy)!;
    final col2 = Color.lerp(th.leafRuined[1], th.leafHealthy[1], healthy)!;
    if (healthy > .1) {
      paintGlow(c, b - Offset(0, s * .6), s * .8, col2, .35 * healthy);
    }
    for (final (dx, hgt, wd) in [
      (-.22, .8, .18),
      (.2, .7, .16),
      (0.0, 1.3, .24),
    ]) {
      final base = b + Offset(dx * s, 0);
      final hh = s * hgt * grow;
      final spire = Path()
        ..moveTo(base.dx - s * wd, base.dy)
        ..lineTo(base.dx - s * wd * .6, base.dy - hh * .8)
        ..lineTo(base.dx, base.dy - hh)
        ..lineTo(base.dx + s * wd * .6, base.dy - hh * .8)
        ..lineTo(base.dx + s * wd, base.dy)
        ..close();
      c.drawPath(
        spire,
        Paint()
          ..shader = LinearGradient(
            colors: [col, col2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(base.dx - s, base.dy - hh, s * 2, hh)),
      );
      c.drawPath(
        Path()
          ..moveTo(base.dx - s * wd, base.dy)
          ..lineTo(base.dx - s * wd * .6, base.dy - hh * .8)
          ..lineTo(base.dx, base.dy - hh)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
      c.drawPath(spire, _stroke);
    }
  }

  /// Theme-specific drifting particles.
  void _themeAmbient(Canvas c) {
    switch (th.ambient) {
      case 'embers':
        for (var i = 0; i < 14; i++) {
          final t = (time * (.08 + (i % 5) * .02) + i * .137) % 1;
          final o =
              at(.1 + ((i * 37) % 80) / 100, .95 - t * .9) +
              Offset(sin(time * 2 + i) * u * .2, 0);
          final a = (1 - t) * .9;
          paintGlow(c, o, u * .18, const Color(0xFFFF8A3D), a * .6);
          c.drawCircle(
            o,
            u * .035,
            Paint()..color = const Color(0xFFFFD166).withValues(alpha: a),
          );
        }
      case 'bubbles':
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .03;
        for (var i = 0; i < 12; i++) {
          final t = (time * (.06 + (i % 4) * .02) + i * .21) % 1;
          final o =
              at(.08 + ((i * 29) % 84) / 100, 1.0 - t) +
              Offset(sin(time * 1.5 + i) * u * .15, 0);
          ring.color = Colors.white.withValues(alpha: .6 * (1 - t));
          c.drawCircle(o, u * (.06 + (i % 3) * .03), ring);
        }
      case 'snow':
        for (var i = 0; i < 22; i++) {
          final t = (time * (.04 + (i % 5) * .012) + i * .093) % 1;
          final o =
              at(((i * 41) % 100) / 100, t * 1.05 - .05) +
              Offset(sin(time + i) * u * .25, 0);
          c.drawCircle(
            o,
            u * (.03 + (i % 3) * .015),
            Paint()..color = Colors.white.withValues(alpha: .85),
          );
        }
      case 'stars':
        for (var i = 0; i < 24; i++) {
          final o = at(((i * 53) % 100) / 100, ((i * 31) % 45) / 100);
          final tw = (sin(time * 2 + i * 1.7) + 1) / 2;
          paintSparkle(
            c,
            o,
            u * (.05 + .07 * tw),
            Colors.white.withValues(alpha: .4 + .6 * tw),
          );
        }
        // Wisps once restored
        for (var i = 0; i < 4; i++) {
          final a = time * .3 + i * 1.6;
          final o = at(.5 + cos(a) * .38, .5 + sin(a * 1.2) * .08);
          paintGlow(c, o, u * .45, const Color(0xFF80F5E0), .5 * healthy);
        }
    }
  }

  void _floatingRocks(Canvas c, {required bool back}) {
    final rocks = back
        ? [(.05, .7, .5, 0.0), (.9, .3, .35, 2.0)]
        : [(.94, .8, .55, 1.0), (.14, .95, .4, 3.0)];
    for (final (x, y, s, phase) in rocks) {
      final o = at(x, y) + Offset(0, sin(time * 1.1 + phase) * u * .15);
      final r = u * s;
      final rock = Path()
        ..moveTo(o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx - r * .6, o.dy + r * 1.1, o.dx, o.dy + r * 1.2)
        ..quadraticBezierTo(o.dx + r * .7, o.dy + r * .9, o.dx + r, o.dy)
        ..close();
      c.drawPath(rock, Paint()..color = th.rock[1]);
      c.drawPath(rock, _stroke);
      c.drawOval(
        Rect.fromCenter(center: o, width: r * 2.1, height: r * .6),
        Paint()
          ..color = Color.lerp(
            th.groundRuined[0],
            th.groundHealthy[0],
            healthy,
          )!,
      );
      c.drawOval(
        Rect.fromCenter(center: o, width: r * 2.1, height: r * .6),
        _stroke,
      );
    }
  }

  /// Fireflies once the lanterns are lit, butterflies once the garden grows.
  void _ambient(Canvas c) {
    final lit = p('lanterns');
    if (lit > 0) {
      for (var i = 0; i < 12; i++) {
        final a = time * (.3 + i * .03) + i * 1.7;
        final o = at(
          .5 + cos(a) * (.3 + (i % 3) * .05),
          .45 + sin(a * 1.3) * .12,
        );
        final twinkle = (sin(time * 3 + i) + 1) / 2;
        paintGlow(c, o, u * .25, const Color(0xFFFFF59D), .8 * lit * twinkle);
        c.drawCircle(
          o,
          u * .03,
          Paint()..color = const Color(0xFFFFFDE7).withValues(alpha: lit),
        );
      }
    }
    final garden = p('garden');
    if (garden > 0) {
      for (var i = 0; i < 2; i++) {
        final a = time * .6 + i * 3;
        final o = at(.22 + cos(a) * .08, .56 + sin(a * 2) * .05);
        final flap = (sin(time * 14 + i) + 1) / 2;
        final col = i == 0 ? const Color(0xFFFFB3D9) : const Color(0xFFB3E5FF);
        for (final dir in [-1.0, 1.0]) {
          c.drawOval(
            Rect.fromCenter(
              center: o + Offset(dir * u * .08 * (.4 + .6 * flap), 0),
              width: u * .16 * (.4 + .6 * flap),
              height: u * .2,
            ),
            Paint()..color = col.withValues(alpha: garden),
          );
        }
        c.drawLine(
          o - Offset(0, u * .08),
          o + Offset(0, u * .08),
          Paint()
            ..strokeWidth = u * .03
            ..color = const Color(0xFF5D4037),
        );
      }
    }
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
      c.drawPath(roof, _fade(th.roofs[0], t));
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
    c.drawPath(roof, _fade(th.roofs[1], t));
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
    c.drawPath(roof, _fade(th.roofs[2], t));
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
    const lines = [
      [(.08, .5), (.2, .42), (.3, .56), (.42, .46), (.5, .6)],
      [(.5, .4), (.62, .56), (.74, .46), (.86, .6), (.94, .5)],
      [(.2, .66), (.36, .6), (.5, .7), (.66, .62), (.8, .68)],
    ];
    Path wiggle(List<(double, double)> pts, double lift) {
      final path = Path()..moveTo(w * pts[0].$1, h * pts[0].$2);
      for (var i = 1; i < pts.length; i++) {
        final prev = at(pts[i - 1].$1, pts[i - 1].$2);
        final cur = at(pts[i].$1, pts[i].$2);
        final mid = (prev + cur) / 2 + Offset(0, -u * lift);
        path.quadraticBezierTo(mid.dx, mid.dy, cur.dx, cur.dy);
      }
      return path;
    }

    switch (th.overlayStyle) {
      case 'lava':
        // Glowing cracks across the ground.
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .22
          ..strokeCap = StrokeCap.round
          ..color = th.overlay.withValues(alpha: .35 * t)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .12);
        final core = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .07
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFD166).withValues(alpha: t);
        for (final pts in lines) {
          final path = wiggle(pts, .15);
          c.drawPath(path, glow);
          c.drawPath(path, core);
        }
      case 'ice':
        final ice = Paint()..color = th.overlay.withValues(alpha: .75 * t);
        final edge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .04
          ..color = const Color(0xFF9CC8F0).withValues(alpha: t);
        for (final (x, y, rw, rh) in [
          (.22, .48, .22, .1),
          (.62, .44, .26, .1),
          (.42, .62, .3, .1),
          (.8, .58, .16, .08),
        ]) {
          final r = Rect.fromCenter(
            center: at(x, y),
            width: w * rw,
            height: h * rh,
          );
          c.drawOval(r, ice);
          c.drawOval(r, edge);
          paintSparkle(
            c,
            r.topCenter + Offset(0, r.height * .3),
            u * .1 * t,
            Colors.white,
          );
        }
      default:
        // vines (meadow), kelp (lagoon), brambles (shadow)
        final kelp = th.overlayStyle == 'kelp';
        final brambles = th.overlayStyle == 'brambles';
        final vine = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * (kelp ? .16 : .12)
          ..strokeCap = StrokeCap.round
          ..color = th.overlay.withValues(alpha: t);
        final thorn = Paint()
          ..color =
              (brambles ? const Color(0xFFB388FF) : const Color(0xFF3B4A22))
                  .withValues(alpha: t);
        for (final pts in lines) {
          final path = wiggle(pts, kelp ? .25 : .4);
          if (brambles) {
            c.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = u * .3
                ..strokeCap = StrokeCap.round
                ..color = const Color(0xFFB388FF).withValues(alpha: .18 * t)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .15),
            );
          }
          c.drawPath(path, vine);
          if (!kelp) {
            for (var i = 1; i < pts.length; i++) {
              final prev = at(pts[i - 1].$1, pts[i - 1].$2);
              final cur = at(pts[i].$1, pts[i].$2);
              final mid = (prev + cur) / 2 + Offset(0, -u * .2);
              c.drawCircle(mid, u * .08, thorn);
            }
          }
        }
    }
  }

  @override
  bool shouldRepaint(IslandPainter old) => true;
}

import 'dart:math';

import 'package:flutter/material.dart';

import 'island_theme.dart';
import 'item_painter.dart';
import 'nature_shapes.dart';

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
    // Soft layered strata
    for (final (y, dark, amp) in [
      (.62, false, .02),
      (.7, true, .03),
      (.79, false, .025),
    ]) {
      final band = Path()
        ..moveTo(0, h * y)
        ..quadraticBezierTo(w * .25, h * (y + amp), w * .5, h * y)
        ..quadraticBezierTo(w * .75, h * (y - amp), w, h * y)
        ..lineTo(w, h * (y + .035))
        ..quadraticBezierTo(
          w * .75,
          h * (y + .035 - amp),
          w * .5,
          h * (y + .035),
        )
        ..quadraticBezierTo(w * .25, h * (y + .035 + amp), 0, h * (y + .035))
        ..close();
      c.drawPath(
        band,
        Paint()
          ..color = dark ? const Color(0x18000000) : const Color(0x22FFE2BD)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .06),
      );
    }
    // Rounded boulders bulging out of the rock face, lit from the top left.
    final rnd = Random(21);
    for (var i = 0; i < 16; i++) {
      final fx = .08 + rnd.nextDouble() * .84;
      final fy = .6 + rnd.nextDouble() * .3;
      final o = at(fx, fy);
      final r = u * (.35 + rnd.nextDouble() * .45) * (1.15 - (fy - .6));
      final shape = blobPath(o, r, r * .72, 40 + i, lobes: 6);
      c.drawPath(
        shape.shift(Offset(r * .12, r * .16)),
        Paint()..color = const Color(0x26000000),
      );
      c.drawPath(
        shape,
        Paint()..color = Color.lerp(th.rock[0], th.rock[1], (fy - .55) * 2.2)!,
      );
      c.drawPath(
        blobPath(o - Offset(r * .25, r * .25), r * .45, r * .25, 90 + i),
        Paint()..color = Colors.white.withValues(alpha: .16),
      );
    }
    // Shadow tucked under the grassy lip
    c.drawRect(
      Rect.fromLTWH(0, h * .52, w, h * .12),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, h * .55, w, h * .09)),
    );
    // Rim light along the left edge
    c.drawPath(
      under,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .35
        ..shader = const LinearGradient(
          colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
          stops: [0, .35],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .12),
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
    final vineCol = Color.lerp(th.leafRuined[1], th.leafHealthy[1], healthy)!;
    final leafLight = Color.lerp(th.leafRuined[0], th.leafHealthy[0], healthy)!;
    for (final (x, y, len) in [
      (.16, .66, .16),
      (.3, .76, .11),
      (.72, .76, .13),
      (.84, .69, .17),
    ]) {
      final sway = sin(time * 1.4 + x * 9) * u * .12;
      final start = at(x, y);
      final end = start + Offset(sway, h * len);
      final spine = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          start.dx - u * .12,
          (start.dy + end.dy) / 2,
          end.dx,
          end.dy,
        );
      c.drawPath(ribbon(spine, u * .07, u * .025), Paint()..color = vineCol);
      final m = spine.computeMetrics().first;
      for (var k = 1; k <= 4; k++) {
        final tan = m.getTangentForOffset(m.length * k / 4.6);
        if (tan == null) continue;
        final side = k.isEven ? 1.0 : -1.0;
        paintLeaf(
          c,
          tan.position,
          pi / 2 - side * 1.0 + sway / u * .3,
          u * (.24 - k * .025),
          leafLight,
          vineCol,
        );
      }
      if (healthy > .5) {
        paintFlower(c, end, u * .07, th.flowers[(x * 10).round() % 4]);
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

    // Grassy top with a scalloped fringe hanging over the front edge
    final rim = Color.lerp(th.rimRuined, th.rimHealthy, healthy)!;
    final g0 = Color.lerp(th.groundRuined[0], th.groundHealthy[0], healthy)!;
    final g1 = Color.lerp(th.groundRuined[1], th.groundHealthy[1], healthy)!;
    final top = Rect.fromLTRB(w * .03, h * .34, w * .97, h * .71);
    final cx = top.center.dx, cy = top.center.dy;
    final rx = top.width / 2, ry = top.height / 2;
    final fringe = Paint()..color = Color.lerp(rim, g1, .3)!;
    for (var i = 0; i <= 26; i++) {
      final a = pi * (.02 + .96 * i / 26);
      final o = Offset(cx + cos(a) * rx, cy + sin(a) * ry * .97);
      final r = u * (i.isEven ? .2 : .15) * (.55 + .45 * sin(a));
      c.drawCircle(o + Offset(0, r * .45), r, fringe);
    }
    final grass = Path()..addOval(top);
    c.drawPath(
      grass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [g0, g1],
        ).createShader(top),
    );
    c.save();
    c.clipPath(grass);
    // Sunlit patch, then a soft shade that deepens toward the edge
    paintGlow(c, at(.36, .44), w * .34, Colors.white, .28);
    c.drawPath(
      grass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .6
        ..color = rim.withValues(alpha: .55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .3),
    );
    // Mottled light and shade
    final rnd2 = Random(11);
    for (var i = 0; i < 22; i++) {
      final o = at(.08 + rnd2.nextDouble() * .84, .38 + rnd2.nextDouble() * .3);
      final light = rnd2.nextBool();
      c.drawPath(
        blobPath(
          o,
          u * (.35 + rnd2.nextDouble() * .5),
          u * (.14 + rnd2.nextDouble() * .12),
          200 + i,
        ),
        Paint()
          ..color = light
              ? const Color(0x1FFFFFFF)
              : rim.withValues(alpha: .16),
      );
    }
    c.restore();
    c.drawArc(top, pi * 1.02, pi * .96, false, _stroke);

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
      final spin = frnd.nextDouble() * pi;
      if (!_insideTop(o)) continue;
      placed++;
      c.drawCircle(
        o + Offset(0, u * .03),
        u * .07,
        Paint()..color = const Color(0x22000000),
      );
      paintFlower(c, o, u * .075, col, const Color(0xFFFFC43D), spin);
    }

    // Grass tufts
    final tuftLight = Color.lerp(g0, rim, .35)!;
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
      (.26, .66),
      (.92, .56),
    ]) {
      paintTuft(c, at(x, y), u * .26, tuftLight, rim, blades: 5);
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

    // Waterfall off the edge: a flaring curtain with flowing streaks, a
    // foamy lip and mist below.
    final fall = at(.34, .71);
    final fallH = h * .17;
    final top0 = u * .26, bot0 = u * .4;
    final curtain = Path()
      ..moveTo(fall.dx - top0, fall.dy - u * .05)
      ..quadraticBezierTo(
        fall.dx - top0 * 1.05,
        fall.dy + fallH * .5,
        fall.dx - bot0,
        fall.dy + fallH,
      )
      ..lineTo(fall.dx + bot0, fall.dy + fallH)
      ..quadraticBezierTo(
        fall.dx + top0 * 1.05,
        fall.dy + fallH * .5,
        fall.dx + top0,
        fall.dy - u * .05,
      )
      ..close();
    final fallRect = Rect.fromLTWH(fall.dx - bot0, fall.dy, bot0 * 2, fallH);
    c.drawPath(
      curtain,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            th.river[0],
            th.river[1].withValues(alpha: .85),
            th.river[1].withValues(alpha: 0),
          ],
          stops: const [0, .55, 1],
        ).createShader(fallRect),
    );
    c.save();
    c.clipPath(curtain);
    for (var k = 0; k < 5; k++) {
      final x = fall.dx + (k - 2) * u * .13;
      final y = fall.dy + ((time * u * 2.4 + k * fallH / 5 * 2.3) % fallH);
      final len = u * (.3 + (k % 3) * .1);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - u * .025, y - len, u * .05, len),
          Radius.circular(u * .025),
        ),
        Paint()
          ..color = Colors.white.withValues(
            alpha: th.lavaRiver ? .35 : .55 * (1 - (y - fall.dy) / fallH),
          ),
      );
    }
    c.restore();
    // Foam where the river tips over the edge
    for (var k = 0; k < 5; k++) {
      final bob = sin(time * 4 + k * 1.3) * u * .02;
      c.drawCircle(
        fall + Offset((k - 2) * u * .12, bob),
        u * (k.isEven ? .1 : .08),
        Paint()
          ..color = (th.lavaRiver ? const Color(0xFFFFE9A0) : Colors.white)
              .withValues(alpha: .85),
      );
    }
    for (var k = 0; k < 5; k++) {
      final t = (time * .5 + k / 5) % 1;
      c.drawCircle(
        Offset(
          fall.dx + (k - 2) * u * .16,
          fall.dy + fallH * .85 - t * u * .45,
        ),
        u * (.1 + t * .14),
        Paint()
          ..color = (th.lavaRiver ? const Color(0xFF8A7A76) : Colors.white)
              .withValues(alpha: .3 * (1 - t)),
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
    final shine = Color.lerp(leafLight, Colors.white, .35)!;
    for (final (x, y, scale, pine) in spots) {
      final b = at(x, y);
      final s = u * scale;
      if (!back) {
        // Rounded bushes along the rim
        c.drawOval(
          Rect.fromCenter(
            center: b + Offset(0, s * .22),
            width: s * 1.3,
            height: s * .3,
          ),
          Paint()..color = const Color(0x33000000),
        );
        final bush = Path();
        for (final (dx, dy, r) in [
          (-.3, 0.0, .3),
          (.3, 0.0, .28),
          (0.0, -.15, .34),
        ]) {
          bush.addOval(
            Rect.fromCircle(center: b + Offset(dx * s, dy * s), radius: r * s),
          );
        }
        c.drawPath(bush, Paint()..color = leafDark);
        for (final (dx, dy, r) in [(-.34, -.06, .17), (-.06, -.24, .2)]) {
          c.drawCircle(
            b + Offset(dx * s, dy * s),
            r * s,
            Paint()..color = leafLight,
          );
        }
        c.drawCircle(
          b + Offset(-.12 * s, -.32 * s),
          .07 * s,
          Paint()..color = shine.withValues(alpha: .8),
        );
        c.drawPath(bush, _stroke);
        if (healthy > .3) {
          for (final (dx, dy) in [(-.25, -.05), (.2, -.2), (.08, .06)]) {
            paintFlower(
              c,
              b + Offset(dx * s, dy * s),
              .09 * s,
              th.flowers[0],
              Colors.white,
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
      final trunk = Paint()..color = th.trunk;
      if (th.treeStyle == 'crystal') {
        _crystalSpire(c, b, s, x);
        continue;
      }
      if (th.treeStyle == 'palm') {
        _palm(c, b, s, x, trunk);
        continue;
      }
      if (healthy < .12) {
        // Bare, ruined tree: a gnarled trunk with forked branches
        final top = b - Offset(s * .04, s * .8);
        c.drawPath(ribbon(curve(b, top, .06), s * .2, s * .07), trunk);
        for (final (from, dx, dy, bend, wd) in [
          (.55, -.34, -.98, .15, .07),
          (.45, .32, -.86, -.15, .065),
          (.75, .1, -1.08, .1, .05),
        ]) {
          final start = b - Offset(0, s * from);
          c.drawPath(
            ribbon(curve(start, b + Offset(s * dx, s * dy), bend), s * wd, 0),
            trunk,
          );
        }
        continue;
      }
      final grow = .55 + .45 * healthy;
      final sway = sin(time * 1.2 + x * 10) * s * .03;
      c.drawPath(
        ribbon(curve(b, b - Offset(0, s * .8), 0), s * .18, s * .1),
        trunk,
      );
      c.drawPath(
        ribbon(
          curve(b + Offset(s * .03, 0), b - Offset(-s * .03, s * .8), 0),
          s * .07,
          s * .04,
        ),
        Paint()..color = const Color(0x22000000),
      );
      if (pine) {
        for (var k = 0; k < 3; k++) {
          final ty = b.dy - s * (.5 + k * .32) * grow;
          final half = s * (.5 - k * .12) * grow;
          final apex = Offset(b.dx + sway, ty - s * .45 * grow);
          final tri = Path()
            ..moveTo(apex.dx, apex.dy)
            ..quadraticBezierTo(b.dx + half * .5, ty - s * .12, b.dx + half, ty)
            ..quadraticBezierTo(b.dx, ty + s * .1, b.dx - half, ty)
            ..quadraticBezierTo(
              b.dx - half * .5,
              ty - s * .12,
              apex.dx,
              apex.dy,
            )
            ..close();
          c.drawPath(tri, Paint()..color = leafDark);
          c.drawPath(
            Path()
              ..moveTo(apex.dx, apex.dy)
              ..quadraticBezierTo(
                b.dx - half * .5,
                ty - s * .12,
                b.dx - half,
                ty,
              )
              ..quadraticBezierTo(
                b.dx - half * .4,
                ty + s * .07,
                b.dx,
                ty + s * .05,
              )
              ..close(),
            Paint()..color = leafLight,
          );
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
        c.drawPath(canopy, Paint()..color = leafDark);
        c.save();
        c.clipPath(canopy);
        // Light puffs on the upper left, shade underneath
        for (final (dx, dy, r) in [
          (-.28, .02, .26),
          (-.06, -.24, .3),
          (.22, -.06, .2),
        ]) {
          c.drawCircle(
            center + Offset(dx * s * grow, dy * s * grow),
            r * s * grow,
            Paint()..color = leafLight,
          );
        }
        c.drawCircle(
          center + Offset(-.16 * s * grow, -.3 * s * grow),
          .11 * s * grow,
          Paint()..color = shine.withValues(alpha: .7),
        );
        c.restore();
        c.drawPath(canopy, _stroke);
        if (healthy > .5) {
          for (final (dx, dy) in [(-.2, 0.0), (.18, -.12), (.05, .15)]) {
            final fruit = center + Offset(dx * s, dy * s);
            c.drawCircle(
              fruit,
              s * .065,
              Paint()..color = const Color(0xFFFFA23D),
            );
            c.drawCircle(
              fruit - Offset(s * .02, s * .02),
              s * .022,
              Paint()..color = Colors.white.withValues(alpha: .7),
            );
          }
        }
      }
    }
  }

  void _palm(Canvas c, Offset b, double s, double x, Paint trunk) {
    final lean = (x < .5 ? -1 : 1) * s * .25;
    final top = b + Offset(lean, -s * 1.15);
    final spine = Path()
      ..moveTo(b.dx, b.dy)
      ..quadraticBezierTo(b.dx + lean * .1, b.dy - s * .6, top.dx, top.dy);
    c.drawPath(ribbon(spine, s * .17, s * .09), trunk);
    // Ring bands on the trunk
    final m = spine.computeMetrics().first;
    final band = Paint()..color = const Color(0x33000000);
    for (var k = 1; k < 7; k++) {
      final tan = m.getTangentForOffset(m.length * k / 7);
      if (tan == null) continue;
      final wd = s * (.17 - .08 * k / 7);
      c.save();
      c.translate(tan.position.dx, tan.position.dy);
      c.rotate(-tan.angle);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * .05, height: wd),
        band,
      );
      c.restore();
    }
    final grow = .4 + .6 * healthy;
    final sway = sin(time * 1.3 + x * 7) * .08;
    final leaf = Color.lerp(th.leafRuined[1], th.leafHealthy[1], healthy)!;
    final light = Color.lerp(th.leafRuined[0], th.leafHealthy[0], healthy)!;
    for (var k = 0; k < 7; k++) {
      final a = -pi / 2 + (k - 3) * .5 + sway;
      c.save();
      c.translate(top.dx, top.dy);
      c.rotate(a);
      final len = s * .8 * grow;
      final frond = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * .5, -s * .22, len, s * .14)
        ..quadraticBezierTo(len * .55, s * .05, 0, 0)
        ..close();
      c.drawPath(frond, Paint()..color = leaf);
      c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(len * .5, -s * .22, len, s * .14)
          ..quadraticBezierTo(len * .5, -s * .08, 0, 0)
          ..close(),
        Paint()..color = light,
      );
      c.drawPath(frond, _stroke);
      c.restore();
    }
    if (healthy > .4) {
      for (final dx in [-.07, .07]) {
        c.drawCircle(
          top + Offset(dx * s, s * .08),
          s * .08,
          Paint()..color = const Color(0xFF8D6E63),
        );
        c.drawCircle(
          top + Offset(dx * s - s * .025, s * .055),
          s * .025,
          Paint()..color = Colors.white.withValues(alpha: .4),
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
    final g0 = Color.lerp(th.groundRuined[0], th.groundHealthy[0], healthy)!;
    final rim = Color.lerp(th.rimRuined, th.rimHealthy, healthy)!;
    for (final (x, y, s, phase) in rocks) {
      final o = at(x, y) + Offset(0, sin(time * 1.1 + phase) * u * .15);
      final r = u * s;
      final rock = Path()
        ..moveTo(o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx - r * .6, o.dy + r * 1.1, o.dx, o.dy + r * 1.2)
        ..quadraticBezierTo(o.dx + r * .7, o.dy + r * .9, o.dx + r, o.dy)
        ..close();
      c.drawPath(
        rock,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [th.rock[0], th.rock[2]],
          ).createShader(Rect.fromLTWH(o.dx - r, o.dy, r * 2, r * 1.2)),
      );
      c.drawPath(rock, _stroke);
      final top = Rect.fromCenter(center: o, width: r * 2.1, height: r * .6);
      for (var i = 0; i <= 6; i++) {
        final a = pi * (.1 + .8 * i / 6);
        c.drawCircle(
          top.center + Offset(cos(a) * top.width / 2, sin(a) * top.height / 2),
          r * .16,
          Paint()..color = rim,
        );
      }
      c.drawOval(top, Paint()..color = g0);
      c.drawOval(
        Rect.fromCenter(
          center: o - Offset(r * .3, r * .08),
          width: r * .8,
          height: r * .2,
        ),
        Paint()..color = Colors.white.withValues(alpha: .25),
      );
      c.drawArc(top, pi, pi, false, _stroke);
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
    const stoneCol = Color(0xFFA7A29B);
    for (final (i, (dx, dy, r)) in const [
      (-.5, 0.0, .2),
      (.3, .05, .24),
      (0.0, -.1, .18),
      (.6, -.05, .14),
      (-.2, .1, .12),
    ].indexed) {
      final o = base + Offset(dx * u * spread, dy * u);
      final shape = blobPath(o, r * u * 1.2, r * u * .8, 60 + i, lobes: 6);
      c.drawPath(
        shape.shift(Offset(0, r * u * .25)),
        _fade(const Color(0xFF6E6962), fade),
      );
      c.drawPath(shape, _fade(stoneCol, fade));
      c.drawOval(
        Rect.fromCenter(
          center: o - Offset(r * u * .35, r * u * .3),
          width: r * u * .9,
          height: r * u * .35,
        ),
        _fade(Colors.white, .35 * fade),
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
    final wall = Color.lerp(
      const Color(0xFF9E9A94),
      const Color(0xFFE8DCC8),
      t,
    )!;
    c.drawRect(body, Paint()..color = wall);
    // Staggered stone blocks
    final rnd = Random(4);
    final block = Paint()..color = Color.lerp(wall, Colors.black, .1)!;
    final lightBlock = Paint()..color = Color.lerp(wall, Colors.white, .3)!;
    var row = 0;
    for (var y = b.dy - u * .28; y > body.top + u * .05; y -= u * .28, row++) {
      for (
        var x = body.left + (row.isEven ? 0 : u * .15);
        x < body.right;
        x += u * .3
      ) {
        if (rnd.nextDouble() < .45) continue;
        final r = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            max(body.left, x + u * .02),
            y,
            min(body.right, x + u * .28),
            y + u * .24,
          ),
          Radius.circular(u * .05),
        );
        c.drawRRect(r, rnd.nextBool() ? block : lightBlock);
      }
    }
    // Shaded right side
    c.drawRect(
      Rect.fromLTRB(b.dx + u * .18, body.top, body.right, b.dy),
      Paint()..color = const Color(0x1F000000),
    );
    // Arched door
    final door = RRect.fromRectAndCorners(
      Rect.fromLTRB(b.dx - u * .17, b.dy - u * .5, b.dx + u * .17, b.dy),
      topLeft: Radius.circular(u * .17),
      topRight: Radius.circular(u * .17),
    );
    c.drawRRect(door, Paint()..color = const Color(0xFF6D4C33));
    c.drawRRect(
      door.deflate(u * .05),
      Paint()..color = const Color(0xFF8A6446),
    );
    c.drawCircle(
      Offset(b.dx + u * .07, b.dy - u * .22),
      u * .03,
      Paint()..color = const Color(0xFFFFD166),
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
      final roofCol = th.roofs[0];
      final roof = Path()
        ..moveTo(body.left - u * .18, body.top)
        ..quadraticBezierTo(
          b.dx - u * .2,
          body.top - u * .3,
          b.dx,
          body.top - u * .75,
        )
        ..quadraticBezierTo(
          b.dx + u * .2,
          body.top - u * .3,
          body.right + u * .18,
          body.top,
        )
        ..close();
      c.drawPath(roof, _fade(roofCol, t));
      c.save();
      c.clipPath(roof);
      c.drawRect(
        Rect.fromLTRB(b.dx, body.top - u, body.right + u, body.top),
        _fade(const Color(0x33000000), t),
      );
      for (var k = 1; k < 4; k++) {
        c.drawRect(
          Rect.fromLTWH(
            body.left - u * .2,
            body.top - u * .18 * k,
            body.width + u * .4,
            u * .05,
          ),
          _fade(const Color(0x22FFFFFF), t),
        );
      }
      c.restore();
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            body.left - u * .2,
            body.top - u * .02,
            body.width + u * .4,
            u * .1,
          ),
          Radius.circular(u * .05),
        ),
        _fade(Color.lerp(roofCol, Colors.black, .25)!, t),
      );
      c.drawPath(
        roof,
        _fade(const Color(0x66301E4F), t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke.strokeWidth,
      );
      final win = RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: Offset(b.dx, body.top + u * .45),
          width: u * .24,
          height: u * .32,
        ),
        topLeft: Radius.circular(u * .12),
        topRight: Radius.circular(u * .12),
      );
      c.drawRRect(win.inflate(u * .04), _fade(const Color(0xFF8A6446), t));
      c.drawRRect(win, _fade(const Color(0xFFFFE082), t));
      paintGlow(c, win.center, u * .4, const Color(0xFFFFE082), .3 * t);
      final pole = Offset(b.dx, body.top - u * .75);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            pole.dx - u * .025,
            pole.dy - u * .42,
            u * .05,
            u * .44,
          ),
          Radius.circular(u * .025),
        ),
        _fade(const Color(0xFF6D4C33), t),
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
          ..quadraticBezierTo(
            pole.dx + u * .2,
            pole.dy - u * .25 - wave,
            pole.dx,
            pole.dy - u * .22,
          )
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
    final wall = Color.lerp(
      const Color(0xFFA1887F),
      const Color(0xFFFFF3E0),
      t,
    )!;
    c.drawPath(body, Paint()..color = wall);
    c.save();
    c.clipPath(body);
    c.drawRect(
      Rect.fromLTRB(b.dx + u * .1, b.dy - u * 1.5, b.dx + u * .5, b.dy),
      Paint()..color = const Color(0x1F000000),
    );
    for (var k = 1; k < 5; k++) {
      c.drawRect(
        Rect.fromLTWH(b.dx - u * .5, b.dy - u * .28 * k, u, u * .03),
        Paint()..color = const Color(0x14000000),
      );
    }
    c.restore();
    // Door and window
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(b.dx - u * .13, b.dy - u * .4, b.dx + u * .13, b.dy),
        topLeft: Radius.circular(u * .13),
        topRight: Radius.circular(u * .13),
      ),
      Paint()..color = const Color(0xFF7A5234),
    );
    c.drawCircle(
      Offset(b.dx, b.dy - u * .8),
      u * .1,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF5D4037),
          const Color(0xFFFFE082),
          t,
        )!,
    );
    // Cap
    final cap = Path()
      ..moveTo(b.dx - u * .33, b.dy - u * 1.36)
      ..quadraticBezierTo(
        b.dx,
        b.dy - u * 1.85,
        b.dx + u * .33,
        b.dy - u * 1.36,
      )
      ..close();
    c.drawPath(
      cap,
      Paint()..color = Color.lerp(const Color(0xFF6D5A52), th.roofs[1], t)!,
    );
    c.drawPath(cap, _stroke);
    c.drawPath(body, _stroke);
    final hub = Offset(b.dx, b.dy - u * 1.35);
    final angle = t * time * 0.8;
    final cloth = Color.lerp(
      const Color(0xFF8D6E63),
      const Color(0xFFFFFFFF),
      t,
    )!;
    final spar = Paint()..color = const Color(0xFF7A5234);
    final blades = t > 0 ? 4 : 2; // ruined: two broken sails
    for (var i = 0; i < blades; i++) {
      final a = angle + i * pi / 2 + .3;
      final len = t > 0 ? u * 1.0 : u * .5;
      c.save();
      c.translate(hub.dx, hub.dy);
      c.rotate(a);
      final sail = RRect.fromRectAndRadius(
        Rect.fromLTWH(u * .18, -u * .02, len - u * .18, u * .24),
        Radius.circular(u * .04),
      );
      c.drawRRect(sail, Paint()..color = cloth);
      for (var k = 1; k < 4; k++) {
        c.drawRect(
          Rect.fromLTWH(
            u * .18 + (len - u * .18) * k / 4,
            -u * .02,
            u * .025,
            u * .24,
          ),
          Paint()..color = const Color(0x22000000),
        );
      }
      c.drawRRect(sail, _stroke);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, -u * .04, len, u * .06),
          Radius.circular(u * .03),
        ),
        spar,
      );
      c.restore();
    }
    c.drawCircle(hub, u * .11, Paint()..color = const Color(0xFF6D4C33));
    c.drawCircle(
      hub - Offset(u * .03, u * .03),
      u * .035,
      Paint()..color = Colors.white.withValues(alpha: .4),
    );
  }

  void _shrine(Canvas c, Offset b) {
    final t = p('shrine');
    final ped = Rect.fromLTRB(
      b.dx - u * .45,
      b.dy - u * .35,
      b.dx + u * .45,
      b.dy,
    );
    final step = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        ped.left - u * .12,
        ped.bottom - u * .12,
        ped.right + u * .12,
        ped.bottom + u * .04,
      ),
      Radius.circular(u * .06),
    );
    c.drawRRect(step, Paint()..color = const Color(0xFFA59CB3));
    c.drawRRect(step, _stroke);
    final pedR = RRect.fromRectAndRadius(ped, Radius.circular(u * .08));
    c.drawRRect(pedR, Paint()..color = const Color(0xFFBDB5C9));
    c.drawRect(
      Rect.fromLTRB(b.dx + u * .15, ped.top, ped.right, ped.bottom),
      Paint()..color = const Color(0x1F000000),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(ped.left, ped.top, ped.right, ped.top + u * .08),
        Radius.circular(u * .04),
      ),
      Paint()..color = Colors.white.withValues(alpha: .35),
    );
    // Rune dots that glow once the shrine is restored
    for (var k = -1; k <= 1; k++) {
      final o = Offset(b.dx + k * u * .22, ped.center.dy + u * .03);
      if (p('shrine') > 0) {
        paintGlow(c, o, u * .14, const Color(0xFF9CF6FF), .8 * p('shrine'));
      }
      c.drawCircle(
        o,
        u * .045,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF8E8699),
            const Color(0xFFE0FDFF),
            p('shrine'),
          )!,
      );
    }
    c.drawRRect(pedR, _stroke);
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
    final baseR = RRect.fromRectAndRadius(base, Radius.circular(u * .1));
    c.drawRRect(baseR, _fade(const Color(0xFFB0A89C), t));
    // Stone courses
    c.save();
    c.clipRRect(baseR);
    for (var row = 0; row < 3; row++) {
      for (var k = -1; k < 4; k++) {
        final x = base.left + k * u * .26 + (row.isOdd ? u * .13 : 0);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x + u * .015,
              base.top + u * .07 + row * u * .13,
              u * .23,
              u * .11,
            ),
            Radius.circular(u * .04),
          ),
          _fade(
            (row + k).isEven
                ? const Color(0xFFC9C1B4)
                : const Color(0xFF9C9488),
            t,
          ),
        );
      }
    }
    c.restore();
    final post = _fade(const Color(0xFF8D6E63), t);
    for (final x in [base.left + u * .05, base.right - u * .12]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, base.top - u * .6, u * .07, u * .62),
          Radius.circular(u * .03),
        ),
        post,
      );
    }
    c.drawOval(
      Rect.fromCenter(center: base.topCenter, width: u * .9, height: u * .25),
      _fade(const Color(0xFF7D766C), t),
    );
    c.drawOval(
      Rect.fromCenter(
        center: base.topCenter + Offset(0, u * .02),
        width: u * .74,
        height: u * .17,
      ),
      _fade(const Color(0xFF4FC3F7), t),
    );
    c.drawOval(
      Rect.fromCenter(
        center: base.topCenter + Offset(-u * .15, 0),
        width: u * .2,
        height: u * .05,
      ),
      _fade(Colors.white, .6 * t),
    );
    c.drawRRect(baseR, _stroke);
    // Rope and bucket
    c.drawRect(
      Rect.fromLTWH(b.dx - u * .01, base.top - u * .5, u * .02, u * .3),
      _fade(const Color(0xFF6D5238), t),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(b.dx, base.top - u * .17),
          width: u * .16,
          height: u * .14,
        ),
        Radius.circular(u * .03),
      ),
      _fade(const Color(0xFFA1754E), t),
    );
    final roofCol = th.roofs[1];
    final roof = Path()
      ..moveTo(base.left - u * .14, base.top - u * .5)
      ..quadraticBezierTo(
        b.dx - u * .2,
        base.top - u * .72,
        b.dx,
        base.top - u * .98,
      )
      ..quadraticBezierTo(
        b.dx + u * .2,
        base.top - u * .72,
        base.right + u * .14,
        base.top - u * .5,
      )
      ..close();
    c.drawPath(roof, _fade(roofCol, t));
    c.save();
    c.clipPath(roof);
    c.drawRect(
      Rect.fromLTRB(b.dx, base.top - u, base.right + u, base.top),
      _fade(const Color(0x2A000000), t),
    );
    c.drawRect(
      Rect.fromLTWH(
        base.left - u * .2,
        base.top - u * .7,
        base.width + u * .4,
        u * .04,
      ),
      _fade(const Color(0x33FFFFFF), t),
    );
    c.restore();
    c.drawPath(roof, _stroke);
  }

  void _shed(Canvas c, Offset b) {
    final t = p('shed');
    if (t < 1) {
      // Scattered broken planks
      final plank = _fade(const Color(0xFF9C7654), 1 - t);
      final dark = _fade(const Color(0xFF6D4C33), 1 - t);
      for (final (dx, dy, len, a) in [
        (-.1, -.05, .8, -.25),
        (.15, 0.0, .7, .1),
        (.05, -.12, .45, 1.1),
      ]) {
        c.save();
        c.translate(b.dx + dx * u, b.dy + dy * u);
        c.rotate(a);
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: len * u, height: u * .13),
          Radius.circular(u * .04),
        );
        c.drawRRect(
          r.shift(Offset(0, u * .04)),
          _fade(const Color(0x33000000), 1 - t),
        );
        c.drawRRect(r, plank);
        c.drawCircle(Offset(-len * u * .38, 0), u * .02, dark);
        c.drawCircle(Offset(len * u * .38, 0), u * .02, dark);
        c.restore();
      }
    }
    if (t <= 0) return;
    final body = Rect.fromLTRB(
      b.dx - u * .5,
      b.dy - u * .65 * t,
      b.dx + u * .5,
      b.dy,
    );
    c.drawRect(body, _fade(const Color(0xFFD7A86E), t));
    // Vertical siding
    for (var k = 0; k < 5; k++) {
      if (k.isOdd) {
        c.drawRect(
          Rect.fromLTWH(body.left + k * u * .2, body.top, u * .2, body.height),
          _fade(const Color(0xFFC4955C), t),
        );
      }
    }
    c.drawRect(
      Rect.fromLTRB(b.dx + u * .25, body.top, body.right, b.dy),
      _fade(const Color(0x22000000), t),
    );
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(b.dx - u * .15, b.dy - u * .42 * t, b.dx + u * .15, b.dy),
        topLeft: Radius.circular(u * .06),
        topRight: Radius.circular(u * .06),
      ),
      _fade(const Color(0xFF8D5A2B), t),
    );
    c.drawRect(body, _stroke);
    final roofCol = th.roofs[2];
    final roof = Path()
      ..moveTo(body.left - u * .15, body.top + u * .04)
      ..lineTo(b.dx, body.top - u * .45 * t)
      ..lineTo(body.right + u * .15, body.top + u * .04)
      ..close();
    c.drawPath(roof, _fade(roofCol, t));
    c.save();
    c.clipPath(roof);
    c.drawRect(
      Rect.fromLTRB(b.dx, body.top - u, body.right + u, body.top + u),
      _fade(const Color(0x2A000000), t),
    );
    c.restore();
    c.drawPath(roof, _stroke);
  }

  void _bridge(Canvas c, Offset b) {
    final t = p('bridge');
    final span = u * 1.3;
    if (t < 1) {
      // Broken plank stubs on both banks
      final broken = _fade(const Color(0xFF8D6E63), 1 - t);
      for (final (x, wd, a) in [
        (b.dx - span / 2, u * .32, -.15),
        (b.dx + span / 2 - u * .3, u * .26, .2),
      ]) {
        c.save();
        c.translate(x + wd / 2, b.dy);
        c.rotate(a);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: wd, height: u * .16),
            Radius.circular(u * .04),
          ),
          broken,
        );
        c.restore();
      }
    }
    if (t <= 0) return;
    final arch = Path()
      ..moveTo(b.dx - span / 2, b.dy)
      ..quadraticBezierTo(b.dx, b.dy - u * .5 * t, b.dx + span / 2, b.dy);
    final m = arch.computeMetrics().first;
    // Deck shadow, then individual planks along the arch
    c.drawPath(
      arch.shift(Offset(0, u * .08)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .26
        ..color = const Color(0x33000000).withValues(alpha: .2 * t),
    );
    const n = 9;
    for (var k = 0; k < n; k++) {
      final tan = m.getTangentForOffset(m.length * (k + .5) / n);
      if (tan == null) continue;
      c.save();
      c.translate(tan.position.dx, tan.position.dy);
      c.rotate(-tan.angle);
      final plank = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: m.length / n - u * .02,
          height: u * .26,
        ),
        Radius.circular(u * .03),
      );
      c.drawRRect(
        plank,
        _fade(k.isEven ? const Color(0xFFC4955C) : const Color(0xFFB0835A), t),
      );
      c.drawRect(
        Rect.fromLTWH(-m.length / n / 2, u * .06, m.length / n, u * .07),
        _fade(const Color(0x22000000), t),
      );
      c.restore();
    }
    final rail = Path()
      ..moveTo(b.dx - span / 2, b.dy - u * .3)
      ..quadraticBezierTo(
        b.dx,
        b.dy - u * .8 * t,
        b.dx + span / 2,
        b.dy - u * .3,
      );
    final railCol = _fade(const Color(0xFF7A4B2A), t);
    final rm = rail.computeMetrics().first;
    for (var k = 0; k <= 4; k++) {
      final tan = rm.getTangentForOffset(rm.length * k / 4);
      if (tan == null) continue;
      final deck = m.getTangentForOffset(m.length * k / 4)!.position;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            tan.position.dx - u * .035,
            tan.position.dy,
            tan.position.dx + u * .035,
            deck.dy,
          ),
          Radius.circular(u * .03),
        ),
        railCol,
      );
    }
    c.drawPath(ribbon(rail, u * .08, u * .08), railCol);
  }

  void _garden(Canvas c, Offset b) {
    final t = p('garden');
    final bed = Rect.fromCenter(center: b, width: u * 1.5, height: u * .6);
    // Stone border around the bed
    for (var i = 0; i < 14; i++) {
      final a = i * pi * 2 / 14;
      c.drawOval(
        Rect.fromCenter(
          center:
              bed.center +
              Offset(cos(a) * bed.width / 2, sin(a) * bed.height / 2),
          width: u * .2,
          height: u * .13,
        ),
        Paint()
          ..color = i.isEven
              ? const Color(0xFFC9C1B4)
              : const Color(0xFFB0A89C),
      );
    }
    c.drawOval(
      bed.deflate(u * .04),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0xFFA1887F), const Color(0xFF8D6E63), t)!,
            Color.lerp(const Color(0xFF8D7A70), const Color(0xFF6D5238), t)!,
          ],
        ).createShader(bed),
    );
    if (t <= 0) {
      // Dry, withered sprigs
      final twig = Paint()..color = const Color(0xFF6D4C41);
      for (final (dx, lean) in [(-.3, -.3), (0.0, .1), (.28, .35)]) {
        final o = b + Offset(u * dx, u * .05);
        final tip = o + Offset(u * lean * .5, -u * .3);
        c.drawPath(ribbon(curve(o, tip, .2), u * .05, u * .015), twig);
        c.drawPath(
          ribbon(
            curve(o + (tip - o) * .5, tip + Offset(u * .12, 0), -.2),
            u * .03,
            0,
          ),
          twig,
        );
      }
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
        final head = o + Offset(sway, -u * .28 * t);
        c.drawPath(
          ribbon(curve(o, head, .1), u * .05, u * .025),
          Paint()..color = const Color(0xFF4F9E43),
        );
        paintLeaf(
          c,
          o + Offset(0, -u * .08 * t),
          i.isEven ? -pi * .8 : -pi * .2,
          u * .16 * t,
          const Color(0xFF8BD66F),
          const Color(0xFF4F9E43),
        );
        paintFlower(
          c,
          head,
          u * .12 * t,
          colors[i % colors.length],
          const Color(0xFFFFF59D),
          i * .7,
        );
        i++;
      }
    }
  }

  void _nest(Canvas c, Offset b) {
    final t = p('nest');
    final stick = Paint()..color = const Color(0xFF8D6E63);
    if (t < 1) {
      stick.color = stick.color.withValues(alpha: 1 - t);
      for (final (ax, ay, bx, by) in [
        (-.5, 0.0, -.1, -.1),
        (.1, .05, .45, -.05),
        (-.2, .1, .2, .12),
      ]) {
        c.drawPath(
          ribbon(
            curve(b + Offset(ax * u, ay * u), b + Offset(bx * u, by * u), .1),
            u * .08,
            u * .04,
          ),
          stick,
        );
      }
    }
    if (t <= 0) return;
    final nest = Rect.fromCenter(
      center: b,
      width: u * 1.4 * t,
      height: u * .6 * t,
    );
    c.drawOval(
      nest.shift(Offset(0, u * .08)),
      Paint()..color = const Color(0x33000000),
    );
    c.drawOval(nest, Paint()..color = const Color(0xFF9C7A54));
    c.drawOval(
      nest.deflate(u * .12 * t),
      Paint()..color = const Color(0xFF6D5238),
    );
    // Woven twigs around the rim
    final rnd = Random(8);
    for (var k = 0; k < 16; k++) {
      final a = k * pi * 2 / 16 + rnd.nextDouble() * .2;
      final o =
          nest.center +
          Offset(cos(a) * nest.width * .44, sin(a) * nest.height * .42);
      final d = Offset(-sin(a) * nest.width, cos(a) * nest.height) * .12;
      c.drawPath(
        ribbon(
          curve(o - d, o + d, rnd.nextDouble() * .3 - .15),
          u * .05 * t,
          u * .03 * t,
        ),
        Paint()
          ..color = k.isEven
              ? const Color(0xFFB8946A)
              : const Color(0xFF7D5E40),
      );
    }
    c.drawOval(nest, _stroke);
    for (final (dx, col) in [
      (-.25, const Color(0xFFFFF4DC)),
      (.05, const Color(0xFFD7FFF3)),
      (.3, const Color(0xFFFFE9B0)),
    ]) {
      final egg = Rect.fromCenter(
        center: b + Offset(dx * u, -u * .12 * t),
        width: u * .25 * t,
        height: u * .32 * t,
      );
      c.drawOval(egg, Paint()..color = col);
      c.drawOval(
        Rect.fromLTWH(
          egg.left + egg.width * .2,
          egg.top + egg.height * .15,
          egg.width * .3,
          egg.height * .25,
        ),
        Paint()..color = Colors.white.withValues(alpha: .7),
      );
      for (final (sx, sy) in [(.6, .5), (.4, .7), (.7, .75)]) {
        c.drawCircle(
          Offset(egg.left + egg.width * sx, egg.top + egg.height * sy),
          u * .018 * t,
          Paint()..color = const Color(0x44795548),
        );
      }
    }
  }

  void _lanterns(Canvas c) {
    final t = p('lanterns');
    for (final (x, y) in [(.1, .56), (.47, .62), (.9, .56), (.66, .5)]) {
      final base = at(x, y);
      c.drawOval(
        Rect.fromCenter(center: base, width: u * .3, height: u * .1),
        Paint()..color = const Color(0x33000000),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            base.dx - u * .03,
            base.dy - u * .75,
            base.dx + u * .03,
            base.dy,
          ),
          Radius.circular(u * .03),
        ),
        Paint()..color = const Color(0xFF5D4037),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: base - Offset(0, u * .04),
            width: u * .14,
            height: u * .08,
          ),
          Radius.circular(u * .03),
        ),
        Paint()..color = const Color(0xFF4A332A),
      );
      final lamp = base - Offset(0, u * .88);
      if (t > 0) {
        final flicker = .75 + .2 * sin(time * 5 + x * 10);
        paintGlow(c, lamp, u * .6, const Color(0xFFFFD54F), flicker * t);
      }
      final glass = RRect.fromRectAndRadius(
        Rect.fromCenter(center: lamp, width: u * .2, height: u * .24),
        Radius.circular(u * .06),
      );
      c.drawRRect(
        glass,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF616161),
            const Color(0xFFFFE082),
            t,
          )!,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: lamp, width: u * .07, height: u * .14),
          Radius.circular(u * .03),
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF4E4E4E),
            const Color(0xFFFFFDE7),
            t,
          )!,
      );
      // Cap and base
      final cap = Path()
        ..moveTo(lamp.dx - u * .15, lamp.dy - u * .11)
        ..quadraticBezierTo(
          lamp.dx,
          lamp.dy - u * .26,
          lamp.dx + u * .15,
          lamp.dy - u * .11,
        )
        ..close();
      c.drawPath(cap, Paint()..color = const Color(0xFF4A332A));
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: lamp + Offset(0, u * .13),
            width: u * .22,
            height: u * .05,
          ),
          Radius.circular(u * .025),
        ),
        Paint()..color = const Color(0xFF4A332A),
      );
    }
  }

  void _vines(Canvas c) {
    final t = 1 - p('vines');
    if (t <= 0) return;
    const clumps = [
      (.22, .47, 1.0),
      (.57, .43, .85),
      (.46, .62, 1.1),
      (.8, .56, .9),
      (.1, .6, .7),
      (.68, .65, .8),
      (.88, .46, .6),
    ];
    if (t < 1) {
      c.saveLayer(null, Paint()..color = Colors.black.withValues(alpha: t));
    }
    for (final (i, (x, y, s)) in clumps.indexed) {
      final o = at(x, y);
      final r = u * s;
      switch (th.overlayStyle) {
        case 'lava':
          _lavaFissure(c, o, r, i);
        case 'ice':
          _frostPatch(c, o, r, i);
        case 'kelp':
          _kelpClump(c, o, r, i);
        case 'brambles':
          _thornClump(c, o, r, i, shadow: true);
        default:
          _thornClump(c, o, r, i, shadow: false);
      }
    }
    if (t < 1) c.restore();
  }

  /// A mound of overgrown weeds (meadow) or shadow brambles, with leaves
  /// and thorny tendrils creeping outward.

  void _thornClump(
    Canvas c,
    Offset o,
    double r,
    int seed, {
    required bool shadow,
  }) {
    final rnd = Random(seed * 13 + 1);
    final base = th.overlay;
    final light = shadow
        ? const Color(0xFF4A3470)
        : Color.lerp(base, const Color(0xFFB5C24A), .45)!;
    final thornCol = shadow ? const Color(0xFFB388FF) : const Color(0xFF2E3A18);
    if (shadow) {
      paintGlow(
        c,
        o,
        r * 1.6,
        const Color(0xFFB388FF),
        .35 + .1 * sin(time * 2 + seed),
      );
    }
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(0, r * .18),
        width: r * 2.1,
        height: r * .6,
      ),
      Paint()..color = const Color(0x33000000),
    );
    // Creeping tendrils
    for (var k = 0; k < 3; k++) {
      final a =
          (k - 1) * 1.1 +
          (rnd.nextDouble() - .5) * .6 +
          (k.isEven ? pi : 0) * .0;
      final dir = Offset(cos(a) * (k == 1 ? 0 : (k == 0 ? -1 : 1)), 0);
      final end =
          o +
          Offset(
            (k - 1) * r * 1.5 + dir.dx * r * .2,
            (rnd.nextDouble() - .3) * r * .4,
          );
      final spine = curve(o, end, (k.isEven ? .35 : -.35));
      c.drawPath(ribbon(spine, r * .14, r * .03), Paint()..color = base);
      final m = spine.computeMetrics().first;
      for (var j = 1; j <= 3; j++) {
        final tan = m.getTangentForOffset(m.length * j / 3.6);
        if (tan == null) continue;
        final n = Offset(-tan.vector.dy, tan.vector.dx) * (j.isEven ? 1 : -1);
        final p0 = tan.position + n * r * .05;
        c.drawPath(
          Path()
            ..moveTo(
              p0.dx - tan.vector.dx * r * .05,
              p0.dy - tan.vector.dy * r * .05,
            )
            ..lineTo(p0.dx + n.dx * r * .12, p0.dy + n.dy * r * .12)
            ..lineTo(
              p0.dx + tan.vector.dx * r * .05,
              p0.dy + tan.vector.dy * r * .05,
            )
            ..close(),
          Paint()..color = thornCol,
        );
        if (!shadow) {
          paintLeaf(
            c,
            tan.position,
            atan2(-n.dy, -n.dx) - .4,
            r * .28,
            light,
            base,
          );
        }
      }
      // Curl at the tip
      c.drawArc(
        Rect.fromCircle(center: end + Offset(0, -r * .08), radius: r * .09),
        0,
        pi * 1.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .04
          ..strokeCap = StrokeCap.round
          ..color = base,
      );
    }
    // The mound itself
    final mound = blobPath(o - Offset(0, r * .15), r * .8, r * .45, seed + 300);
    c.drawPath(mound, Paint()..color = base);
    for (var k = 0; k < 9; k++) {
      final a = -pi + k * pi / 8 + (rnd.nextDouble() - .5) * .3;
      final p0 =
          o - Offset(0, r * .12) + Offset(cos(a) * r * .5, sin(a) * r * .25);
      paintLeaf(
        c,
        p0,
        a - (rnd.nextDouble() * .4),
        r * (.35 + rnd.nextDouble() * .15),
        light,
        base,
      );
    }
    if (shadow) {
      for (var k = 0; k < 3; k++) {
        final bud =
            o + Offset((k - 1) * r * .4, -r * (.45 + (k.isOdd ? .15 : 0)));
        final pulse = .6 + .4 * sin(time * 2.5 + seed + k);
        paintGlow(c, bud, r * .25, const Color(0xFFFF8AD8), .6 * pulse);
        c.drawCircle(bud, r * .06, Paint()..color = const Color(0xFFFFC2EE));
      }
    } else {
      for (var k = 0; k < 4; k++) {
        final p0 =
            o +
            Offset(
              (rnd.nextDouble() - .5) * r * 1.1,
              -r * (.2 + rnd.nextDouble() * .3),
            );
        c.drawPath(
          Path()
            ..moveTo(p0.dx - r * .05, p0.dy)
            ..lineTo(p0.dx, p0.dy - r * .14)
            ..lineTo(p0.dx + r * .05, p0.dy)
            ..close(),
          Paint()..color = thornCol,
        );
      }
    }
  }

  /// A glowing fissure of lava with dark crust, a molten pool and smoke.

  void _lavaFissure(Canvas c, Offset o, double r, int seed) {
    final rnd = Random(seed * 7 + 3);
    const crust = Color(0xFF2A1812);
    final pulse = .8 + .2 * sin(time * 2 + seed);
    // Cooled rock slab
    c.drawPath(
      blobPath(o, r * 1.1, r * .45, seed + 500, lobes: 7),
      Paint()..color = const Color(0x55301A14),
    );
    for (var k = 0; k < 3; k++) {
      final a = -pi / 2 + (k - 1) * 2.1 + (rnd.nextDouble() - .5) * .5;
      final end = o + Offset(cos(a) * r * 1.3, sin(a) * r * .5);
      final pts = jagged(o, end, 3, r * .18, rnd);
      final spine = polyline(pts);
      c.drawPath(
        ribbon(spine, r * .45, r * .1),
        Paint()
          ..color = th.overlay.withValues(alpha: .45 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .15),
      );
      c.drawPath(ribbon(spine, r * .26, r * .05), Paint()..color = crust);
      c.drawPath(
        ribbon(spine, r * .14, r * .02),
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xFFFFF1A8),
              Color(0xFFFFB13D),
              Color(0xFFFF5A1A),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: r * 1.3)),
      );
    }
    // Molten pool
    final pool = blobPath(o, r * .38, r * .2, seed + 700, lobes: 7);
    c.drawPath(pool.shift(Offset(0, r * .04)), Paint()..color = crust);
    c.drawPath(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFFFF4B0),
            Color(0xFFFF9A2E),
            Color(0xFFE0461A),
          ],
          stops: const [0, .5, 1],
        ).createShader(Rect.fromCircle(center: o, radius: r * .4)),
    );
    paintGlow(c, o, r * .9, const Color(0xFFFF8A3D), .4 * pulse);
    final bubble = (time * .7 + seed * .3) % 1;
    c.drawCircle(
      o + Offset(r * .1, 0),
      r * .06 * (1 - bubble),
      Paint()..color = const Color(0xFFFFF4B0),
    );
    // Smoke
    for (var k = 0; k < 2; k++) {
      final ph = (time * .25 + k * .5 + seed * .17) % 1;
      c.drawCircle(
        o + Offset(sin(time + k + seed) * r * .2, -r * (.3 + ph * 1.4)),
        r * (.12 + ph * .2),
        Paint()
          ..color = const Color(0xFF6E5F5A).withValues(alpha: .35 * (1 - ph)),
      );
    }
  }

  /// A frozen patch with a frosty rim and ice shards.

  void _frostPatch(Canvas c, Offset o, double r, int seed) {
    final rnd = Random(seed * 5 + 2);
    final patch = blobPath(o, r * 1.2, r * .5, seed + 800);
    c.drawPath(
      patch.shift(Offset(0, r * .06)),
      Paint()..color = const Color(0x557FA6CF),
    );
    c.drawPath(
      patch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .95),
            th.overlay.withValues(alpha: .85),
            const Color(0xFFBFD8F2).withValues(alpha: .9),
          ],
        ).createShader(Rect.fromCenter(center: o, width: r * 2.4, height: r)),
    );
    c.drawPath(
      patch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .05
        ..color = const Color(0xFF9CC8F0),
    );
    c.drawPath(
      blobPath(o - Offset(r * .35, r * .12), r * .45, r * .1, seed + 900),
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
    // Shards
    for (var k = 0; k < 3; k++) {
      final bx = o.dx + (k - 1) * r * .45 + (rnd.nextDouble() - .5) * r * .2;
      final by = o.dy + r * .05;
      final hh = r * (.45 + rnd.nextDouble() * .35) * (k == 1 ? 1.3 : 1);
      final wd = r * .12;
      final lean = (k - 1) * .25;
      final tip = Offset(bx + lean * hh, by - hh);
      final shard = Path()
        ..moveTo(bx - wd, by)
        ..lineTo(tip.dx - wd * .5, tip.dy + hh * .2)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + wd * .5, tip.dy + hh * .2)
        ..lineTo(bx + wd, by)
        ..close();
      c.drawPath(shard, Paint()..color = const Color(0xFFCFE6FF));
      c.drawPath(
        Path()
          ..moveTo(bx - wd, by)
          ..lineTo(tip.dx - wd * .5, tip.dy + hh * .2)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(bx, by)
          ..close(),
        Paint()..color = Colors.white,
      );
      c.drawPath(shard, _stroke);
    }
    final tw = (sin(time * 2 + seed) + 1) / 2;
    paintSparkle(
      c,
      o + Offset(r * .5, -r * .5),
      r * (.08 + .08 * tw),
      Colors.white,
    );
  }

  /// Swaying seaweed fronds growing out of a sandy mound.

  void _kelpClump(Canvas c, Offset o, double r, int seed) {
    final rnd = Random(seed * 3 + 9);
    final dark = th.overlay;
    final light = Color.lerp(dark, const Color(0xFF9BD86A), .45)!;
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(0, r * .08),
        width: r * 1.8,
        height: r * .45,
      ),
      Paint()..color = const Color(0x33000000),
    );
    for (var k = 0; k < 5; k++) {
      final bx = o.dx + (k - 2) * r * .28;
      final hh = r * (.9 + rnd.nextDouble() * .6) * (k == 2 ? 1.25 : 1);
      final sway = sin(time * 1.3 + k + seed) * r * .25;
      final base = Offset(bx, o.dy);
      final tip = base + Offset(sway + (k - 2) * r * .15, -hh);
      final spine = Path()
        ..moveTo(base.dx, base.dy)
        ..cubicTo(
          base.dx + r * .25,
          base.dy - hh * .35,
          tip.dx - r * .3 - sway * .5,
          base.dy - hh * .7,
          tip.dx,
          tip.dy,
        );
      c.drawPath(
        ribbon(spine, r * .22, r * .04),
        Paint()..color = k.isEven ? dark : light,
      );
      c.drawPath(
        ribbon(spine, r * .05, r * .01),
        Paint()..color = Colors.white.withValues(alpha: .18),
      );
      if (k.isOdd) {
        final m = spine.computeMetrics().first;
        final tan = m.getTangentForOffset(m.length * .6);
        if (tan != null) {
          c.drawCircle(
            tan.position,
            r * .08,
            Paint()..color = const Color(0xFFC8B04A),
          );
          c.drawCircle(
            tan.position - Offset(r * .025, r * .025),
            r * .025,
            Paint()..color = Colors.white.withValues(alpha: .6),
          );
        }
      }
    }
    c.drawPath(
      blobPath(o, r * .75, r * .2, seed + 950),
      Paint()..color = const Color(0xFF9C8A5A),
    );
    for (var k = 0; k < 2; k++) {
      final ph = (time * .4 + k * .5 + seed * .13) % 1;
      c.drawCircle(
        o +
            Offset(
              (k - .5) * r * .5 + sin(time * 2 + k) * r * .08,
              -r * (.4 + ph * 1.4),
            ),
        r * .06,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .025
          ..color = Colors.white.withValues(alpha: .7 * (1 - ph)),
      );
    }
  }

  @override
  bool shouldRepaint(IslandPainter old) => true;
}

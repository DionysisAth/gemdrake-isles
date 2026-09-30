import 'dart:math';

import 'package:flutter/material.dart';

import 'item_painter.dart';

// Generators added after the MVP. Drawn in a unit square of side [s].

Paint _g(Color a, Color b, double s) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [a, b],
  ).createShader(Rect.fromLTWH(0, 0, s, s));

void paintForge(Canvas c, double s, Paint stroke) {
  // Chimney with smoke
  final chimney = Rect.fromLTWH(s * .6, s * .14, s * .14, s * .3);
  c.drawRect(chimney, _g(const Color(0xFF8D7B76), const Color(0xFF5A4A46), s));
  c.drawRect(chimney, stroke);
  for (var i = 0; i < 3; i++) {
    c.drawCircle(
      Offset(s * (.68 + i * .04), s * (.1 - i * .03)),
      s * (.05 + i * .015),
      Paint()..color = Colors.white.withValues(alpha: .5 - i * .12),
    );
  }
  // Stone furnace
  final body = Path()
    ..moveTo(s * .12, s * .86)
    ..lineTo(s * .16, s * .4)
    ..quadraticBezierTo(s * .5, s * .26, s * .84, s * .4)
    ..lineTo(s * .88, s * .86)
    ..close();
  c.drawPath(body, _g(const Color(0xFFA1887F), const Color(0xFF5D4037), s));
  final brick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * .012
    ..color = const Color(0x33000000);
  for (var y = .5; y < .86; y += .1) {
    c.drawLine(Offset(s * .16, s * y), Offset(s * .86, s * y), brick);
  }
  c.drawPath(body, stroke);
  // Fire mouth
  final mouth = Path()
    ..moveTo(s * .32, s * .86)
    ..lineTo(s * .32, s * .62)
    ..quadraticBezierTo(s * .5, s * .48, s * .68, s * .62)
    ..lineTo(s * .68, s * .86)
    ..close();
  c.drawPath(mouth, Paint()..color = const Color(0xFF2B1A14));
  paintGlow(c, Offset(s * .5, s * .78), s * .22, const Color(0xFFFF8A3D), .95);
  for (final (x, h) in [(.42, .14), (.5, .2), (.58, .13)]) {
    c.drawPath(
      Path()
        ..moveTo(s * (x - .05), s * .86)
        ..quadraticBezierTo(s * x, s * (.86 - h * 1.4), s * (x + .05), s * .86)
        ..close(),
      Paint()..color = const Color(0xFFFFB347),
    );
  }
}

void paintTidePool(Canvas c, double s, Paint stroke) {
  final rim = Rect.fromCenter(
    center: Offset(s * .5, s * .66),
    width: s * .84,
    height: s * .42,
  );
  c.drawOval(rim, _g(const Color(0xFFB0A89C), const Color(0xFF7A726A), s));
  c.drawOval(rim, stroke);
  final water = rim.deflate(s * .07);
  c.drawOval(water, _g(const Color(0xFF80DEEA), const Color(0xFF26A6C4), s));
  c.drawArc(
    water.deflate(s * .05),
    pi * 1.1,
    pi * .5,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .025
      ..color = Colors.white.withValues(alpha: .7),
  );
  // Starfish and shell
  final star = Path();
  final o = Offset(s * .36, s * .68);
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? s * .09 : s * .04;
    final a = -pi / 2 + i * pi / 5;
    final pt = o + Offset(cos(a), sin(a)) * r;
    i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
  }
  c.drawPath(star..close(), Paint()..color = const Color(0xFFFF8A65));
  c.drawCircle(
    Offset(s * .64, s * .64),
    s * .06,
    Paint()..color = const Color(0xFFFFD1DC),
  );
  // Seaweed
  final weed = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * .04
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF43A047);
  for (final x in [.2, .8]) {
    c.drawPath(
      Path()
        ..moveTo(s * x, s * .56)
        ..quadraticBezierTo(s * (x - .06), s * .4, s * x, s * .26),
      weed,
    );
  }
}

void paintCavern(Canvas c, double s, Paint stroke) {
  final rock = Path()
    ..moveTo(s * .06, s * .88)
    ..lineTo(s * .14, s * .44)
    ..lineTo(s * .34, s * .22)
    ..lineTo(s * .56, s * .3)
    ..lineTo(s * .74, s * .18)
    ..lineTo(s * .9, s * .46)
    ..lineTo(s * .94, s * .88)
    ..close();
  c.drawPath(rock, _g(const Color(0xFFB8B0D6), const Color(0xFF5E568A), s));
  c.drawPath(rock, stroke);
  final cave = Path()
    ..moveTo(s * .3, s * .88)
    ..quadraticBezierTo(s * .3, s * .5, s * .5, s * .48)
    ..quadraticBezierTo(s * .7, s * .5, s * .7, s * .88)
    ..close();
  c.drawPath(cave, Paint()..color = const Color(0xFF231B3D));
  paintGlow(c, Offset(s * .5, s * .76), s * .2, const Color(0xFFD7A6FF), .9);
  for (final (x, y, h, col) in [
    (.22, .5, .16, const Color(0xFFD7A6FF)),
    (.8, .52, .18, const Color(0xFF80DEEA)),
    (.62, .3, .12, const Color(0xFFB39DFF)),
  ]) {
    final base = Offset(s * x, s * y);
    final p = Path()
      ..moveTo(base.dx - s * .04, base.dy)
      ..lineTo(base.dx, base.dy - s * h)
      ..lineTo(base.dx + s * .04, base.dy)
      ..close();
    c.drawPath(p, Paint()..color = col);
    c.drawPath(p, stroke);
  }
}

void paintStarWell(Canvas c, double s, Paint stroke) {
  paintGlow(c, Offset(s * .5, s * .36), s * .42, const Color(0xFFB388FF), .7);
  final base = RRect.fromRectAndRadius(
    Rect.fromLTWH(s * .16, s * .52, s * .68, s * .34),
    Radius.circular(s * .06),
  );
  c.drawRRect(base, _g(const Color(0xFF7E6FB0), const Color(0xFF3A2E5C), s));
  final brick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * .012
    ..color = const Color(0x44000000);
  c.drawLine(Offset(s * .16, s * .68), Offset(s * .84, s * .68), brick);
  c.drawRRect(base, stroke);
  c.drawOval(
    Rect.fromCenter(
      center: Offset(s * .5, s * .52),
      width: s * .68,
      height: s * .16,
    ),
    Paint()..color = const Color(0xFF1A1045),
  );
  // Starlight rising
  for (var i = 0; i < 6; i++) {
    final o = Offset(s * (.32 + (i % 3) * .18), s * (.44 - (i ~/ 3) * .16));
    paintSparkle(
      c,
      o,
      s * (.05 + (i % 2) * .03),
      i.isEven ? const Color(0xFFFFF59D) : Colors.white,
    );
  }
}

void paintBlossomTree(Canvas c, double s, Paint stroke) {
  final pot = Path()
    ..moveTo(s * .3, s * .66)
    ..lineTo(s * .7, s * .66)
    ..lineTo(s * .64, s * .88)
    ..lineTo(s * .36, s * .88)
    ..close();
  c.drawRect(
    Rect.fromLTWH(s * .46, s * .42, s * .08, s * .26),
    Paint()..color = const Color(0xFF8A5A33),
  );
  for (final (x, y, r) in [
    (.5, .3, .22),
    (.3, .42, .16),
    (.7, .42, .16),
    (.5, .46, .16),
  ]) {
    c.drawCircle(
      Offset(s * x, s * y),
      s * r,
      Paint()..color = const Color(0xFFFF9EC7),
    );
  }
  for (final (x, y) in [(.4, .26), (.62, .3), (.3, .44), (.7, .46)]) {
    c.drawCircle(
      Offset(s * x, s * y),
      s * .04,
      Paint()..color = const Color(0xFFFFF0F6),
    );
  }
  c.drawPath(pot, _g(const Color(0xFFFFB74D), const Color(0xFFE65100), s));
  c.drawPath(pot, stroke);
  paintSparkle(c, Offset(s * .82, s * .2), s * .05);
}

void paintLanternStall(Canvas c, double s, Paint stroke) {
  final counter = RRect.fromRectAndRadius(
    Rect.fromLTWH(s * .12, s * .58, s * .76, s * .28),
    Radius.circular(s * .04),
  );
  c.drawRRect(counter, _g(const Color(0xFFD69A5E), const Color(0xFF8A5A33), s));
  c.drawRRect(counter, stroke);
  // Striped awning
  for (var i = 0; i < 5; i++) {
    final r = Rect.fromLTWH(s * (.1 + i * .16), s * .18, s * .16, s * .16);
    c.drawRect(
      r,
      Paint()..color = i.isEven ? const Color(0xFFE53935) : Colors.white,
    );
  }
  c.drawRect(Rect.fromLTWH(s * .1, s * .18, s * .8, s * .16), stroke);
  final post = Paint()..color = const Color(0xFF6D4C41);
  c.drawRect(Rect.fromLTWH(s * .14, s * .34, s * .04, s * .26), post);
  c.drawRect(Rect.fromLTWH(s * .82, s * .34, s * .04, s * .26), post);
  for (final (x, col) in [
    (.34, const Color(0xFFFFB300)),
    (.5, const Color(0xFFE53935)),
    (.66, const Color(0xFF8E24AA)),
  ]) {
    final o = Offset(s * x, s * .46);
    paintGlow(c, o, s * .12, const Color(0xFFFFD166), .7);
    c.drawOval(
      Rect.fromCenter(center: o, width: s * .1, height: s * .12),
      Paint()..color = col,
    );
  }
}

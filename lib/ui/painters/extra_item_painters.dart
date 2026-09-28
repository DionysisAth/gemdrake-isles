import 'dart:math';

import 'package:flutter/material.dart';

import 'item_painter.dart';

// Procedural art for the chains added after the MVP: treasure, tools,
// shells, geodes, starlight, legendary eggs and the festival chains.
// Everything is drawn in a unit square of side [s].

Paint _stroke(double s) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..strokeWidth = max(1.0, s * .025)
  ..color = const Color(0x55301E4F);

Paint _grad(Color a, Color b, Rect r, {bool vertical = false}) =>
    Paint()
      ..shader = LinearGradient(
        begin: vertical ? Alignment.topCenter : Alignment.topLeft,
        end: vertical ? Alignment.bottomCenter : Alignment.bottomRight,
        colors: [a, b],
      ).createShader(r);

void _shadow(Canvas c, double s, double width) => c.drawOval(
  Rect.fromCenter(
    center: Offset(s * .5, s * .88),
    width: width,
    height: s * .09,
  ),
  Paint()..color = Colors.black.withValues(alpha: .16),
);

void _highlight(Canvas c, Offset o, double w, double h) => c.drawOval(
  Rect.fromCenter(center: o, width: w, height: h),
  Paint()..color = Colors.white.withValues(alpha: .55),
);

Path _star(
  Offset c,
  double outer,
  double inner, [
  int points = 5,
  double rot = -pi / 2,
]) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = rot + i * pi / points;
    final pt = c + Offset(cos(a), sin(a)) * r;
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

Path _heart(double cx, double cy, double w, double h) => Path()
  ..moveTo(cx, cy + h * .5)
  ..cubicTo(
    cx - w * .8,
    cy + h * .05,
    cx - w * .7,
    cy - h * .5,
    cx - w * .3,
    cy - h * .5,
  )
  ..cubicTo(cx - w * .1, cy - h * .5, cx, cy - h * .3, cx, cy - h * .2)
  ..cubicTo(cx, cy - h * .3, cx + w * .1, cy - h * .5, cx + w * .3, cy - h * .5)
  ..cubicTo(
    cx + w * .7,
    cy - h * .5,
    cx + w * .8,
    cy + h * .05,
    cx,
    cy + h * .5,
  )
  ..close();

void _coin(Canvas c, Offset o, double r, double s) {
  c.drawCircle(o, r, Paint()..color = const Color(0xFFD99A0B));
  c.drawCircle(
    o,
    r * .86,
    _grad(
      const Color(0xFFFFE27A),
      const Color(0xFFF2A516),
      Rect.fromCircle(center: o, radius: r),
    ),
  );
  c.drawCircle(
    o,
    r * .55,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .12
      ..color = const Color(0xFFE39B10),
  );
  _highlight(c, o + Offset(-r * .35, -r * .4), r * .5, r * .28);
  c.drawCircle(o, r, _stroke(s));
}

// ---------------------------------------------------------------------------

void paintTreasure(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  if (level >= 3) {
    paintGlow(
      c,
      Offset(s * .5, s * .5),
      s * .5,
      const Color(0xFFFFD54F),
      .2 + level * .1,
    );
  }
  _shadow(c, s, s * (.35 + level * .08));
  switch (level) {
    case 1:
      _coin(c, Offset(s * .5, s * .55), s * .24, s);
      paintSparkle(c, Offset(s * .72, s * .32), s * .05);
    case 2:
      for (var i = 0; i < 4; i++) {
        final y = s * (.76 - i * .1);
        final r = Rect.fromCenter(
          center: Offset(s * .5 + (i.isOdd ? s * .02 : 0), y),
          width: s * .5,
          height: s * .16,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            r.shift(Offset(0, s * .04)),
            Radius.circular(s * .08),
          ),
          Paint()..color = const Color(0xFFC98A0A),
        );
        c.drawOval(
          r,
          _grad(const Color(0xFFFFE27A), const Color(0xFFF2A516), r),
        );
        c.drawOval(r, stroke);
      }
      paintSparkle(c, Offset(s * .74, s * .36), s * .05);
    case 3:
      final bag = Path()
        ..moveTo(s * .4, s * .34)
        ..quadraticBezierTo(s * .14, s * .5, s * .2, s * .76)
        ..quadraticBezierTo(s * .5, s * .92, s * .8, s * .76)
        ..quadraticBezierTo(s * .86, s * .5, s * .6, s * .34)
        ..close();
      c.drawPath(
        bag,
        _grad(
          const Color(0xFFC89A6A),
          const Color(0xFF8A5E36),
          Rect.fromLTWH(0, s * .3, s, s * .6),
        ),
      );
      c.drawPath(bag, stroke);
      // Tie and flaps
      c.drawPath(
        Path()
          ..moveTo(s * .36, s * .24)
          ..lineTo(s * .5, s * .34)
          ..lineTo(s * .64, s * .24)
          ..lineTo(s * .58, s * .36)
          ..lineTo(s * .42, s * .36)
          ..close(),
        Paint()..color = const Color(0xFFB0835A),
      );
      c.drawRect(
        Rect.fromLTWH(s * .4, s * .33, s * .2, s * .05),
        Paint()..color = const Color(0xFFE0B040),
      );
      _coin(c, Offset(s * .5, s * .62), s * .11, s);
      _coin(c, Offset(s * .7, s * .8), s * .08, s);
    default:
      // Treasure chest
      final body = Rect.fromLTWH(s * .16, s * .46, s * .68, s * .36);
      final lid = Path()
        ..moveTo(s * .16, s * .48)
        ..lineTo(s * .16, s * .38)
        ..quadraticBezierTo(s * .5, s * .16, s * .84, s * .38)
        ..lineTo(s * .84, s * .48)
        ..close();
      c.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(s * .04)),
        _grad(
          const Color(0xFFB57B45),
          const Color(0xFF7A4B2A),
          body,
          vertical: true,
        ),
      );
      c.drawPath(
        lid,
        _grad(
          const Color(0xFFC9905A),
          const Color(0xFF8A5A33),
          Rect.fromLTWH(0, s * .2, s, s * .3),
          vertical: true,
        ),
      );
      final gold = Paint()..color = const Color(0xFFFFCB2E);
      for (final x in [.24, .72]) {
        c.drawRect(Rect.fromLTWH(s * x, s * .3, s * .06, s * .52), gold);
      }
      c.drawRect(Rect.fromLTWH(s * .16, s * .46, s * .68, s * .05), gold);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s * .5, s * .52),
            width: s * .14,
            height: s * .16,
          ),
          Radius.circular(s * .03),
        ),
        Paint()..color = const Color(0xFFFFE27A),
      );
      c.drawCircle(
        Offset(s * .5, s * .53),
        s * .025,
        Paint()..color = const Color(0xFF7A4B2A),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(s * .04)),
        stroke,
      );
      c.drawPath(lid, stroke);
      paintSparkle(c, Offset(s * .8, s * .24), s * .07);
      paintSparkle(c, Offset(s * .2, s * .26), s * .045);
  }
}

// ---------------------------------------------------------------------------

void paintTool(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  if (level >= 4) {
    paintGlow(c, Offset(s * .5, s * .55), s * .5, const Color(0xFFFF8A3D), .35);
  }
  _shadow(c, s, s * (.3 + level * .08));
  final metal = _grad(
    const Color(0xFFE3E7EE),
    const Color(0xFF8C96A8),
    Rect.fromLTWH(0, 0, s, s),
  );
  final wood = _grad(
    const Color(0xFFD69A5E),
    const Color(0xFF8A5A33),
    Rect.fromLTWH(0, 0, s, s),
  );
  switch (level) {
    case 1:
      c.save();
      c.translate(s * .5, s * .55);
      c.rotate(-.7);
      final shaft = RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * .04, -s * .28, s * .08, s * .5),
        Radius.circular(s * .02),
      );
      c.drawRRect(shaft, metal);
      c.drawRRect(shaft, stroke);
      final head = RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * .12, -s * .32, s * .24, s * .07),
        Radius.circular(s * .03),
      );
      c.drawRRect(head, metal);
      c.drawRRect(head, stroke);
      c.drawPath(
        Path()
          ..moveTo(-s * .04, s * .22)
          ..lineTo(0, s * .3)
          ..lineTo(s * .04, s * .22)
          ..close(),
        metal,
      );
      c.restore();
    case 2:
      c.save();
      c.translate(s * .5, s * .55);
      c.rotate(-.6);
      final handle = RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * .05, -s * .15, s * .1, s * .5),
        Radius.circular(s * .04),
      );
      c.drawRRect(handle, wood);
      c.drawRRect(handle, stroke);
      final head = RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * .22, -s * .3, s * .44, s * .16),
        Radius.circular(s * .04),
      );
      c.drawRRect(head, metal);
      c.drawRRect(head, stroke);
      c.restore();
    case 3:
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .14, s * .44, s * .72, s * .38),
        Radius.circular(s * .06),
      );
      // Tools peeking out
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .28, s * .24, s * .07, s * .3),
          Radius.circular(s * .03),
        ),
        wood,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .2, s * .2, s * .24, s * .08),
          Radius.circular(s * .03),
        ),
        metal,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .6, s * .26, s * .06, s * .28),
          Radius.circular(s * .02),
        ),
        metal,
      );
      c.drawRRect(
        box,
        _grad(
          const Color(0xFFFF6B6B),
          const Color(0xFFC0392B),
          box.outerRect,
          vertical: true,
        ),
      );
      c.drawRect(
        Rect.fromLTWH(s * .14, s * .54, s * .72, s * .05),
        Paint()..color = const Color(0x33000000),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .44, s * .5, s * .12, s * .08),
          Radius.circular(s * .02),
        ),
        Paint()..color = const Color(0xFFFFD166),
      );
      c.drawRRect(box, stroke);
    case 4:
      // Anvil
      final anvil = Path()
        ..moveTo(s * .1, s * .36)
        ..lineTo(s * .86, s * .36)
        ..quadraticBezierTo(s * .8, s * .5, s * .66, s * .5)
        ..lineTo(s * .62, s * .64)
        ..lineTo(s * .74, s * .8)
        ..lineTo(s * .26, s * .8)
        ..lineTo(s * .38, s * .64)
        ..lineTo(s * .34, s * .5)
        ..quadraticBezierTo(s * .16, s * .48, s * .1, s * .36)
        ..close();
      c.drawPath(
        anvil,
        _grad(
          const Color(0xFF7D8596),
          const Color(0xFF3D4452),
          Rect.fromLTWH(0, s * .3, s, s * .5),
        ),
      );
      c.drawRect(
        Rect.fromLTWH(s * .14, s * .34, s * .7, s * .04),
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
      paintGlow(
        c,
        Offset(s * .55, s * .33),
        s * .16,
        const Color(0xFFFFB347),
        .9,
      );
      c.drawPath(anvil, stroke);
    default:
      // Workbench
      final top = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .08, s * .42, s * .84, s * .12),
        Radius.circular(s * .03),
      );
      final leg = Paint()..color = const Color(0xFF8A5A33);
      c.drawRect(Rect.fromLTWH(s * .16, s * .52, s * .08, s * .32), leg);
      c.drawRect(Rect.fromLTWH(s * .76, s * .52, s * .08, s * .32), leg);
      c.drawRect(Rect.fromLTWH(s * .2, s * .7, s * .6, s * .05), leg);
      c.drawRRect(top, wood);
      c.drawRRect(top, stroke);
      // Tools on top
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .2, s * .3, s * .22, s * .12),
          Radius.circular(s * .03),
        ),
        Paint()..color = const Color(0xFFE74C3C),
      );
      c.save();
      c.translate(s * .66, s * .34);
      c.rotate(.4);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-s * .03, -s * .14, s * .06, s * .22),
          Radius.circular(s * .02),
        ),
        wood,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-s * .1, -s * .18, s * .2, s * .07),
          Radius.circular(s * .02),
        ),
        metal,
      );
      c.restore();
      paintSparkle(
        c,
        Offset(s * .84, s * .26),
        s * .06,
        const Color(0xFFFFE082),
      );
  }
}

// ---------------------------------------------------------------------------

void paintShell(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  if (level >= 4) {
    paintGlow(
      c,
      Offset(s * .5, s * .55),
      s * .5,
      const Color(0xFFB3F5FF),
      .3 + level * .06,
    );
  }
  _shadow(c, s, s * (.3 + level * .07));
  switch (level) {
    case 1:
      final r = Rect.fromCenter(
        center: Offset(s * .5, s * .58),
        width: s * .48,
        height: s * .44,
      );
      c.drawOval(r, _grad(const Color(0xFFF7E7C6), const Color(0xFFD9BE8C), r));
      c.drawPath(
        _star(Offset(s * .5, s * .58), s * .14, s * .05),
        Paint()..color = const Color(0x55A07840),
      );
      c.drawOval(r, stroke);
    case 2:
      final fan = Path()..moveTo(s * .5, s * .8);
      for (var i = 0; i <= 8; i++) {
        final a = pi + i * pi / 8;
        final pt = Offset(
          s * .5 + cos(a) * s * .32,
          s * .56 + sin(a) * s * .32,
        );
        final ctrl = Offset(
          s * .5 + cos(a - pi / 16) * s * .38,
          s * .56 + sin(a - pi / 16) * s * .38,
        );
        i == 0
            ? fan.lineTo(pt.dx, pt.dy)
            : fan.quadraticBezierTo(ctrl.dx, ctrl.dy, pt.dx, pt.dy);
      }
      fan.close();
      c.drawPath(
        fan,
        _grad(
          const Color(0xFFFFD1DC),
          const Color(0xFFF48FB1),
          Rect.fromLTWH(0, s * .2, s, s * .6),
        ),
      );
      final rib = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .015
        ..color = const Color(0x55C2185B);
      for (var i = 1; i < 8; i++) {
        final a = pi + i * pi / 8;
        c.drawLine(
          Offset(s * .5, s * .8),
          Offset(s * .5 + cos(a) * s * .3, s * .56 + sin(a) * s * .3),
          rib,
        );
      }
      c.drawPath(fan, stroke);
    case 3:
      // Conch: spiral cone
      final conch = Path()
        ..moveTo(s * .2, s * .7)
        ..quadraticBezierTo(s * .24, s * .3, s * .56, s * .22)
        ..quadraticBezierTo(s * .86, s * .2, s * .82, s * .46)
        ..quadraticBezierTo(s * .78, s * .7, s * .2, s * .7)
        ..close();
      c.drawPath(
        conch,
        _grad(
          const Color(0xFFFFE0C2),
          const Color(0xFFF4A261),
          Rect.fromLTWH(0, s * .2, s, s * .5),
        ),
      );
      c.drawPath(
        Path()
          ..moveTo(s * .3, s * .62)
          ..quadraticBezierTo(s * .5, s * .52, s * .7, s * .44),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .05
          ..color = const Color(0xFFFF8FAB),
      );
      for (var i = 0; i < 3; i++) {
        c.drawCircle(
          Offset(s * (.62 + i * .06), s * (.28 + i * .04)),
          s * .03,
          Paint()..color = const Color(0x55A0522D),
        );
      }
      c.drawPath(conch, stroke);
    case 4:
      final r = Rect.fromCenter(
        center: Offset(s * .5, s * .58),
        width: s * .64,
        height: s * .44,
      );
      c.drawOval(r, _grad(const Color(0xFFCFC5E8), const Color(0xFF7E6FA8), r));
      c.drawArc(
        r.deflate(s * .06),
        pi * 1.1,
        pi * .8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .02
          ..color = Colors.white.withValues(alpha: .5),
      );
      c.drawLine(
        Offset(r.left + s * .04, s * .58),
        Offset(r.right - s * .04, s * .58),
        Paint()
          ..strokeWidth = s * .025
          ..color = const Color(0xFF4A3F6B),
      );
      paintGlow(c, Offset(s * .5, s * .58), s * .12, Colors.white, .9);
      c.drawOval(r, stroke);
    case 5:
      // Pearl in an open shell
      final shell = Path()
        ..moveTo(s * .14, s * .62)
        ..quadraticBezierTo(s * .5, s * .98, s * .86, s * .62)
        ..close();
      c.drawPath(
        shell,
        _grad(
          const Color(0xFFFFD1DC),
          const Color(0xFFE891A8),
          Rect.fromLTWH(0, s * .6, s, s * .3),
        ),
      );
      c.drawPath(shell, stroke);
      final pearl = Offset(s * .5, s * .5);
      c.drawCircle(
        pearl,
        s * .2,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.4, -.4),
            colors: [Colors.white, Color(0xFFE8E4F5), Color(0xFFB9B0D6)],
          ).createShader(Rect.fromCircle(center: pearl, radius: s * .2)),
      );
      c.drawCircle(pearl, s * .2, stroke);
      paintSparkle(c, Offset(s * .64, s * .36), s * .06);
    default:
      // Pearl crown
      final band = Path()
        ..moveTo(s * .14, s * .74)
        ..lineTo(s * .18, s * .42)
        ..lineTo(s * .34, s * .56)
        ..lineTo(s * .5, s * .3)
        ..lineTo(s * .66, s * .56)
        ..lineTo(s * .82, s * .42)
        ..lineTo(s * .86, s * .74)
        ..close();
      c.drawPath(
        band,
        _grad(
          const Color(0xFFB2EBF2),
          const Color(0xFF26C6DA),
          Rect.fromLTWH(0, s * .3, s, s * .45),
        ),
      );
      c.drawPath(band, stroke);
      for (final (x, y, r) in [
        (.18, .4, .05),
        (.5, .27, .07),
        (.82, .4, .05),
        (.34, .66, .04),
        (.66, .66, .04),
        (.5, .66, .045),
      ]) {
        final o = Offset(s * x, s * y);
        c.drawCircle(o, s * r, Paint()..color = Colors.white);
        c.drawCircle(o, s * r, stroke);
      }
      paintSparkle(c, Offset(s * .74, s * .22), s * .07);
  }
}

// ---------------------------------------------------------------------------

void paintGeode(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  if (level >= 3) {
    paintGlow(
      c,
      Offset(s * .5, s * .52),
      s * .5,
      const Color(0xFFD7A6FF),
      .25 + level * .08,
    );
  }
  _shadow(c, s, s * (.32 + level * .07));
  final rock = _grad(
    const Color(0xFFB3A89A),
    const Color(0xFF6E6358),
    Rect.fromLTWH(0, 0, s, s),
  );
  switch (level) {
    case 1:
      final g = Path()
        ..moveTo(s * .24, s * .7)
        ..quadraticBezierTo(s * .16, s * .42, s * .42, s * .32)
        ..quadraticBezierTo(s * .74, s * .26, s * .8, s * .56)
        ..quadraticBezierTo(s * .78, s * .8, s * .5, s * .8)
        ..close();
      c.drawPath(g, rock);
      for (final o in [
        Offset(s * .38, s * .5),
        Offset(s * .6, s * .62),
        Offset(s * .62, s * .42),
      ]) {
        c.drawCircle(o, s * .03, Paint()..color = const Color(0x33000000));
      }
      c.drawPath(g, stroke);
    case 2:
      final outer = Rect.fromCenter(
        center: Offset(s * .5, s * .58),
        width: s * .66,
        height: s * .5,
      );
      c.drawOval(outer, rock);
      final inner = outer.deflate(s * .07);
      c.drawOval(inner, Paint()..color = const Color(0xFF5E3A8A));
      for (var i = 0; i < 9; i++) {
        final a = i * pi * 2 / 9;
        final o =
            inner.center +
            Offset(cos(a) * inner.width * .32, sin(a) * inner.height * .3);
        c.drawPath(
          _star(o, s * .06, s * .02, 4, a),
          Paint()..color = const Color(0xFFD7A6FF),
        );
      }
      paintGlow(c, inner.center, s * .12, const Color(0xFFE6C8FF), .8);
      c.drawOval(outer, stroke);
    case 3:
      final heart = _heart(s * .5, s * .56, s * .5, s * .56);
      c.drawPath(
        heart,
        _grad(
          const Color(0xFFE6C8FF),
          const Color(0xFF8E44AD),
          Rect.fromLTWH(0, s * .2, s, s * .6),
        ),
      );
      c.drawPath(
        Path()
          ..moveTo(s * .5, s * .36)
          ..lineTo(s * .5, s * .84)
          ..lineTo(s * .28, s * .5)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: .22),
      );
      c.drawPath(heart, stroke);
      paintSparkle(c, Offset(s * .7, s * .34), s * .06);
    case 4:
      // Crystal orb on a stand
      final stand = Path()
        ..moveTo(s * .34, s * .84)
        ..lineTo(s * .4, s * .7)
        ..lineTo(s * .6, s * .7)
        ..lineTo(s * .66, s * .84)
        ..close();
      c.drawPath(
        stand,
        _grad(
          const Color(0xFFFFD166),
          const Color(0xFFC98A0A),
          Rect.fromLTWH(0, s * .7, s, s * .15),
        ),
      );
      c.drawPath(stand, stroke);
      final o = Offset(s * .5, s * .46);
      c.drawCircle(
        o,
        s * .26,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.3, -.3),
            colors: [Color(0xFFF3E5FF), Color(0xFFB39DFF), Color(0xFF5E35B1)],
          ).createShader(Rect.fromCircle(center: o, radius: s * .26)),
      );
      c.drawPath(
        _star(o, s * .1, s * .04, 4),
        Paint()..color = Colors.white.withValues(alpha: .8),
      );
      c.drawCircle(o, s * .26, stroke);
      _highlight(c, o + Offset(-s * .09, -s * .11), s * .1, s * .06);
    default:
      // Prism star with rainbow glow
      final o = Offset(s * .5, s * .5);
      for (final (col, dx) in [
        (const Color(0xFFFF6B6B), -.04),
        (const Color(0xFF4FC3F7), .04),
        (const Color(0xFF9CFF8A), 0.0),
      ]) {
        paintGlow(c, o + Offset(s * dx, 0), s * .42, col, .35);
      }
      final star = _star(o, s * .36, s * .16);
      c.drawPath(
        star,
        Paint()
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFFFB3D9),
              Color(0xFFB3E5FF),
              Color(0xFFD7FFB3),
              Color(0xFFFFF1B3),
              Color(0xFFFFB3D9),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: s * .36)),
      );
      c.drawPath(
        _star(o, s * .18, s * .08),
        Paint()..color = Colors.white.withValues(alpha: .6),
      );
      c.drawPath(star, stroke);
      paintSparkle(c, Offset(s * .82, s * .2), s * .06);
  }
}

// ---------------------------------------------------------------------------

void paintStarlight(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  paintGlow(
    c,
    Offset(s * .5, s * .5),
    s * (.3 + level * .05),
    const Color(0xFFFFF59D),
    .3 + level * .08,
  );
  _shadow(c, s, s * (.3 + level * .06));
  switch (level) {
    case 1:
      final rnd = Random(4);
      for (var i = 0; i < 9; i++) {
        final o = Offset(
          s * (.3 + rnd.nextDouble() * .4),
          s * (.5 + rnd.nextDouble() * .3),
        );
        paintSparkle(
          c,
          o,
          s * (.03 + rnd.nextDouble() * .04),
          i.isEven ? const Color(0xFFFFF59D) : Colors.white,
        );
      }
    case 2:
      final o = Offset(s * .5, s * .54);
      final star = _star(o, s * .3, s * .14);
      c.drawPath(
        star,
        _grad(
          const Color(0xFFFFF59D),
          const Color(0xFFFFB300),
          Rect.fromCircle(center: o, radius: s * .3),
        ),
      );
      c.drawPath(star, stroke);
      // Cute face
      final ink = Paint()..color = const Color(0xFF6D4C41);
      c.drawCircle(o + Offset(-s * .06, -s * .01), s * .025, ink);
      c.drawCircle(o + Offset(s * .06, -s * .01), s * .025, ink);
      c.drawArc(
        Rect.fromCenter(
          center: o + Offset(0, s * .04),
          width: s * .08,
          height: s * .05,
        ),
        .2,
        pi - .4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .018
          ..color = const Color(0xFF6D4C41),
      );
    case 3:
      final o = Offset(s * .5, s * .56);
      final moon = Path()..addOval(Rect.fromCircle(center: o, radius: s * .26));
      final cut = Path()
        ..addOval(
          Rect.fromCircle(
            center: o + Offset(s * .12, -s * .08),
            radius: s * .22,
          ),
        );
      final crescent = Path.combine(PathOperation.difference, moon, cut);
      c.drawLine(
        Offset(s * .44, s * .12),
        Offset(s * .44, s * .32),
        Paint()
          ..strokeWidth = s * .015
          ..color = const Color(0xFFB0BEC5),
      );
      c.drawPath(
        crescent,
        _grad(
          Colors.white,
          const Color(0xFFB0BEC5),
          Rect.fromCircle(center: o, radius: s * .26),
        ),
      );
      c.drawPath(crescent, stroke);
      paintSparkle(c, Offset(s * .7, s * .42), s * .06);
    case 4:
      // Comet with tail
      final head = Offset(s * .64, s * .4);
      final tail = Path()
        ..moveTo(head.dx - s * .08, head.dy - s * .08)
        ..quadraticBezierTo(s * .3, s * .5, s * .12, s * .82)
        ..quadraticBezierTo(
          s * .4,
          s * .66,
          head.dx + s * .06,
          head.dy + s * .1,
        )
        ..close();
      c.drawPath(
        tail,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFF80DEEA),
              const Color(0xFF80DEEA).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, s * .3, s * .8, s * .6)),
      );
      c.drawCircle(
        head,
        s * .14,
        _grad(
          Colors.white,
          const Color(0xFF4FC3F7),
          Rect.fromCircle(center: head, radius: s * .14),
        ),
      );
      c.drawCircle(head, s * .14, stroke);
      paintSparkle(c, Offset(s * .82, s * .22), s * .05);
    default:
      // Galaxy orb
      final o = Offset(s * .5, s * .52);
      c.drawCircle(
        o,
        s * .3,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFE0F5), Color(0xFF7C4DFF), Color(0xFF1A1045)],
            stops: [0, .45, 1],
          ).createShader(Rect.fromCircle(center: o, radius: s * .3)),
      );
      final swirl = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .03
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xAAFFB3F5);
      c.drawArc(
        Rect.fromCircle(center: o, radius: s * .18),
        0,
        pi * 1.2,
        false,
        swirl,
      );
      c.drawArc(
        Rect.fromCircle(center: o, radius: s * .1),
        pi,
        pi * 1.2,
        false,
        swirl,
      );
      final rnd = Random(9);
      for (var i = 0; i < 8; i++) {
        final a = rnd.nextDouble() * pi * 2;
        final r = rnd.nextDouble() * s * .25;
        c.drawCircle(
          o + Offset(cos(a), sin(a)) * r,
          s * .012,
          Paint()..color = Colors.white,
        );
      }
      c.drawCircle(o, s * .3, stroke);
      _highlight(c, o + Offset(-s * .11, -s * .13), s * .12, s * .07);
      paintSparkle(c, Offset(s * .84, s * .2), s * .06);
  }
}

// ---------------------------------------------------------------------------

void paintLegendEgg(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  final glow = [
    const Color(0xFF7C9CFF),
    const Color(0xFFB388FF),
    const Color(0xFFFFD166),
  ][level - 1];
  paintGlow(
    c,
    Offset(s * .5, s * .52),
    s * (.46 + level * .05),
    glow,
    .5 + level * .12,
  );
  _shadow(c, s, s * .42);
  final w = s * (.5 + level * .03), h = s * (.64 + level * .03);
  final top = s * .86 - h;
  final egg = Path()
    ..moveTo(s * .5, top)
    ..cubicTo(s * .5 + w * .62, top, s * .5 + w * .55, s * .86, s * .5, s * .86)
    ..cubicTo(s * .5 - w * .55, s * .86, s * .5 - w * .62, top, s * .5, top)
    ..close();
  final colors = [
    [const Color(0xFF3F51B5), const Color(0xFF1A237E)],
    [const Color(0xFF7E57C2), const Color(0xFF311B92)],
    [const Color(0xFF3A2E5C), const Color(0xFF0D0820)],
  ][level - 1];
  c.drawPath(egg, _grad(colors[0], colors[1], Rect.fromLTWH(0, top, s, h)));
  c.save();
  c.clipPath(egg);
  final rnd = Random(level);
  for (var i = 0; i < 10; i++) {
    paintSparkle(
      c,
      Offset(
        s * (.3 + rnd.nextDouble() * .4),
        top + h * (.15 + rnd.nextDouble() * .75),
      ),
      s * (.02 + rnd.nextDouble() * .03),
      Colors.white.withValues(alpha: .8),
    );
  }
  if (level >= 2) {
    c.drawCircle(
      Offset(s * .58, s * .5),
      s * .1,
      Paint()..color = const Color(0x88E1D5FF),
    );
    c.drawCircle(Offset(s * .62, s * .47), s * .09, Paint()..color = colors[0]);
  }
  c.restore();
  if (level == 3) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .03
      ..color = const Color(0xFFFFD166);
    c.drawPath(
      Path()
        ..moveTo(s * .3, s * .48)
        ..lineTo(s * .38, s * .42)
        ..lineTo(s * .44, s * .5)
        ..lineTo(s * .52, s * .4)
        ..lineTo(s * .6, s * .48)
        ..lineTo(s * .7, s * .42),
      ring,
    );
  }
  _highlight(c, Offset(s * .41, top + h * .25), s * .1, s * .16);
  c.drawPath(egg, stroke);
  paintSparkle(c, Offset(s * .76, s * .26), s * .06, const Color(0xFFFFE082));
}

// ---------------------------------------------------------------------------

void _flower(
  Canvas c,
  Offset o,
  double r,
  Color petal,
  Color center,
  double s,
) {
  for (var i = 0; i < 5; i++) {
    final a = -pi / 2 + i * pi * 2 / 5;
    c.drawCircle(
      o + Offset(cos(a), sin(a)) * r * .6,
      r * .5,
      Paint()..color = petal,
    );
  }
  c.drawCircle(o, r * .35, Paint()..color = center);
}

void paintBlossom(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  if (level >= 3) {
    paintGlow(
      c,
      Offset(s * .5, s * .5),
      s * .5,
      const Color(0xFFFFB3D9),
      .2 + level * .1,
    );
  }
  _shadow(c, s, s * (.3 + level * .07));
  const pink = Color(0xFFFF9EC7),
      light = Color(0xFFFFD1E6),
      yellow = Color(0xFFFFD166);
  switch (level) {
    case 1:
      c.save();
      c.translate(s * .5, s * .56);
      c.rotate(.5);
      final petal = Path()
        ..moveTo(0, s * .22)
        ..quadraticBezierTo(-s * .24, 0, 0, -s * .24)
        ..quadraticBezierTo(s * .24, 0, 0, s * .22)
        ..close();
      c.drawPath(
        petal,
        _grad(light, pink, Rect.fromLTWH(-s * .2, -s * .24, s * .4, s * .46)),
      );
      c.drawPath(petal, stroke);
      c.restore();
    case 2:
      _flower(c, Offset(s * .5, s * .52), s * .3, pink, yellow, s);
      paintSparkle(c, Offset(s * .76, s * .28), s * .05);
    case 3:
      final wrap = Path()
        ..moveTo(s * .3, s * .5)
        ..lineTo(s * .7, s * .5)
        ..lineTo(s * .54, s * .86)
        ..lineTo(s * .46, s * .86)
        ..close();
      c.drawPath(
        wrap,
        _grad(
          const Color(0xFFB3E5FC),
          const Color(0xFF4FC3F7),
          Rect.fromLTWH(0, s * .5, s, s * .36),
        ),
      );
      c.drawPath(wrap, stroke);
      _flower(c, Offset(s * .36, s * .42), s * .18, pink, yellow, s);
      _flower(
        c,
        Offset(s * .64, s * .42),
        s * .18,
        const Color(0xFFB39DFF),
        yellow,
        s,
      );
      _flower(c, Offset(s * .5, s * .3), s * .2, light, yellow, s);
    case 4:
      final ring = Rect.fromCenter(
        center: Offset(s * .5, s * .56),
        width: s * .7,
        height: s * .4,
      );
      c.drawOval(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .05
          ..color = const Color(0xFF7CC46B),
      );
      for (var i = 0; i < 7; i++) {
        final a = i * pi * 2 / 7;
        final o =
            ring.center +
            Offset(cos(a) * ring.width / 2, sin(a) * ring.height / 2);
        _flower(
          c,
          o,
          s * .11,
          i.isEven ? pink : const Color(0xFFB39DFF),
          yellow,
          s,
        );
      }
    default:
      // Blossom totem: a little glowing blossom tree
      c.drawRect(
        Rect.fromLTWH(s * .45, s * .5, s * .1, s * .34),
        Paint()..color = const Color(0xFF8A5A33),
      );
      for (final (x, y, r) in [
        (.5, .3, .22),
        (.32, .44, .17),
        (.68, .44, .17),
        (.5, .5, .18),
      ]) {
        c.drawCircle(Offset(s * x, s * y), s * r, Paint()..color = pink);
      }
      for (final (x, y) in [
        (.4, .28),
        (.6, .34),
        (.3, .48),
        (.7, .5),
        (.5, .44),
      ]) {
        _flower(c, Offset(s * x, s * y), s * .07, light, yellow, s);
      }
      paintSparkle(c, Offset(s * .82, s * .2), s * .06);
      paintSparkle(c, Offset(s * .18, s * .28), s * .045);
  }
}

void _lanternShape(
  Canvas c,
  Offset o,
  double r,
  Color color,
  double s, {
  bool glow = true,
}) {
  if (glow) paintGlow(c, o, r * 2, const Color(0xFFFFD166), .7);
  final body = Rect.fromCenter(center: o, width: r * 1.6, height: r * 1.9);
  c.drawOval(body, _grad(Color.lerp(color, Colors.white, .3)!, color, body));
  final rib = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, r * .08)
    ..color = Colors.black.withValues(alpha: .15);
  c.drawOval(Rect.fromCenter(center: o, width: r * .8, height: r * 1.9), rib);
  final cap = Paint()..color = const Color(0xFF3E2723);
  c.drawRect(
    Rect.fromCenter(
      center: o - Offset(0, r * .95),
      width: r * .7,
      height: r * .2,
    ),
    cap,
  );
  c.drawRect(
    Rect.fromCenter(
      center: o + Offset(0, r * .95),
      width: r * .7,
      height: r * .2,
    ),
    cap,
  );
  c.drawOval(body, _stroke(s));
}

void paintLantern(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  if (level >= 2) {
    paintGlow(
      c,
      Offset(s * .5, s * .5),
      s * .5,
      const Color(0xFFFFD166),
      .2 + level * .1,
    );
  }
  _shadow(c, s, s * (.3 + level * .07));
  switch (level) {
    case 1:
      final paper = Path()
        ..moveTo(s * .24, s * .36)
        ..lineTo(s * .72, s * .3)
        ..lineTo(s * .78, s * .72)
        ..lineTo(s * .3, s * .78)
        ..close();
      c.drawPath(
        paper,
        _grad(
          const Color(0xFFFFF4E0),
          const Color(0xFFF3D9B1),
          Rect.fromLTWH(0, 0, s, s),
        ),
      );
      c.drawLine(
        Offset(s * .27, s * .57),
        Offset(s * .75, s * .51),
        Paint()
          ..strokeWidth = s * .015
          ..color = const Color(0x33000000),
      );
      c.drawPath(paper, stroke);
    case 2:
      c.drawLine(
        Offset(s * .5, s * .14),
        Offset(s * .5, s * .28),
        Paint()
          ..strokeWidth = s * .02
          ..color = const Color(0xFF3E2723),
      );
      _lanternShape(
        c,
        Offset(s * .5, s * .54),
        s * .2,
        const Color(0xFFE53935),
        s,
      );
    case 3:
      final string = Path()
        ..moveTo(s * .08, s * .3)
        ..quadraticBezierTo(s * .5, s * .56, s * .92, s * .3);
      c.drawPath(
        string,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .02
          ..color = const Color(0xFF3E2723),
      );
      for (final (x, y, col) in [
        (.24, .52, const Color(0xFFE53935)),
        (.5, .62, const Color(0xFFFFB300)),
        (.76, .52, const Color(0xFF8E24AA)),
      ]) {
        _lanternShape(c, Offset(s * x, s * y), s * .1, col, s);
      }
    case 4:
      final boat = Path()
        ..moveTo(s * .12, s * .64)
        ..lineTo(s * .88, s * .64)
        ..quadraticBezierTo(s * .74, s * .84, s * .5, s * .84)
        ..quadraticBezierTo(s * .26, s * .84, s * .12, s * .64)
        ..close();
      c.drawPath(
        boat,
        _grad(
          const Color(0xFFD69A5E),
          const Color(0xFF8A5A33),
          Rect.fromLTWH(0, s * .6, s, s * .25),
        ),
      );
      c.drawPath(boat, stroke);
      c.drawLine(
        Offset(s * .5, s * .64),
        Offset(s * .5, s * .34),
        Paint()
          ..strokeWidth = s * .025
          ..color = const Color(0xFF5D4037),
      );
      _lanternShape(
        c,
        Offset(s * .5, s * .4),
        s * .13,
        const Color(0xFFFF7043),
        s,
      );
    default:
      // Sky lantern floating up
      final o = Offset(s * .5, s * .44);
      paintGlow(c, o, s * .45, const Color(0xFFFFB74D), .9);
      final body = Path()
        ..moveTo(s * .3, s * .22)
        ..lineTo(s * .7, s * .22)
        ..lineTo(s * .64, s * .66)
        ..lineTo(s * .36, s * .66)
        ..close();
      c.drawPath(
        body,
        _grad(
          const Color(0xFFFFF1C1),
          const Color(0xFFFF8A3D),
          Rect.fromLTWH(0, s * .2, s, s * .5),
          vertical: true,
        ),
      );
      c.drawPath(body, stroke);
      paintGlow(c, Offset(s * .5, s * .62), s * .1, Colors.white, .9);
      paintSparkle(c, Offset(s * .8, s * .2), s * .06);
      paintSparkle(c, Offset(s * .22, s * .74), s * .04);
  }
}

// ---------------------------------------------------------------------------
// Energy potions: drop, vial, flask, elixir
// ---------------------------------------------------------------------------

Path _boltPath(Offset c, double h) {
  final w = h * .55;
  return Path()
    ..moveTo(c.dx + w * .15, c.dy - h * .5)
    ..lineTo(c.dx - w * .45, c.dy + h * .08)
    ..lineTo(c.dx - w * .02, c.dy + h * .08)
    ..lineTo(c.dx - w * .15, c.dy + h * .5)
    ..lineTo(c.dx + w * .45, c.dy - h * .1)
    ..lineTo(c.dx + w * .02, c.dy - h * .1)
    ..close();
}

void paintPotion(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  paintGlow(
    c,
    Offset(s * .5, s * .56),
    s * (.3 + level * .06),
    const Color(0xFF6FE3FF),
    .25 + level * .12,
  );
  _shadow(c, s, s * (.3 + level * .08));
  const liquidA = Color(0xFF9DF3FF);
  const liquidB = Color(0xFF1E88E5);
  switch (level) {
    case 1:
      final drop = Path()
        ..moveTo(s * .5, s * .2)
        ..cubicTo(s * .64, s * .42, s * .72, s * .52, s * .72, s * .62)
        ..arcToPoint(Offset(s * .28, s * .62), radius: Radius.circular(s * .22))
        ..cubicTo(s * .28, s * .52, s * .36, s * .42, s * .5, s * .2)
        ..close();
      c.drawPath(
        drop,
        _grad(
          liquidA,
          liquidB,
          Rect.fromLTWH(0, s * .2, s, s * .64),
          vertical: true,
        ),
      );
      c.drawPath(drop, stroke);
      c.drawPath(
        _boltPath(Offset(s * .5, s * .6), s * .24),
        Paint()..color = const Color(0xFFFFF176),
      );
      c.drawOval(
        Rect.fromLTWH(s * .36, s * .44, s * .08, s * .14),
        Paint()..color = Colors.white.withValues(alpha: .7),
      );
    default:
      // Bottle grows fancier with level.
      final bw = s * (.34 + level * .06);
      final bh = s * (.34 + level * .05);
      final body = Rect.fromCenter(
        center: Offset(s * .5, s * .62),
        width: bw,
        height: bh,
      );
      final neck = Rect.fromCenter(
        center: Offset(s * .5, body.top - s * .06),
        width: s * .16,
        height: s * .14,
      );
      final glass = Paint()..color = Colors.white.withValues(alpha: .55);
      final bottle = Path()
        ..addRRect(RRect.fromRectAndRadius(neck, Radius.circular(s * .03)));
      if (level == 2) {
        bottle.addRRect(
          RRect.fromRectAndRadius(body, Radius.circular(s * .08)),
        );
      } else {
        bottle.addOval(body);
      }
      c.drawPath(bottle, glass);
      // Liquid
      c.save();
      c.clipPath(bottle);
      final fill = Rect.fromLTRB(
        body.left,
        body.top + bh * .25,
        body.right,
        body.bottom,
      );
      c.drawRect(fill, _grad(liquidA, liquidB, fill, vertical: true));
      c.drawOval(
        Rect.fromLTRB(
          body.left,
          fill.top - s * .03,
          body.right,
          fill.top + s * .03,
        ),
        Paint()..color = const Color(0xFFD9FBFF),
      );
      // Bubbles
      for (var i = 0; i < level + 1; i++) {
        c.drawCircle(
          Offset(
            body.left + bw * (.25 + (i * .23) % .55),
            fill.top + bh * (.2 + (i * .17) % .5),
          ),
          s * (.018 + (i % 2) * .012),
          Paint()..color = Colors.white.withValues(alpha: .7),
        );
      }
      c.restore();
      c.drawPath(bottle, stroke);
      c.drawPath(
        _boltPath(Offset(s * .5, body.center.dy + bh * .08), bh * .42),
        Paint()..color = const Color(0xFFFFF176),
      );
      c.drawPath(
        _boltPath(Offset(s * .5, body.center.dy + bh * .08), bh * .42),
        stroke,
      );
      // Cork / cap
      final cap = Rect.fromCenter(
        center: Offset(s * .5, neck.top - s * .02),
        width: s * .2,
        height: s * .08,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(cap, Radius.circular(s * .03)),
        level >= 4
            ? _grad(const Color(0xFFFFE27A), const Color(0xFFE0A21A), cap)
            : _grad(const Color(0xFFD7A77A), const Color(0xFF9A6B4A), cap),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(cap, Radius.circular(s * .03)),
        stroke,
      );
      // Glass shine
      c.drawArc(
        body.deflate(s * .05),
        pi * 1.1,
        pi * .35,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .03
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: .8),
      );
      if (level >= 4) {
        // Gold filigree and a heart-gem
        c.drawArc(
          body.inflate(s * .01),
          pi * .15,
          pi * .7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * .03
            ..color = const Color(0xFFFFC43D),
        );
        paintSparkle(c, Offset(s * .78, s * .3), s * .07);
        paintSparkle(c, Offset(s * .22, s * .44), s * .05);
      }
      if (level >= 3) paintSparkle(c, Offset(s * .72, s * .42), s * .05);
  }
}

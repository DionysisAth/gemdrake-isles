import 'dart:math';

import 'package:flutter/material.dart';

import 'item_painter.dart';

/// The dreamy sky behind every screen: gradient, sun glow, distant floating
/// islands, cloud banks and twinkles. Static (no animation) to save battery.
class SkyPainter extends CustomPainter {
  const SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF7CC8FF),
            Color(0xFFB3DDFF),
            Color(0xFFDCCBFF),
            Color(0xFFFFD9EC),
          ],
          stops: [0, .35, .7, 1],
        ).createShader(rect),
    );

    // Sun glow
    paintGlow(
      canvas,
      Offset(w * .82, h * .06),
      w * .55,
      const Color(0xFFFFF4C2),
      .75,
    );

    // Distant floating islands
    void islet(double cx, double cy, double s, double alpha) {
      final top = Rect.fromCenter(
        center: Offset(cx, cy),
        width: s,
        height: s * .28,
      );
      final under = Path()
        ..moveTo(top.left, cy)
        ..quadraticBezierTo(cx - s * .1, cy + s * .55, cx, cy + s * .6)
        ..quadraticBezierTo(cx + s * .15, cy + s * .5, top.right, cy)
        ..close();
      canvas.drawPath(
        under,
        Paint()..color = const Color(0xFF9C8AC9).withValues(alpha: alpha),
      );
      canvas.drawOval(
        top,
        Paint()..color = const Color(0xFF9BD6A6).withValues(alpha: alpha),
      );
    }

    islet(w * .12, h * .2, w * .16, .45);
    islet(w * .9, h * .34, w * .12, .35);
    islet(w * .7, h * .14, w * .08, .3);

    // Cloud banks
    final cloud = Paint()..color = Colors.white.withValues(alpha: .55);
    void puff(double x, double y, double r) {
      canvas.drawCircle(Offset(x, y), r, cloud);
      canvas.drawCircle(Offset(x + r * 1.1, y + r * .2), r * .8, cloud);
      canvas.drawCircle(Offset(x - r * 1.1, y + r * .3), r * .7, cloud);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - r * 1.7, y, x + r * 1.8, y + r * .9),
          Radius.circular(r * .45),
        ),
        cloud,
      );
    }

    puff(w * .2, h * .1, w * .06);
    puff(w * .62, h * .26, w * .045);
    puff(w * .08, h * .5, w * .05);
    puff(w * .94, h * .62, w * .06);
    // Soft cloud floor
    final floor = Paint()..color = Colors.white.withValues(alpha: .5);
    for (var i = 0; i < 9; i++) {
      final x = w * (i / 8);
      canvas.drawCircle(Offset(x, h * 1.02), w * (.12 + (i % 3) * .03), floor);
    }

    // Twinkles
    final rnd = Random(7);
    for (var i = 0; i < 26; i++) {
      final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * .8);
      paintSparkle(
        canvas,
        p,
        1.5 + rnd.nextDouble() * 3,
        Colors.white.withValues(alpha: .35 + rnd.nextDouble() * .4),
      );
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) => false;
}

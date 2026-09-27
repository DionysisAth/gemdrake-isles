import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import 'item_painter.dart';

/// A cute chibi dragon. Grows horns, spikes, bigger wings and finally a
/// glowing gem crest as it levels from Baby to Gemdrake.
class DragonPainter extends CustomPainter {
  DragonPainter({
    required this.type,
    required this.level,
    this.flap = 0,
    this.blink = false,
    this.silhouette = false,
  });

  final DragonTypeDef type;
  final int level;

  /// Wing position 0..1.
  final double flap;
  final bool blink;
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    if (silhouette) canvas.saveLayer(Rect.fromLTWH(0, 0, s, s), Paint());

    // Babies are mostly head; adults have longer bodies.
    final grow = (level - 1) / 4.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, s * .022)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x77301E4F);
    Paint fill(Color a, Color b, Rect r) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [a, b],
      ).createShader(r);
    final dark = Color.lerp(type.body, Colors.black, .25)!;
    final light = Color.lerp(type.body, Colors.white, .25)!;

    if (level >= 5) {
      paintGlow(canvas, Offset(s * .5, s * .5), s * .52, type.accent, .55);
    }
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * .48, s * .92),
        width: s * (.42 + grow * .2),
        height: s * .07,
      ),
      Paint()..color = Colors.black.withValues(alpha: .15),
    );

    final bodyC = Offset(s * .44, s * (.66 - grow * .02));
    final bodyW = s * (.34 + grow * .14);
    final bodyH = s * (.3 + grow * .08);
    final headC = Offset(s * (.6 + grow * .04), s * (.4 - grow * .06));
    final headR = s * (.2 - grow * .02);

    // Tail
    final tail = Path()
      ..moveTo(bodyC.dx - bodyW * .35, bodyC.dy + bodyH * .1)
      ..quadraticBezierTo(
        s * .08,
        bodyC.dy + bodyH * .4,
        s * (.1 - grow * .02),
        bodyC.dy - bodyH * .3,
      )
      ..quadraticBezierTo(
        s * .16,
        bodyC.dy + bodyH * .1,
        bodyC.dx - bodyW * .3,
        bodyC.dy + bodyH * .35,
      )
      ..close();
    canvas.drawPath(
      tail,
      fill(light, dark, Rect.fromLTWH(0, bodyC.dy - bodyH, s, bodyH * 2)),
    );
    canvas.drawPath(tail, stroke);
    // Tail tip
    final tip = Offset(s * (.1 - grow * .02), bodyC.dy - bodyH * .3);
    final tipPath = Path()
      ..moveTo(tip.dx, tip.dy - s * .06)
      ..lineTo(tip.dx + s * .05, tip.dy + s * .02)
      ..lineTo(tip.dx - s * .04, tip.dy + s * .03)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = type.accent);
    canvas.drawPath(tipPath, stroke);

    // Wings (behind body)
    final wingSpan = s * (.2 + grow * .16);
    final wingAngle = -0.35 - flap * 0.6;
    void wing(Offset root, double scale, double shade) {
      canvas.save();
      canvas.translate(root.dx, root.dy);
      canvas.rotate(wingAngle);
      canvas.scale(scale);
      final w = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
          -wingSpan * .2,
          -wingSpan * 1.1,
          wingSpan * .3,
          -wingSpan * 1.2,
        )
        ..quadraticBezierTo(
          wingSpan * .5,
          -wingSpan * .7,
          wingSpan * .8,
          -wingSpan * .7,
        )
        ..quadraticBezierTo(
          wingSpan * .6,
          -wingSpan * .3,
          wingSpan * .9,
          -wingSpan * .1,
        )
        ..quadraticBezierTo(wingSpan * .4, 0, 0, 0)
        ..close();
      canvas.drawPath(
        w,
        Paint()..color = Color.lerp(type.wing, Colors.black, shade)!,
      );
      canvas.drawPath(w, stroke);
      canvas.restore();
    }

    wing(Offset(bodyC.dx - bodyW * .05, bodyC.dy - bodyH * .35), .85, .18);

    // Back spikes
    if (level >= 3) {
      final spike = Paint()..color = type.accent;
      for (var i = 0; i < 3; i++) {
        final t = i / 3;
        final base = Offset(
          bodyC.dx - bodyW * (.3 - t * .5),
          bodyC.dy - bodyH * (.42 + t * .08),
        );
        final p = Path()
          ..moveTo(base.dx - s * .03, base.dy + s * .01)
          ..lineTo(base.dx, base.dy - s * (.05 + grow * .03))
          ..lineTo(base.dx + s * .03, base.dy + s * .01)
          ..close();
        canvas.drawPath(p, spike);
        canvas.drawPath(p, stroke);
      }
    }

    // Legs
    final leg = Paint()..color = dark;
    for (final dx in [-.22, .22]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bodyC.dx + bodyW * dx, bodyC.dy + bodyH * .45),
          width: s * .09,
          height: s * .1,
        ),
        Radius.circular(s * .04),
      );
      canvas.drawRRect(r, leg);
      canvas.drawRRect(r, stroke);
    }

    // Body
    final body = Rect.fromCenter(center: bodyC, width: bodyW, height: bodyH);
    canvas.drawOval(body, fill(light, type.body, body));
    canvas.drawOval(
      Rect.fromCenter(
        center: bodyC + Offset(bodyW * .08, bodyH * .1),
        width: bodyW * .6,
        height: bodyH * .62,
      ),
      Paint()..color = type.belly,
    );
    canvas.drawOval(body, stroke);

    // Front wing
    wing(Offset(bodyC.dx + bodyW * .05, bodyC.dy - bodyH * .3), 1, 0);

    // Neck
    final neck = Path()
      ..moveTo(bodyC.dx + bodyW * .15, bodyC.dy - bodyH * .3)
      ..quadraticBezierTo(
        headC.dx - headR * .2,
        headC.dy + headR * .6,
        headC.dx,
        headC.dy + headR * .3,
      )
      ..lineTo(headC.dx + headR * .3, headC.dy + headR * .7)
      ..quadraticBezierTo(
        bodyC.dx + bodyW * .4,
        bodyC.dy - bodyH * .1,
        bodyC.dx + bodyW * .35,
        bodyC.dy,
      )
      ..close();
    canvas.drawPath(neck, Paint()..color = type.body);

    // Horns
    if (level >= 2) {
      final hornLen = s * (.06 + grow * .08);
      final horn = Paint()..color = Color.lerp(type.accent, Colors.white, .2)!;
      for (final dx in [-.45, .15]) {
        final base = Offset(headC.dx + headR * dx, headC.dy - headR * .75);
        final p = Path()
          ..moveTo(base.dx - s * .025, base.dy + s * .02)
          ..quadraticBezierTo(
            base.dx - s * .03,
            base.dy - hornLen * .6,
            base.dx - s * .05,
            base.dy - hornLen,
          )
          ..quadraticBezierTo(
            base.dx + s * .03,
            base.dy - hornLen * .4,
            base.dx + s * .03,
            base.dy + s * .02,
          )
          ..close();
        canvas.drawPath(p, horn);
        canvas.drawPath(p, stroke);
      }
    }

    // Head
    final head = Rect.fromCircle(center: headC, radius: headR);
    canvas.drawOval(head, fill(light, type.body, head));
    // Snout
    final snout = Rect.fromCenter(
      center: headC + Offset(headR * .7, headR * .3),
      width: headR * 1.1,
      height: headR * .8,
    );
    canvas.drawOval(
      snout,
      Paint()..color = Color.lerp(type.body, type.belly, .45)!,
    );
    canvas.drawOval(head, stroke);
    canvas.drawOval(snout, stroke);
    canvas.drawCircle(
      snout.center + Offset(snout.width * .22, -snout.height * .1),
      s * .012,
      Paint()..color = const Color(0x88301E4F),
    );

    // Eyes: bigger for babies.
    final eyeR = headR * (.3 - grow * .08);
    final eyeC = headC + Offset(headR * .05, -headR * .15);
    if (blink) {
      canvas.drawArc(
        Rect.fromCircle(center: eyeC, radius: eyeR * .8),
        .2,
        pi - .4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, s * .02)
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF2B1B3F),
      );
    } else {
      canvas.drawCircle(eyeC, eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(
        eyeC + Offset(eyeR * .2, 0),
        eyeR * .7,
        Paint()..color = const Color(0xFF2B1B3F),
      );
      canvas.drawCircle(
        eyeC + Offset(eyeR * .4, -eyeR * .3),
        eyeR * .28,
        Paint()..color = Colors.white,
      );
    }
    // Blush
    canvas.drawOval(
      Rect.fromCenter(
        center: headC + Offset(-headR * .15, headR * .45),
        width: headR * .4,
        height: headR * .2,
      ),
      Paint()..color = const Color(0x55FF6B8B),
    );

    // Elder whiskers
    if (level >= 4) {
      final whisker = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, s * .015)
        ..strokeCap = StrokeCap.round
        ..color = type.accent;
      canvas.drawPath(
        Path()
          ..moveTo(snout.center.dx, snout.bottom - s * .01)
          ..quadraticBezierTo(
            snout.center.dx + s * .02,
            snout.bottom + s * .08,
            snout.center.dx + s * .1,
            snout.bottom + s * .06,
          ),
        whisker,
      );
    }

    // Gemdrake crest gem
    if (level >= 5) {
      final g = headC + Offset(-headR * .15, -headR * .82);
      final p = Path()
        ..moveTo(g.dx, g.dy - s * .05)
        ..lineTo(g.dx + s * .035, g.dy)
        ..lineTo(g.dx, g.dy + s * .04)
        ..lineTo(g.dx - s * .035, g.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFFFF4FA3));
      canvas.drawPath(p, stroke);
      paintSparkle(canvas, g + Offset(s * .05, -s * .04), s * .03);
      paintSparkle(canvas, Offset(s * .86, s * .2), s * .04);
    }

    if (silhouette) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, s, s),
        Paint()
          ..color = const Color(0xFF4A4460)
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DragonPainter old) =>
      old.type != type ||
      old.level != level ||
      old.flap != flap ||
      old.blink != blink ||
      old.silhouette != silhouette;
}

/// Island character portraits (Pip, Sage Ember...).
class CharacterPainter extends CustomPainter {
  CharacterPainter(this.character);

  final CharacterDef character;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height * .58);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, s * .03)
      ..color = const Color(0x66301E4F);
    // Face
    canvas.drawCircle(c, s * .32, Paint()..color = character.skin);
    canvas.drawCircle(c, s * .32, stroke);
    // Eyes
    final eye = Paint()..color = const Color(0xFF2B1B3F);
    canvas.drawCircle(c + Offset(-s * .11, -s * .02), s * .04, eye);
    canvas.drawCircle(c + Offset(s * .11, -s * .02), s * .04, eye);
    canvas.drawCircle(
      c + Offset(-s * .1, -s * .035),
      s * .013,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      c + Offset(s * .12, -s * .035),
      s * .013,
      Paint()..color = Colors.white,
    );
    // Smile + blush
    canvas.drawArc(
      Rect.fromCenter(
        center: c + Offset(0, s * .07),
        width: s * .16,
        height: s * .1,
      ),
      .2,
      pi - .4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .03
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8A3B3B),
    );
    final blush = Paint()..color = const Color(0x55FF6B8B);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-s * .19, s * .07),
        width: s * .1,
        height: s * .06,
      ),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(s * .19, s * .07),
        width: s * .1,
        height: s * .06,
      ),
      blush,
    );

    final hatPaint = Paint()..color = character.hatColor;
    if (character.hat == 'wizard') {
      // Glasses
      final glass = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .025
        ..color = const Color(0xFF5D4037);
      canvas.drawCircle(c + Offset(-s * .11, -s * .02), s * .075, glass);
      canvas.drawCircle(c + Offset(s * .11, -s * .02), s * .075, glass);
      canvas.drawLine(
        c + Offset(-s * .035, -s * .02),
        c + Offset(s * .035, -s * .02),
        glass,
      );
      // Pointy hat
      final hat = Path()
        ..moveTo(c.dx - s * .4, c.dy - s * .18)
        ..quadraticBezierTo(c.dx, c.dy - s * .28, c.dx + s * .4, c.dy - s * .18)
        ..lineTo(c.dx + s * .12, c.dy - s * .24)
        ..quadraticBezierTo(
          c.dx + s * .1,
          c.dy - s * .5,
          c.dx + s * .24,
          c.dy - s * .58,
        )
        ..quadraticBezierTo(
          c.dx - s * .08,
          c.dy - s * .5,
          c.dx - s * .14,
          c.dy - s * .24,
        )
        ..close();
      canvas.drawPath(hat, hatPaint);
      canvas.drawPath(hat, stroke);
      paintSparkle(
        canvas,
        c + Offset(-s * .02, -s * .34),
        s * .05,
        const Color(0xFFFFE082),
      );
    } else {
      // Leaf cap
      final cap = Path()
        ..addArc(
          Rect.fromCircle(center: c + Offset(0, -s * .06), radius: s * .33),
          pi + .15,
          pi - .3,
        )
        ..close();
      canvas.drawPath(cap, hatPaint);
      canvas.drawPath(cap, stroke);
      canvas.save();
      canvas.translate(c.dx + s * .04, c.dy - s * .38);
      canvas.rotate(-.6);
      final leaf = Rect.fromCenter(
        center: Offset.zero,
        width: s * .14,
        height: s * .26,
      );
      canvas.drawOval(leaf, Paint()..color = const Color(0xFF8BD66A));
      canvas.drawOval(leaf, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CharacterPainter old) => old.character != character;
}

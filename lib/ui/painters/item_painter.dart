import 'dart:math';

import 'package:flutter/material.dart';

import '../../model/item_ref.dart';

/// Procedural 2D art for board items. Each level of a chain is visibly
/// "bigger/better" than the last: size, glow and detail all grow.
class ItemPainter extends CustomPainter {
  ItemPainter(this.ref, {this.silhouette = false});

  final ItemRef ref;

  /// Draw as a dark silhouette (undiscovered items in the chain view).
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final r = Rect.fromLTWH(0, 0, s, s);
    if (silhouette) {
      canvas.saveLayer(r, Paint());
    }
    switch (ref.chain) {
      case 'gem':
        _paintGem(canvas, s, ref.level);
      case 'plant':
        _paintPlant(canvas, s, ref.level);
      case 'egg':
        _paintEgg(canvas, s, ref.level);
      default:
        _paintUnknown(canvas, s);
    }
    if (silhouette) {
      canvas.drawRect(
        r,
        Paint()
          ..color = const Color(0xFF4A4460)
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ItemPainter old) =>
      old.ref != ref || old.silhouette != silhouette;
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

void paintGlow(
  Canvas c,
  Offset center,
  double radius,
  Color color, [
  double strength = 0.55,
]) {
  c.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: strength),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

void paintSparkle(Canvas c, Offset p, double r, [Color color = Colors.white]) {
  final path = Path()
    ..moveTo(p.dx, p.dy - r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
    ..close();
  c.drawPath(path, Paint()..color = color);
}

void _shadow(Canvas c, double s, double width) {
  c.drawOval(
    Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.88),
      width: width,
      height: s * 0.09,
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.16),
  );
}

Paint _fill(Color a, Color b, Rect r) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [a, b],
  ).createShader(r);

final _outline = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..color = const Color(0x55301E4F);

Paint _stroke(double s) => Paint()
  ..style = _outline.style
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = max(1.0, s * 0.025)
  ..color = _outline.color;

// ---------------------------------------------------------------------------
// Gems: Pebble -> Shard -> Crystal -> Cut Gem -> Jewel -> Crown Jewel -> Heart
// ---------------------------------------------------------------------------

const _gemColors = [
  (Color(0xFFC9CDD6), Color(0xFF8C93A6)), // pebble
  (Color(0xFFBDF3FF), Color(0xFF4FB9E3)), // shard
  (Color(0xFFE4C8FF), Color(0xFF9B5DE5)), // crystal
  (Color(0xFFB8FFD9), Color(0xFF21B573)), // cut gem
  (Color(0xFFFFC2CF), Color(0xFFE0245E)), // jewel
  (Color(0xFFFFF1B8), Color(0xFFF2A516)), // crown jewel
  (Color(0xFFFFD1F4), Color(0xFFFF3FA4)), // heart gem
];

void _paintGem(Canvas c, double s, int level) {
  final (light, dark) = _gemColors[(level - 1).clamp(0, _gemColors.length - 1)];
  final center = Offset(s / 2, s / 2);
  if (level >= 3) {
    paintGlow(c, center, s * (0.34 + level * 0.025), dark, 0.25 + level * 0.04);
  }
  _shadow(c, s, s * (0.3 + level * 0.04));
  final box = Rect.fromLTWH(0, 0, s, s);
  final stroke = _stroke(s);

  switch (level) {
    case 1: // Pebble: smooth rounded stone
      final r = Rect.fromCenter(
        center: Offset(s * .5, s * .6),
        width: s * .55,
        height: s * .4,
      );
      c.drawOval(r, _fill(light, dark, r));
      c.drawOval(r, stroke);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s * .42, s * .52),
          width: s * .18,
          height: s * .08,
        ),
        Paint()..color = Colors.white.withValues(alpha: .6),
      );
      paintSparkle(
        c,
        Offset(s * .64, s * .5),
        s * .04,
        const Color(0xFFDFF6FF),
      );
    case 2: // Shard: single tall crystal
      final p = Path()
        ..moveTo(s * .5, s * .14)
        ..lineTo(s * .66, s * .42)
        ..lineTo(s * .58, s * .84)
        ..lineTo(s * .42, s * .84)
        ..lineTo(s * .34, s * .42)
        ..close();
      c.drawPath(p, _fill(light, dark, box));
      c.drawPath(
        Path()
          ..moveTo(s * .5, s * .14)
          ..lineTo(s * .5, s * .84)
          ..lineTo(s * .42, s * .84)
          ..lineTo(s * .34, s * .42)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: .25),
      );
      c.drawPath(p, stroke);
      paintSparkle(c, Offset(s * .44, s * .36), s * .05);
    case 3: // Crystal cluster
      void crystal(double cx, double base, double w, double h, double tilt) {
        c.save();
        c.translate(cx, base);
        c.rotate(tilt);
        final p = Path()
          ..moveTo(0, -h)
          ..lineTo(w / 2, -h * .75)
          ..lineTo(w / 2, 0)
          ..lineTo(-w / 2, 0)
          ..lineTo(-w / 2, -h * .75)
          ..close();
        c.drawPath(p, _fill(light, dark, Rect.fromLTWH(-w / 2, -h, w, h)));
        c.drawRect(
          Rect.fromLTWH(-w / 2, -h * .75, w / 4, h * .75),
          Paint()..color = Colors.white.withValues(alpha: .25),
        );
        c.drawPath(p, stroke);
        c.restore();
      }
      crystal(s * .33, s * .84, s * .18, s * .42, -.35);
      crystal(s * .67, s * .84, s * .18, s * .44, .35);
      crystal(s * .5, s * .86, s * .22, s * .66, 0);
      paintSparkle(c, Offset(s * .46, s * .34), s * .05);
      paintSparkle(c, Offset(s * .72, s * .46), s * .035);
    default: // Faceted gems
      _facetedGem(c, s, level, light, dark, stroke);
  }
}

void _facetedGem(
  Canvas c,
  double s,
  int level,
  Color light,
  Color dark,
  Paint stroke,
) {
  final box = Rect.fromLTWH(0, 0, s, s);
  if (level == 7) {
    // Heart gem
    final p = Path()
      ..moveTo(s * .5, s * .86)
      ..cubicTo(s * .1, s * .6, s * .08, s * .3, s * .3, s * .2)
      ..cubicTo(s * .42, s * .15, s * .5, s * .25, s * .5, s * .3)
      ..cubicTo(s * .5, s * .25, s * .58, s * .15, s * .7, s * .2)
      ..cubicTo(s * .92, s * .3, s * .9, s * .6, s * .5, s * .86)
      ..close();
    c.drawPath(p, _fill(light, dark, box));
    c.drawPath(
      Path()
        ..moveTo(s * .5, s * .3)
        ..lineTo(s * .5, s * .86)
        ..lineTo(s * .22, s * .5)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .2),
    );
    c.drawPath(
      Path()
        ..moveTo(s * .3, s * .28)
        ..quadraticBezierTo(s * .2, s * .34, s * .22, s * .45),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * .04
        ..color = Colors.white.withValues(alpha: .7),
    );
    c.drawPath(p, stroke);
    paintSparkle(c, Offset(s * .72, s * .3), s * .07);
    paintSparkle(c, Offset(s * .2, s * .7), s * .045);
    paintSparkle(c, Offset(s * .82, s * .66), s * .04);
    return;
  }

  final w = s * (0.52 + (level - 4) * 0.05);
  final top = s * (0.3 - (level - 4) * 0.02);
  final mid = s * 0.44;
  final bottom = s * 0.84;
  final cx = s / 2;

  if (level == 6) {
    // Crown behind the gem.
    final gold = _fill(const Color(0xFFFFE27A), const Color(0xFFD4900A), box);
    final crown = Path()
      ..moveTo(cx - w * .55, mid)
      ..lineTo(cx - w * .6, s * .12)
      ..lineTo(cx - w * .28, s * .26)
      ..lineTo(cx, s * .06)
      ..lineTo(cx + w * .28, s * .26)
      ..lineTo(cx + w * .6, s * .12)
      ..lineTo(cx + w * .55, mid)
      ..close();
    c.drawPath(crown, gold);
    c.drawPath(crown, stroke);
    for (final x in [-.6, 0.0, .6]) {
      c.drawCircle(
        Offset(cx + w * x, x == 0 ? s * .07 : s * .13),
        s * .035,
        Paint()..color = const Color(0xFFFF4F7B),
      );
    }
  }

  final outline = Path()
    ..moveTo(cx - w * .3, top)
    ..lineTo(cx + w * .3, top)
    ..lineTo(cx + w * .5, mid)
    ..lineTo(cx, bottom)
    ..lineTo(cx - w * .5, mid)
    ..close();
  c.drawPath(outline, _fill(light, dark, box));
  // Facets
  final facet = Paint()..color = Colors.white.withValues(alpha: .28);
  c.drawPath(
    Path()
      ..moveTo(cx - w * .3, top)
      ..lineTo(cx, mid)
      ..lineTo(cx - w * .5, mid)
      ..close(),
    facet,
  );
  c.drawPath(
    Path()
      ..moveTo(cx - w * .5, mid)
      ..lineTo(cx, mid)
      ..lineTo(cx, bottom)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: .14),
  );
  c.drawPath(
    Path()
      ..moveTo(cx + w * .3, top)
      ..lineTo(cx + w * .5, mid)
      ..lineTo(cx, mid)
      ..close(),
    Paint()..color = Colors.black.withValues(alpha: .08),
  );
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.8, s * .012)
    ..color = Colors.white.withValues(alpha: .45);
  c.drawLine(Offset(cx - w * .5, mid), Offset(cx + w * .5, mid), line);
  c.drawLine(Offset(cx - w * .3, top), Offset(cx, mid), line);
  c.drawLine(Offset(cx + w * .3, top), Offset(cx, mid), line);
  c.drawPath(outline, stroke);

  if (level == 5) {
    // Gold setting
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .045
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF2B634);
    c.drawLine(
      Offset(cx - w * .52, mid),
      Offset(cx - w * .62, mid + s * .06),
      band,
    );
    c.drawLine(
      Offset(cx + w * .52, mid),
      Offset(cx + w * .62, mid + s * .06),
      band,
    );
  }
  paintSparkle(c, Offset(cx - w * .22, top + s * .07), s * .05);
  if (level >= 5) paintSparkle(c, Offset(cx + w * .55, top), s * .04);
}

// ---------------------------------------------------------------------------
// Plants: Seed -> Sprout -> Bush -> Fruit Tree -> Magic Tree
// ---------------------------------------------------------------------------

const _leafLight = Color(0xFF9BE36D);
const _leafDark = Color(0xFF3E9B4F);

void _paintPlant(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  final box = Rect.fromLTWH(0, 0, s, s);
  if (level == 5) {
    paintGlow(c, Offset(s * .5, s * .42), s * .5, const Color(0xFF7CF2E0), .45);
  }
  _shadow(c, s, s * (0.3 + level * 0.07));

  void leaf(Offset base, double len, double angle, [Color? a, Color? b]) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(angle);
    final p = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * .5, -len * .35, len, 0)
      ..quadraticBezierTo(len * .5, len * .35, 0, 0)
      ..close();
    c.drawPath(
      p,
      _fill(
        a ?? _leafLight,
        b ?? _leafDark,
        Rect.fromLTWH(0, -len / 2, len, len),
      ),
    );
    c.drawPath(p, stroke);
    c.restore();
  }

  void trunk(double w, double top) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * .5 - w / 2, top, s * .5 + w / 2, s * .87),
      Radius.circular(w / 2),
    );
    c.drawRRect(
      r,
      _fill(const Color(0xFFB07A4E), const Color(0xFF7A4B2A), r.outerRect),
    );
    c.drawRRect(r, stroke);
  }

  void canopy(Offset center, double r, Color a, Color b) {
    final blobs = [
      Offset(center.dx - r * .55, center.dy + r * .15),
      Offset(center.dx + r * .55, center.dy + r * .15),
      Offset(center.dx, center.dy - r * .35),
      center,
    ];
    final path = Path();
    for (final o in blobs) {
      path.addOval(Rect.fromCircle(center: o, radius: r * .62));
    }
    c.drawPath(path, _fill(a, b, Rect.fromCircle(center: center, radius: r)));
    c.drawPath(path, stroke);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - r * .3, center.dy - r * .4),
        width: r * .5,
        height: r * .25,
      ),
      Paint()..color = Colors.white.withValues(alpha: .3),
    );
  }

  switch (level) {
    case 1: // Seed
      final r = Rect.fromCenter(
        center: Offset(s * .5, s * .62),
        width: s * .3,
        height: s * .4,
      );
      c.save();
      c.translate(s * .5, s * .62);
      c.rotate(.4);
      c.translate(-s * .5, -s * .62);
      c.drawOval(r, _fill(const Color(0xFFE8C07A), const Color(0xFF9C6B30), r));
      c.drawOval(r, stroke);
      c.drawLine(
        Offset(s * .5, s * .46),
        Offset(s * .5, s * .76),
        Paint()
          ..strokeWidth = s * .02
          ..color = const Color(0x55603A10),
      );
      c.restore();
      leaf(Offset(s * .52, s * .42), s * .18, -1.0);
    case 2: // Sprout in soil
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s * .5, s * .8),
          width: s * .5,
          height: s * .16,
        ),
        _fill(const Color(0xFFA1754F), const Color(0xFF6D4C33), box),
      );
      c.drawLine(
        Offset(s * .5, s * .8),
        Offset(s * .5, s * .45),
        Paint()
          ..strokeWidth = s * .05
          ..strokeCap = StrokeCap.round
          ..color = _leafDark,
      );
      leaf(Offset(s * .5, s * .5), s * .28, -0.5);
      leaf(Offset(s * .5, s * .56), s * .26, pi + 0.45);
    case 3: // Bush
      canopy(Offset(s * .5, s * .58), s * .3, _leafLight, _leafDark);
      for (final o in [
        Offset(s * .38, s * .58),
        Offset(s * .62, s * .5),
        Offset(s * .55, s * .7),
      ]) {
        c.drawCircle(o, s * .035, Paint()..color = const Color(0xFFFF7EA8));
      }
    case 4: // Fruit tree
      trunk(s * .12, s * .5);
      canopy(Offset(s * .5, s * .4), s * .33, _leafLight, _leafDark);
      for (final o in [
        Offset(s * .36, s * .42),
        Offset(s * .6, s * .32),
        Offset(s * .64, s * .5),
        Offset(s * .47, s * .54),
      ]) {
        c.drawCircle(
          o,
          s * .045,
          _fill(const Color(0xFFFFD166), const Color(0xFFF08A24), box),
        );
      }
    default: // Magic tree
      trunk(s * .13, s * .48);
      canopy(
        Offset(s * .5, s * .38),
        s * .37,
        const Color(0xFFA6F7E1),
        const Color(0xFF3AAFA9),
      );
      for (final o in [
        Offset(s * .32, s * .4),
        Offset(s * .62, s * .26),
        Offset(s * .7, s * .48),
        Offset(s * .46, s * .52),
        Offset(s * .5, s * .2),
      ]) {
        paintGlow(c, o, s * .07, const Color(0xFFFFF59D), .9);
        c.drawCircle(o, s * .025, Paint()..color = const Color(0xFFFFFDE7));
      }
      paintSparkle(c, Offset(s * .82, s * .22), s * .05);
      paintSparkle(c, Offset(s * .18, s * .62), s * .04);
  }
}

// ---------------------------------------------------------------------------
// Eggs: Dragon Egg -> Glowing Egg -> Cracking Egg
// ---------------------------------------------------------------------------

void _paintEgg(Canvas c, double s, int level) {
  final stroke = _stroke(s);
  final center = Offset(s * .5, s * .52);
  if (level >= 2) {
    paintGlow(
      c,
      center,
      s * (.42 + level * .04),
      const Color(0xFFFFB74D),
      .35 + level * .12,
    );
  }
  _shadow(c, s, s * .4);
  final w = s * (.44 + level * .03);
  final h = s * (.58 + level * .03);
  final top = s * .86 - h;
  final egg = Path()
    ..moveTo(s * .5, top)
    ..cubicTo(s * .5 + w * .62, top, s * .5 + w * .55, s * .86, s * .5, s * .86)
    ..cubicTo(s * .5 - w * .55, s * .86, s * .5 - w * .62, top, s * .5, top)
    ..close();
  final colors = switch (level) {
    1 => (const Color(0xFFFFF4DC), const Color(0xFFE9C98F)),
    2 => (const Color(0xFFD7FFF3), const Color(0xFF4CC3A6)),
    _ => (const Color(0xFFFFE9B0), const Color(0xFFF08A3C)),
  };
  c.drawPath(egg, _fill(colors.$1, colors.$2, Rect.fromLTWH(0, top, s, h)));

  c.save();
  c.clipPath(egg);
  final spot = Paint()..color = Colors.black.withValues(alpha: .1);
  if (level == 1) {
    c.drawCircle(Offset(s * .42, s * .5), s * .06, spot);
    c.drawCircle(Offset(s * .6, s * .66), s * .08, spot);
    c.drawCircle(Offset(s * .56, s * .38), s * .04, spot);
  } else {
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .05
      ..color = Colors.white.withValues(alpha: .45);
    c.drawPath(
      Path()
        ..moveTo(0, s * .6)
        ..quadraticBezierTo(s * .25, s * .52, s * .5, s * .6)
        ..quadraticBezierTo(s * .75, s * .68, s, s * .6),
      band,
    );
  }
  c.restore();

  c.drawOval(
    Rect.fromCenter(
      center: Offset(s * .41, top + h * .25),
      width: s * .1,
      height: s * .16,
    ),
    Paint()..color = Colors.white.withValues(alpha: .65),
  );
  c.drawPath(egg, stroke);

  if (level == 3) {
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, s * .025)
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF7A3E12);
    c.drawPath(
      Path()
        ..moveTo(s * .3, s * .46)
        ..lineTo(s * .38, s * .42)
        ..lineTo(s * .44, s * .5)
        ..lineTo(s * .52, s * .4)
        ..lineTo(s * .58, s * .47)
        ..lineTo(s * .66, s * .41),
      crack,
    );
    paintSparkle(c, Offset(s * .74, s * .3), s * .05);
    paintSparkle(c, Offset(s * .24, s * .34), s * .04);
  }
  if (level == 2) paintSparkle(c, Offset(s * .7, s * .32), s * .045);
}

void _paintUnknown(Canvas c, double s) {
  c.drawCircle(Offset(s / 2, s / 2), s * .3, Paint()..color = Colors.grey);
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import 'item_painter.dart';

const _ink = Color(0xFF241634);

/// A cute chibi dragon. Grows horns, spikes, bigger wings and finally a
/// glowing gem crest as it levels from Baby to Gemdrake. Every type has its
/// own tail tip and markings.
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
    if (s <= 0) return;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    // Everything below is drawn in a 1 x 1 box.
    canvas.scale(s);
    const bounds = Rect.fromLTWH(-.2, -.2, 1.4, 1.4);
    if (silhouette) canvas.saveLayer(bounds, Paint());
    _DragonArt(canvas, type, level, flap, blink, silhouette, s).paint();
    if (silhouette) {
      canvas.drawRect(
        bounds,
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

class _DragonArt {
  _DragonArt(
    this.c,
    this.type,
    this.level,
    this.flap,
    this.blink,
    this.silhouette,
    double px,
  ) : g = (level - 1) / 4,
      ow = max(1.3 / px, .016);

  final Canvas c;
  final DragonTypeDef type;
  final int level;
  final double flap;
  final bool blink;
  final bool silhouette;

  /// Growth 0 (Baby) .. 1 (Gemdrake).
  final double g;

  /// Visible outline width.
  final double ow;

  // Colours
  Color get body => type.body;
  late final light = Color.lerp(body, Colors.white, .4)!;
  late final shade = Color.lerp(body, const Color(0xFF3A2466), .4)!;
  late final ink = Color.lerp(body, _ink, .8)!;
  late final wingLight = Color.lerp(type.wing, Colors.white, .32)!;
  late final wingDark = Color.lerp(type.wing, _ink, .35)!;
  late final bellyLight = Color.lerp(type.belly, Colors.white, .45)!;
  late final bellyShade = Color.lerp(type.belly, body, .5)!;
  late final accentLight = Color.lerp(type.accent, Colors.white, .45)!;
  late final accentDark = Color.lerp(type.accent, _ink, .3)!;
  late final claw = Color.lerp(type.belly, Colors.white, .5)!;

  // Shape. Babies are mostly head; adults have longer bodies.
  late final bodyC = Offset(.43, .655 - g * .015);
  late final bw = .36 + g * .12;
  late final bh = .31 + g * .06;
  late final headC = Offset(.6 + g * .04, .39 - g * .05);
  late final hr = .195 - g * .02;

  late final bodyPath = Path()
    ..addOval(Rect.fromCenter(center: bodyC, width: bw, height: bh));
  late final neckPath = () {
    final n1 = Offset(bodyC.dx - bw * .04, bodyC.dy - bh * .4);
    final n2 = Offset(headC.dx - hr * .62, headC.dy + hr * .3);
    final n3 = Offset(headC.dx + hr * .42, headC.dy + hr * .82);
    final n4 = Offset(bodyC.dx + bw * .44, bodyC.dy - bh * .02);
    return Path()
      ..moveTo(n1.dx, n1.dy)
      ..quadraticBezierTo(n1.dx + bw * .02, n2.dy + hr * .2, n2.dx, n2.dy)
      ..lineTo(n3.dx, n3.dy)
      ..quadraticBezierTo(n4.dx + bw * .02, n3.dy + hr * .3, n4.dx, n4.dy)
      ..lineTo(bodyC.dx, bodyC.dy)
      ..close();
  }();
  late final trunk = Path()
    ..addPath(bodyPath, Offset.zero)
    ..addPath(neckPath, Offset.zero);
  late final headPath = Path()
    ..addOval(Rect.fromCircle(center: headC, radius: hr));
  late final snout = Rect.fromCenter(
    center: headC + Offset(hr * .7, hr * .3),
    width: hr * 1.1,
    height: hr * .82,
  );
  late final face = Path()
    ..addPath(headPath, Offset.zero)
    ..addOval(snout);

  /// The skin's light comes from the top left.
  late final skin = radial(
    const Offset(.4, .2),
    .9,
    [light, body, shade],
    [0, .45, 1],
  );

  // ---------------------------------------------------------------------
  // Helpers

  Paint outline([double? width]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width ?? ow * 2
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = ink;

  Paint line(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  /// Fills shapes with one outline around all of them (no inner lines).
  void sticker(List<Path> paths, Paint fill, [double? width]) {
    final o = outline(width);
    for (final p in paths) {
      c.drawPath(p, o);
    }
    for (final p in paths) {
      c.drawPath(p, fill);
    }
  }

  Paint linear(
    Rect r,
    List<Color> colors, {
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
  }) => Paint()
    ..shader = LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
    ).createShader(r);

  Paint radial(
    Offset center,
    double radius,
    List<Color> colors, [
    List<double>? stops,
  ]) => Paint()
    ..shader = RadialGradient(
      colors: colors,
      stops: stops,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

  void softSpot(Offset o, double r, Color color, double alpha) => c.drawCircle(
    o,
    r,
    radial(o, r, [color.withValues(alpha: alpha), color.withValues(alpha: 0)]),
  );

  // ---------------------------------------------------------------------

  void paint() {
    if (level >= 5 && !silhouette) {
      paintGlow(c, const Offset(.5, .52), .56, type.accent, .5);
    }
    // Ground shadow
    c.drawOval(
      Rect.fromCenter(
        center: Offset(bodyC.dx + .03, .885),
        width: .44 + g * .2,
        height: .07,
      ),
      Paint()..color = Colors.black.withValues(alpha: .15),
    );
    wing(near: false);
    tail();
    backSpikes();
    foot(Offset(bodyC.dx + bw * .1, bodyC.dy + bh * .43), far: true);
    trunkAndBelly();
    foot(Offset(bodyC.dx - bw * .2, bodyC.dy + bh * .46));
    foot(Offset(bodyC.dx + bw * .3, bodyC.dy + bh * .47));
    arm();
    wing(near: true);
    earFrill();
    horns();
    head();
    eye();
    snoutDetails();
    headTop();
    if (level >= 5 && !silhouette) {
      paintSparkle(c, const Offset(.88, .18), .04);
      paintSparkle(c, const Offset(.12, .24), .028);
      paintSparkle(c, const Offset(.9, .62), .025);
    }
  }

  // ---------------------------------------------------------------------
  // Body

  void trunkAndBelly() {
    sticker([bodyPath, neckPath], skin);
    c.save();
    c.clipPath(trunk);
    // Belly plates from the chin down to the tummy.
    final belly = Path()
      ..moveTo(bodyC.dx - bw * .2, bodyC.dy + bh * .36)
      ..quadraticBezierTo(
        bodyC.dx - bw * .1,
        bodyC.dy - bh * .3,
        headC.dx + hr * .02,
        headC.dy + hr * .74,
      )
      ..lineTo(headC.dx + hr * .5, headC.dy + hr * .7)
      ..quadraticBezierTo(
        bodyC.dx + bw * .56,
        bodyC.dy - bh * .1,
        bodyC.dx + bw * .4,
        bodyC.dy + bh * .3,
      )
      ..quadraticBezierTo(
        bodyC.dx + bw * .12,
        bodyC.dy + bh * .62,
        bodyC.dx - bw * .2,
        bodyC.dy + bh * .36,
      )
      ..close();
    final br = belly.getBounds();
    c.drawPath(
      belly,
      linear(
        br,
        [bellyLight, type.belly, bellyShade],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    c.save();
    c.clipPath(belly);
    final plate = line(bellyShade.withValues(alpha: .8), ow * .9);
    final step = .036 + g * .006;
    for (var y = br.top + step; y < br.bottom; y += step) {
      c.drawPath(
        Path()
          ..moveTo(br.left, y - step * .3)
          ..quadraticBezierTo(
            br.center.dx,
            y + step * .45,
            br.right,
            y - step * .3,
          ),
        plate,
      );
    }
    c.restore();
    c.drawPath(belly, line(ink.withValues(alpha: .25), ow * .8));
    markings();
    // The head casts a soft shadow on the neck.
    c.drawOval(
      Rect.fromCenter(
        center: headC + Offset(-hr * .05, hr * 1.0),
        width: hr * 2.1,
        height: hr * .9,
      ),
      radial(headC + Offset(-hr * .05, hr * 1.0), hr * 1.05, [
        shade.withValues(alpha: .55),
        shade.withValues(alpha: 0),
      ]),
    );
    // Shine along the back.
    softSpot(
      Offset(bodyC.dx - bw * .2, bodyC.dy - bh * .28),
      bw * .32,
      Colors.white,
      .35,
    );
    c.restore();
    // Thigh
    final thigh = Rect.fromCenter(
      center: Offset(bodyC.dx - bw * .2, bodyC.dy + bh * .16),
      width: bw * .5,
      height: bh * .62,
    );
    c.drawArc(thigh, 3.7, 1.5, false, line(shade.withValues(alpha: .55), ow));
    c.drawArc(
      thigh.deflate(ow * 1.6),
      3.75,
      1.3,
      false,
      line(light.withValues(alpha: .7), ow * 1.1),
    );
  }

  /// Spots on the back, different for each type.
  void markings() {
    final spots = [
      (-.22, -.2, .05),
      (-.02, -.33, .036),
      (-.36, .02, .036),
      (-.1, -.08, .026),
    ];
    for (final (x, y, r0) in spots) {
      final o = bodyC + Offset(bw * x, bh * y);
      final r = r0 * (1 + g * .4);
      switch (type.id) {
        case 'shadow':
          paintSparkle(c, o, r * 1.1, type.accent.withValues(alpha: .85));
        case 'lumen':
          paintGlow(c, o, r * 1.8, const Color(0xFFFFF3B0), .9);
          c.drawCircle(o, r * .5, Paint()..color = const Color(0xFFFFFBE6));
        case 'crystal':
          c.drawPath(
            Path()
              ..moveTo(o.dx, o.dy - r)
              ..lineTo(o.dx + r * .7, o.dy)
              ..lineTo(o.dx, o.dy + r)
              ..lineTo(o.dx - r * .7, o.dy)
              ..close(),
            Paint()..color = accentLight.withValues(alpha: .8),
          );
        case 'earth':
          c.drawCircle(
            o,
            r,
            Paint()
              ..color = Color.lerp(body, type.wing, .6)!.withValues(alpha: .8),
          );
        case 'fire':
          c.drawCircle(
            o,
            r,
            Paint()
              ..color = Color.lerp(
                body,
                type.accent,
                .55,
              )!.withValues(alpha: .75),
          );
        default:
          c.drawCircle(o, r, Paint()..color = light.withValues(alpha: .7));
      }
    }
  }

  void foot(Offset at, {bool far = false}) {
    final fw = .1 + g * .025;
    final fh = .07 + g * .01;
    final r = RRect.fromRectAndCorners(
      Rect.fromCenter(center: at, width: fw, height: fh),
      topLeft: Radius.circular(fh * .6),
      topRight: Radius.circular(fh * .7),
      bottomLeft: Radius.circular(fh * .3),
      bottomRight: Radius.circular(fh * .45),
    );
    sticker(
      [Path()..addRRect(r)],
      far
          ? (Paint()..color = shade)
          : linear(r.outerRect, [light, body, shade]),
    );
    if (far) return;
    // Claws
    for (var i = 0; i < 3; i++) {
      final o = Offset(at.dx + fw * (.06 + i * .16), at.dy + fh * .36);
      final cl = Rect.fromCenter(center: o, width: fw * .15, height: fh * .3);
      c.drawOval(cl, outline(ow * 1.2));
      c.drawOval(cl, Paint()..color = claw);
    }
  }

  void arm() {
    final a0 = Offset(bodyC.dx + bw * .25, bodyC.dy - bh * .14);
    final a1 = Offset(bodyC.dx + bw * .36, bodyC.dy + bh * .2);
    final aw = .05 + g * .012;
    final p = Path()
      ..moveTo(a0.dx, a0.dy)
      ..quadraticBezierTo(bodyC.dx + bw * .44, bodyC.dy, a1.dx, a1.dy);
    c.drawPath(p, outline(aw + ow * 2));
    c.drawPath(p, line(body, aw));
    c.drawPath(
      p.shift(Offset(-aw * .18, -aw * .1)),
      line(light.withValues(alpha: .6), aw * .3),
    );
    final paw = Path()..addOval(Rect.fromCircle(center: a1, radius: aw * .62));
    sticker([paw], Paint()..color = body);
    for (final dx in [-.3, .3]) {
      final cl = Rect.fromCenter(
        center: a1 + Offset(aw * (dx + .25), aw * .5),
        width: aw * .32,
        height: aw * .3,
      );
      c.drawOval(cl, outline(ow * 1.2));
      c.drawOval(cl, Paint()..color = claw);
    }
  }

  // ---------------------------------------------------------------------
  // Tail

  void tail() {
    final p0 = Offset(bodyC.dx - bw * .26, bodyC.dy + bh * .28);
    final p1 = Offset(bodyC.dx - bw * .85, bodyC.dy + bh * .6);
    final p2 = Offset(.02, bodyC.dy + bh * .25);
    final p3 = Offset(.05 - g * .015, bodyC.dy - bh * .1 - g * .02);
    Offset at(double t) {
      final u = 1 - t;
      return p0 * (u * u * u) +
          p1 * (3 * u * u * t) +
          p2 * (3 * u * t * t) +
          p3 * (t * t * t);
    }

    Offset dir(double t) {
      final u = 1 - t;
      final d =
          (p1 - p0) * (3 * u * u) +
          (p2 - p1) * (6 * u * t) +
          (p3 - p2) * (3 * t * t);
      return d / d.distance;
    }

    Offset normal(double t) {
      final d = dir(t);
      return Offset(-d.dy, d.dx);
    }

    double width(double t) => (.075 + g * .02) * (1 - t) + .017 * t;

    // Spikes along the top of the tail.
    if (level >= 3) {
      for (final t in [.3, .5, .68]) {
        spike(
          at(t) + normal(t) * width(t) * .6,
          normal(t),
          .032 + g * .015,
          .02,
        );
      }
    }
    const n = 24;
    final top = [
      for (var i = 0; i <= n; i++) at(i / n) + normal(i / n) * width(i / n),
    ];
    final bottom = [
      for (var i = n; i >= 0; i--) at(i / n) - normal(i / n) * width(i / n),
    ];
    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final o in [...top.skip(1), ...bottom]) {
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    sticker([path], skin);
    // Lighter underside stripe and a shine along the top.
    final under = Path()..moveTo(bottom.first.dx, bottom.first.dy);
    for (var i = n; i >= 0; i--) {
      final o = at(i / n) - normal(i / n) * width(i / n) * .2;
      under.lineTo(o.dx, o.dy);
    }
    for (final o in bottom.reversed) {
      under.lineTo(o.dx, o.dy);
    }
    c.save();
    c.clipPath(path);
    c.drawPath(under, Paint()..color = type.belly.withValues(alpha: .7));
    final shine = Path();
    for (var i = 2; i <= n - 4; i++) {
      final o = at(i / n) + normal(i / n) * width(i / n) * .5;
      i == 2 ? shine.moveTo(o.dx, o.dy) : shine.lineTo(o.dx, o.dy);
    }
    c.drawPath(shine, line(light.withValues(alpha: .6), ow * 1.2));
    c.restore();
    final d = dir(1);
    tailTip(p3 - d * .01, atan2(d.dy, d.dx));
  }

  void tailTip(Offset p, double angle) {
    final k = .055 + g * .03;
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(angle);
    final box = Rect.fromLTRB(-k * .3, -k, k * 1.8, k);
    switch (type.id) {
      case 'fire':
        final flame = Path()
          ..moveTo(k * 1.8, -k * .4)
          ..cubicTo(k * 1.15, -k * .2, k * 1.1, -k * .85, k * .35, -k * .66)
          ..cubicTo(-k * .25, -k * .48, -k * .3, k * .48, k * .3, k * .58)
          ..cubicTo(k * .85, k * .66, k * 1.05, k * .22, k * 1.4, k * .3)
          ..cubicTo(k * 1.15, k * .05, k * 1.35, -k * .2, k * 1.8, -k * .4)
          ..close();
        if (!silhouette) {
          paintGlow(c, Offset(k * .6, 0), k * 1.6, const Color(0xFFFFB74D), .6);
        }
        sticker(
          [flame],
          linear(
            box,
            const [Color(0xFFFF5A1F), Color(0xFFFFA726), Color(0xFFFFE082)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        );
        c.save();
        c.translate(k * .3, 0);
        c.scale(.55);
        c.drawPath(flame, Paint()..color = const Color(0xFFFFF4C2));
        c.restore();
      case 'water':
        final fin = Path()
          ..moveTo(-k * .1, 0)
          ..quadraticBezierTo(k * .35, -k * 1.05, k * 1.15, -k * .95)
          ..quadraticBezierTo(k * .8, -k * .45, k * 1.4, -k * .02)
          ..quadraticBezierTo(k * .8, k * .38, k * 1.1, k * .88)
          ..quadraticBezierTo(k * .35, k * .9, -k * .1, 0)
          ..close();
        sticker([fin], linear(box, [wingLight, type.wing]));
        final ray = line(Colors.white.withValues(alpha: .55), ow);
        for (final o in [
          Offset(k * .95, -k * .75),
          Offset(k * 1.15, -k * .02),
          Offset(k * .9, k * .7),
        ]) {
          c.drawLine(Offset(k * .1, 0), o, ray);
        }
      case 'earth':
        leaf(k, const Color(0xFFA5E07A), const Color(0xFF4E9A52));
      case 'crystal':
        final shard = Path()
          ..moveTo(-k * .05, 0)
          ..lineTo(k * .35, -k * .55)
          ..lineTo(k * 1.7, -k * .05)
          ..lineTo(k * .45, k * .5)
          ..close();
        sticker([shard], linear(box, [accentLight, type.accent, accentDark]));
        c.drawPath(
          Path()
            ..moveTo(-k * .05, 0)
            ..lineTo(k * .35, -k * .55)
            ..lineTo(k * 1.7, -k * .05)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: .45),
        );
      case 'blossom':
        flower(Offset(k * .6, 0), k * .75);
      case 'lumen':
        if (!silhouette) {
          paintGlow(
            c,
            Offset(k * .65, 0),
            k * 1.8,
            const Color(0xFFFFE082),
            .8,
          );
        }
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? k * .85 : k * .4;
          final a = i * pi / 5;
          final o = Offset(k * .65 + cos(a) * r, sin(a) * r);
          i == 0 ? star.moveTo(o.dx, o.dy) : star.lineTo(o.dx, o.dy);
        }
        star.close();
        sticker([
          star,
        ], linear(box, const [Color(0xFFFFF6C4), Color(0xFFFFC107)]));
      case 'shadow':
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(
            Rect.fromCircle(center: Offset(k * .6, 0), radius: k * .72),
          ),
          Path()..addOval(
            Rect.fromCircle(center: Offset(k * .95, -k * .3), radius: k * .6),
          ),
        );
        sticker([moon], linear(box, [accentLight, type.accent]));
        paintSparkle(c, Offset(k * 1.35, -k * .55), k * .3, accentLight);
      default:
        leaf(k, accentLight, type.accent);
    }
    c.restore();
  }

  void leaf(double k, Color a, Color b) {
    final p = Path()
      ..moveTo(-k * .05, 0)
      ..quadraticBezierTo(k * .45, -k * .9, k * 1.6, -k * .1)
      ..quadraticBezierTo(k * .6, k * .8, -k * .05, 0)
      ..close();
    sticker([p], linear(Rect.fromLTRB(0, -k, k * 1.6, k), [a, b]));
    final vein = line(Colors.white.withValues(alpha: .5), ow);
    c.drawLine(Offset(k * .05, 0), Offset(k * 1.35, -k * .1), vein);
    for (final x in [.45, .85]) {
      c.drawLine(
        Offset(k * x, -k * .04),
        Offset(k * (x + .25), -k * .35),
        vein,
      );
    }
  }

  void flower(Offset o, double r) {
    final petals = [
      for (var i = 0; i < 5; i++)
        () {
          final a = i * 2 * pi / 5 - pi / 2;
          final pc = o + Offset(cos(a), sin(a)) * r * .55;
          return Path()..addOval(Rect.fromCircle(center: pc, radius: r * .48));
        }(),
    ];
    sticker(
      petals,
      radial(
        o,
        r * 1.1,
        const [Color(0xFFFFFFFF), Color(0xFFFFC2DA), Color(0xFFF77FB0)],
        const [0, .45, 1],
      ),
      ow * 1.6,
    );
    c.drawCircle(o, r * .3, Paint()..color = const Color(0xFFFFD54F));
    c.drawCircle(
      o + Offset(-r * .08, -r * .08),
      r * .12,
      Paint()..color = const Color(0xFFFFF3C4),
    );
  }

  // ---------------------------------------------------------------------
  // Spikes, wings, horns

  /// One curved spike standing out from [base] along [dir].
  void spike(Offset base, Offset dir, double h, double hw) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(atan2(dir.dx, -dir.dy));
    final crystal = type.id == 'crystal';
    final p = crystal
        ? (Path()
            ..moveTo(-hw, hw * .5)
            ..lineTo(-hw * .55, -h * .8)
            ..lineTo(-hw * .1, -h * 1.15)
            ..lineTo(hw * .45, -h * .75)
            ..lineTo(hw, hw * .5)
            ..close())
        : (Path()
            ..moveTo(-hw, hw * .5)
            ..quadraticBezierTo(-hw * .55, -h * .5, -hw * 1.1, -h)
            ..quadraticBezierTo(hw * .7, -h * .5, hw, hw * .5)
            ..close());
    sticker(
      [p],
      linear(Rect.fromLTRB(-hw, -h, hw, hw), [
        accentLight,
        type.accent,
        accentDark,
      ]),
      ow * 1.8,
    );
    c.drawPath(
      Path()
        ..moveTo(-hw * .4, 0)
        ..lineTo(-hw * (crystal ? .3 : .75), -h * .75),
      line(Colors.white.withValues(alpha: .5), ow * .8),
    );
    c.restore();
  }

  void backSpikes() {
    if (level < 3) return;
    final k = level + 1;
    for (var i = 0; i < k; i++) {
      final t = i / (k - 1);
      final a = (196 + t * 68) * pi / 180;
      final base = bodyC + Offset(cos(a) * bw * .47, sin(a) * bh * .47);
      final nrm = Offset(cos(a) / bw, sin(a) / bh);
      final big = .75 + .4 * sin(pi * t);
      spike(base, nrm / nrm.distance, (.05 + g * .03) * big, .024 + g * .006);
    }
    if (level >= 4) {
      // Along the back of the neck.
      final n1 = Offset(bodyC.dx - bw * .04, bodyC.dy - bh * .4);
      final n2 = Offset(headC.dx - hr * .62, headC.dy + hr * .3);
      final d = n2 - n1;
      final nrm = Offset(d.dy, -d.dx) / d.distance;
      for (final t in [.35, .7]) {
        spike(n1 + d * t, nrm, .045 + g * .015, .022);
      }
    }
  }

  void wing({required bool near}) {
    final w = .165 + g * .15;
    final root = near
        ? Offset(bodyC.dx - bw * .04, bodyC.dy - bh * .34)
        : Offset(bodyC.dx + bw * .16, bodyC.dy - bh * .42);
    c.save();
    c.translate(root.dx, root.dy);
    c.rotate(near ? .14 - flap * .7 : .46 - flap * .55);
    if (!near) c.scale(.8);
    final wrist = Offset(-.08 * w, -1.05 * w);
    final tips = [
      Offset(-.8 * w, -.98 * w),
      Offset(-1.04 * w, -.56 * w),
      Offset(-.86 * w, -.14 * w),
    ];
    final membrane = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(.16 * w, -.6 * w, wrist.dx, wrist.dy)
      ..quadraticBezierTo(-.38 * w, -1.14 * w, tips[0].dx, tips[0].dy)
      ..quadraticBezierTo(-.66 * w, -.7 * w, tips[1].dx, tips[1].dy)
      ..quadraticBezierTo(-.72 * w, -.32 * w, tips[2].dx, tips[2].dy)
      ..quadraticBezierTo(-.48 * w, -.2 * w, -.3 * w, .04 * w)
      ..close();
    final box = Rect.fromLTRB(-1.05 * w, -1.1 * w, .2 * w, .1 * w);
    final top = near ? wingLight : type.wing;
    final bottom = near ? type.wing : wingDark;
    sticker(
      [membrane],
      linear(
        box,
        [top, bottom],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    );
    c.save();
    c.clipPath(membrane);
    softSpot(
      wrist + Offset(-.2 * w, .25 * w),
      .5 * w,
      Colors.white,
      near ? .3 : .12,
    );
    c.restore();
    // Finger bones
    final bone = line(wingDark.withValues(alpha: .9), ow * (1 + g * .4));
    for (final t in tips) {
      c.drawPath(
        Path()
          ..moveTo(wrist.dx, wrist.dy)
          ..quadraticBezierTo(
            (wrist.dx + t.dx) / 2 + .04 * w,
            (wrist.dy + t.dy) / 2 + .04 * w,
            t.dx,
            t.dy,
          ),
        bone,
      );
    }
    // Arm along the leading edge.
    final arm = Path()
      ..moveTo(.063 * w, -.4 * w)
      ..quadraticBezierTo(.076 * w, -.76 * w, wrist.dx, wrist.dy);
    final aw = .022 + g * .012;
    c.drawPath(arm, outline(aw + ow * 2));
    c.drawPath(arm, line(near ? body : shade, aw));
    if (!near) {
      c.restore();
      return;
    }
    // Little claw on the wrist.
    final hook = Path()
      ..moveTo(wrist.dx - aw * .5, wrist.dy)
      ..quadraticBezierTo(
        wrist.dx,
        wrist.dy - aw * 1.6,
        wrist.dx + aw * 1.0,
        wrist.dy - aw * 1.2,
      )
      ..quadraticBezierTo(
        wrist.dx + aw * .4,
        wrist.dy - aw * .6,
        wrist.dx + aw * .6,
        wrist.dy + aw * .2,
      )
      ..close();
    sticker(
      [hook],
      Paint()..color = Color.lerp(type.accent, type.belly, .35)!,
      ow * 1.4,
    );
    c.restore();
  }

  void earFrill() {
    final f = hr * (.62 + g * .2);
    c.save();
    final o = headC + Offset(-hr * .7, -hr * .08);
    c.translate(o.dx, o.dy);
    c.rotate(-.3);
    final p = Path()
      ..moveTo(f * .2, -f * .4)
      ..quadraticBezierTo(-f * .5, -f * .78, -f * 1.15, -f * .62)
      ..quadraticBezierTo(-f * .75, -f * .3, -f * 1.05, f * .05)
      ..quadraticBezierTo(-f * .6, f * .25, f * .2, f * .4)
      ..close();
    sticker([p], linear(p.getBounds(), [wingLight, type.wing]));
    final ray = line(wingDark.withValues(alpha: .6), ow * .9);
    c.drawLine(Offset.zero, Offset(-f * .95, -f * .52), ray);
    c.drawLine(Offset.zero, Offset(-f * .9, f * .02), ray);
    c.restore();
  }

  void horns() {
    if (level < 2) return;
    final len = .045 + g * .11;
    final hw = .024 + g * .01;
    final base0 = Color.lerp(type.accent, type.belly, .35)!;
    for (final far in [true, false]) {
      final base =
          headC +
          (far ? Offset(hr * .22, -hr * .86) : Offset(-hr * .22, -hr * .84));
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(far ? -.05 : -.3);
      final p = Path()
        ..moveTo(-hw, hw * .6)
        ..quadraticBezierTo(-hw * .7, -len * .65, -len * .5, -len)
        ..quadraticBezierTo(hw * .7, -len * .55, hw, hw * .6)
        ..close();
      final colA = far ? Color.lerp(base0, shade, .3)! : base0;
      final colB = level >= 5
          ? const Color(0xFFFFD54F)
          : Color.lerp(colA, Colors.white, .5)!;
      sticker(
        [p],
        linear(
          Rect.fromLTRB(-len * .5, -len, hw, hw),
          [colB, colA],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        ow * 1.8,
      );
      // Ridges on older horns.
      if (level >= 4) {
        c.save();
        c.clipPath(p);
        final ridge = line(ink.withValues(alpha: .3), ow * .8);
        for (final t in [.25, .5]) {
          final y = -len * t;
          c.drawLine(
            Offset(-hw * 1.4, y + hw * .3),
            Offset(hw * 1.2, y - hw * .2),
            ridge,
          );
        }
        c.restore();
      }
      c.drawLine(
        Offset(-hw * .35, 0),
        Offset(-hw * .5 - len * .2, -len * .65),
        line(Colors.white.withValues(alpha: .55), ow * .8),
      );
      c.restore();
    }
  }

  // ---------------------------------------------------------------------
  // Head

  void head() {
    sticker([headPath, Path()..addOval(snout)], skin, ow * 1.7);
    c.save();
    c.clipPath(face);
    // Lighter muzzle
    c.drawOval(
      snout.shift(Offset(hr * .08, hr * .05)),
      Paint()..color = Color.lerp(body, type.belly, .45)!.withValues(alpha: .6),
    );
    // Shadow under the jaw and shine on the forehead.
    softSpot(headC + Offset(hr * .2, hr * 1.05), hr * .85, shade, .55);
    softSpot(headC + Offset(-hr * .38, -hr * .45), hr * .62, Colors.white, .5);
    c.restore();
    // Rim light
    c.drawArc(
      Rect.fromCircle(center: headC, radius: hr * .84),
      3.5,
      1.0,
      false,
      line(Colors.white.withValues(alpha: .45), ow * 1.1),
    );
    // Cheek blush
    c.drawOval(
      Rect.fromCenter(
        center: headC + Offset(-hr * .1, hr * .44),
        width: hr * .44,
        height: hr * .24,
      ),
      radial(headC + Offset(-hr * .1, hr * .44), hr * .24, const [
        Color(0x88FF6B8B),
        Color(0x00FF6B8B),
      ]),
    );
  }

  void eye() {
    final er = hr * (.34 - g * .08);
    final eyeC = headC + Offset(hr * .1, -hr * .1);
    final sclera = Rect.fromCenter(
      center: eyeC,
      width: er * 1.6,
      height: er * 2.0,
    );
    if (blink) {
      c.drawArc(
        sclera.shift(Offset(0, er * .15)),
        .25,
        pi - .5,
        false,
        line(_ink, ow * 1.8),
      );
      c.drawLine(
        sclera.centerLeft + Offset(er * .05, er * .35),
        sclera.centerLeft + Offset(-er * .3, er * .05),
        line(_ink, ow * 1.4),
      );
      return;
    }
    c.drawOval(sclera, outline(ow * 1.6));
    c.drawOval(sclera, linear(sclera, const [Colors.white, Color(0xFFE6E0F5)]));
    c.save();
    c.clipPath(Path()..addOval(sclera));
    final irisC = eyeC + Offset(er * .22, er * .12);
    final iris = Rect.fromCenter(
      center: irisC,
      width: er * 1.2,
      height: er * 1.55,
    );
    final irisCol = level >= 5
        ? const Color(0xFFE0388F)
        : Color.lerp(type.wing, _ink, .25)!;
    c.drawOval(
      iris,
      radial(
        irisC + Offset(0, er * .3),
        er * .9,
        [
          Color.lerp(irisCol, Colors.white, .45)!,
          irisCol,
          Color.lerp(irisCol, _ink, .55)!,
        ],
        const [0, .55, 1],
      ),
    );
    c.drawOval(
      Rect.fromCenter(
        center: irisC + Offset(er * .04, er * .02),
        width: er * .62,
        height: er * .95,
      ),
      Paint()..color = const Color(0xFF1A0F28),
    );
    c.restore();
    // Catchlights
    c.drawCircle(
      eyeC + Offset(er * .45, -er * .38),
      er * .3,
      Paint()..color = Colors.white,
    );
    c.drawCircle(
      eyeC + Offset(-er * .02, er * .45),
      er * .13,
      Paint()..color = Colors.white.withValues(alpha: .85),
    );
    // Upper lid and a little lash.
    c.drawArc(sclera, pi * 1.08, pi * .86, false, line(_ink, ow * 2));
    c.drawLine(
      sclera.centerLeft + Offset(er * .08, -er * .5),
      sclera.centerLeft + Offset(-er * .28, -er * .82),
      line(_ink, ow * 1.5),
    );
    if (level >= 4) {
      // Brow
      c.drawArc(
        sclera.inflate(er * .35).shift(Offset(-er * .05, -er * .2)),
        pi * 1.15,
        pi * .55,
        false,
        line(shade.withValues(alpha: .6), ow * 1.5),
      );
    }
  }

  void snoutDetails() {
    // Nostril
    c.save();
    final n = snout.center + Offset(snout.width * .3, -snout.height * .14);
    c.translate(n.dx, n.dy);
    c.rotate(-.5);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: hr * .13, height: hr * .08),
      Paint()..color = ink.withValues(alpha: .7),
    );
    c.restore();
    // Smile
    final m0 = Offset(
      snout.left + snout.width * .3,
      snout.center.dy + snout.height * .2,
    );
    final m1 = Offset(
      snout.right - snout.width * .12,
      snout.center.dy + snout.height * .1,
    );
    c.drawPath(
      Path()
        ..moveTo(m0.dx, m0.dy)
        ..quadraticBezierTo(
          snout.center.dx + snout.width * .1,
          snout.bottom - snout.height * .04,
          m1.dx,
          m1.dy,
        ),
      line(ink, ow * 1.2),
    );
    if (level >= 3) {
      // Tiny fang
      final f = Offset(
        snout.center.dx + snout.width * .16,
        snout.bottom - snout.height * .12,
      );
      final fang = Path()
        ..moveTo(f.dx - hr * .06, f.dy - hr * .02)
        ..lineTo(f.dx + hr * .06, f.dy - hr * .04)
        ..lineTo(f.dx + hr * .01, f.dy + hr * .1)
        ..close();
      c.drawPath(fang, Paint()..color = Colors.white);
      c.drawPath(fang, line(ink.withValues(alpha: .6), ow * .8));
    }
    if (level >= 4) {
      // Whiskers droop from the upper lip.
      final long = level >= 5 ? .045 : 0.0;
      final s0 = Offset(
        snout.right - snout.width * .14,
        snout.center.dy + snout.height * .06,
      );
      strand(
        s0,
        s0 + const Offset(.04, .01),
        s0 + Offset(-.01, .05 + long * .4),
        s0 + Offset(.035 + long * .5, .085 + long),
        type.accent,
      );
      strand(
        s0 + Offset(-snout.width * .16, snout.height * .12),
        s0 + Offset(-snout.width * .16 + .02, .05),
        s0 + Offset(-.045, .03 + long * .3),
        s0 + Offset(-.04 - long * .5, .075 + long * .7),
        type.accent,
      );
    }
  }

  /// A thin tapering hair (whisker) along a curve.
  void strand(Offset p0, Offset p1, Offset p2, Offset p3, Color color) {
    Offset at(double t) {
      final u = 1 - t;
      return p0 * (u * u * u) +
          p1 * (3 * u * u * t) +
          p2 * (3 * u * t * t) +
          p3 * (t * t * t);
    }

    const n = 14;
    final pts = [for (var i = 0; i <= n; i++) at(i / n)];
    final a = <Offset>[];
    final b = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final d = pts[min(i + 1, n)] - pts[max(i - 1, 0)];
      final nrm = Offset(-d.dy, d.dx) / d.distance;
      final w = ow * (.55 * (1 - i / n) + .2);
      a.add(pts[i] + nrm * w);
      b.add(pts[i] - nrm * w);
    }
    final p = Path()..moveTo(a.first.dx, a.first.dy);
    for (final o in [...a.skip(1), ...b.reversed]) {
      p.lineTo(o.dx, o.dy);
    }
    p.close();
    sticker([p], Paint()..color = color, ow * 1.2);
  }

  /// Egg shell on babies, type flourishes and the Gemdrake crest.
  void headTop() {
    if (level == 1) {
      final o = headC + Offset(-hr * .12, -hr * .6);
      final sw = hr * 1.3;
      final sh = hr * .95;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(-.28);
      final shell = Path()
        ..addArc(
          Rect.fromCenter(center: Offset.zero, width: sw, height: sh),
          pi,
          pi,
        );
      const teeth = 6;
      for (var i = 1; i <= teeth; i++) {
        final x = sw / 2 - sw * i / teeth;
        shell.lineTo(x, i.isOdd ? sh * .16 : -sh * .02);
      }
      shell.close();
      sticker(
        [shell],
        linear(shell.getBounds(), const [Color(0xFFFFFCF2), Color(0xFFF2E2BF)]),
        ow * 1.8,
      );
      final dot = Paint()..color = type.accent.withValues(alpha: .7);
      for (final (x, y, r) in [
        (-.22, -.22, .07),
        (.12, -.32, .05),
        (.28, -.08, .06),
      ]) {
        c.drawCircle(Offset(sw * x, sh * y), hr * r, dot);
      }
      c.drawArc(
        Rect.fromCenter(center: Offset.zero, width: sw * .78, height: sh * .7),
        pi * 1.15,
        pi * .3,
        false,
        line(Colors.white, ow * 1.2),
      );
      c.restore();
      return;
    }
    if (type.id == 'earth') {
      // Little sprout
      final o = headC + Offset(-hr * .02, -hr * .95);
      c.drawPath(
        Path()
          ..moveTo(o.dx, o.dy + hr * .08)
          ..quadraticBezierTo(
            o.dx - hr * .02,
            o.dy - hr * .1,
            o.dx + hr * .04,
            o.dy - hr * .2,
          ),
        line(const Color(0xFF4E9A52), ow * 1.6),
      );
      for (final (dx, a) in [(-1.0, -2.6), (1.0, -.5)]) {
        c.save();
        c.translate(o.dx + hr * .04, o.dy - hr * .2);
        c.rotate(a);
        final l = Path()
          ..addOval(Rect.fromLTWH(0, -hr * .09, hr * .3, hr * .18));
        sticker(
          [l],
          Paint()
            ..color = Color.lerp(
              const Color(0xFF8BD66A),
              Colors.white,
              dx > 0 ? .1 : 0,
            )!,
          ow * 1.6,
        );
        c.restore();
      }
    }
    if (type.id == 'blossom') {
      flower(headC + Offset(-hr * .62, -hr * .62), hr * .32);
    }
    if (level >= 5) {
      final o = headC + Offset(hr * .02, -hr * .74);
      final gw = hr * .3;
      final gh = hr * .4;
      c.drawOval(
        Rect.fromCenter(
          center: o + Offset(0, gh * .32),
          width: gw * 1.6,
          height: gh * .5,
        ),
        Paint()..color = const Color(0xFFFFC94D),
      );
      final gem = Path()
        ..moveTo(o.dx, o.dy - gh * .6)
        ..lineTo(o.dx + gw * .5, o.dy - gh * .1)
        ..lineTo(o.dx, o.dy + gh * .45)
        ..lineTo(o.dx - gw * .5, o.dy - gh * .1)
        ..close();
      sticker(
        [gem],
        linear(gem.getBounds(), const [
          Color(0xFFFF9CD2),
          Color(0xFFE0388F),
          Color(0xFF9C1D62),
        ]),
        ow * 1.6,
      );
      c.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - gh * .6)
          ..lineTo(o.dx - gw * .5, o.dy - gh * .1)
          ..lineTo(o.dx, o.dy - gh * .02)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: .55),
      );
      if (!silhouette) {
        paintSparkle(c, o + Offset(gw * .55, -gh * .55), hr * .16);
      }
    }
  }
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
    if (character.hat == 'helmet') {
      final helmet = Path()
        ..addArc(
          Rect.fromCircle(center: c + Offset(0, -s * .05), radius: s * .34),
          pi + .1,
          pi - .2,
        )
        ..close();
      canvas.drawPath(helmet, hatPaint);
      canvas.drawPath(helmet, stroke);
      canvas.drawRect(
        Rect.fromCenter(
          center: c + Offset(0, -s * .13),
          width: s * .7,
          height: s * .06,
        ),
        Paint()..color = const Color(0xFFFFD166),
      );
      return;
    }
    if (character.hat == 'crown') {
      final crown = Path()
        ..moveTo(c.dx - s * .26, c.dy - s * .22)
        ..lineTo(c.dx - s * .3, c.dy - s * .46)
        ..lineTo(c.dx - s * .12, c.dy - s * .34)
        ..lineTo(c.dx, c.dy - s * .52)
        ..lineTo(c.dx + s * .12, c.dy - s * .34)
        ..lineTo(c.dx + s * .3, c.dy - s * .46)
        ..lineTo(c.dx + s * .26, c.dy - s * .22)
        ..close();
      canvas.drawPath(crown, hatPaint);
      canvas.drawPath(crown, stroke);
      canvas.drawCircle(
        c + Offset(0, -s * .4),
        s * .04,
        Paint()..color = Colors.white,
      );
      return;
    }
    if (character.hat == 'hood') {
      final hood = Path()
        ..moveTo(c.dx - s * .4, c.dy + s * .2)
        ..quadraticBezierTo(c.dx - s * .46, c.dy - s * .5, c.dx, c.dy - s * .5)
        ..quadraticBezierTo(
          c.dx + s * .46,
          c.dy - s * .5,
          c.dx + s * .4,
          c.dy + s * .2,
        )
        ..lineTo(c.dx + s * .3, c.dy + s * .1)
        ..quadraticBezierTo(c.dx + s * .3, c.dy - s * .3, c.dx, c.dy - s * .32)
        ..quadraticBezierTo(
          c.dx - s * .3,
          c.dy - s * .3,
          c.dx - s * .3,
          c.dy + s * .1,
        )
        ..close();
      canvas.drawPath(hood, hatPaint);
      canvas.drawPath(hood, stroke);
      paintSparkle(
        canvas,
        c + Offset(s * .22, -s * .36),
        s * .05,
        const Color(0xFFFFE082),
      );
      return;
    }
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

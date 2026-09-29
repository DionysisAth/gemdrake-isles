import 'dart:math';

import 'package:flutter/material.dart';

/// Small organic shapes shared by the island and board painters: tapered
/// ribbons (stems, vines, branches, cracks), leaves, grass blades, flowers
/// and soft blobs. Everything is filled rather than stroked so it reads as
/// painted instead of drawn with lines.

/// A filled shape that follows [spine], [w0] wide at the start and [w1] at
/// the end, with rounded caps.
Path ribbon(Path spine, double w0, double w1, {int samples = 18}) {
  final left = <Offset>[], right = <Offset>[];
  for (final m in spine.computeMetrics()) {
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final tan = m.getTangentForOffset(m.length * t);
      if (tan == null) continue;
      final n = Offset(-tan.vector.dy, tan.vector.dx);
      final half = (w0 + (w1 - w0) * t) / 2;
      left.add(tan.position + n * half);
      right.add(tan.position - n * half);
    }
    break;
  }
  final path = Path();
  if (left.isEmpty) return path;
  path.moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  final endR = w1 / 2;
  if (endR > .3) {
    path.arcToPoint(right.last, radius: Radius.circular(endR));
  } else {
    path.lineTo(right.last.dx, right.last.dy);
  }
  for (final p in right.reversed.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  final startR = w0 / 2;
  if (startR > .3) {
    path.arcToPoint(left.first, radius: Radius.circular(startR));
  }
  return path..close();
}

/// A curved spine from [a] to [b], bowed sideways by [bend] (fraction of
/// the length; positive bends to the left of the direction of travel).
Path curve(Offset a, Offset b, double bend) {
  final d = b - a;
  final n = Offset(-d.dy, d.dx);
  final m = (a + b) / 2 + n * bend;
  return Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy);
}

/// A pointed leaf whose base sits at [base], pointing along [angle].
Path leafPath(Offset base, double angle, double len, double width) {
  final dir = Offset(cos(angle), sin(angle));
  final n = Offset(-dir.dy, dir.dx);
  final tip = base + dir * len;
  final c1 = base + dir * len * .45 + n * width;
  final c2 = base + dir * len * .45 - n * width;
  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(c2.dx, c2.dy, base.dx, base.dy)
    ..close();
}

/// A two-tone leaf: [dark] body with a lighter half and a thin midrib.
void paintLeaf(
  Canvas c,
  Offset base,
  double angle,
  double len,
  Color light,
  Color dark,
) {
  final w = len * .38;
  c.drawPath(leafPath(base, angle, len, w), Paint()..color = dark);
  final dir = Offset(cos(angle), sin(angle));
  final n = Offset(-dir.dy, dir.dx);
  final tip = base + dir * len;
  final c1 = base + dir * len * .45 + n * w;
  c.drawPath(
    Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
      ..lineTo(base.dx, base.dy)
      ..close(),
    Paint()..color = light,
  );
}

/// A tapered blade of grass rising from [base], leaning by [lean] radians.
Path bladePath(Offset base, double height, double width, double lean) {
  final tip = base + Offset(sin(lean) * height, -cos(lean) * height);
  final ctrl = base + Offset(sin(lean) * height * .2, -height * .6);
  return Path()
    ..moveTo(base.dx - width / 2, base.dy)
    ..quadraticBezierTo(ctrl.dx - width * .3, ctrl.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(
      ctrl.dx + width * .3,
      ctrl.dy,
      base.dx + width / 2,
      base.dy,
    )
    ..close();
}

/// A little clump of 3-5 grass blades.
void paintTuft(
  Canvas c,
  Offset base,
  double size,
  Color light,
  Color dark, {
  int blades = 3,
}) {
  for (var i = 0; i < blades; i++) {
    final t = blades == 1 ? 0.0 : i / (blades - 1) - .5;
    final h = size * (1 - t.abs() * .5);
    c.drawPath(
      bladePath(base + Offset(t * size * .5, 0), h, size * .22, t * .9),
      Paint()..color = i.isEven ? dark : light,
    );
  }
}

/// A five-petal flower seen from above.
void paintFlower(
  Canvas c,
  Offset o,
  double r,
  Color petal, [
  Color center = const Color(0xFFFFC43D),
  double spin = 0,
]) {
  final p = Paint()..color = petal;
  for (var i = 0; i < 5; i++) {
    final a = spin + i * pi * 2 / 5;
    c.drawCircle(o + Offset(cos(a), sin(a)) * r * .55, r * .48, p);
  }
  c.drawCircle(o, r * .38, Paint()..color = center);
  c.drawCircle(
    o - Offset(r * .1, r * .1),
    r * .14,
    Paint()..color = Colors.white.withValues(alpha: .7),
  );
}

/// A smooth closed blob around [center] with a wobbly outline.
Path blobPath(Offset center, double rx, double ry, int seed, {int lobes = 9}) {
  final rnd = Random(seed);
  final pts = <Offset>[];
  for (var i = 0; i < lobes; i++) {
    final a = i * pi * 2 / lobes + rnd.nextDouble() * .3;
    final k = .78 + rnd.nextDouble() * .3;
    pts.add(center + Offset(cos(a) * rx * k, sin(a) * ry * k));
  }
  final path = Path();
  final start = (pts.last + pts.first) / 2;
  path.moveTo(start.dx, start.dy);
  for (var i = 0; i < pts.length; i++) {
    final cur = pts[i];
    final next = pts[(i + 1) % pts.length];
    final mid = (cur + next) / 2;
    path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
  }
  return path..close();
}

/// A jagged crack from [a] to [b] with [kinks] random bends.
List<Offset> jagged(Offset a, Offset b, int kinks, double amp, Random rnd) {
  final d = b - a;
  final n = Offset(-d.dy, d.dx) / max(1.0, d.distance);
  return [
    a,
    for (var i = 1; i <= kinks; i++)
      a + d * (i / (kinks + 1)) + n * amp * (rnd.nextDouble() * 2 - 1),
    b,
  ];
}

Path polyline(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final o in pts.skip(1)) {
    p.lineTo(o.dx, o.dy);
  }
  return p;
}

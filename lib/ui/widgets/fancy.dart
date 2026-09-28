import 'dart:math';

import 'package:flutter/material.dart';

import '../painters/item_painter.dart';
import '../theme.dart';

/// A title ribbon with folded tails, a glossy face and a light sweep.
class RibbonBanner extends StatelessWidget {
  const RibbonBanner({super.key, required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(color, Colors.black, .45)!;
    return CustomPaint(
      painter: _RibbonPainter(color),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 9, 40, 13),
        child: ShineSweep(
          child: OutlinedText(title, size: 21, strokeWidth: 3.5, stroke: dark),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final dark = Color.lerp(color, Colors.black, .35)!;
    final darker = Color.lerp(color, Colors.black, .55)!;
    final light = Color.lerp(color, Colors.white, .35)!;
    const tail = 22.0;
    const inset = 16.0;
    // Tails (behind), notched ends.
    for (final left in [true, false]) {
      final x0 = left ? inset + 4 : w - inset - 4;
      final dir = left ? -1.0 : 1.0;
      final tailPath = Path()
        ..moveTo(x0, h * .28)
        ..lineTo(x0 + dir * (inset + tail), h * .28)
        ..lineTo(x0 + dir * (inset + tail - 10), h * .66)
        ..lineTo(x0 + dir * (inset + tail), h * 1.02)
        ..lineTo(x0, h * 1.02)
        ..close();
      canvas.drawPath(tailPath, Paint()..color = dark);
      // Fold shadow
      canvas.drawPath(
        Path()
          ..moveTo(x0, h * .84)
          ..lineTo(x0 + dir * 8, h * 1.02)
          ..lineTo(x0, h * 1.02)
          ..close(),
        Paint()..color = darker,
      );
    }
    // Face
    final face = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, 0, w - inset * 2, h * .86),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      face.shift(const Offset(0, 4)),
      Paint()..color = darker.withValues(alpha: .6),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, color, dark],
          stops: const [0, .55, 1],
        ).createShader(face.outerRect),
    );
    canvas.drawRRect(
      face.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .55),
    );
    // Stitching
    final stitch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: .45);
    for (final y in [5.0, face.outerRect.bottom - 5]) {
      for (var x = inset + 12; x < w - inset - 12; x += 9) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), stitch);
      }
    }
    // Gloss
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset + 8, 3, w - inset * 2 - 16, h * .26),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: .28),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.color != color;
}

/// A band of light that sweeps across [child] every few seconds.
class ShineSweep extends StatefulWidget {
  const ShineSweep({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 3200),
  });

  final Widget child;
  final Duration period;

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // Sweep during the first 30% of each period, then rest.
        final t = (_c.value / .3).clamp(0.0, 1.0);
        if (t >= 1) return child!;
        final x = -1.5 + 3 * t;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - .5, -1),
            end: Alignment(x + .5, 1),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: .75),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Little stars that twinkle around a spot (used next to titles).
class Twinkles extends StatefulWidget {
  const Twinkles({super.key, this.count = 5, this.color = Colors.white});

  final int count;
  final Color color;

  @override
  State<Twinkles> createState() => _TwinklesState();
}

class _TwinklesState extends State<Twinkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  late final List<(double, double, double, double)> _stars = () {
    final r = Random(7);
    return [
      for (var i = 0; i < widget.count; i++)
        (
          r.nextDouble(),
          r.nextDouble(),
          4 + r.nextDouble() * 5,
          r.nextDouble(),
        ),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _TwinklePainter(_stars, _c.value, widget.color),
      ),
    ),
  );
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter(this.stars, this.t, this.color);

  final List<(double, double, double, double)> stars;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, r, phase) in stars) {
      final k = (sin((t + phase) * pi * 2) + 1) / 2;
      if (k < .15) continue;
      paintSparkle(
        canvas,
        Offset(x * size.width, y * size.height),
        r * (.5 + .5 * k),
        color.withValues(alpha: k),
      );
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter old) => old.t != t;
}

/// Slowly turning light rays (behind celebratory popups).
class RotatingRays extends StatefulWidget {
  const RotatingRays({super.key, this.color = const Color(0xFFFFF1A8)});

  final Color color;

  @override
  State<RotatingRays> createState() => _RotatingRaysState();
}

class _RotatingRaysState extends State<RotatingRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _RaysBgPainter(_c.value, widget.color),
      ),
    ),
  );
}

class _RaysBgPainter extends CustomPainter {
  _RaysBgPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide * .75;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: .55), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = t * pi * 2 + i * pi * 2 / n;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a - .1) * r, c.dy + sin(a - .1) * r)
          ..lineTo(c.dx + cos(a + .1) * r, c.dy + sin(a + .1) * r)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysBgPainter old) => old.t != t;
}

/// Tiny cut gems for dialog corners.
class CornerGem extends StatelessWidget {
  const CornerGem({super.key, this.color = Palette.pink, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CornerGemPainter(color));
}

class _CornerGemPainter extends CustomPainter {
  _CornerGemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = Path()
      ..moveTo(s / 2, 0)
      ..lineTo(s, s / 2)
      ..lineTo(s / 2, s)
      ..lineTo(0, s / 2)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, .6)!, color],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s / 2, s * .15)
        ..lineTo(s * .75, s / 2)
        ..lineTo(s / 2, s / 2)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .6),
    );
  }

  @override
  bool shouldRepaint(_CornerGemPainter old) => old.color != color;
}

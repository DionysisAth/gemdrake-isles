import 'dart:math';

import 'package:flutter/material.dart';

import 'painters/item_painter.dart';

/// Fire-and-forget juice: particle bursts, icons flying to counters,
/// floating "+5" text and screen flashes. All positions are global.
class FxController {
  _FxLayerState? _state;

  void burst(
    Offset at, {
    Color color = const Color(0xFFFFE27A),
    int count = 14,
    double spread = 70,
  }) => _state?._add(
    (key, done) => _Burst(
      key: key,
      at: at,
      color: color,
      count: count,
      spread: spread,
      onDone: done,
    ),
  );

  void fly({
    required Offset from,
    required Offset to,
    required Widget icon,
    int count = 6,
    VoidCallback? onArrive,
  }) => _state?._add(
    (key, done) => _Fly(
      key: key,
      from: from,
      to: to,
      icon: icon,
      count: count,
      onDone: done,
      onArrive: onArrive,
    ),
  );

  void floatText(Offset at, String text, {Color color = Colors.white}) =>
      _state?._add(
        (key, done) => _FloatText(
          key: key,
          at: at,
          text: text,
          color: color,
          onDone: done,
        ),
      );

  void flash(Color color) =>
      _state?._add((key, done) => _Flash(key: key, color: color, onDone: done));
}

class FxLayer extends StatefulWidget {
  const FxLayer({super.key, required this.controller});

  final FxController controller;

  @override
  State<FxLayer> createState() => _FxLayerState();
}

class _FxLayerState extends State<FxLayer> {
  final _effects = <Key, Widget>{};
  var _n = 0;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    super.dispose();
  }

  void _add(Widget Function(Key key, VoidCallback done) build) {
    if (!mounted) return;
    final key = ValueKey(_n++);
    setState(() {
      _effects[key] = build(key, () {
        if (mounted) setState(() => _effects.remove(key));
      });
    });
  }

  /// Converts a global point into this layer's coordinates.
  Offset local(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(clipBehavior: Clip.none, children: _effects.values.toList()),
  );
}

mixin _OneShot<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController anim;
  Duration get duration;
  VoidCallback get onDone;

  @override
  void initState() {
    super.initState();
    anim = AnimationController(vsync: this, duration: duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  Offset toLocal(Offset global) =>
      context.findAncestorStateOfType<_FxLayerState>()?.local(global) ?? global;
}

class _Burst extends StatefulWidget {
  const _Burst({
    super.key,
    required this.at,
    required this.color,
    required this.count,
    required this.spread,
    required this.onDone,
  });

  final Offset at;
  final Color color;
  final int count;
  final double spread;
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst>
    with SingleTickerProviderStateMixin, _OneShot {
  late final List<(double, double, double, bool)> _parts;

  @override
  Duration get duration => const Duration(milliseconds: 650);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  void initState() {
    final r = Random();
    _parts = [
      for (var i = 0; i < widget.count; i++)
        (
          r.nextDouble() * pi * 2,
          .5 + r.nextDouble() * .5,
          3 + r.nextDouble() * 4,
          r.nextBool(),
        ),
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final at = toLocal(widget.at);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) => CustomPaint(
          painter: _BurstPainter(
            at,
            _parts,
            anim.value,
            widget.color,
            widget.spread,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.at, this.parts, this.t, this.color, this.spread);

  final Offset at;
  final List<(double, double, double, bool)> parts;
  final double t;
  final Color color;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(t);
    final alpha = (1 - t).clamp(0.0, 1.0);
    // Ring
    canvas.drawCircle(
      at,
      spread * .7 * ease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t)
        ..color = Colors.white.withValues(alpha: alpha * .8),
    );
    for (final (angle, speed, size, star) in parts) {
      final p =
          at +
          Offset(cos(angle), sin(angle)) * spread * speed * ease +
          Offset(0, 20 * t * t);
      if (star) {
        paintSparkle(
          canvas,
          p,
          size * 1.6 * (1 - t * .5),
          Colors.white.withValues(alpha: alpha),
        );
      } else {
        canvas.drawCircle(
          p,
          size * (1 - t * .6),
          Paint()..color = color.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class _Fly extends StatefulWidget {
  const _Fly({
    super.key,
    required this.from,
    required this.to,
    required this.icon,
    required this.count,
    required this.onDone,
    this.onArrive,
  });

  final Offset from;
  final Offset to;
  final Widget icon;
  final int count;
  final VoidCallback onDone;
  final VoidCallback? onArrive;

  @override
  State<_Fly> createState() => _FlyState();
}

class _FlyState extends State<_Fly>
    with SingleTickerProviderStateMixin, _OneShot {
  final _r = Random();
  late final List<Offset> _scatter = [
    for (var i = 0; i < widget.count; i++)
      Offset(_r.nextDouble() * 80 - 40, _r.nextDouble() * 60 - 40),
  ];
  var _arrived = false;

  @override
  Duration get duration => Duration(milliseconds: 700 + widget.count * 45);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final from = toLocal(widget.from);
    final to = toLocal(widget.to);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        if (!_arrived && anim.value > .75) {
          _arrived = true;
          widget.onArrive?.call();
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < widget.count; i++)
              Builder(
                builder: (context) {
                  final start = i * .05;
                  final t = ((anim.value - start) / (1 - start * 1.5)).clamp(
                    0.0,
                    1.0,
                  );
                  // Pop out, then swoop to the counter.
                  final out = Curves.easeOut.transform(
                    (t / .3).clamp(0.0, 1.0),
                  );
                  final go = Curves.easeInCubic.transform(
                    ((t - .3) / .7).clamp(0.0, 1.0),
                  );
                  final scattered = from + _scatter[i] * out;
                  final pos = Offset.lerp(scattered, to, go)!;
                  final scale = t >= 1 ? 0.0 : (.6 + .5 * out - .3 * go);
                  return Positioned(
                    left: pos.dx - 14,
                    top: pos.dy - 14,
                    child: Transform.scale(
                      scale: scale,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: widget.icon,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _FloatText extends StatefulWidget {
  const _FloatText({
    super.key,
    required this.at,
    required this.text,
    required this.color,
    required this.onDone,
  });

  final Offset at;
  final String text;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_FloatText> createState() => _FloatTextState();
}

class _FloatTextState extends State<_FloatText>
    with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => const Duration(milliseconds: 1100);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final at = toLocal(widget.at);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value;
        return Positioned(
          left: at.dx - 100,
          top: at.dy - 20 - 50 * Curves.easeOut.transform(t),
          width: 200,
          child: Opacity(
            opacity: t < .7 ? 1 : (1 - (t - .7) / .3),
            child: Transform.scale(
              scale: t < .15 ? .6 + t / .15 * .4 : 1,
              child: child,
            ),
          ),
        );
      },
      child: Center(
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: widget.color,
            shadows: const [
              Shadow(
                color: Color(0xFF3B2A5A),
                blurRadius: 0,
                offset: Offset(1.5, 1.5),
              ),
              Shadow(
                color: Color(0xFF3B2A5A),
                blurRadius: 0,
                offset: Offset(-1.5, 1.5),
              ),
              Shadow(
                color: Color(0xFF3B2A5A),
                blurRadius: 0,
                offset: Offset(1.5, -1.5),
              ),
              Shadow(
                color: Color(0xFF3B2A5A),
                blurRadius: 0,
                offset: Offset(-1.5, -1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Flash extends StatefulWidget {
  const _Flash({super.key, required this.color, required this.onDone});

  final Color color;
  final VoidCallback onDone;

  @override
  State<_Flash> createState() => _FlashState();
}

class _FlashState extends State<_Flash>
    with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => const Duration(milliseconds: 500);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: AnimatedBuilder(
      animation: anim,
      builder: (context, _) => ColoredBox(
        color: widget.color.withValues(
          alpha: widget.color.a * (1 - anim.value),
        ),
      ),
    ),
  );
}

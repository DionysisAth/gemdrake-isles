import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

  /// An expanding ring of light.
  void shockwave(
    Offset at, {
    Color color = Colors.white,
    double radius = 90,
    double width = 10,
    Duration duration = const Duration(milliseconds: 550),
  }) => _state?._add(
    (key, done) => _Shockwave(
      key: key,
      at: at,
      color: color,
      radius: radius,
      width: width,
      duration: duration,
      onDone: done,
    ),
  );

  /// Spinning light rays that fade out.
  void rays(Offset at, {Color color = Colors.white, double radius = 140}) =>
      _state?._add(
        (key, done) =>
            _Rays(key: key, at: at, color: color, radius: radius, onDone: done),
      );

  /// A big bouncy word ("Great!", "BONUS x3!").
  void combo(
    Offset at,
    String text, {
    List<Color> colors = const [Color(0xFFFFF3A0), Color(0xFFFFB300)],
    double size = 34,
  }) => _state?._add(
    (key, done) => _Combo(
      key: key,
      at: at,
      text: text,
      colors: colors,
      size: size,
      onDone: done,
    ),
  );

  /// Colorful paper confetti bursting up and fluttering down.
  void confetti(Offset at, {int count = 40, double power = 1}) => _state?._add(
    (key, done) =>
        _Confetti(key: key, at: at, count: count, power: power, onDone: done),
  );

  /// Sparkles streaking from [from] into [to] (pieces fusing together).
  void streak(Offset from, Offset to, {Color color = Colors.white}) =>
      _state?._add(
        (key, done) =>
            _Streak(key: key, from: from, to: to, color: color, onDone: done),
      );

  /// Shakes the game screen (see [shakeOffset]).
  void shake(double amplitude, {int ms = 300}) => _state?._shake(amplitude, ms);

  /// Current screen-shake offset; the home screen translates by it.
  final shakeOffset = ValueNotifier(Offset.zero);
}

class FxLayer extends StatefulWidget {
  const FxLayer({super.key, required this.controller});

  final FxController controller;

  @override
  State<FxLayer> createState() => _FxLayerState();
}

class _FxLayerState extends State<FxLayer> with SingleTickerProviderStateMixin {
  final _effects = <Key, Widget>{};
  var _n = 0;
  late final Ticker _shaker = createTicker(_onShake);
  final _rand = Random();
  double _amp = 0;
  int _shakeMs = 1;
  Duration _shakeStart = Duration.zero;
  bool _shakeFresh = false;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _shaker.dispose();
    super.dispose();
  }

  void _shake(double amplitude, int ms) {
    if (!mounted) return;
    // A stronger shake replaces a weaker one still running.
    if (_shaker.isActive && amplitude < _amp) return;
    _amp = amplitude;
    _shakeMs = ms;
    _shakeFresh = true;
    if (!_shaker.isActive) _shaker.start();
  }

  void _onShake(Duration elapsed) {
    if (_shakeFresh) {
      _shakeStart = elapsed;
      _shakeFresh = false;
    }
    final t = (elapsed - _shakeStart).inMilliseconds / _shakeMs;
    final notifier = widget.controller.shakeOffset;
    if (t >= 1) {
      _shaker.stop();
      _amp = 0;
      notifier.value = Offset.zero;
      return;
    }
    final a = _amp * (1 - t) * (1 - t);
    notifier.value = Offset(
      (_rand.nextDouble() * 2 - 1) * a,
      (_rand.nextDouble() * 2 - 1) * a,
    );
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

class _Shockwave extends StatefulWidget {
  const _Shockwave({
    super.key,
    required this.at,
    required this.color,
    required this.radius,
    required this.width,
    required this.duration,
    required this.onDone,
  });

  final Offset at;
  final Color color;
  final double radius;
  final double width;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_Shockwave> createState() => _ShockwaveState();
}

class _ShockwaveState extends State<_Shockwave>
    with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => widget.duration;
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final at = toLocal(widget.at);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) => CustomPaint(
          painter: _ShockwavePainter(
            at,
            anim.value,
            widget.color,
            widget.radius,
            widget.width,
          ),
        ),
      ),
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter(this.at, this.t, this.color, this.radius, this.width);

  final Offset at;
  final double t;
  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final e = Curves.easeOutCubic.transform(t);
    final r = radius * (.15 + .85 * e);
    final a = (1 - t).clamp(0.0, 1.0);
    // Soft inner glow
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: .25 * a),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * (1 - e * .8)
        ..color = color.withValues(alpha: .9 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) => old.t != t;
}

class _Rays extends StatefulWidget {
  const _Rays({
    super.key,
    required this.at,
    required this.color,
    required this.radius,
    required this.onDone,
  });

  final Offset at;
  final Color color;
  final double radius;
  final VoidCallback onDone;

  @override
  State<_Rays> createState() => _RaysState();
}

class _RaysState extends State<_Rays>
    with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => const Duration(milliseconds: 900);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final at = toLocal(widget.at);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) => CustomPaint(
          painter: _RaysPainter(at, anim.value, widget.color, widget.radius),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.at, this.t, this.color, this.radius);

  final Offset at;
  final double t;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = Curves.easeOutBack.transform((t / .35).clamp(0.0, 1.0));
    final a = t < .5 ? 1.0 : (1 - (t - .5) / .5);
    final r = radius * grow;
    if (r <= 0) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: .75 * a),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: at, radius: r));
    const n = 10;
    final spin = t * .9;
    for (var i = 0; i < n; i++) {
      final ang = spin + i * 2 * pi / n;
      final path = Path()
        ..moveTo(at.dx, at.dy)
        ..lineTo(at.dx + cos(ang - .13) * r, at.dy + sin(ang - .13) * r)
        ..lineTo(at.dx + cos(ang + .13) * r, at.dy + sin(ang + .13) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.t != t;
}

class _Combo extends StatefulWidget {
  const _Combo({
    super.key,
    required this.at,
    required this.text,
    required this.colors,
    required this.size,
    required this.onDone,
  });

  final Offset at;
  final String text;
  final List<Color> colors;
  final double size;
  final VoidCallback onDone;

  @override
  State<_Combo> createState() => _ComboState();
}

class _ComboState extends State<_Combo>
    with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => const Duration(milliseconds: 1300);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final at = toLocal(widget.at);
    final style = TextStyle(
      fontSize: widget.size,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: 1,
    );
    final text = Stack(
      children: [
        Text(
          widget.text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = widget.size * .2
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF3B1F66),
          ),
        ),
        Text(
          widget.text,
          style: style.copyWith(
            foreground: Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.colors,
              ).createShader(Rect.fromLTWH(0, 0, 10, widget.size)),
          ),
        ),
      ],
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value;
        final pop = Curves.elasticOut.transform((t / .45).clamp(0.0, 1.0));
        final rise = Curves.easeIn.transform(((t - .6) / .4).clamp(0.0, 1.0));
        final wobble = sin(t * pi * 6) * .06 * (1 - t);
        return Positioned(
          left: at.dx - 160,
          top: at.dy - widget.size - 30 - 40 * rise,
          width: 320,
          child: Opacity(
            opacity: (1 - rise).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: wobble,
              child: Transform.scale(scale: .3 + .7 * pop, child: child),
            ),
          ),
        );
      },
      child: Center(child: text),
    );
  }
}

class _Confetti extends StatefulWidget {
  const _Confetti({
    super.key,
    required this.at,
    required this.count,
    required this.power,
    required this.onDone,
  });

  final Offset at;
  final int count;
  final double power;
  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin, _OneShot {
  static const _colors = [
    Color(0xFFFF5FA2),
    Color(0xFFFFC43D),
    Color(0xFF4CBF6B),
    Color(0xFF3FA7F5),
    Color(0xFF9C6BFF),
    Color(0xFFFF8A3D),
  ];
  late final List<List<double>> _parts;

  @override
  Duration get duration => const Duration(milliseconds: 1600);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  void initState() {
    final r = Random();
    _parts = [
      for (var i = 0; i < widget.count; i++)
        [
          (r.nextDouble() * 2 - 1) * 220 * widget.power, // vx
          -(250 + r.nextDouble() * 350) * widget.power, // vy
          r.nextDouble() * pi * 2, // rotation
          (r.nextDouble() * 2 - 1) * 14, // spin
          r.nextInt(_colors.length).toDouble(),
          5 + r.nextDouble() * 5, // size
          r.nextDouble() * pi * 2, // flutter phase
        ],
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final at = toLocal(widget.at);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) =>
            CustomPaint(painter: _ConfettiPainter(at, _parts, anim.value)),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.at, this.parts, this.t);

  final Offset at;
  final List<List<double>> parts;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t * 1.6;
    final a = t < .75 ? 1.0 : (1 - (t - .75) / .25);
    for (final p in parts) {
      // Air drag: fast burst, then a slow flutter down.
      final drag = 1 - exp(-3 * time);
      final x = at.dx + p[0] * drag / 3 + sin(time * 5 + p[6]) * 8;
      final y = at.dy + p[1] * drag / 3 + 160 * time * time;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p[2] + p[3] * time);
      final w = p[5];
      final flip = cos(time * 9 + p[6]).abs();
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: w,
          height: w * .55 * (.3 + .7 * flip),
        ),
        Paint()
          ..color = _ConfettiState._colors[p[4].toInt()].withValues(alpha: a),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Streak extends StatefulWidget {
  const _Streak({
    super.key,
    required this.from,
    required this.to,
    required this.color,
    required this.onDone,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_Streak> createState() => _StreakState();
}

class _StreakState extends State<_Streak>
    with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => const Duration(milliseconds: 380);
  @override
  VoidCallback get onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    final from = toLocal(widget.from);
    final to = toLocal(widget.to);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) => CustomPaint(
          painter: _StreakPainter(from, to, anim.value, widget.color),
        ),
      ),
    );
  }
}

class _StreakPainter extends CustomPainter {
  _StreakPainter(this.from, this.to, this.t, this.color);

  final Offset from;
  final Offset to;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final head = Curves.easeInCubic.transform(t);
    final tail = Curves.easeInCubic.transform((t - .25).clamp(0.0, 1.0));
    // Curve slightly so several streaks don't overlap.
    final mid =
        Offset.lerp(from, to, .5)! +
        Offset(-(to.dy - from.dy), to.dx - from.dx) * .15;
    Offset at(double u) {
      final a = Offset.lerp(from, mid, u)!;
      final b = Offset.lerp(mid, to, u)!;
      return Offset.lerp(a, b, u)!;
    }

    const steps = 10;
    for (var i = 0; i <= steps; i++) {
      final u = tail + (head - tail) * i / steps;
      final k = i / steps;
      canvas.drawCircle(
        at(u),
        2 + 5 * k,
        Paint()..color = color.withValues(alpha: .25 + .6 * k),
      );
    }
    paintSparkle(canvas, at(head), 9, Colors.white);
  }

  @override
  bool shouldRepaint(_StreakPainter old) => old.t != t;
}

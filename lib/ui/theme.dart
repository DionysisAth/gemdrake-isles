import 'package:flutter/material.dart';

class Palette {
  static const ink = Color(0xFF3B2A5A);
  static const inkSoft = Color(0xFF6E5D8C);
  static const panel = Color(0xFFFFF8EE);
  static const panelEdge = Color(0xFFE9D9C4);
  static const wood = Color(0xFF9A6B4A);
  static const woodDark = Color(0xFF6E4A33);
  static const accent = Color(0xFF8E5CF7);
  static const green = Color(0xFF4CBF6B);
  static const greenDark = Color(0xFF2E9A4F);
  static const gold = Color(0xFFFFC43D);
  static const pink = Color(0xFFFF5FA2);
  static const sky1 = Color(0xFF9ED8FF);
  static const sky2 = Color(0xFFE6D7FF);
  static const danger = Color(0xFFE5484D);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Fredoka',
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.accent,
      brightness: Brightness.light,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
      fontFamily: 'Fredoka',
    ),
    sliderTheme: base.sliderTheme.copyWith(activeTrackColor: Palette.accent),
  );
}

/// Chunky text with a dark outline, for numbers and titles over art.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 16,
    this.color = Colors.white,
    this.stroke = Palette.ink,
    this.strokeWidth = 3,
    this.weight = FontWeight.w700,
  });

  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double strokeWidth;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: weight, height: 1.1);
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(text, style: style.copyWith(color: color)),
      ],
    );
  }
}

/// Cozy rounded panel.
BoxDecoration panelDecoration({
  Color color = Palette.panel,
  double radius = 18,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Palette.panelEdge, width: 2),
  boxShadow: const [
    BoxShadow(color: Color(0x33301E4F), blurRadius: 8, offset: Offset(0, 3)),
  ],
);

/// A squishy 3D-ish button.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Palette.green,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.radius = 14,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets padding;
  final double radius;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = enabled ? widget.color : const Color(0xFFBDB6C8);
    final dark = Color.lerp(color, Colors.black, .28)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .94 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border(
              bottom: BorderSide(color: dark, width: _down ? 1 : 4),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white, size: 18),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatDuration(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String formatNumber(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.floor().toString();
}

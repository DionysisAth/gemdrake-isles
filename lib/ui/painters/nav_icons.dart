import 'dart:math';

import 'package:flutter/material.dart';

import 'item_painter.dart';

enum NavIconKind { board, island, festival, book, trophy }

/// Colorful hand-drawn icons for the bottom navigation.
class NavIcon extends StatelessWidget {
  const NavIcon(this.kind, {super.key, this.size = 30, this.locked = false});

  final NavIconKind kind;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _NavIconPainter(kind, locked),
  );
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter(this.kind, this.locked);

  final NavIconKind kind;
  final bool locked;

  static const _ink = Color(0xFF3B1F66);

  Paint _line(double s, [double w = .07]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _ink;

  Paint _grad(Rect r, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(r);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (locked) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = const Color(0x88FFFFFF),
      );
    }
    switch (kind) {
      case NavIconKind.board:
        const colors = [
          [Color(0xFFB3F0FF), Color(0xFF3FA7F5)],
          [Color(0xFFFFC9E6), Color(0xFFFF4F9A)],
          [Color(0xFFD7F9A8), Color(0xFF4CBF6B)],
          [Color(0xFFFFF1A8), Color(0xFFFFB300)],
        ];
        for (var i = 0; i < 4; i++) {
          final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              s * (.06 + (i % 2) * .47),
              s * (.06 + (i ~/ 2) * .47),
              s * .41,
              s * .41,
            ),
            Radius.circular(s * .1),
          );
          canvas.drawRRect(r, _grad(r.outerRect, colors[i]));
          canvas.drawRRect(r, _line(s, .06));
          canvas.drawCircle(
            r.outerRect.topLeft + Offset(s * .12, s * .11),
            s * .045,
            Paint()..color = Colors.white.withValues(alpha: .85),
          );
        }
      case NavIconKind.island:
        final rock = Path()
          ..moveTo(s * .08, s * .55)
          ..quadraticBezierTo(s * .5, s * 1.08, s * .92, s * .55)
          ..close();
        canvas.drawPath(
          rock,
          _grad(Offset.zero & size, const [
            Color(0xFFC98E62),
            Color(0xFF6B4432),
          ]),
        );
        canvas.drawPath(rock, _line(s));
        final top = Rect.fromLTWH(s * .06, s * .44, s * .88, s * .22);
        canvas.drawOval(
          top,
          _grad(top, const [Color(0xFFB6F57A), Color(0xFF4DB85A)]),
        );
        canvas.drawOval(top, _line(s));
        // Tree
        canvas.drawLine(
          Offset(s * .62, s * .5),
          Offset(s * .62, s * .32),
          _line(s, .08)..color = const Color(0xFF7A5234),
        );
        final crown = Rect.fromCircle(
          center: Offset(s * .62, s * .24),
          radius: s * .17,
        );
        canvas.drawOval(
          crown,
          _grad(crown, const [Color(0xFF9CF07A), Color(0xFF2E9A4F)]),
        );
        canvas.drawOval(crown, _line(s));
        // Tower
        final tower = Rect.fromLTWH(s * .24, s * .24, s * .16, s * .28);
        canvas.drawRect(tower, Paint()..color = const Color(0xFFF3E6D3));
        canvas.drawRect(tower, _line(s, .06));
        final roof = Path()
          ..moveTo(s * .2, s * .26)
          ..lineTo(s * .32, s * .08)
          ..lineTo(s * .44, s * .26)
          ..close();
        canvas.drawPath(roof, Paint()..color = const Color(0xFF5C7CFA));
        canvas.drawPath(roof, _line(s, .06));
      case NavIconKind.festival:
        // Glowing paper lantern with a tassel.
        canvas.drawCircle(
          Offset(s * .5, s * .5),
          s * .48,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFE082).withValues(alpha: .8),
                const Color(0x00FFE082),
              ],
            ).createShader(Offset.zero & size),
        );
        canvas.drawLine(
          Offset(s * .5, 0),
          Offset(s * .5, s * .14),
          _line(s, .06),
        );
        final body = Rect.fromLTWH(s * .18, s * .16, s * .64, s * .6);
        canvas.drawOval(
          body,
          _grad(body, const [
            Color(0xFFFF8A80),
            Color(0xFFE53935),
            Color(0xFFB71C1C),
          ]),
        );
        for (final dx in [-.14, 0.0, .14]) {
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(s * (.5 + dx), s * .46),
              width: s * .16,
              height: s * .6,
            ),
            -pi / 2,
            pi,
            false,
            _line(s, .035)..color = const Color(0x88FFD54F),
          );
        }
        canvas.drawOval(body, _line(s));
        for (final y in [.14, .74]) {
          final cap = RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .32, s * y, s * .36, s * .1),
            Radius.circular(s * .04),
          );
          canvas.drawRRect(cap, Paint()..color = const Color(0xFFFFC43D));
          canvas.drawRRect(cap, _line(s, .05));
        }
        canvas.drawLine(
          Offset(s * .5, s * .84),
          Offset(s * .5, s * .98),
          _line(s, .07)..color = const Color(0xFFFFB300),
        );
        paintSparkle(canvas, Offset(s * .84, s * .18), s * .12);
      case NavIconKind.book:
        final cover = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .12, s * .08, s * .76, s * .86),
          Radius.circular(s * .1),
        );
        canvas.drawRRect(
          cover,
          _grad(cover.outerRect, const [Color(0xFFB57BFF), Color(0xFF6A3FD0)]),
        );
        canvas.drawRRect(cover, _line(s));
        // Pages edge
        canvas.drawRect(
          Rect.fromLTWH(s * .76, s * .14, s * .08, s * .74),
          Paint()..color = const Color(0xFFFFF8EE),
        );
        // Spine band
        canvas.drawRect(
          Rect.fromLTWH(s * .12, s * .08, s * .12, s * .86),
          Paint()..color = const Color(0x33000000),
        );
        // Gem emblem
        final e = Offset(s * .5, s * .5);
        final gem = Path()
          ..moveTo(e.dx - s * .14, e.dy - s * .1)
          ..lineTo(e.dx + s * .14, e.dy - s * .1)
          ..lineTo(e.dx + s * .2, e.dy - s * .02)
          ..lineTo(e.dx, e.dy + s * .2)
          ..lineTo(e.dx - s * .2, e.dy - s * .02)
          ..close();
        canvas.drawPath(
          gem,
          _grad(gem.getBounds(), const [Color(0xFFFFD1EC), Color(0xFFFF4F9A)]),
        );
        canvas.drawPath(gem, _line(s, .05));
        paintSparkle(canvas, Offset(s * .7, s * .24), s * .1);
      case NavIconKind.trophy:
        final cup = Path()
          ..moveTo(s * .22, s * .1)
          ..lineTo(s * .78, s * .1)
          ..quadraticBezierTo(s * .78, s * .62, s * .5, s * .64)
          ..quadraticBezierTo(s * .22, s * .62, s * .22, s * .1)
          ..close();
        for (final left in [true, false]) {
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(s * (left ? .2 : .8), s * .3),
              width: s * .3,
              height: s * .3,
            ),
            left ? pi / 2 : -pi / 2,
            pi,
            false,
            _line(s, .08)..color = const Color(0xFFE0A21A),
          );
        }
        canvas.drawPath(
          cup,
          _grad(cup.getBounds(), const [
            Color(0xFFFFF1A8),
            Color(0xFFFFC43D),
            Color(0xFFE0A21A),
          ]),
        );
        canvas.drawPath(cup, _line(s));
        canvas.drawRect(
          Rect.fromLTWH(s * .44, s * .62, s * .12, s * .16),
          Paint()..color = const Color(0xFFE0A21A),
        );
        final base = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .26, s * .76, s * .48, s * .16),
          Radius.circular(s * .04),
        );
        canvas.drawRRect(base, Paint()..color = const Color(0xFF8E5CF7));
        canvas.drawRRect(base, _line(s, .06));
        paintSparkle(canvas, Offset(s * .38, s * .26), s * .1);
    }
    if (locked) {
      canvas.restore();
      final lock = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .56, s * .58, s * .38, s * .34),
        Radius.circular(s * .06),
      );
      canvas.drawArc(
        Rect.fromLTWH(s * .62, s * .44, s * .26, s * .3),
        pi,
        pi,
        false,
        _line(s, .07)..color = const Color(0xFF6E5D8C),
      );
      canvas.drawRRect(lock, Paint()..color = const Color(0xFF6E5D8C));
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.kind != kind || old.locked != locked;
}

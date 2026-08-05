import 'dart:math' as math;

import 'package:flutter/material.dart';

class LiveLocationPointer extends StatelessWidget {
  final double? headingDegrees;
  final bool isStale;
  final double size;

  const LiveLocationPointer({
    super.key,
    required this.headingDegrees,
    this.isStale = false,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A73E8);
    final tint = isStale ? const Color(0xFF9E9E9E) : blue;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (headingDegrees != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: headingDegrees!, end: headingDegrees!),
              duration: const Duration(milliseconds: 250),
              builder: (context, value, _) => Transform.rotate(
                angle: value * math.pi / 180,
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _HeadingConePainter(color: tint),
                ),
              ),
            ),
          Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  final Color color;

  const _HeadingConePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const sweep = 60 * math.pi / 180;
    const start = -math.pi / 2 - sweep / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(rect);

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, start, sweep, false)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeadingConePainter oldDelegate) =>
      oldDelegate.color != color;
}

class SearchedPlaceMarker extends StatelessWidget {
  const SearchedPlaceMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on,
      size: 44,
      color: Color(0xFFD93025),
      shadows: [
        Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }
}

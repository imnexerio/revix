// Custom painter for drawing the proportional ring
import 'dart:math';

import 'package:flutter/cupertino.dart';

class ProportionalRingPainter extends CustomPainter {
  final List<Map<String, dynamic>> events;
  final int totalEvents;

  ProportionalRingPainter({
    required this.events,
    required this.totalEvents,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 5.0;

    // Sort events by count for consistent ordering
    final sortedEvents = List.from(events);
    sortedEvents.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    double startAngle = 0;

    for (var event in sortedEvents) {
      final count = event['count'] as int;
      final proportion = count / totalEvents;
      final sweepAngle = proportion * 2 * pi;

      final paint = Paint()
        ..color = event['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
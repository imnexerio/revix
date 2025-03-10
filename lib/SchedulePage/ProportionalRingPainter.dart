import 'dart:math';
import 'package:flutter/material.dart';

class EnhancedRingPainter extends CustomPainter {
  final List<Map<String, dynamic>> events;
  final int totalEvents;
  final bool useGradients;

  EnhancedRingPainter({
    required this.events,
    required this.totalEvents,
    this.useGradients = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5 - 1; // Slight inset to ensure rings stay within bounds

    // Sort events by count - largest to smallest
    final sortedEvents = List.from(events);
    sortedEvents.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // Configure stroke width with slight variation for aesthetic appeal
    const double baseStrokeWidth = 4.5;

    // Start all rings from the top (negative PI/2)
    const double startPosition = -pi / 2;

    // Draw rings from largest (back) to smallest (front)
    for (int i = 0; i < sortedEvents.length; i++) {
      final event = sortedEvents[i];
      final count = event['count'] as int;
      final color = event['color'] as Color;

      // Calculate sweep angle based on weight
      final proportion = count / totalEvents;
      final sweepAngle = proportion * 2 * pi;

      // Use slightly different stroke widths for aesthetic variation
      final strokeWidth = baseStrokeWidth - (i * 0.2).clamp(0.0, 1.0);

      Paint paint;

      if (useGradients) {
        // Create an enhanced gradient that shows progression
        // Create a lighter shade of the color for the starting point
        final Color startColor = _getLighterColor(color, 0.7);
        // Create a more saturated/darker version for the end point
        final Color endColor = _getEnhancedColor(color, 1.2);

        // Add intermediate colors for a smoother progression
        paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: startPosition,
            endAngle: startPosition + sweepAngle,
            colors: [
              startColor,
              color,
              endColor,
            ],
            stops: const [0.0, 0.7, 1.0], // Adjust these values to control gradient progression
            transform: GradientRotation(startPosition),
          ).createShader(Rect.fromCircle(center: center, radius: radius));
      } else {
        // Use solid color
        paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
      }

      // Draw arc starting from the top position
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startPosition,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  // Helper method to create a lighter version of a color
  Color _getLighterColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      _clampInt((color.red * factor).round(), 0, 255),
      _clampInt((color.green * factor).round(), 0, 255),
      _clampInt((color.blue * factor).round(), 0, 255),
    );
  }

  // Helper method to create a more saturated/darker version of a color
  Color _getEnhancedColor(Color color, double factor) {
    // Increase saturation by making the dominant channel more prominent
    int maxChannel = [color.red, color.green, color.blue].reduce(max);

    int enhancedRed = color.red;
    int enhancedGreen = color.green;
    int enhancedBlue = color.blue;

    if (maxChannel == color.red) {
      enhancedRed = _clampInt((color.red * factor).round(), 0, 255);
    } else if (maxChannel == color.green) {
      enhancedGreen = _clampInt((color.green * factor).round(), 0, 255);
    } else {
      enhancedBlue = _clampInt((color.blue * factor).round(), 0, 255);
    }

    return Color.fromARGB(
      color.alpha,
      enhancedRed,
      enhancedGreen,
      enhancedBlue,
    );
  }

  // Helper method to clamp integer values
  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
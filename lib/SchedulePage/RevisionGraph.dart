import 'dart:math';
import 'package:flutter/material.dart';

class CircularTimelineChart extends StatefulWidget {
  final String dateLearnt;
  final List<String> datesMissedRevisions;
  final List<String> datesRevised;
  final double size;
  final Duration animationDuration;
  final Color missedColor;
  final Color revisedColor;

  const CircularTimelineChart({
    Key? key,
    required this.dateLearnt,
    required this.datesMissedRevisions,
    required this.datesRevised,
    this.size = 220,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.missedColor = Colors.red,
    this.revisedColor = Colors.green,
  }) : super(key: key);

  @override
  State<CircularTimelineChart> createState() => _CircularTimelineChartState();
}

class _CircularTimelineChartState extends State<CircularTimelineChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create a combined list of all revisions (both missed and completed)
    final allRevisions = <RevisionEvent>[];

    // Add missed revisions
    for (final dateStr in widget.datesMissedRevisions) {
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allRevisions.add(RevisionEvent(date: date, isMissed: true));
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    // Add completed revisions
    for (final dateStr in widget.datesRevised) {
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allRevisions.add(RevisionEvent(date: date, isMissed: false));
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    // Sort all revisions by date
    allRevisions.sort((a, b) => a.date.compareTo(b.date));

    if (allRevisions.isEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Text(
            'No revision data',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              // Base circle
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: CirclePainter(
                  animationValue: _animation.value,
                  circleColor: Colors.grey.shade300,
                ),
              ),

              // Plot all revision dots
              ...List.generate(
                (allRevisions.length * _animation.value).ceil(),
                    (index) {
                  if (index >= allRevisions.length) return const SizedBox.shrink();

                  final revision = allRevisions[index];
                  final totalEvents = allRevisions.length;

                  // Calculate position (starting from bottom, going clockwise)
                  // Map index from 0 to totalEvents to 0 to 2π
                  final angle = 3 * pi / 2 + (index / totalEvents) * 2 * pi;

                  return _buildDot(
                    angle,
                    revision.isMissed ? widget.missedColor : widget.revisedColor,
                    revision.date,
                    index + 1,
                    totalEvents,
                  );
                },
              ),


              // Center indicator
              Center(
                child: AnimatedOpacity(
                  opacity: _animation.value,
                  duration: widget.animationDuration,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              // Blue dot indicating starting date (dateLearnt)
              _buildStartDateDot(3 * pi / 2, Colors.blue, widget.dateLearnt),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(double angle, Color color, DateTime date, int index, int total) {
    final radius = (widget.size / 2 - 15);

    // Convert polar to cartesian coordinates
    final x = widget.size / 2 + radius * cos(angle) * _animation.value;
    final y = widget.size / 2 + radius * sin(angle) * _animation.value;

    // Calculate time-based animation delay
    final delayFactor = index / total;
    final delayedAnimation = _animation.value > delayFactor ?
    (_animation.value - delayFactor) * (1 / (1 - delayFactor)) : 0.0;
    final opacity = delayedAnimation.clamp(0.0, 1.0);

    return Positioned(
      left: x - 5,
      top: y - 5,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Tooltip(
          message: '${date.day}/${date.month}/${date.year} (${index}/${total})',
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartDateDot(double angle, Color color, String dateStr) {
    final radius = (widget.size / 2 - 15);

    // Convert polar to cartesian coordinates
    final x = widget.size / 2 + radius * cos(angle) * _animation.value;
    final y = widget.size / 2 + radius * sin(angle) * _animation.value;

    return Positioned(
      left: x - 6,
      top: y - 6,
      child: AnimatedOpacity(
        opacity: _animation.value,
        duration: widget.animationDuration,
        child: Tooltip(
          message: 'Date Learnt: $dateStr',
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CirclePainter extends CustomPainter {
  final double animationValue;
  final Color circleColor;

  CirclePainter({
    required this.animationValue,
    required this.circleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Paint for the circle
    final circlePaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw the circle with animation
    // Calculate sweep angle based on animation value (0 to 2π)
    final sweepAngle = 2 * pi * animationValue;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3 * pi / 2, // Start from bottom (270° or 3π/2)
      sweepAngle,
      false,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Data model for revision events
class RevisionEvent {
  final DateTime date;
  final bool isMissed;

  RevisionEvent({
    required this.date,
    required this.isMissed,
  });
}
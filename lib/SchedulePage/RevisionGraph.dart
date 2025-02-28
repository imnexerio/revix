import 'dart:math';
import 'package:flutter/material.dart';

class RevisionRadarChart extends StatefulWidget {
  final String dateLearnt;
  final List<String> datesMissedRevisions;
  final List<String> datesRevised;
  final Duration animationDuration;
  final Color missedColor;
  final Color revisedColor;
  final Color learntColor;
  final bool showLabels;

  const RevisionRadarChart({
    Key? key,
    required this.dateLearnt,
    required this.datesMissedRevisions,
    required this.datesRevised,
    this.animationDuration = const Duration(milliseconds: 1800),
    this.missedColor = Colors.redAccent,
    this.revisedColor = Colors.greenAccent,
    this.learntColor = Colors.blueAccent,
    this.showLabels = true,
  }) : super(key: key);

  @override
  State<RevisionRadarChart> createState() => _RevisionRadarChartState();
}


class _RevisionRadarChartState extends State<RevisionRadarChart> with TickerProviderStateMixin {

  late AnimationController _animationController;
  late Animation<double> _animation;

  // New animation controller for the light effect
  late AnimationController _lightAnimationController;
  late Animation<double> _lightAnimation;

  late List<RevisionEvent> allRevisions;

  // Track statistics
  late int totalRevisions;
  late int completedRevisions;
  late int missedRevisions;
  late Duration totalSpan;
  late double revisionRatio;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );

    // Initialize the light animation controller (continuous animation)
    _lightAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Light travels in 2 seconds
    );

    _lightAnimation = CurvedAnimation(
      parent: _lightAnimationController,
      curve: Curves.linear,
    );

    _processRevisionData();
    _calculateStatistics();

    _animationController.forward();

    // Start the light animation and make it repeat
    _lightAnimationController.repeat();
  }

  void _processRevisionData() {
    allRevisions = <RevisionEvent>[];

    // Add "date learned" as the first event
    try {
      if (widget.dateLearnt.isNotEmpty) {
        final learnedDate = DateTime.parse(widget.dateLearnt);
        allRevisions.add(RevisionEvent(
            date: learnedDate,
            dateString: widget.dateLearnt,
            isMissed: false,
            isLearned: true
        ));
      }
    } catch (e) {
      print('Error parsing date learned: $e');
    }

    // Add missed revisions
    for (final dateStr in widget.datesMissedRevisions) {
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allRevisions.add(RevisionEvent(
              date: date,
              dateString: dateStr,
              isMissed: true,
              isLearned: false
          ));
        } catch (e) {
          print('Error parsing missed revision date: $e');
        }
      }
    }

    // Add completed revisions
    for (final dateStr in widget.datesRevised) {
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allRevisions.add(RevisionEvent(
              date: date,
              dateString: dateStr,
              isMissed: false,
              isLearned: false
          ));
        } catch (e) {
          print('Error parsing completed revision date: $e');
        }
      }
    }

    // Sort all revisions by date
    allRevisions.sort((a, b) => a.date.compareTo(b.date));
  }

  void _calculateStatistics() {
    totalRevisions = allRevisions.where((e) => !e.isLearned).length;
    completedRevisions = allRevisions.where((e) => !e.isLearned && !e.isMissed).length;
    missedRevisions = allRevisions.where((e) => e.isMissed).length;

    // Calculate time span from first to last date
    if (allRevisions.isNotEmpty) {
      DateTime firstDate = allRevisions.first.date;
      DateTime lastDate = allRevisions.last.date;
      totalSpan = lastDate.difference(firstDate);
    } else {
      totalSpan = Duration.zero;
    }

    // Calculate completion ratio
    revisionRatio = totalRevisions > 0 ? completedRevisions / totalRevisions : 0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _lightAnimationController.dispose(); // Dispose the light animation controller
    super.dispose();
  }

  // Helper function to format date without intl
  String _formatDate(DateTime date) {
    // Extract day and month
    int day = date.day;

    // Month abbreviations
    List<String> monthAbbr = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    String month = monthAbbr[date.month - 1];

    // Format as "d MMM" (e.g., "1 Jan")
    return '$day $month';
  }

  @override
  Widget build(BuildContext context) {
    if (allRevisions.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableSize = min(constraints.maxWidth, constraints.maxHeight);
          return SizedBox(
            width: availableSize,
            height: availableSize,
            child: Center(
              child: Text(
                'No revision data',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the minimum of available width and height to ensure the chart is always a circle
        final availableSize = min(constraints.maxWidth, constraints.maxHeight);

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The radar chart
                SizedBox(
                  width: availableSize,
                  height: availableSize,
                  child: Stack(
                    children: [
                      // Background web
                      CustomPaint(
                        size: Size(availableSize, availableSize),
                        painter: RadarWebPainter(
                          animationValue: _animation.value,
                          levels: 5,
                          webColor: Colors.grey.withOpacity(0.3),
                        ),
                      ),

                      // The data paths
                      AnimatedBuilder(
                          animation: _lightAnimation,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(availableSize, availableSize),
                              painter: RadarChartPainter(
                                animationValue: _animation.value,
                                lightAnimationValue: _lightAnimation.value,
                                revisions: allRevisions,
                                learntColor: widget.learntColor,
                                revisedColor: widget.revisedColor,
                                missedColor: widget.missedColor,
                              ),
                            );
                          }
                      ),

                      // Labels
                      if (widget.showLabels)
                        ...List.generate(
                          allRevisions.length,
                              (index) {
                            final revision = allRevisions[index];
                            final totalEvents = allRevisions.length;

                            // Changed from 3π/2 (top) to π/2 (bottom)
                            final angle = pi / 2 + (index / totalEvents) * 2 * pi;

                            // final angle = -pi / 2 + (index / totalEvents) * 2 * pi;
                            final labelRadius = (availableSize / 2) * 0.85;

                            final labelX = availableSize / 2 + labelRadius * cos(angle);
                            final labelY = availableSize / 2 + labelRadius * sin(angle);
                            final dateLabel = _formatDate(revision.date);

                            // Calculate a font size proportional to the available size
                            final fontSize = max(8.0, availableSize / 30);

                            // Calculate box size proportional to the available size
                            final boxPadding = availableSize / 100;

                            return Positioned(
                              left: labelX,
                              top: labelY,
                              child: AnimatedOpacity(
                                opacity: _animation.value,
                                duration: widget.animationDuration,
                                child: Transform.translate(
                                  offset: Offset(
                                    -20 * (availableSize / 300), // Scale offset based on available size
                                    -10 * (availableSize / 300),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: boxPadding,
                                      vertical: boxPadding / 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: revision.isLearned
                                            ? widget.learntColor
                                            : (revision.isMissed
                                            ? widget.missedColor
                                            : widget.revisedColor),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      dateLabel,
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // Center dot
                      Center(
                        child: AnimatedContainer(
                          duration: widget.animationDuration,
                          width: max(8.0, availableSize / 25), // Scale dot size based on available size
                          height: max(8.0, availableSize / 25),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueGrey.shade800,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Data model for revision events
class RevisionEvent {
  final DateTime date;
  final String dateString;
  final bool isMissed;
  final bool isLearned;

  RevisionEvent({
    required this.date,
    required this.dateString,
    required this.isMissed,
    this.isLearned = false,
  });
}

// Painter for the radar background web
class RadarWebPainter extends CustomPainter {
  final double animationValue;
  final int levels;
  final Color webColor;

  RadarWebPainter({
    required this.animationValue,
    this.levels = 5,
    required this.webColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.70; // Use 70% of the available space

    final webPaint = Paint()
      ..color = webColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 300; // Scale stroke width based on size

    // Draw the circular levels
    for (int i = 1; i <= levels; i++) {
      final levelRadius = radius * (i / levels) * animationValue;
      canvas.drawCircle(center, levelRadius, webPaint);
    }

    // Calculate the number of spokes based on the revision data in the parent widget
    const totalSpokes = 12; // Default to 12 (monthly)

    // Draw the spokes
    for (int i = 0; i < totalSpokes; i++) {
      final angle = pi/2 + (i / totalSpokes) * 2 * pi;
      final x = center.dx + radius * cos(angle) * animationValue;
      final y = center.dy + radius * sin(angle) * animationValue;

      canvas.drawLine(center, Offset(x, y), webPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarWebPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

// Painter for the radar chart data
class RadarChartPainter extends CustomPainter {
  final double animationValue;
  final double lightAnimationValue; // Value for the moving light effect
  final List<RevisionEvent> revisions;
  final Color learntColor;
  final Color revisedColor;
  final Color missedColor;

  RadarChartPainter({
    required this.animationValue,
    required this.lightAnimationValue,
    required this.revisions,
    required this.learntColor,
    required this.revisedColor,
    required this.missedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (revisions.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.70; // Use 70% of the available space

    // Create paths for different types of events
    final learnedPath = Path();
    final revisedPath = Path();
    final missedPath = Path();

    // Store points for light effect
    final learnedPoints = <Offset>[];
    final revisedPoints = <Offset>[];
    final missedPoints = <Offset>[];

    // Variables to track if we've moved to first points
    bool learnedMoved = false;
    bool revisedMoved = false;
    bool missedMoved = false;

    // Calculate point size based on the widget size
    final pointSize = max(3.0, size.width / 60);

    // Draw points for each revision
    for (int i = 0; i < revisions.length; i++) {
      final revision = revisions[i];
      final totalEvents = revisions.length;

      // Calculate angle and radiusRatio based on animation
      final angle = pi/2 + (i / totalEvents) * 2 * pi;
      double pointRadius = radius;

      // Calculate x, y of the point
      final x = center.dx + pointRadius * cos(angle) * animationValue;
      final y = center.dy + pointRadius * sin(angle) * animationValue;
      final point = Offset(x, y);

      // Add point to appropriate path and point list
      if (revision.isLearned) {
        if (!learnedMoved) {
          learnedPath.moveTo(point.dx, point.dy);
          learnedMoved = true;
        } else {
          learnedPath.lineTo(point.dx, point.dy);
        }
        learnedPoints.add(point);

        // Draw the learned point
        canvas.drawCircle(
          point,
          pointSize * 1.2, // Make learned points slightly larger
          Paint()..color = learntColor,
        );
      } else if (revision.isMissed) {
        if (!missedMoved) {
          missedPath.moveTo(point.dx, point.dy);
          missedMoved = true;
        } else {
          missedPath.lineTo(point.dx, point.dy);
        }
        missedPoints.add(point);

        // Draw the missed point
        canvas.drawCircle(
          point,
          pointSize,
          Paint()..color = missedColor,
        );
      } else {
        if (!revisedMoved) {
          revisedPath.moveTo(point.dx, point.dy);
          revisedMoved = true;
        } else {
          revisedPath.lineTo(point.dx, point.dy);
        }
        revisedPoints.add(point);

        // Draw the revised point
        canvas.drawCircle(
          point,
          pointSize,
          Paint()..color = revisedColor,
        );
      }
    }

    // Scale stroke width based on size
    final strokeWidth = max(1.0, size.width / 150);

    // Close and fill the paths with light effect
    if (learnedMoved) {
      // Draw the fill
      canvas.drawPath(
        learnedPath,
        Paint()
          ..color = learntColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Draw the path stroke
      canvas.drawPath(
        learnedPath,
        Paint()
          ..color = learntColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );

      // Draw the light effect if we have more than 1 point
      if (learnedPoints.length > 1) {
        _drawLightEffect(canvas, learnedPoints, learntColor, size, strokeWidth);
      }
    }

    if (revisedMoved) {
      // Draw the fill
      canvas.drawPath(
        revisedPath,
        Paint()
          ..color = revisedColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Draw the path stroke
      canvas.drawPath(
        revisedPath,
        Paint()
          ..color = revisedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );

      // Draw the light effect if we have more than 1 point
      if (revisedPoints.length > 1) {
        _drawLightEffect(canvas, revisedPoints, revisedColor, size, strokeWidth);
      }
    }

    if (missedMoved) {
      // Draw the fill
      canvas.drawPath(
        missedPath,
        Paint()
          ..color = missedColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Draw the path stroke
      canvas.drawPath(
        missedPath,
        Paint()
          ..color = missedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );

      // Draw the light effect if we have more than 1 point
      if (missedPoints.length > 1) {
        _drawLightEffect(canvas, missedPoints, missedColor, size, strokeWidth);
      }
    }
  }

  // Method to draw light moving along the path
  void _drawLightEffect(Canvas canvas, List<Offset> points, Color color, Size size, double strokeWidth) {
    if (points.length < 2) return;

    // Calculate total path length to determine light position
    double totalLength = 0;
    List<double> segmentLengths = [];

    for (int i = 0; i < points.length - 1; i++) {
      final distance = (points[i] - points[i + 1]).distance;
      segmentLengths.add(distance);
      totalLength += distance;
    }

    // Add the last segment that connects back to the first point (close the path)
    final lastDistance = (points.last - points.first).distance;
    segmentLengths.add(lastDistance);
    totalLength += lastDistance;

    // Calculate where the light should be based on animation value
    double targetDistance = totalLength * lightAnimationValue;

    // Find which segment the light is in
    int segmentIndex = 0;
    double distanceCovered = 0;

    while (segmentIndex < segmentLengths.length && distanceCovered + segmentLengths[segmentIndex] < targetDistance) {
      distanceCovered += segmentLengths[segmentIndex];
      segmentIndex++;
    }

    // The segment is between points[segmentIndex] and points[(segmentIndex + 1) % points.length]
    final startPoint = points[segmentIndex];
    final endPoint = points[(segmentIndex + 1) % points.length];

    // Calculate how far along this segment the light should be
    final segmentProgress = (targetDistance - distanceCovered) / segmentLengths[segmentIndex];

    // Interpolate the position
    final lightPosition = Offset(
      startPoint.dx + (endPoint.dx - startPoint.dx) * segmentProgress,
      startPoint.dy + (endPoint.dy - startPoint.dy) * segmentProgress,
    );

    // Size of light is proportional to chart size
    final lightSize = max(strokeWidth * 3, size.width / 50);

    // Draw a glowing light effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, lightSize / 2);

    canvas.drawCircle(lightPosition, lightSize, glowPaint);

    // Draw a brighter center
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(lightPosition, lightSize / 3, centerPaint);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
          oldDelegate.lightAnimationValue != lightAnimationValue ||
          oldDelegate.revisions.length != revisions.length;
}
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
  final int maxPoints; // New parameter to control the number of points

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
    this.maxPoints = 18, // Default to showing 15 points
  }) : super(key: key);

  @override
  State<RevisionRadarChart> createState() => _RevisionRadarChartState();
}

class _RevisionRadarChartState extends State<RevisionRadarChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late List<RevisionEvent> allRevisions;
  late List<RevisionEvent> displayRevisions; // The filtered list to display

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

    _processRevisionData();
    _calculateStatistics();

    _animationController.forward();
  }

  void _processRevisionData() {
    allRevisions = <RevisionEvent>[];
    RevisionEvent? learnedEvent;

    // Add "date learned" as the first event
    try {
      if (widget.dateLearnt.isNotEmpty) {
        final learnedDate = DateTime.parse(widget.dateLearnt);
        learnedEvent = RevisionEvent(
            date: learnedDate,
            dateString: widget.dateLearnt,
            isMissed: false,
            isLearned: true
        );
        allRevisions.add(learnedEvent);
      }
    } catch (e) {
      // print('Error parsing date learned: $e');
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
          // print('Error parsing missed revision date: $e');
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

    // Filter to keep only the learned event and the last maxPoints events
    displayRevisions = <RevisionEvent>[];

    // Always include the learned event if it exists
    if (learnedEvent != null) {
      displayRevisions.add(learnedEvent);
    }

    // Get non-learned events
    final nonLearnedEvents = allRevisions.where((event) => !event.isLearned).toList();

    // Take the last maxPoints non-learned events
    if (nonLearnedEvents.length > widget.maxPoints) {
      displayRevisions.addAll(nonLearnedEvents.sublist(nonLearnedEvents.length - widget.maxPoints));
    } else {
      displayRevisions.addAll(nonLearnedEvents);
    }

    // Re-sort the display revisions by date
    displayRevisions.sort((a, b) => a.date.compareTo(b.date));
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
    if (displayRevisions.isEmpty) {
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
                Container(
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
                      CustomPaint(
                        size: Size(availableSize, availableSize),
                        painter: RadarChartPainter(
                          animationValue: _animation.value,
                          revisions: displayRevisions, // Use filtered revisions here
                          learntColor: widget.learntColor,
                          revisedColor: widget.revisedColor,
                          missedColor: widget.missedColor,
                        ),
                      ),

                      // Labels
                      if (widget.showLabels)
                        ...List.generate(
                          displayRevisions.length, // Use filtered revisions for labels too
                              (index) {
                            final revision = displayRevisions[index];
                            final totalEvents = displayRevisions.length;

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
                              const BoxShadow(
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
  final List<RevisionEvent> revisions;
  final Color learntColor;
  final Color revisedColor;
  final Color missedColor;

  RadarChartPainter({
    required this.animationValue,
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

      // Add point to appropriate path
      if (revision.isLearned) {
        if (!learnedMoved) {
          learnedPath.moveTo(point.dx, point.dy);
          learnedMoved = true;
        } else {
          learnedPath.lineTo(point.dx, point.dy);
        }

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

    // Close and fill the paths
    if (learnedMoved) {
      canvas.drawPath(
        learnedPath,
        Paint()
          ..color = learntColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Also draw the stroke
      canvas.drawPath(
        learnedPath,
        Paint()
          ..color = learntColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }

    if (revisedMoved) {
      canvas.drawPath(
        revisedPath,
        Paint()
          ..color = revisedColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Also draw the stroke
      canvas.drawPath(
        revisedPath,
        Paint()
          ..color = revisedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }

    if (missedMoved) {
      canvas.drawPath(
        missedPath,
        Paint()
          ..color = missedColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Also draw the stroke
      canvas.drawPath(
        missedPath,
        Paint()
          ..color = missedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
          oldDelegate.revisions.length != revisions.length;
}
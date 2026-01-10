import 'dart:math';
import 'package:flutter/material.dart';

class RecurrenceRadarChart extends StatefulWidget {
  final String dateInitiated;
  final List<String> datesMissedReviews;
  final List<String> datesReviewed;
  final List<String> datesSkipped;
  final Duration animationDuration;
  final Color missedColor;
  final Color reviewedColor;
  final Color initiatedColor;
  final Color skippedColor;
  final bool showLabels;
  final int maxPoints; // New parameter to control the number of points

  const RecurrenceRadarChart({
    Key? key,
    required this.dateInitiated,
    required this.datesMissedReviews,
    required this.datesReviewed,
    this.datesSkipped = const [],
    this.animationDuration = const Duration(milliseconds: 1800),
    this.missedColor = Colors.redAccent,
    this.reviewedColor = Colors.greenAccent,
    this.initiatedColor = Colors.blueAccent,
    this.skippedColor = Colors.orangeAccent,
    this.showLabels = true,
    this.maxPoints = 18, // Default to showing 18 points
  }) : super(key: key);

  @override
  State<RecurrenceRadarChart> createState() => _RecurrenceRadarChartState();
}

class _RecurrenceRadarChartState extends State<RecurrenceRadarChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late List<RecurrenceEvent> allEvents;
  late List<RecurrenceEvent> displayEvents; // The filtered list to display

  // Track statistics
  late int totalReviews;
  late int completedReviews;
  late int missedReviews;
  late int skippedReviews;
  late Duration totalSpan;
  late double reviewRatio;

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

    _processEventData();
    _calculateStatistics();

    _animationController.forward();
  }

  void _processEventData() {
    allEvents = <RecurrenceEvent>[];
    RecurrenceEvent? initiatedEvent;

    // Add "date initiated" as the first event
    try {
      if (widget.dateInitiated.isNotEmpty) {
        final initiatedDate = DateTime.parse(widget.dateInitiated);
        initiatedEvent = RecurrenceEvent(
            date: initiatedDate,
            dateString: widget.dateInitiated,
            isMissed: false,
            isInitiated: true,
            isSkipped: false
        );
        allEvents.add(initiatedEvent);
      }
    } catch (e) {
      // print('Error parsing date initiated: $e');
    }

    // Add missed reviews
    for (final dateStr in widget.datesMissedReviews) {
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allEvents.add(RecurrenceEvent(
              date: date,
              dateString: dateStr,
              isMissed: true,
              isInitiated: false,
              isSkipped: false
          ));
        } catch (e) {
          // print('Error parsing missed review date: $e');
        }
      }
    }

    // Add completed reviews
    for (final dateStr in widget.datesReviewed) {
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allEvents.add(RecurrenceEvent(
              date: date,
              dateString: dateStr,
              isMissed: false,
              isInitiated: false,
              isSkipped: false
          ));
        } catch (e) {
          print('Error parsing completed review date: $e');
        }
      }
    }

    // Add skipped events
    for (final dateStr in widget.datesSkipped) {
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allEvents.add(RecurrenceEvent(
              date: date,
              dateString: dateStr,
              isMissed: false,
              isInitiated: false,
              isSkipped: true
          ));
        } catch (e) {
          print('Error parsing skipped date: $e');
        }
      }
    }

    // Sort all events by date
    allEvents.sort((a, b) => a.date.compareTo(b.date));

    // Filter to keep only the initiated event and the last maxPoints events
    displayEvents = <RecurrenceEvent>[];

    // Always include the initiated event if it exists
    if (initiatedEvent != null) {
      displayEvents.add(initiatedEvent);
    }

    // Get non-initiated events
    final nonInitiatedEvents = allEvents.where((event) => !event.isInitiated).toList();

    // Take the last maxPoints non-initiated events
    if (nonInitiatedEvents.length > widget.maxPoints) {
      displayEvents.addAll(nonInitiatedEvents.sublist(nonInitiatedEvents.length - widget.maxPoints));
    } else {
      displayEvents.addAll(nonInitiatedEvents);
    }

    // Re-sort the display events by date
    displayEvents.sort((a, b) => a.date.compareTo(b.date));
  }

  void _calculateStatistics() {
    totalReviews = allEvents.where((e) => !e.isInitiated).length;
    completedReviews = allEvents.where((e) => !e.isInitiated && !e.isMissed && !e.isSkipped).length;
    missedReviews = allEvents.where((e) => e.isMissed).length;
    skippedReviews = allEvents.where((e) => e.isSkipped).length;

    // Calculate time span from first to last date
    if (allEvents.isNotEmpty) {
      DateTime firstDate = allEvents.first.date;
      DateTime lastDate = allEvents.last.date;
      totalSpan = lastDate.difference(firstDate);
    } else {
      totalSpan = Duration.zero;
    }

    // Calculate completion ratio
    reviewRatio = totalReviews > 0 ? completedReviews / totalReviews : 0;
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
    if (displayEvents.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableSize = min(constraints.maxWidth, constraints.maxHeight);
          return SizedBox(
            width: availableSize,
            height: availableSize,
            child: Center(
              child: Text(
                'No review data',
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
                          events: displayEvents, // Use filtered events here
                          initiatedColor: widget.initiatedColor,
                          reviewedColor: widget.reviewedColor,
                          missedColor: widget.missedColor,
                          skippedColor: widget.skippedColor,
                        ),
                      ),

                      // Labels
                      if (widget.showLabels)
                        ...List.generate(
                          displayEvents.length, // Use filtered events for labels too
                              (index) {
                            final event = displayEvents[index];
                            final totalEvents = displayEvents.length;

                            // Changed from 3π/2 (top) to π/2 (bottom)
                            final angle = pi / 2 + (index / totalEvents) * 2 * pi;

                            // final angle = -pi / 2 + (index / totalEvents) * 2 * pi;
                            final labelRadius = (availableSize / 2) * 0.85;

                            final labelX = availableSize / 2 + labelRadius * cos(angle);
                            final labelY = availableSize / 2 + labelRadius * sin(angle);
                            final dateLabel = _formatDate(event.date);

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
                                        color: event.isInitiated
                                            ? widget.initiatedColor
                                            : (event.isMissed
                                            ? widget.missedColor
                                            : (event.isSkipped
                                            ? widget.skippedColor
                                            : widget.reviewedColor)),
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

// Data model for recurrence events
class RecurrenceEvent {
  final DateTime date;
  final String dateString;
  final bool isMissed;
  final bool isInitiated;
  final bool isSkipped;

  RecurrenceEvent({
    required this.date,
    required this.dateString,
    required this.isMissed,
    this.isInitiated = false,
    this.isSkipped = false,
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

    // Calculate the number of spokes based on the event data in the parent widget
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
  final List<RecurrenceEvent> events;
  final Color initiatedColor;
  final Color reviewedColor;
  final Color missedColor;
  final Color skippedColor;

  RadarChartPainter({
    required this.animationValue,
    required this.events,
    required this.initiatedColor,
    required this.reviewedColor,
    required this.missedColor,
    required this.skippedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (events.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.70; // Use 70% of the available space

    // Create paths for different types of events
    final initiatedPath = Path();
    final reviewedPath = Path();
    final missedPath = Path();
    final skippedPath = Path();

    // Variables to track if we've moved to first points
    bool initiatedMoved = false;
    bool reviewedMoved = false;
    bool missedMoved = false;
    bool skippedMoved = false;

    // Calculate point size based on the widget size
    final pointSize = max(3.0, size.width / 60);

    // Draw points for each event
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final totalEvents = events.length;

      // Calculate angle and radiusRatio based on animation
      final angle = pi/2 + (i / totalEvents) * 2 * pi;
      double pointRadius = radius;

      // Calculate x, y of the point
      final x = center.dx + pointRadius * cos(angle) * animationValue;
      final y = center.dy + pointRadius * sin(angle) * animationValue;
      final point = Offset(x, y);

      // Add point to appropriate path
      if (event.isInitiated) {
        if (!initiatedMoved) {
          initiatedPath.moveTo(point.dx, point.dy);
          initiatedMoved = true;
        } else {
          initiatedPath.lineTo(point.dx, point.dy);
        }

        // Draw the initiated point
        canvas.drawCircle(
          point,
          pointSize * 1.2, // Make initiated points slightly larger
          Paint()..color = initiatedColor,
        );
      } else if (event.isMissed) {
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
      } else if (event.isSkipped) {
        if (!skippedMoved) {
          skippedPath.moveTo(point.dx, point.dy);
          skippedMoved = true;
        } else {
          skippedPath.lineTo(point.dx, point.dy);
        }

        // Draw the skipped point
        canvas.drawCircle(
          point,
          pointSize,
          Paint()..color = skippedColor,
        );
      } else {
        if (!reviewedMoved) {
          reviewedPath.moveTo(point.dx, point.dy);
          reviewedMoved = true;
        } else {
          reviewedPath.lineTo(point.dx, point.dy);
        }

        // Draw the reviewed point
        canvas.drawCircle(
          point,
          pointSize,
          Paint()..color = reviewedColor,
        );
      }
    }

    // Scale stroke width based on size
    final strokeWidth = max(1.0, size.width / 150);

    // Close and fill the paths
    if (initiatedMoved) {
      canvas.drawPath(
        initiatedPath,
        Paint()
          ..color = initiatedColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Also draw the stroke
      canvas.drawPath(
        initiatedPath,
        Paint()
          ..color = initiatedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }

    if (reviewedMoved) {
      canvas.drawPath(
        reviewedPath,
        Paint()
          ..color = reviewedColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Also draw the stroke
      canvas.drawPath(
        reviewedPath,
        Paint()
          ..color = reviewedColor
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

    if (skippedMoved) {
      canvas.drawPath(
        skippedPath,
        Paint()
          ..color = skippedColor.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // Also draw the stroke
      canvas.drawPath(
        skippedPath,
        Paint()
          ..color = skippedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
          oldDelegate.events.length != events.length;
}

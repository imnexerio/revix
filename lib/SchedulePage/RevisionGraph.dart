import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RevisionRadarChart extends StatefulWidget {
  final String dateLearnt;
  final List<String> datesMissedRevisions;
  final List<String> datesRevised;
  final double size;
  final Duration animationDuration;
  final Color missedColor;
  final Color revisedColor;
  final Color learntColor;

  const RevisionRadarChart({
    Key? key,
    required this.dateLearnt,
    required this.datesMissedRevisions,
    required this.datesRevised,
    this.size = 300,
    this.animationDuration = const Duration(milliseconds: 1800),
    this.missedColor = Colors.redAccent,
    this.revisedColor = Colors.greenAccent,
    this.learntColor = Colors.blueAccent,
  }) : super(key: key);

  @override
  State<RevisionRadarChart> createState() => _RevisionRadarChartState();
}

class _RevisionRadarChartState extends State<RevisionRadarChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
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

    _processRevisionData();
    _calculateStatistics();

    _animationController.forward();
  }

  void _processRevisionData() {
    allRevisions = <RevisionEvent>[];

    // Add "date learned" as the first event
    try {
      if (widget.dateLearnt.isNotEmpty) {
        final learnedDate = DateTime.parse(widget.dateLearnt);
        allRevisions.add(RevisionEvent(date: learnedDate, isMissed: false, isLearned: true));
      }
    } catch (e) {
      print('Error parsing date learned: $e');
    }

    // Add missed revisions
    for (final dateStr in widget.datesMissedRevisions) {
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          allRevisions.add(RevisionEvent(date: date, isMissed: true, isLearned: false));
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
          allRevisions.add(RevisionEvent(date: date, isMissed: false, isLearned: false));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The radar chart
            Container(
              width: widget.size,
              height: widget.size,
              child: Stack(
                children: [
                  // Background web
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: RadarWebPainter(
                      animationValue: _animation.value,
                      levels: 5,
                      webColor: Colors.grey.withOpacity(0.3),
                    ),
                  ),

                  // The data paths
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: RadarChartPainter(
                      animationValue: _animation.value,
                      revisions: allRevisions,
                      learntColor: widget.learntColor,
                      revisedColor: widget.revisedColor,
                      missedColor: widget.missedColor,
                    ),
                  ),

                  // Labels
                  ...List.generate(
                    allRevisions.length,
                        (index) {
                      final revision = allRevisions[index];
                      final totalEvents = allRevisions.length;

                      // Calculate position
                      final angle = -pi/2 + (index / totalEvents) * 2 * pi;
                      final labelRadius = (widget.size / 2) * 0.9;

                      // Convert to cartesian coordinates
                      final labelX = widget.size / 2 + labelRadius * cos(angle);
                      final labelY = widget.size / 2 + labelRadius * sin(angle);

                      // Format the date for display
                      final dateFormat = DateFormat('d MMM');
                      final dateLabel = dateFormat.format(revision.date);

                      return Positioned(
                        left: labelX - 30,
                        top: labelY - 12,
                        child: AnimatedOpacity(
                          opacity: _animation.value,
                          duration: widget.animationDuration,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                fontSize: 10,
                                color: Colors.black87,
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
                      width: 12,
                      height: 12,
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
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

// Data model for revision events
class RevisionEvent {
  final DateTime date;
  final bool isMissed;
  final bool isLearned;

  RevisionEvent({
    required this.date,
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
    final radius = size.width / 2 * 0.85; // Use 85% of the available space

    final webPaint = Paint()
      ..color = webColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw the circular levels
    for (int i = 1; i <= levels; i++) {
      final levelRadius = radius * (i / levels) * animationValue;
      canvas.drawCircle(center, levelRadius, webPaint);
    }

    // Calculate the number of spokes based on the revision data in the parent widget
    const totalSpokes = 12; // Default to 12 (monthly)

    // Draw the spokes
    for (int i = 0; i < totalSpokes; i++) {
      final angle = -pi/2 + (i / totalSpokes) * 2 * pi;
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
    final radius = size.width / 2 * 0.85; // Use 85% of the available space

    // Create paths for different types of events
    final learnedPath = Path();
    final revisedPath = Path();
    final missedPath = Path();

    // Variables to track if we've moved to first points
    bool learnedMoved = false;
    bool revisedMoved = false;
    bool missedMoved = false;

    // Draw points for each revision
    for (int i = 0; i < revisions.length; i++) {
      final revision = revisions[i];
      final totalEvents = revisions.length;

      // Calculate angle and radiusRatio based on animation
      final angle = -pi/2 + (i / totalEvents) * 2 * pi;
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
          6,
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
          5,
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
          5,
          Paint()..color = revisedColor,
        );
      }
    }

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
          ..strokeWidth = 2.0,
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
          ..strokeWidth = 2.0,
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
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
          oldDelegate.revisions.length != revisions.length;
}
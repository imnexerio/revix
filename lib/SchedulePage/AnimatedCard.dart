import 'package:flutter/material.dart';
import 'RevisionGraph.dart';
import '../Utils/lecture_colors.dart';

class AnimatedCard extends StatefulWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;

  const AnimatedCard({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
  }) : super(key: key);

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  Color? _backgroundColor;

  @override
  void initState() {
    super.initState();
    _loadBackgroundColor();
  }

  @override
  void didUpdateWidget(AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload color if entry_type changed
    if (widget.record['entry_type'] != oldWidget.record['entry_type']) {
      _loadBackgroundColor();
    }
  }

  Future<void> _loadBackgroundColor() async {
    if (mounted) {
      final entryType = widget.record['entry_type']?.toString() ?? '';
      if (entryType.isNotEmpty) {
        try {
          final color = await LectureColors.getLectureTypeColor(context, entryType);
          if (mounted) {
            setState(() {
              _backgroundColor = color.withOpacity(0.15); // Subtle background opacity
            });
          }
        } catch (e) {
          // Fallback to default color on error
          if (mounted) {
            setState(() {
              _backgroundColor = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1);
            });
          }
        }
      } else {
        // Default color for empty entry_type
        if (mounted) {
          setState(() {
            _backgroundColor = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.05);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // print('record : $record');
    // Apply multiple animations
    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(widget.animation);
    final fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(widget.animation);
    final slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(widget.animation);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: Card(
                elevation: 5,
                margin: const EdgeInsets.all(4),
                color: _backgroundColor ?? Theme.of(context).cardColor, // Apply background color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelect(context, widget.record),
                  child: Stack(
                    children: [
                      // Main content
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left side with category information
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${widget.record['category']} · ${widget.record['sub_category']} · ${widget.record['record_title']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.record['entry_type']} · ${widget.record['reminder_time']}',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildDateInfo(
                                    context,
                                    'Scheduled',
                                    widget.record['scheduled_date'] ?? '',
                                    Icons.calendar_today,
                                  ),
                                  if (widget.isCompleted)
                                    _buildDateInfo(
                                      context,
                                      'Initiated',
                                      widget.record['date_initiated'] ?? '',
                                      Icons.check_circle_outline,
                                    ),
                                ],
                              ),
                            ),
                            // Right side with the revision graph
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                // height: 200,
                                child: Center(
                                  // Add a key to force rebuild of RevisionRadarChart when data changes
                                  child: RevisionRadarChart(
                                    key: ValueKey('chart_${widget.record['category']}_${widget.record['record_title']}_${widget.record['dates_updated']?.length ?? 0}_${widget.record['dates_missed_revisions']?.length ?? 0}'),
                                    dateLearnt: widget.record['date_initiated'],
                                    datesMissedRevisions: List<String>.from(widget.record['dates_missed_revisions'] ?? []),
                                    datesRevised: List<String>.from(widget.record['dates_updated'] ?? []),
                                    showLabels: false,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // L-shaped border accent (like phone case design)
                      if (_backgroundColor != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LShapedBorderPainter(
                              color: _backgroundColor!.withOpacity(0.9),
                              borderRadius: 12,
                              borderWidth: 3.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateInfo(BuildContext context, String label, String date, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            Text(
              date,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom painter for L-shaped border accent (like phone case design)
class LShapedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double borderWidth;

  LShapedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    // Create a rounded rectangle for the full border outline
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderWidth / 2, 
        borderWidth / 2, 
        size.width - borderWidth, 
        size.height - borderWidth
      ),
      Radius.circular(borderRadius - borderWidth / 2),
    );

    // Draw the complete rounded border
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is LShapedBorderPainter) {
      return oldDelegate.color != color || 
             oldDelegate.borderRadius != borderRadius ||
             oldDelegate.borderWidth != borderWidth;
    }
    return true;
  }
}
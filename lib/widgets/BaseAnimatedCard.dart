import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../SchedulePage/RevisionGraph.dart';

enum CardDisplayMode {
  schedule, // For AnimatedCard
  detail,   // For AnimatedCardDetailP
}

class FieldConfig {
  final bool isEditable;
  final String? label;
  final IconData? icon;
  final Function(String)? onChanged;

  const FieldConfig({
    this.isEditable = false,
    this.label,
    this.icon,
    this.onChanged,
  });
}

class BaseAnimatedCard extends StatefulWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final CardDisplayMode displayMode;
  final Map<String, FieldConfig> fieldConfigs;

  const BaseAnimatedCard({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
    required this.displayMode,
    this.fieldConfigs = const {},
  }) : super(key: key);

  @override
  State<BaseAnimatedCard> createState() => _BaseAnimatedCardState();
}

class _BaseAnimatedCardState extends State<BaseAnimatedCard> {
  late Map<String, dynamic> editableRecord;
  Map<String, bool> editingStates = {};

  @override
  void initState() {
    super.initState();
    editableRecord = Map<String, dynamic>.from(widget.record);
  }

  @override
  Widget build(BuildContext context) {
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelect(context, editableRecord),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side with subject information
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildEditableText(
                                context,
                                _getTitleText(),
                                'title',
                                const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildEditableText(
                                context,
                                _getSubtitleText(),
                                'subtitle',
                                TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildDateInfo(
                                context,
                                'Scheduled',
                                editableRecord['date_scheduled'] ?? '',
                                Icons.calendar_today,
                                'date_scheduled',
                              ),
                              if (widget.isCompleted)
                                _buildDateInfo(
                                  context,
                                  'Initiated',
                                  editableRecord['date_learnt'] ?? '',
                                  Icons.check_circle_outline,
                                  'date_learnt',
                                ),
                            ],
                          ),
                        ),
                        // Right side with the revision graph
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            child: Center(
                              // Add a key to force rebuild of RevisionRadarChart when data changes
                              child: RevisionRadarChart(
                                key: ValueKey('chart_${editableRecord['subject']}_${editableRecord['lecture_no']}_${editableRecord['dates_revised']?.length ?? 0}_${editableRecord['dates_missed_revisions']?.length ?? 0}'),
                                dateLearnt: editableRecord['date_learnt'],
                                datesMissedRevisions: List<String>.from(editableRecord['dates_missed_revisions'] ?? []),
                                datesRevised: List<String>.from(editableRecord['dates_revised'] ?? []),
                                showLabels: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditableText(BuildContext context, String text, String fieldKey, TextStyle style) {
    final config = widget.fieldConfigs[fieldKey];
    final isEditable = config?.isEditable ?? false;
    final isEditing = editingStates[fieldKey] ?? false;

    if (isEditable && isEditing) {
      return TextFormField(
        initialValue: text,
        style: style,
        maxLines: 1,
        onFieldSubmitted: (value) {
          setState(() {
            editingStates[fieldKey] = false;
            config?.onChanged?.call(value);
          });
        },
        onTapOutside: (_) {
          setState(() {
            editingStates[fieldKey] = false;
          });
        },
        autofocus: true,
      );
    }

    return GestureDetector(
      onTap: isEditable
          ? () {
              setState(() {
                editingStates[fieldKey] = true;
              });
            }
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isEditable)
            Icon(
              Icons.edit,
              size: 14,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
        ],
      ),
    );
  }

  String _getTitleText() {
    switch (widget.displayMode) {
      case CardDisplayMode.schedule:
        return '${editableRecord['subject']} · ${editableRecord['subject_code']} · ${editableRecord['lecture_no']}';
      case CardDisplayMode.detail:
        return '${editableRecord['lecture_type']} · ${editableRecord['lecture_no']}';
    }
  }

  String _getSubtitleText() {
    switch (widget.displayMode) {
      case CardDisplayMode.schedule:
        return '${editableRecord['lecture_type']} · ${editableRecord['reminder_time']}';
      case CardDisplayMode.detail:
        return '${_formatDate(editableRecord['initiated_on'])} · ${editableRecord['no_revision']} · ${editableRecord['missed_revision']}';
    }
  }

  String _formatDate(String date) {
    try {
      final DateTime parsedDate = DateTime.parse(date);
      final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
      return formatter.format(parsedDate);
    } catch (e) {
      return date; // Return original string if parsing fails
    }
  }

  Widget _buildDateInfo(BuildContext context, String label, String date, IconData icon, String fieldKey) {
    final config = widget.fieldConfigs[fieldKey];
    final isEditable = config?.isEditable ?? false;
    final isEditing = editingStates[fieldKey] ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
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
              if (isEditable && isEditing)
                TextFormField(
                  initialValue: date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  onFieldSubmitted: (value) {
                    setState(() {
                      editingStates[fieldKey] = false;
                      editableRecord[fieldKey] = value;
                      config?.onChanged?.call(value);
                    });
                  },
                  onTapOutside: (_) {
                    setState(() {
                      editingStates[fieldKey] = false;
                    });
                  },
                  autofocus: true,
                )
              else
                GestureDetector(
                  onTap: isEditable
                      ? () {
                          setState(() {
                            editingStates[fieldKey] = true;
                          });
                        }
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isEditable)
                        Icon(
                          Icons.edit,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

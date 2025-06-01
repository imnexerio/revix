import 'package:flutter/material.dart';
import '../widgets/BaseAnimatedCard.dart';

/// Example widget demonstrating how to use the BaseAnimatedCard with full editing capabilities
class EditableAnimatedCard extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final CardDisplayMode displayMode;
  final Function(String, String)? onFieldChanged;

  const EditableAnimatedCard({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
    required this.displayMode,
    this.onFieldChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // All fields are editable by default, you can customize as needed
    final fieldConfigs = {
      'title': FieldConfig(
        isEditable: true,
        onChanged: (value) => onFieldChanged?.call('title', value),
      ),
      'subtitle': FieldConfig(
        isEditable: true,
        onChanged: (value) => onFieldChanged?.call('subtitle', value),
      ),
      'scheduled_date': FieldConfig(
        isEditable: true,
        onChanged: (value) => onFieldChanged?.call('scheduled_date', value),
      ),
      'date_initiated': FieldConfig(
        isEditable: true,
        onChanged: (value) => onFieldChanged?.call('date_initiated', value),
      ),
    };

    return BaseAnimatedCard(
      animation: animation,
      record: record,
      isCompleted: isCompleted,
      onSelect: onSelect,
      displayMode: displayMode,
      fieldConfigs: fieldConfigs,
    );
  }
}

/// Example widget for cards with specific editable fields only
class PartiallyEditableAnimatedCard extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final CardDisplayMode displayMode;
  final Set<String> editableFields;
  final Function(String, String)? onFieldChanged;

  const PartiallyEditableAnimatedCard({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
    required this.displayMode,
    this.editableFields = const {},
    this.onFieldChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only specified fields are editable
    final fieldConfigs = <String, FieldConfig>{};
    
    for (final field in ['title', 'subtitle', 'scheduled_date', 'date_initiated']) {
      fieldConfigs[field] = FieldConfig(
        isEditable: editableFields.contains(field),
        onChanged: editableFields.contains(field) 
            ? (value) => onFieldChanged?.call(field, value)
            : null,
      );
    }

    return BaseAnimatedCard(
      animation: animation,
      record: record,
      isCompleted: isCompleted,
      onSelect: onSelect,
      displayMode: displayMode,
      fieldConfigs: fieldConfigs,
    );
  }
}

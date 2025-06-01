import 'package:flutter/material.dart';
import '../widgets/BaseAnimatedCard.dart';

class AnimatedCardDetailP extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final bool enableEditing;

  const AnimatedCardDetailP({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
    this.enableEditing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Configure which fields are editable
    Map<String, FieldConfig> fieldConfigs = {};
    
    if (enableEditing) {
      fieldConfigs = {
        'title': FieldConfig(
          isEditable: true,
          onChanged: (value) {
            // Handle title change
            print('Title changed to: $value');
          },
        ),
        'subtitle': FieldConfig(
          isEditable: true,
          onChanged: (value) {
            // Handle subtitle change
            print('Subtitle changed to: $value');
          },
        ),
        'scheduled_date': FieldConfig(
          isEditable: true,
          onChanged: (value) {
            // Handle scheduled date change
            print('Scheduled date changed to: $value');
          },
        ),
        'date_initiated': FieldConfig(
          isEditable: true,
          onChanged: (value) {
            // Handle learnt date change
            print('Learnt date changed to: $value');
          },
        ),
      };
    }

    return BaseAnimatedCard(
      animation: animation,
      record: record,
      isCompleted: isCompleted,
      onSelect: onSelect,
      displayMode: CardDisplayMode.detail,
      fieldConfigs: fieldConfigs,
    );
  }
}
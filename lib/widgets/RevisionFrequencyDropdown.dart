import 'package:flutter/material.dart';

class RevisionFrequencyDropdown extends StatelessWidget {
  final String revisionFrequency;
  final ValueChanged<String?> onChanged;

  const RevisionFrequencyDropdown({
    required this.revisionFrequency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Revision Frequency',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        value: revisionFrequency,
        onChanged: onChanged,
        items: [
          DropdownMenuItem<String>(
            value: 'Daily',
            child: Text('Daily'),
          ),
          DropdownMenuItem<String>(
            value: '2 Day',
            child: Text('2 Day'),
          ),
          DropdownMenuItem<String>(
            value: '3 Day',
            child: Text('3 Day'),
          ),
          DropdownMenuItem<String>(
            value: 'Weekly',
            child: Text('Weekly'),
          ),
          DropdownMenuItem<String>(
            value: 'Priority',
            child: Text('Priority'),
          ),
          DropdownMenuItem<String>(
            value: 'Default',
            child: Text('Default'),
          ),
        ],
        validator: (value) => value == null ? 'Please select a revision frequency' : null,
      ),
    );
  }
}
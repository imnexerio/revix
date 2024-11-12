import 'package:flutter/material.dart';

class LectureTypeDropdown extends StatelessWidget {
  final String lectureType;
  final ValueChanged<String?> onChanged;

  const LectureTypeDropdown({
    required this.lectureType,
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
          labelText: 'Type',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        value: lectureType,
        onChanged: onChanged,
        items: [
          DropdownMenuItem<String>(
            value: 'Lectures',
            child: Text('Lectures'),
          ),
          DropdownMenuItem<String>(
            value: 'Handouts',
            child: Text('Handouts'),
          ),
          DropdownMenuItem<String>(
            value: 'O-NCERTs',
            child: Text('O-NCERTs'),
          ),
          DropdownMenuItem<String>(
            value: 'N-NCERTs',
            child: Text('N-NCERTs'),
          ),
          DropdownMenuItem<String>(
            value: 'Others',
            child: Text('Others'),
          ),
        ],
        validator: (value) => value == null ? 'Please select a type' : null,
      ),
    );
  }
}
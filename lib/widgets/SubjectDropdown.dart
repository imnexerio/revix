import 'package:flutter/material.dart';

class SubjectDropdown extends StatelessWidget {
  final List<String> subjects;
  final String selectedSubject;
  final ValueChanged<String?> onChanged;

  const SubjectDropdown({
    required this.subjects,
    required this.selectedSubject,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Select Subject',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        value: selectedSubject.isEmpty ? null : selectedSubject,
        onChanged: onChanged,
        items: [
          ...subjects.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          const DropdownMenuItem<String>(
            value: 'Others',
            child: Text('Others'),
          ),
        ],
        validator: (value) => value == null ? 'Please select a Category' : null,
      ),
    );
  }
}
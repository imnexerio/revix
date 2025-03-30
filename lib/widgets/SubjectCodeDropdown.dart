import 'package:flutter/material.dart';

class SubjectCodeDropdown extends StatelessWidget {
  final Map<String, List<String>> subjectCodes;
  final String selectedSubject;
  final String selectedSubjectCode;
  final ValueChanged<String?> onChanged;

  const SubjectCodeDropdown({
    required this.subjectCodes,
    required this.selectedSubject,
    required this.selectedSubjectCode,
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
          labelText: 'Select Subject Code',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        value: selectedSubjectCode.isEmpty ? null : selectedSubjectCode,
        onChanged: onChanged,
        items: selectedSubject.isEmpty
            ? []
            : [
                ...subjectCodes[selectedSubject]!.map<DropdownMenuItem<String>>((String value) {
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
        validator: (value) => value == null ? 'Please select a Sub Category' : null,
      ),
    );
  }
}
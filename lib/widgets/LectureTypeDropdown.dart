import 'package:flutter/material.dart';

import '../Utils/FetchTypesUtils.dart'; // Adjust the import path as necessary

class LectureTypeDropdown extends StatefulWidget {
  final String lectureType;
  final ValueChanged<String?> onChanged;

  const LectureTypeDropdown({
    required this.lectureType,
    required this.onChanged,
  });

  @override
  _LectureTypeDropdownState createState() => _LectureTypeDropdownState();
}

class _LectureTypeDropdownState extends State<LectureTypeDropdown> {
  List<String> _lectureTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLectureTypes();
  }

  Future<void> _fetchLectureTypes() async {
    List<String> types = await FetchtrackingTypeUtils.fetchtrackingType();
    setState(() {
      _lectureTypes = types;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<String>(
        value: widget.lectureType,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        items: _lectureTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: widget.onChanged,
      ),
    );
  }
}
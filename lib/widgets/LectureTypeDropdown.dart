import 'package:flutter/material.dart';
import '../Utils/FirebaseDatabaseService.dart'; // Adjust the import path as necessary
import '../SettingsPage/AddTrackingTypeSheet.dart'; // Adjust the import path as necessary

class LectureTypeDropdown extends StatefulWidget {
  final String lectureType;
  final ValueChanged<String?> onChanged;
  final Function(String)? onLectureTypesLoaded;

  const LectureTypeDropdown({
    required this.lectureType,
    required this.onChanged,
    this.onLectureTypesLoaded,
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
    final databaseService = FirebaseDatabaseService();
    List<String> types = await databaseService.fetchCustomTrackingTypes();
    setState(() {
      _lectureTypes = types;
      _lectureTypes.add('Add new'); // Add the 'Add new' option
      _isLoading = false;
    });
    
    // Notify parent that lecture types are loaded and provide the first one as default
    if (widget.onLectureTypesLoaded != null && types.isNotEmpty) {
      widget.onLectureTypesLoaded!(types[0]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<String>(
        value: widget.lectureType == 'DEFAULT_LECTURE_TYPE' ? null : 
               (_lectureTypes.contains(widget.lectureType) ? widget.lectureType : null),
        decoration: const InputDecoration(
          labelText: 'Type',
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        items: _lectureTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue == 'Add new') {
            showAddtrackingTypeSheet(
              context,
              GlobalKey<FormState>(),
              TextEditingController(),
                  (newState) {
                setState(() {
                  _fetchLectureTypes(); // Refresh the list after adding a new type
                });
              },
              _fetchLectureTypes, // Pass the callback to refresh the dropdown
            );
          } else {
            widget.onChanged(newValue);
          }
        },
      ),
    );
  }
}
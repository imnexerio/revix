import 'package:flutter/material.dart';
import '../Utils/FirebaseDatabaseService.dart'; // Adjust the import path as necessary
import '../Utils/entry_colors.dart'; // Add this import for colors
import '../SettingsPage/AddTrackingTypeSheet.dart'; // Adjust the import path as necessary

class EntryTypeDropdown extends StatefulWidget {
  final String entryType;
  final ValueChanged<String?> onChanged;
  final Function(String)? onEntryTypesLoaded;

  const EntryTypeDropdown({
    required this.entryType,
    required this.onChanged,
    this.onEntryTypesLoaded,
  });

  @override
  _EntryTypeDropdownState createState() => _EntryTypeDropdownState();
}

class _EntryTypeDropdownState extends State<EntryTypeDropdown> {
  List<String> _entryTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEntryTypes();
  }

  Future<void> _fetchEntryTypes() async {
    final databaseService = FirebaseDatabaseService();
    List<String> types = await databaseService.fetchCustomTrackingTypes();
    setState(() {
      _entryTypes = types;
      _entryTypes.add('Add new'); // Add the 'Add new' option
      _isLoading = false;
    });
    
    // Notify parent that entry types are loaded and provide the first one as default
    if (widget.onEntryTypesLoaded != null && types.isNotEmpty) {
      widget.onEntryTypesLoaded!(types[0]);
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
        value: widget.entryType == 'DEFAULT_ENTRY_TYPE' ? null : 
               (_entryTypes.contains(widget.entryType) ? widget.entryType : null),
        decoration: const InputDecoration(
          labelText: 'Type',
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        hint: widget.entryType != 'DEFAULT_ENTRY_TYPE' && !_entryTypes.contains(widget.entryType)
            ? Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: EntryColors.generateColorFromString(widget.entryType),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.entryType,
                    style: TextStyle(
                      color: EntryColors.generateColorFromString(widget.entryType),
                    ),
                  ),
                ],
              )
            : null,
        selectedItemBuilder: (BuildContext context) {
          return _entryTypes.map((String type) {
            if (type == 'Add new') {
              return Text(type);
            }
            return Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: EntryColors.generateColorFromString(type),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  type,
                  style: TextStyle(
                    color: EntryColors.generateColorFromString(type),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }).toList();
        },
        items: _entryTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: type == 'Add new' 
                ? Text(type)
                : Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: EntryColors.generateColorFromString(type),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(type),
                    ],
                  ),
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
                  _fetchEntryTypes(); // Refresh the list after adding a new type
                });
              },
              _fetchEntryTypes, // Pass the callback to refresh the dropdown
            );
          } else {
            widget.onChanged(newValue);
          }
        },
      ),
    );
  }
}

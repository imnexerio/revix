import 'package:flutter/material.dart';
import 'package:retracker/Utils/FetchTypesUtils.dart';

class TrackingTypeDropdown extends StatefulWidget {
  final String trackingType;
  final ValueChanged<String?> onChanged;

  const TrackingTypeDropdown({
    required this.trackingType,
    required this.onChanged,
  });

  @override
  _TrackingTypeDropdownState createState() => _TrackingTypeDropdownState();
}

class _TrackingTypeDropdownState extends State<TrackingTypeDropdown> {
  List<DropdownMenuItem<String>> _dropdownItems = [];

  @override
  void initState() {
    super.initState();
    _fetchFrequencies();
  }

  Future<void> _fetchFrequencies() async {
    List<String> trackingTypes = await FetchtrackingTypeUtils.fetchtrackingType();
    List<DropdownMenuItem<String>> items = trackingTypes.map((type) {
      return DropdownMenuItem<String>(
        value: type,
        child: Text(type),
      );
    }).toList();

    setState(() {
      _dropdownItems = items;
    });
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
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Tracking Type',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        value: widget.trackingType,
        onChanged: widget.onChanged,
        items: _dropdownItems,
        validator: (value) => value == null ? 'Please select a Tracking Type' : null,
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:revix/Utils/FirebaseDatabaseService.dart';

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
  StreamSubscription? _entryTypesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchFrequencies();
  }

  @override
  void dispose() {
    _entryTypesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchFrequencies() async {
    final databaseService = FirebaseDatabaseService();
    
    // Step 1: Show cached data immediately
    final cachedTypes = databaseService.currentEntryTypes;
    if (cachedTypes.isNotEmpty) {
      _updateDropdownItems(cachedTypes);
    }
    
    // Step 2: Subscribe to stream for live updates
    _entryTypesSubscription = databaseService.entryTypesStream.listen((types) {
      if (mounted) {
        _updateDropdownItems(types);
      }
    });
    
    // Step 3: Trigger background refresh
    databaseService.fetchCustomTrackingTypes();
  }
  
  void _updateDropdownItems(List<String> trackingTypes) {
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
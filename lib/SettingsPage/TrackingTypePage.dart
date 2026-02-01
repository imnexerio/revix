import 'dart:async';
import 'package:flutter/material.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/entry_colors.dart';
import 'AddTrackingTypeSheet.dart';

class TrackingTypePage extends StatefulWidget {
  @override
  _TrackingTypePageState createState() => _TrackingTypePageState();
}

class _TrackingTypePageState extends State<TrackingTypePage> {
  List<Map<String, String>> trackingtype = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customTitleController = TextEditingController();
  StreamSubscription? _entryTypesSubscription;

  @override
  void initState() {
    super.initState();
    fetchtrackingType();
  }

  @override
  void dispose() {
    _entryTypesSubscription?.cancel();
    _customTitleController.dispose();
    super.dispose();
  }

  void fetchtrackingType() async {
    try {
      final databaseService = FirebaseDatabaseService();
      
      // Step 1: Show cached data immediately
      final cachedData = databaseService.currentEntryTypes;
      if (cachedData.isNotEmpty) {
        _updateTrackingTypes(cachedData);
      }
      
      // Step 2: Subscribe to stream for live updates
      _entryTypesSubscription?.cancel();
      _entryTypesSubscription = databaseService.entryTypesStream.listen((types) {
        if (mounted) {
          _updateTrackingTypes(types);
        }
      });
      
      // Step 3: Trigger background refresh
      databaseService.fetchCustomTrackingTypes();
    } catch (e) {
      // Handle error appropriately
    }
  }
  
  void _updateTrackingTypes(List<String> data) {
    if (!mounted) return;
    setState(() {
      trackingtype = data.map((trackingTitle) {
        return {
          'trackingTitle': trackingTitle
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tracking Title',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...trackingtype.map((tracking) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Colored indicator circle
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: EntryColors.generateColorFromString(tracking['trackingTitle']!),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tracking['trackingTitle']!,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trackingtype.indexOf(tracking) != trackingtype.length - 1)
                        const Divider(height: 1),
                    ],
                  )).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showAddtrackingTypeSheet(
                context,
                _formKey,
                _customTitleController,
                setState,
                fetchtrackingType, // Pass the callback to refresh the list
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Type'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
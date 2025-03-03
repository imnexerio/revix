// lib/Utils/TrackingTypeUtils.dart
import 'package:flutter/material.dart';

import '../Utils/FetchTypesUtils.dart';
import 'AddTrackingTypeSheet.dart';

void showTrackingTypeBottomSheet(BuildContext context) {
  List<Map<String, String>> trackingtype = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customTitleController = TextEditingController();

  void fetchtrackingType(StateSetter setState) async {
    try {
      List<String> data = await FetchtrackingTypeUtils.fetchtrackingType();
      setState(() {
        trackingtype = data.map((trackingTitle) {
          return {
            'trackingTitle': trackingTitle
          };
        }).toList();
      });
    } catch (e) {
      // Handle error appropriately
    }
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          fetchtrackingType(setState);
          return Container(
            height: MediaQuery.of(context).size.height * 0.73,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar and header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tracking Type',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Customize your tracking types',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
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
                                padding: EdgeInsets.all(16),
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
                              Divider(height: 1),
                              ...trackingtype.map((tracking) => Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
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
                                    Divider(height: 1),
                                ],
                              )).toList(),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => showAddtrackingTypeSheet(
                            context,
                            _formKey,
                            _customTitleController,
                            setState,
                          ),
                          icon: Icon(Icons.add),
                          label: Text('Add Custom Type'),
                          style: FilledButton.styleFrom(
                            minimumSize: Size(200, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
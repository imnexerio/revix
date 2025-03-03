import 'package:flutter/material.dart';

import '../Utils/fetchFrequencies_utils.dart';
import 'FrequencyPageSheet.dart';

void showFrequencyBottomSheet(BuildContext context) {
  List<Map<String, String>> frequencies = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customFrequencyController = TextEditingController();
  final TextEditingController _customTitleController = TextEditingController();

  bool isValidFrequencyFormat(String frequency) {
    if (frequency.isEmpty) return false;
    try {
      List<String> numbers = frequency.split(',').map((e) => e.trim()).toList();
      List<int> numericalValues = numbers.map((e) => int.parse(e)).toList();
      numericalValues.sort();
      for (int i = 0; i < numericalValues.length - 1; i++) {
        if (numericalValues[i] >= numericalValues[i + 1]) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void fetchFrequencies(StateSetter setState) async {
    try {
      Map<String, dynamic> data = await FetchFrequenciesUtils.fetchFrequencies();
      setState(() {
        frequencies = data.entries.map((entry) {
          String title = entry.key;
          List<dynamic> frequencyList = entry.value;
          String frequency = frequencyList.join(', ');

          return {
            'title': title,
            'frequency': frequency,
          };
        }).toList();
      });
    } catch (e) {
      // Handle error
    }
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          fetchFrequencies(setState);
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
                                'Frequency (Days)',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Customize your tracking frequency',
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
                                        'Title',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Frequency',
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
                              ...frequencies.map((frequency) => Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            frequency['title']!,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            frequency['frequency']!,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (frequencies.indexOf(frequency) != frequencies.length - 1)
                                    Divider(height: 1),
                                ],
                              )).toList(),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => showAddFrequencySheet(
                            context,
                            _formKey,
                            _customTitleController,
                            _customFrequencyController,
                            frequencies,
                            setState,
                            isValidFrequencyFormat,
                          ),
                          icon: Icon(Icons.add),
                          label: Text('Add Custom Frequency'),
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
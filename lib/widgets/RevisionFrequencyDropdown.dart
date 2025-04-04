import 'package:flutter/material.dart';
import '../Utils/fetchFrequencies_utils.dart';
import '../SettingsPage/FrequencyPageSheet.dart';

class RevisionFrequencyDropdown extends StatefulWidget {
  final Map<String, dynamic> revisionFrequency;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const RevisionFrequencyDropdown({
    required this.revisionFrequency,
    required this.onChanged,
  });

  @override
  _RevisionFrequencyDropdownState createState() => _RevisionFrequencyDropdownState();
}

class _RevisionFrequencyDropdownState extends State<RevisionFrequencyDropdown> {
  List<DropdownMenuItem<String>> _dropdownItems = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();

  // For custom frequency
  final TextEditingController _customValueController = TextEditingController();
  String _customFrequencyType = 'day';
  List<bool> _selectedDaysOfWeek = List.filled(7, false); // For weekly selection
  int _selectedDayOfMonth = 1; // For monthly selection

  @override
  void initState() {
    super.initState();
    _fetchFrequencies();
  }

  Future<void> _fetchFrequencies() async {
    Map<String, dynamic> frequencies = await FetchFrequenciesUtils.fetchFrequencies();
    List<DropdownMenuItem<String>> items = frequencies.keys.map((key) {
      String frequency = frequencies[key].toString();
      return DropdownMenuItem<String>(
        value: key,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            double availableWidth = constraints.maxWidth;
            return Container(
              width: availableWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Text(
                      frequency,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }).toList();

    // Add "No Repetition" option
    items.add(
      DropdownMenuItem<String>(
        value: 'No Repetition',
        child: Text(
          'No Repetition',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );

    // Add "Custom" option
    items.add(
      DropdownMenuItem<String>(
        value: 'Custom',
        child: Text(
          'Custom',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );

    // Add "Add New" option
    items.add(
      DropdownMenuItem<String>(
        value: 'Add New',
        child: Text(
          'Add New',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );

    setState(() {
      _dropdownItems = items;
    });
  }

  void _showCustomFrequencySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Custom Frequency',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Frequency type selection
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).cardColor,
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _customFrequencyType,
                              decoration: const InputDecoration(
                                labelText: 'Frequency Type',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: [
                                DropdownMenuItem(value: 'day', child: Text('Every X Day')),
                                DropdownMenuItem(value: 'week', child: Text('Every X Week')),
                                DropdownMenuItem(value: 'month', child: Text('Every X Month')),
                                DropdownMenuItem(value: 'year', child: Text('Every X Year')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _customFrequencyType = value!;
                                });
                              },
                            ),
                          ),

                          // Value input
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).cardColor,
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: TextFormField(
                              controller: _customValueController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Every how many ${_customFrequencyType}s?',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a value';
                                }
                                if (int.tryParse(value) == null || int.parse(value) < 1) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),

                          // Weekly selection - shown only when type is 'week'
                          if (_customFrequencyType == 'week')
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                Text(
                                  'Select days of the week:',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                                  ].asMap().entries.map((entry) {
                                    int idx = entry.key;
                                    String day = entry.value;
                                    return FilterChip(
                                      selected: _selectedDaysOfWeek[idx],
                                      label: Text(day),
                                      onSelected: (bool selected) {
                                        setState(() {
                                          _selectedDaysOfWeek[idx] = selected;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),

                          // Monthly selection - shown only when type is 'month'
                          if (_customFrequencyType == 'month')
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                Text(
                                  'Select day of the month:',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 60,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 31,
                                    itemBuilder: (context, index) {
                                      int day = index + 1;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: ChoiceChip(
                                          selected: _selectedDayOfMonth == day,
                                          label: Text(day.toString()),
                                          onSelected: (bool selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedDayOfMonth = day;
                                              });
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_customValueController.text.isEmpty ||
                                  int.tryParse(_customValueController.text) == null ||
                                  int.parse(_customValueController.text) < 1) {
                                // Show error
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please enter a valid number')),
                                );
                                return;
                              }

                              // If weekly, ensure at least one day is selected
                              if (_customFrequencyType == 'week' &&
                                  !_selectedDaysOfWeek.contains(true)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please select at least one day of the week')),
                                );
                                return;
                              }

                              // Create custom frequency data
                              Map<String, dynamic> customData = {
                                'type': 'custom',
                                'frequencyType': _customFrequencyType,
                                'value': int.parse(_customValueController.text),
                              };

                              // Add additional data based on frequency type
                              if (_customFrequencyType == 'week') {
                                customData['daysOfWeek'] = _selectedDaysOfWeek;
                              } else if (_customFrequencyType == 'month') {
                                customData['dayOfMonth'] = _selectedDayOfMonth;
                              }

                              // Pass the custom data back
                              widget.onChanged(customData);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Get the current selected value from the revisionFrequency map
        String currentValue = 'Default';
        if (widget.revisionFrequency['type'] == 'custom') {
          currentValue = 'Custom';
        } else if (widget.revisionFrequency['type'] == 'none') {
          currentValue = 'No Repetition';
        } else if (widget.revisionFrequency['type'] == 'predefined') {
          currentValue = widget.revisionFrequency['value'];
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Review Frequency',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              value: currentValue,
              onChanged: (String? newValue) {
                if (newValue == 'Add New') {
                  showAddFrequencySheet(
                    context,
                    _formKey,
                    _titleController,
                    _frequencyController,
                    [],
                    setState,
                        (value) => true, // Replace with actual validation logic
                    _fetchFrequencies, // Pass the callback to refresh the dropdown
                  );
                } else if (newValue == 'Custom') {
                  _showCustomFrequencySheet(context);
                } else if (newValue == 'No Repetition') {
                  widget.onChanged({'type': 'none'});
                } else {
                  widget.onChanged({'type': 'predefined', 'value': newValue});
                }
              },
              items: _dropdownItems,
              menuMaxHeight: MediaQuery.of(context).size.height * 0.5,
              validator: (value) => value == null ? 'Please select a Review frequency' : null,
            ),
          ),
        );
      },
    );
  }
}
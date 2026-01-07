import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:revix/Utils/date_utils.dart';
import 'package:revix/widgets/EntryTypeDropdown.dart';
import 'package:revix/widgets/RecurrenceDropdown.dart';
import 'Utils/CustomFrequencySelector.dart';
import 'Utils/CalculateCustomNextDate.dart';
import 'Utils/UnifiedDatabaseService.dart';
import 'Utils/customSnackBar_error.dart';

class AddEntryForm extends StatefulWidget {
  @override
  _AddEntryFormState createState() => _AddEntryFormState();
}

class _AddEntryFormState extends State<AddEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _initiationdateController = TextEditingController();
  final TextEditingController _scheduleddateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  String _selectedCategory = 'DEFAULT_VALUE';
  String _selectedCategoryCode = '';
  String _entryType = 'DEFAULT_ENTRY_TYPE';
  String _title = '';
  String _description = '';
  String _recurrenceFrequency = 'Default';  String _duration = 'Forever';
  List<String> _categories = [];
  Map<String, List<String>> _subCategories = {};
  String dateScheduled = '';
  String todayDate = '';
  Map<String, dynamic> _durationData = {
    "type": "forever",
    "numberOfTimes": null,
    "endDate": null
  };
  String start_timestamp = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
  
  // End timestamp fields
  bool _hasEndTime = false;
  String? end_timestamp; // null by default
  
  // Alarm type field
  int _alarmType = 0; // 0: no reminder, 1: notification only, 2: vibration only, 3: sound, 4: sound + vibration, 5: loud alarm
  final List<String> _alarmOptions = ['No Reminder', 'Notification Only', 'Vibration Only', 'Sound', 'Sound + Vibration', 'Loud Alarm'];

  // Custom frequency parameters
  Map<String, dynamic> _customFrequencyParams = {};

  bool _showAddNewCategory = false;
  bool _showAddNewCategoryCode_ = false;

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndSubCategories();
    _setInitialDate();
    _setScheduledDate();
    _timeController.text = 'All Day';
    _alarmType = 0; // Initialize alarm type to no reminder
    _hasEndTime = false;
    end_timestamp = null;
  }
  
  /// Sets default end time to +1 hour from start
  void _setDefaultEndTime() {
    if (_timeController.text == 'All Day') {
      // For all day, default end date is same day
      _endDateController.text = _initiationdateController.text;
      _endTimeController.text = 'All Day';
    } else {
      // Parse start time and add 1 hour
      final startTime = _timeController.text;
      final parts = startTime.split(':');
      if (parts.length == 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        hour = (hour + 1) % 24; // Add 1 hour, wrap at midnight
        _endTimeController.text = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        
        // If wrapped to next day, update end date
        if (hour < int.parse(parts[0])) {
          final startDate = DateTime.parse(todayDate);
          final nextDay = startDate.add(const Duration(days: 1));
          _endDateController.text = nextDay.toIso8601String().split('T')[0];
        } else {
          _endDateController.text = todayDate;
        }
      }
    }
    _updateEndTimestamp();
  }
  
  /// Updates end_timestamp from end date and time controllers
  void _updateEndTimestamp() {
    if (!_hasEndTime) {
      end_timestamp = null;
      return;
    }
    
    if (_endDateController.text.isEmpty || _endDateController.text == 'Unspecified') {
      end_timestamp = null;
      return;
    }
    
    if (_endTimeController.text == 'All Day') {
      // All day: set to end of day (23:59)
      end_timestamp = '${_endDateController.text}T23:59';
    } else {
      end_timestamp = '${_endDateController.text}T${_endTimeController.text}';
    }
  }
  
  /// Validates that end timestamp is after start timestamp
  bool _validateEndTime() {
    if (!_hasEndTime || end_timestamp == null) return true;
    
    try {
      final start = DateTime.parse(start_timestamp);
      final end = DateTime.parse(end_timestamp!);
      return end.isAfter(start);
    } catch (e) {
      return false;
    }
  }
  Future<void> _loadCategoriesAndSubCategories() async {
    try {
      // Get the singleton instance and use the loadCategoriesAndSubCategories method
      final service = UnifiedDatabaseService();
      final data = await service.loadCategoriesAndSubCategories();

      // Update state with the retrieved data
      setState(() {
        _categories = data['subjects'];
        _subCategories = data['subCategories'];

        // Set appropriate selection
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories[0];
          // Set default sub-category for the selected category
          if (_subCategories[_categories[0]]?.isNotEmpty == true) {
            _selectedCategoryCode = _subCategories[_categories[0]]![0];
          }
        } else {
          _selectedCategory = 'DEFAULT_VALUE';
        }
      });

      // No need to set up a listener here since this is part of a form
      // that's not constantly visible in the UI

    } catch (e) {
      customSnackBar_error(
        context: context,
        message: 'Error loading categories and sub categories: $e',
      );
    }
  }
  Future<void> UpdateRecords(BuildContext context) async {
    try {
      // Validate end time if set
      if (_hasEndTime && !_validateEndTime()) {
        customSnackBar_error(
          context: context,
          message: 'End time must be after start time',
        );
        return;
      }
      
      final unifiedService = UnifiedDatabaseService();
      
      // Set alarm type to 0 if "All Day" is selected
      int finalAlarmType = _timeController.text == 'All Day' ? 0 : _alarmType;
      
      await unifiedService.updateRecords(
        context,
        _selectedCategory,
        _selectedCategoryCode,
        _title,
        start_timestamp,
        _timeController.text,
        _entryType,
        todayDate,
        dateScheduled,
        _description,
        _recurrenceFrequency,
        _durationData,
        _customFrequencyParams,
        finalAlarmType,
        endTimestamp: end_timestamp,
      );
    } catch (e) {
      throw Exception('Failed to save entry: $e');
    }
  }

  Future<void> _setInitialDate() async {
    DateTime initialDate = DateTime.now();
    setState(() {
      todayDate = initialDate.toIso8601String().split('T')[0];
      _initiationdateController.text = todayDate;
    });
  }

  Future<void> _setScheduledDate() async {
    if (todayDate == 'Unspecified') {
      setState(() {
        dateScheduled = 'Unspecified';
        _scheduleddateController.text = dateScheduled;
      });
    }
    else {
      // If it's no repetition, don't calculate next date
      if (_recurrenceFrequency == 'No Repetition') {
        setState(() {
          dateScheduled = todayDate;
          _scheduleddateController.text = dateScheduled;
        });
        return;
      }

      // For custom frequency, add the custom parameters
      if (_recurrenceFrequency == 'Custom' && _customFrequencyParams.isNotEmpty) {
        // Use custom parameters to calculate the next date
        DateTime initialDate = DateTime.parse(todayDate);
        DateTime nextDate = CalculateCustomNextDate.calculateCustomNextDate(
            initialDate, _customFrequencyParams);
        setState(() {
          dateScheduled = nextDate.toIso8601String().split('T')[0];
          _scheduleddateController.text = dateScheduled;
        });
        return; // Skip the standard calculation
      }

      // For standard frequencies
      DateTime initialDate = await DateNextRecurrence.calculateNextRecurrenceDate(
        DateTime.parse(todayDate),
        _recurrenceFrequency,
        0,
      );

      setState(() {
        dateScheduled = initialDate.toIso8601String().split('T')[0];
        if (DateTime.parse(start_timestamp).isBefore(DateTime.parse(todayDate))) {
          dateScheduled= todayDate;
        }
        _scheduleddateController.text = dateScheduled;
      });
    }
  }

  String _getCustomFrequencyDescription() {
    if (_customFrequencyParams.isEmpty) {
      return 'Custom frequency';
    }

    String frequencyType = _customFrequencyParams['frequencyType'] ?? 'day';
    int value = _customFrequencyParams['value'] ?? 1;

    String description = 'Every $value ';

    switch (frequencyType) {
      case 'day':
        description += value == 1 ? 'day' : 'days';
        break;
      case 'week':
        description += value == 1 ? 'week' : 'weeks';

        // If we have days of week selected, add them
        if (_customFrequencyParams['daysOfWeek'] != null) {
          List<bool> daysOfWeek = List<bool>.from(_customFrequencyParams['daysOfWeek']);
          List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          List<String> selectedDays = [];

          for (int i = 0; i < daysOfWeek.length; i++) {
            if (daysOfWeek[i]) {
              selectedDays.add(dayNames[i]);
            }
          }

          if (selectedDays.isNotEmpty) {
            description += ' on ' + selectedDays.join(', ');
          }
        }
        break;
      case 'month':
        description += value == 1 ? 'month' : 'months';

        // If day of month is specified, add it
        if (_customFrequencyParams['dayOfMonth'] != null) {
          int dayOfMonth = _customFrequencyParams['dayOfMonth'];
          description += ' on day $dayOfMonth';
        }
        break;
      case 'year':
        description += value == 1 ? 'year' : 'years';
        break;
    }

    return description;
  }

  // Function to show custom frequency selection bottom sheet
  Future<void> _showCustomFrequencySelector() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // This will make the modal adjust to keyboard height
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CustomFrequencySelector(
            initialParams: _customFrequencyParams,
            referenceDate: todayDate != 'Unspecified' ? DateTime.parse(todayDate) : DateTime.now(),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _customFrequencyParams = result;
        _setScheduledDate(); // Update scheduled date based on new frequency
      });
    } else {
      setState(() { // Added setState here to update the UI
        _recurrenceFrequency = 'Default';
        _setScheduledDate(); // Update scheduled date based on the default frequency
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              'Add New Record',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Category dropdown
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory == 'DEFAULT_VALUE' && _categories.isNotEmpty ? _categories[0] :
                        (_categories.contains(_selectedCategory) ? _selectedCategory : null),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        isExpanded: true,
                        items: [
                          ..._categories.map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          )).toList(),
                          const DropdownMenuItem(
                            value: "Add New Category",
                            child: Text("Add New Category"),
                          ),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            if (newValue == "Add New Category") {
                              _showAddNewCategory = true;
                              _showAddNewCategoryCode_ = false; // Reset subcategory input
                            } else {
                              _selectedCategory = newValue!;
                              _selectedCategoryCode = '';
                              _showAddNewCategory = false;
                              _showAddNewCategoryCode_ = false; // Reset subcategory input
                              // Set default sub-category for the newly selected category
                              if (_subCategories[newValue]?.isNotEmpty == true) {
                                _selectedCategoryCode = _subCategories[newValue]![0];
                              }
                            }
                          });
                        },
                      ),
                    ),

                    // New Category input field (conditionally shown)
                    if (_showAddNewCategory)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Add New Category',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSaved: (value) {
                                  _selectedCategory = value!;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    // New Sub Category input field (when adding new Category)
                    if (_showAddNewCategory)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Add New Sub Category',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSaved: (value) {
                                  _selectedCategoryCode = value!;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Sub Category dropdown (when category is selected)
                    if (_selectedCategory != 'DEFAULT_VALUE' && !_showAddNewCategory)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _subCategories[_selectedCategory]?.contains(_selectedCategoryCode) ?? false
                              ? _selectedCategoryCode : null,
                          decoration: const InputDecoration(
                            labelText: 'Sub Category',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          isExpanded: true,
                          items: [
                            ...(_subCategories[_selectedCategory] ?? []).map((code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            )).toList(),
                            const DropdownMenuItem(
                              value: "Add New Sub Category",
                              child: Text("Add New Sub Category"),
                            ),
                          ],
                          onChanged: (newValue) {
                            setState(() {
                              if (newValue == "Add New Sub Category") {
                                _showAddNewCategoryCode_ = true;
                              } else {
                                _selectedCategoryCode = newValue!;
                                _showAddNewCategoryCode_ = false; // Reset when selecting existing subcategory
                              }
                            });
                          },
                        ),
                      ),

                    // New Sub Category input field (when adding to existing category)
                    if (_showAddNewCategoryCode_)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Add New Sub Category',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSaved: (value) {
                                  _selectedCategoryCode = value!;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Entry Type Dropdown
                    EntryTypeDropdown(
                      entryType: _entryType,
                      onChanged: (String? newValue) {
                        setState(() {
                          _entryType = newValue!;
                        });
                      },
                      onEntryTypesLoaded: (String firstEntryType) {
                        // Set default entry type when entry types are loaded
                        if (_entryType == 'DEFAULT_ENTRY_TYPE') {
                          setState(() {
                            _entryType = firstEntryType;
                          });
                        }
                      },
                    ),

                    // Title Field
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSaved: (value) {
                          _title = value!;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a Title';
                          }
                          return null;
                        },
                      ),
                    ),

                    // Reminder Time Field with All Day option
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _timeController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Reminder Time',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                hintText: 'Tap to select time',
                              ),
                              onTap: () async {
                                TimeOfDay? pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: _timeController.text != 'All Day' && _timeController.text.isNotEmpty
                                      ? TimeOfDay(
                                      hour: int.parse(_timeController.text.split(':')[0]),
                                      minute: int.parse(_timeController.text.split(':')[1]))
                                      : TimeOfDay.now(),
                                  builder: (BuildContext context, Widget? child) {
                                    return MediaQuery(
                                      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                      child: child!,
                                    );
                                  },
                                );

                                if (pickedTime != null) {
                                  final now = DateTime.now();
                                  final formattedTime = DateFormat('HH:mm').format(
                                    DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute),
                                  );
                                  setState(() {
                                    _timeController.text = formattedTime;
                                  });
                                }
                              },
                            ),
                          ),
                          // "All Day" option as a toggle button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (_timeController.text == 'All Day') {
                                    // If already "All Day", set to current time
                                    final now = DateTime.now();
                                    _timeController.text = DateFormat('HH:mm').format(now);
                                  } else {
                                    // Set to "All Day" (all day)
                                    _timeController.text = 'All Day';
                                    // Reset alarm type to no reminder when "All Day" is selected
                                    _alarmType = 0;
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _timeController.text == 'All Day'
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('All Day'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),                    // Alarm Type Field (only shown when not "All Day")
                    if (_timeController.text != 'All Day')
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alarm Type',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _alarmOptions.asMap().entries.map((entry) {
                                int index = entry.key;
                                String option = entry.value;
                                bool isSelected = _alarmType == index;
                                
                                return ChoiceChip(
                                  label: Text(option),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _alarmType = index;
                                      });
                                    }
                                  },
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                    // End Time Section (Optional)
                    if (!_hasEndTime)
                      // "+ Add End Time" button
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _hasEndTime = true;
                              _setDefaultEndTime();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add End Time',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      // End Time Fields
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with remove button
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'End',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _hasEndTime = false;
                                        end_timestamp = null;
                                        _endDateController.clear();
                                        _endTimeController.clear();
                                      });
                                    },
                                    tooltip: 'Remove end time',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            // Date and Time row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: Row(
                                children: [
                                  // End Date
                                  Expanded(
                                    flex: 3,
                                    child: InkWell(
                                      onTap: () async {
                                        final initialDate = _endDateController.text.isNotEmpty && 
                                                           _endDateController.text != 'Unspecified'
                                            ? DateTime.parse(_endDateController.text)
                                            : DateTime.parse(todayDate);
                                        
                                        DateTime? pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: initialDate,
                                          firstDate: DateTime.parse(todayDate),
                                          lastDate: DateTime(2101),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            _endDateController.text = pickedDate.toIso8601String().split('T')[0];
                                            _updateEndTimestamp();
                                          });
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 18,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _endDateController.text.isNotEmpty
                                                    ? DateFormat('EEE, MMM d, yyyy').format(DateTime.parse(_endDateController.text))
                                                    : 'Select date',
                                                style: TextStyle(
                                                  color: _endDateController.text.isNotEmpty
                                                      ? Theme.of(context).colorScheme.onSurface
                                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // End Time (only if not All Day)
                                  if (_timeController.text != 'All Day')
                                    Expanded(
                                      flex: 2,
                                      child: InkWell(
                                        onTap: () async {
                                          TimeOfDay initialTime = TimeOfDay.now();
                                          if (_endTimeController.text.isNotEmpty && _endTimeController.text != 'All Day') {
                                            final parts = _endTimeController.text.split(':');
                                            if (parts.length == 2) {
                                              initialTime = TimeOfDay(
                                                hour: int.parse(parts[0]),
                                                minute: int.parse(parts[1]),
                                              );
                                            }
                                          }
                                          
                                          TimeOfDay? pickedTime = await showTimePicker(
                                            context: context,
                                            initialTime: initialTime,
                                            builder: (BuildContext context, Widget? child) {
                                              return MediaQuery(
                                                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                                child: child!,
                                              );
                                            },
                                          );
                                          
                                          if (pickedTime != null) {
                                            setState(() {
                                              _endTimeController.text = 
                                                '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                                              
                                              // Auto-adjust date if end time < start time on same day
                                              if (_endDateController.text == todayDate) {
                                                final startParts = _timeController.text.split(':');
                                                if (startParts.length == 2) {
                                                  final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                                                  final endMinutes = pickedTime.hour * 60 + pickedTime.minute;
                                                  if (endMinutes <= startMinutes) {
                                                    // Move to next day
                                                    final nextDay = DateTime.parse(todayDate).add(const Duration(days: 1));
                                                    _endDateController.text = nextDay.toIso8601String().split('T')[0];
                                                  }
                                                }
                                              }
                                              
                                              _updateEndTimestamp();
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 18,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _endTimeController.text.isNotEmpty
                                                    ? _endTimeController.text
                                                    : 'Time',
                                                style: TextStyle(
                                                  color: _endTimeController.text.isNotEmpty
                                                      ? Theme.of(context).colorScheme.onSurface
                                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Initiation Date Field
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _initiationdateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Initiation Date',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onTap: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2101),
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    todayDate = pickedDate.toIso8601String().split('T')[0];
                                    _initiationdateController.text = todayDate; // Update the controller
                                    _setScheduledDate(); // Update the scheduled date
                                  });
                                }
                              },
                              validator: (value) {
                                if (todayDate.isEmpty && _initiationdateController.text != 'Unspecified') {
                                  return 'Please select a date';
                                }
                                return null;
                              },
                            ),
                          ),
                          // "Unspecified" toggle button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (_initiationdateController.text == 'Unspecified') {
                                    // If already "Unspecified", set to today's date
                                    final now = DateTime.now();
                                    todayDate = now.toIso8601String().split('T')[0];
                                    _initiationdateController.text = todayDate;
                                    _recurrenceFrequency =  'Default'; // Reset recurrence frequency
                                  } else {
                                    // Set to "Unspecified"
                                    _initiationdateController.text = 'Unspecified';
                                    todayDate = 'Unspecified'; // Clear the actual date
                                    _recurrenceFrequency= 'No Repetition'; // Reset recurrence frequency
                                  }
                                  _setScheduledDate(); // Update the scheduled date
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _initiationdateController.text == 'Unspecified'
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('Unspecified'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Recurrence Frequency options
                    if(todayDate != 'Unspecified')
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: RecurrenceDropdown(
                                    recurrenceFrequency: _recurrenceFrequency,
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _recurrenceFrequency = newValue;

                                          // If custom is selected, show custom options
                                          if (newValue == 'Custom') {
                                            _showCustomFrequencySelector();
                                          } else {
                                            // Clear custom parameters if not using custom
                                            _customFrequencyParams = {};
                                          }

                                          // Update scheduled date based on frequency
                                          _setScheduledDate();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                // "No Repetition" toggle button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        if (_recurrenceFrequency == 'No Repetition') {
                                          // If already "No Repetition", set back to default
                                          _recurrenceFrequency = 'Default';
                                        } else {
                                          // Set to "No Repetition"
                                          _recurrenceFrequency = 'No Repetition';
                                        }
                                        _setScheduledDate();
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _recurrenceFrequency == 'No Repetition'
                                                ? Icons.check_box
                                                : Icons.check_box_outline_blank,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          const Text('No Repetition'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Custom frequency description (if selected)
                            if (_recurrenceFrequency == 'Custom' && _customFrequencyParams.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _getCustomFrequencyDescription(),
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // First Reminder Date Field (conditionally shown)
                    if (_recurrenceFrequency != 'No Repetition')
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: TextFormField(
                          controller: _scheduleddateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Select First Reminder Date',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onTap: () async {
                            // Create recurrence data map with all parameters
                            Map<String, dynamic> recurrenceData = {
                              'frequency': _recurrenceFrequency,
                            };

                            // Add custom parameters if present
                            if (_recurrenceFrequency == 'Custom') {
                              recurrenceData['custom_params'] = _customFrequencyParams;
                            }

                            // Use unified method for all frequency types
                            DateTime initialDate = await DateNextRecurrence.calculateNextRecurrenceDate(
                              DateTime.parse(todayDate),
                              _recurrenceFrequency,
                              0,
                            );

                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                dateScheduled = pickedDate.toIso8601String().split('T')[0];
                                _scheduleddateController.text = dateScheduled;
                              });
                            }
                          },
                        ),
                      ),

                    if(_recurrenceFrequency != 'No Repetition')
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Forever Chip
                                ChoiceChip(
                                  label: const Text('Forever'),
                                  selected: _duration == 'Forever',
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _duration = 'Forever';
                                        _durationData = {
                                          "type": "forever",
                                          "numberOfTimes": null,
                                          "endDate": null
                                        };
                                      });
                                    }
                                  },
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _duration == 'Forever'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                    fontWeight: _duration == 'Forever' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: _duration == 'Forever'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                                  ),
                                ),
                                // Specific Number of Times Chip
                                ChoiceChip(
                                  label: Text(
                                    _duration == 'Specific Number of Times' && _durationData["numberOfTimes"] != null
                                        ? '${_durationData["numberOfTimes"]} times'
                                        : 'Specific Times',
                                  ),
                                  selected: _duration == 'Specific Number of Times',
                                  onSelected: (selected) {
                                    if (selected) {
                                      // Show dialog to enter number of times
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          final controller = TextEditingController(
                                              text: _durationData["numberOfTimes"]?.toString() ?? ''
                                          );

                                          return AlertDialog(
                                            title: const Text('Enter Number of Times'),
                                            content: TextFormField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Number of Times',
                                                hintText: 'Enter a value >= 1',
                                              ),
                                              inputFormatters: [
                                                FilteringTextInputFormatter.digitsOnly,
                                              ],
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter a value';
                                                }
                                                final number = int.tryParse(value);
                                                if (number == null || number < 1) {
                                                  return 'Value must be at least 1';
                                                }
                                                return null;
                                              },
                                              autovalidateMode: AutovalidateMode.onUserInteraction,
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                child: const Text(
                                                  'CANCEL',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              TextButton(
                                                child: const Text('OK'),
                                                onPressed: () {
                                                  int? parsedValue = int.tryParse(controller.text);
                                                  if (parsedValue != null && parsedValue >= 1) {
                                                    setState(() {
                                                      _duration = 'Specific Number of Times';
                                                      _durationData = {
                                                        "type": "specificTimes",
                                                        "numberOfTimes": parsedValue,
                                                        "endDate": null
                                                      };
                                                    });
                                                    Navigator.of(context).pop();
                                                  } else {
                                                    // Show error feedback
                                                    customSnackBar_error(
                                                      context: context,
                                                      message: 'Please enter a valid number (minimum 1)',
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    }
                                  },
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _duration == 'Specific Number of Times'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                    fontWeight: _duration == 'Specific Number of Times' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: _duration == 'Specific Number of Times'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                                  ),
                                ),
                                // Until Chip
                                ChoiceChip(
                                  label: Text(
                                    _duration == 'Until' && _durationData["endDate"] != null
                                        ? 'Until ${_durationData["endDate"]}'
                                        : 'Until',
                                  ),
                                  selected: _duration == 'Until',
                                  onSelected: (selected) {
                                    if (selected) {
                                      // Show date picker to select end date
                                      showDatePicker(
                                        context: context,
                                        initialDate: _durationData["endDate"] != null
                                            ? DateTime.parse(_durationData["endDate"])
                                            : DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime(2101),
                                      ).then((pickedDate) {
                                        if (pickedDate != null) {
                                          setState(() {
                                            _duration = 'Until';
                                            _durationData = {
                                              "type": "until",
                                              "numberOfTimes": null,
                                              "endDate": pickedDate.toIso8601String().split('T')[0]
                                            };
                                          });
                                        }
                                      });
                                    }
                                  },
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _duration == 'Until'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                    fontWeight: _duration == 'Until' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: _duration == 'Until'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),


                    // Description Field
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: 3,
                        onSaved: (value) {
                          _description = value!;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
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
                              'CANCEL',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                try {
                                  _formKey.currentState!.save();
                                  await UpdateRecords(context);
                                  Navigator.of(context).pop(); // Navigate after showing SnackBar
                                } catch (e) {
                                  customSnackBar_error(
                                    context: context,
                                    message: 'Failed to save record: $e',
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'SAVE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

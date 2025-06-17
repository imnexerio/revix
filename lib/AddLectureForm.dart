import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:revix/Utils/date_utils.dart';
import 'package:revix/widgets/LectureTypeDropdown.dart';
import 'package:revix/widgets/RevisionFrequencyDropdown.dart';
import 'CustomFrequencySelector.dart';
import 'Utils/CalculateCustomNextDate.dart';
import 'Utils/UnifiedDatabaseService.dart';
import 'Utils/customSnackBar_error.dart';

class AddLectureForm extends StatefulWidget {
  @override
  _AddLectureFormState createState() => _AddLectureFormState();
}

class _AddLectureFormState extends State<AddLectureForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _initiationdateController = TextEditingController();
  final TextEditingController _scheduleddateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'DEFAULT_VALUE';
  String _selectedCategoryCode = '';
  String _lectureType = 'Lectures';
  String _lectureNo = '';
  String _description = '';
  String _revisionFrequency = 'Default';  String _duration = 'Forever';
  List<String> _subjects = [];
  Map<String, List<String>> _subCategories = {};
  String dateScheduled = '';
  String todayDate = '';
  Map<String, dynamic> _durationData = {
    "type": "forever",
    "numberOfTimes": null,
    "endDate": null
  };
  String start_timestamp = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
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
  }
  Future<void> _loadCategoriesAndSubCategories() async {
    try {
      // Get the singleton instance and use the new loadCategoriesAndSubCategories method
      final provider = categoryDataProvider();
      final data = await provider.loadCategoriesAndSubCategories();

      // Update state with the retrieved data
      setState(() {
        _subjects = data['subjects'];
        _subCategories = data['subCategories'];

        // Set appropriate selection
        if (_subjects.isNotEmpty) {
          _selectedCategory = _subjects[0];
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
      final unifiedService = UnifiedDatabaseService();
      
      // Set alarm type to 0 if "All Day" is selected
      int finalAlarmType = _timeController.text == 'All Day' ? 0 : _alarmType;
      
      await unifiedService.updateRecords(
        context,
        _selectedCategory,
        _selectedCategoryCode,
        _lectureNo,
        start_timestamp,
        _timeController.text,
        _lectureType,
        todayDate,
        dateScheduled,
        _description,
        _revisionFrequency,
        _durationData,
        _customFrequencyParams,
        finalAlarmType,
      );
    } catch (e) {
      throw Exception('Failed to save lecture: $e');
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
      if (_revisionFrequency == 'No Repetition') {
        setState(() {
          dateScheduled = todayDate;
          _scheduleddateController.text = dateScheduled;
        });
        return;
      }

      // For custom frequency, add the custom parameters
      if (_revisionFrequency == 'Custom' && _customFrequencyParams.isNotEmpty) {
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
      DateTime initialDate = await DateNextRevision.calculateNextRevisionDate(
        DateTime.parse(todayDate),
        _revisionFrequency,
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
        _revisionFrequency = 'Default';
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
                        value: _selectedCategory == 'DEFAULT_VALUE' && _subjects.isNotEmpty ? _subjects[0] :
                        (_subjects.contains(_selectedCategory) ? _selectedCategory : null),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        isExpanded: true,
                        items: [
                          ..._subjects.map((category) => DropdownMenuItem(
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
                            } else {
                              _selectedCategory = newValue!;
                              _selectedCategoryCode = '';
                              _showAddNewCategory = false;
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

                    // Lecture Type Dropdown
                    LectureTypeDropdown(
                      lectureType: _lectureType,
                      onChanged: (String? newValue) {
                        setState(() {
                          _lectureType = newValue!;
                        });
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
                          _lectureNo = value!;
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
                    ),
                    // Alarm Type Field (only shown when not "All Day")
                    if (_timeController.text != 'All Day')
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
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alarm,
                                    size: 20,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Alarm Type',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _alarmOptions.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  String option = entry.value;
                                  return FilterChip(
                                    label: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _alarmType == index ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    selected: _alarmType == index,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _alarmType = index;
                                        });
                                      }
                                    },
                                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    checkmarkColor: Theme.of(context).primaryColor,
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                    side: BorderSide(
                                      color: _alarmType == index 
                                        ? Theme.of(context).primaryColor 
                                        : Theme.of(context).dividerColor,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
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
                                    _revisionFrequency =  'Default'; // Reset revision frequency
                                  } else {
                                    // Set to "Unspecified"
                                    _initiationdateController.text = 'Unspecified';
                                    todayDate = 'Unspecified'; // Clear the actual date
                                    _revisionFrequency= 'No Repetition'; // Reset revision frequency
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

                    // Revision Frequency options
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
                                  child: RevisionFrequencyDropdown(
                                    revisionFrequency: _revisionFrequency,
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _revisionFrequency = newValue;

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
                                        if (_revisionFrequency == 'No Repetition') {
                                          // If already "No Repetition", set back to default
                                          _revisionFrequency = 'Default';
                                        } else {
                                          // Set to "No Repetition"
                                          _revisionFrequency = 'No Repetition';
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
                                            _revisionFrequency == 'No Repetition'
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
                            if (_revisionFrequency == 'Custom' && _customFrequencyParams.isNotEmpty)
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
                    if (_revisionFrequency != 'No Repetition')
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
                            // Create revision data map with all parameters
                            Map<String, dynamic> revisionData = {
                              'frequency': _revisionFrequency,
                            };

                            // Add custom parameters if present
                            if (_revisionFrequency == 'Custom') {
                              revisionData['custom_params'] = _customFrequencyParams;
                            }

                            // Use unified method for all frequency types
                            DateTime initialDate = await DateNextRevision.calculateNextRevisionDate(
                              DateTime.parse(todayDate),
                              _revisionFrequency,
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

                    if(_revisionFrequency != 'No Repetition')
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
                                  child: DropdownButtonFormField<String>(
                                    value: _duration,
                                    decoration: const InputDecoration(
                                      labelText: 'Duration',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem<String>(
                                        value: 'Forever',
                                        child: Text('Forever'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'Specific Number of Times',
                                        child: Text('Specific Number of Times'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'Until',
                                        child: Text('Until'),
                                      ),
                                    ],
                                    onChanged: (String? newValue) {
                                      if(newValue != null) {
                                        setState(() {
                                          _duration = newValue;
                                          if (_duration == 'Forever') {
                                            _durationData = {
                                              "type": "forever",
                                              "numberOfTimes": null,
                                              "endDate": null
                                            };
                                          }
                                          else if (_duration == 'Specific Number of Times') {
                                            // Show a dialog or bottom sheet to enter the number of times
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
                                                        'SAVE',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _duration = 'Forever';
                                                          _durationData = {
                                                            "type": "forever",
                                                            "numberOfTimes": null,
                                                            "endDate": null
                                                          };
                                                        });
                                                        Navigator.of(context).pop();
                                                      },
                                                    ),
                                                    TextButton(
                                                      child: const Text('OK'),
                                                      onPressed: () {
                                                        int? parsedValue = int.tryParse(controller.text);
                                                        if (parsedValue != null && parsedValue >= 1) {
                                                          setState(() {
                                                            _durationData = {
                                                              "type": "specificTimes",
                                                              "numberOfTimes": parsedValue,
                                                              "endDate": null
                                                            };
                                                          });
                                                          Navigator.of(context).pop();
                                                        } else {
                                                          // Show error feedback
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Please enter a valid number (minimum 1)'),
                                                              duration: Duration(seconds: 2),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            ).then((value) {
                                              if (_durationData["type"] != "specificTimes") {
                                                setState(() {
                                                  _duration = 'Forever';
                                                  _durationData = {
                                                    "type": "forever",
                                                    "numberOfTimes": null,
                                                    "endDate": null
                                                  };
                                                });
                                              }
                                            });
                                          }
                                          else if (_duration == 'Until') {
                                            // Show a date picker to select the end date
                                            showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime(2101),
                                            ).then((pickedDate) {
                                              if (pickedDate != null) {
                                                setState(() {
                                                  _durationData = {
                                                    "type": "until",
                                                    "numberOfTimes": null,
                                                    "endDate": pickedDate.toIso8601String().split('T')[0]
                                                  };
                                                });
                                              }else{
                                                setState(() {
                                                  _duration= 'Forever';
                                                  _durationData = {
                                                    "type": "forever",
                                                    "numberOfTimes": null,
                                                    "endDate": null
                                                  };
                                                });
                                              }
                                            });
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            // Custom frequency description (if selected)
                            if (_revisionFrequency == 'Custom' && _customFrequencyParams.isNotEmpty)
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
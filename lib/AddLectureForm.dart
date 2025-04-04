import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:retracker/Utils/date_utils.dart';
import 'package:retracker/widgets/LectureTypeDropdown.dart';
import 'package:retracker/widgets/RevisionFrequencyDropdown.dart';
import 'CustomFrequencySelector.dart';
import 'RecordForm/CalculateCustomNextDate.dart';
import 'Utils/CustomSnackBar.dart';
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
  String _selectedSubject = 'DEFAULT_VALUE';
  String _selectedSubjectCode = '';
  String _lectureType = 'Lectures';
  String _lectureNo = '';
  String _description = '';
  String _revisionFrequency = 'Default';
  // Removed onlyOnce boolean flag
  List<String> _subjects = [];
  Map<String, List<String>> _subjectCodes = {};
  String dateScheduled = '';
  String todayDate = '';
  int no_revision = 0;

  // Custom frequency parameters
  Map<String, dynamic> _customFrequencyParams = {};

  bool _showAddNewSubject = false;
  bool _showAddNewSubjectCode_ = false;

  @override
  void initState() {
    super.initState();
    _loadSubjectsAndCodes();
    _setInitialDate();
    _setScheduledDate();
    _timeController.text = 'All Day';
  }

  Future<void> _loadSubjectsAndCodes() async {
    try {
      // Get the singleton instance
      final provider = SubjectDataProvider();

      // First check if cached data is available
      Map<String, dynamic>? data = provider.currentData;

      if (data == null) {
        // If no cached data, fetch from database
        data = await provider.fetchSubjectsAndCodes();
      }

      // Update state with the retrieved data
      setState(() {
        _subjects = data!['subjects'];
        _subjectCodes = data['subjectCodes'];

        // Set appropriate selection
        if (_subjects.isNotEmpty) {
          _selectedSubject = _subjects[0];
        } else {
          _selectedSubject = 'DEFAULT_VALUE';
        }
      });

      // No need to set up a listener here since this is part of a form
      // that's not constantly visible in the UI

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        customSnackBar_error(
          context: context,
          message: 'Error loading subjects and codes: $e',
        ),
      );
    }
  }

  Future<void> UpdateRecords(BuildContext context) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }
      String uid = user.uid;

      DatabaseReference ref = FirebaseDatabase.instance
          .ref('users/$uid/user_data')
          .child(_selectedSubject)
          .child(_selectedSubjectCode)
          .child(_lectureNo);

      String initiated_on = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
      if (todayDate == 'Unspecified') {
        no_revision = -1;
        _revisionFrequency = 'Unspecified';
        dateScheduled = 'Unspecified';
      }else{
      if (DateTime.parse(initiated_on).isBefore(DateTime.parse(todayDate))) {
        no_revision = -1;
      }}

      // Create a map to store all revision parameters including custom ones
      Map<String, dynamic> revisionData = {
        'frequency': _revisionFrequency,
      };

      // Add custom frequency parameters if present
      if (_customFrequencyParams.isNotEmpty) {
        revisionData['custom_params'] = _customFrequencyParams;
      }

      await ref.set({
        'initiated_on': initiated_on,
        'reminder_time': _timeController.text,
        'lecture_type': _lectureType,
        'date_learnt': todayDate,
        'date_revised': initiated_on,
        'date_scheduled': dateScheduled,
        'description': _description,
        'missed_revision': 0,
        'no_revision': no_revision,
        'revision_frequency': _revisionFrequency,
        'revision_data': revisionData,  // Store all revision-related data here
        'status': 'Enabled',
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        customSnackBar(
          context: context,
          message: 'Record added successfully',
        ),
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
    print('todaydate: $todayDate');
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return CustomFrequencySelector(
          initialParams: _customFrequencyParams,
        );
      },
    );

    if (result != null) {
      setState(() {
        _customFrequencyParams = result;
        _setScheduledDate(); // Update scheduled date based on new frequency
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
                          value: _selectedSubject == 'DEFAULT_VALUE' && _subjects.isNotEmpty ? _subjects[0] :
                              (_subjects.contains(_selectedSubject) ? _selectedSubject : null),
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          isExpanded: true,
                          items: [
                            ..._subjects.map((subject) => DropdownMenuItem(
                              value: subject,
                              child: Text(subject),
                            )).toList(),
                            const DropdownMenuItem(
                              value: "Add New Category",
                              child: Text("Add New Category"),
                            ),
                          ],
                          onChanged: (newValue) {
                            setState(() {
                              if (newValue == "Add New Category") {
                                _showAddNewSubject = true;
                              } else {
                                _selectedSubject = newValue!;
                                _selectedSubjectCode = '';
                                _showAddNewSubject = false;
                              }
                            });
                          },
                        ),
                      ),

                      // New Category input field (conditionally shown)
                      if (_showAddNewSubject)
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
                                    _selectedSubject = value!;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                      // New Sub Category input field (when adding new Category)
                      if (_showAddNewSubject)
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
                                    _selectedSubjectCode = value!;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Sub Category dropdown (when category is selected)
                      if (_selectedSubject != 'DEFAULT_VALUE' && !_showAddNewSubject)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).cardColor,
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _subjectCodes[_selectedSubject]?.contains(_selectedSubjectCode) ?? false
                                ? _selectedSubjectCode : null,
                            decoration: const InputDecoration(
                              labelText: 'Sub Category',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            isExpanded: true,
                            items: [
                              ...(_subjectCodes[_selectedSubject] ?? []).map((code) => DropdownMenuItem(
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
                                  _showAddNewSubjectCode_ = true;
                                } else {
                                  _selectedSubjectCode = newValue!;
                                }
                              });
                            },
                          ),
                        ),

                      // New Sub Category input field (when adding to existing category)
                      if (_showAddNewSubjectCode_)
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
                                    _selectedSubjectCode = value!;
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
                                    } else {
                                      // Set to "Unspecified"
                                      _initiationdateController.text = 'Unspecified';
                                      todayDate = 'Unspecified'; // Clear the actual date
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

                      // Description Field
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: TextFormField(
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
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    _formKey.currentState!.save();
                                    await UpdateRecords(context);
                                    Navigator.of(context).pop(); // Navigate after showing SnackBar
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      customSnackBar_error(
                                        context: context,
                                        message: 'Failed to save record: $e',
                                      ),
                                    );
                                  }
                                }
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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:retracker/Utils/date_utils.dart';
import 'package:retracker/widgets/LectureTypeDropdown.dart';
import 'package:retracker/widgets/RevisionFrequencyDropdown.dart';
import 'Utils/CustomSnackBar.dart';
import 'Utils/customSnackBar_error.dart';
import 'Utils/subject_utils_static.dart';

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
  bool isEnabled = true;
  bool onlyOnce = false;
  List<String> _subjects = [];
  Map<String, List<String>> _subjectCodes = {};
  String dateScheduled = '';
  String todayDate = '';

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
      final last_revised = await fetchSubjectsAndCodesStatic();
      setState(() {
        _subjects = last_revised['subjects'];
        _subjectCodes = last_revised['subjectCodes'];

        // Set default selection if available
        if (_subjects.isNotEmpty) {
          _selectedSubject = _subjects[0];
        } else {
          _selectedSubject = 'DEFAULT_VALUE'; // Keep the default value
        }
      });
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

      await ref.set({
        'initiated_on': initiated_on,
        'reminder_time': _timeController.text,
        'lecture_type': _lectureType,
        'date_learnt': todayDate,
        'date_revised': initiated_on,
        'date_scheduled': dateScheduled,
        'description': _description,
        'missed_revision': 0,
        'no_revision': 0,
        'revision_frequency': _revisionFrequency,
        'only_once': onlyOnce? 1 : 0,
        'status': isEnabled ? 'Enabled' : 'Disabled',
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
    DateTime initialDate = await DateNextRevision.calculateNextRevisionDate(
      DateTime.parse(todayDate), // Convert todayDate to DateTime
      _revisionFrequency,
      0,
    );
    setState(() {
      dateScheduled = initialDate.toIso8601String().split('T')[0];
      _scheduleddateController.text = dateScheduled;
    });
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
                              // controller: _newSubjectCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Add New Sub Category',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSaved: (value) {
                                _selectedSubjectCode = value!;
                              },
                              // onFieldSubmitted: (_) => _addNewSubjectCode(),
                            ),
                          ),
                        ],
                      ),
                    ),

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

                    // Rest of the form remains the same
                    LectureTypeDropdown(
                      lectureType: _lectureType,
                      onChanged: (String? newValue) {
                        setState(() {
                          _lectureType = newValue!;
                        });
                      },
                    ),
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
                          // Add "All Day" option as a toggle button
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

                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
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
                          if (todayDate.isEmpty) {
                            return 'Please select a date';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (!onlyOnce)
                      RevisionFrequencyDropdown(
                        revisionFrequency: _revisionFrequency,
                        onChanged: (String? newValue) {
                          setState(() {
                            _revisionFrequency = newValue!;
                          });
                          _setScheduledDate();
                        },
                      ),
                    if (!onlyOnce)
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
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: await DateNextRevision.calculateNextRevisionDate(
                              DateTime.parse(todayDate), // Convert todayDate to DateTime
                              _revisionFrequency,
                              0,
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              dateScheduled = pickedDate.toIso8601String().split('T')[0];
                              _initiationdateController.text = dateScheduled;
                            });
                          }
                        },
                        validator: (value) {
                          return null;
                        },
                      ),
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status', style: Theme.of(context).textTheme.titleMedium),
                        Switch(
                          value: isEnabled,
                          onChanged: (bool newValue) {
                            setState(() {
                              isEnabled = newValue;
                            });
                          },
                        ),
                        Text('No Repetition', style: Theme.of(context).textTheme.titleMedium),
                        Switch(
                          value: onlyOnce,
                          onChanged: (bool newValue) {
                            setState(() {
                              onlyOnce = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                try {
                                  _formKey.currentState!.save();
                                  await UpdateRecords(context); // Pass context to UpdateRecords
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
          ),
        ],
      ),
    );
  }
}
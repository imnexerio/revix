import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:retracker/Utils/date_utils.dart';
import 'package:retracker/widgets/LectureTypeDropdown.dart';
import 'package:retracker/widgets/RevisionFrequencyDropdown.dart';
import 'Utils/CustomSnackBar.dart';
import 'Utils/customSnackBar_error.dart';

class AddLectureForm extends StatefulWidget {
  @override
  _AddLectureFormState createState() => _AddLectureFormState();
}

class _AddLectureFormState extends State<AddLectureForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _initiationdateController = TextEditingController();
  final TextEditingController _scheduleddateController = TextEditingController();
  String _selectedSubject = 'DEFAULT_VALUE'; // Start with a non-empty default to prevent showing Add New Subject at start
  String _selectedSubjectCode = '';
  String _lectureType = 'Lectures';
  String _lectureNo = '';
  String _description = '';
  String _revisionFrequency = 'Default';
  bool isEnabled = true;
  List<String> _subjects = [];
  Map<String, List<String>> _subjectCodes = {};
  String dateScheduled = '';
  String todayDate = '';

  bool _showAddNewSubject = false;
  bool _showAddNewSubjectCode = false;
  bool _showAddNewSubjectCode_ = false;

  @override
  void initState() {
    super.initState();
    _loadSubjectsAndCodes();
    _setInitialDate();
    _setScheduledDate();
  }


  Future<void> _loadSubjectsAndCodes() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    String uid = user.uid;
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists) {
        Map<Object?, Object?> data = snapshot.value as Map<Object?, Object?>;
        setState(() {
          _subjects = data.keys.map((key) => key.toString()).toList();
          _subjectCodes = {};

          data.forEach((subject, value) {
            if (value is Map) {
              _subjectCodes[subject.toString()] =
                  value.keys.map((code) => code.toString()).toList();
            }
          });

          // Set default selection if available
          if (_subjects.isNotEmpty) {
            _selectedSubject = _subjects[0];
          } else {
            _selectedSubject = 'DEFAULT_VALUE'; // Keep the default value
          }
        });
      }
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

      await ref.set({
        'lecture_type': _lectureType,
        'date_learnt': todayDate,
        'date_revised': todayDate,
        'date_scheduled': dateScheduled,
        'description': _description,
        'missed_revision': 0,
        'no_revision': 0,
        'revision_frequency': _revisionFrequency,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
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
                padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Subject dropdown with "Others" option
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubject == 'DEFAULT_VALUE' && _subjects.isNotEmpty ? _subjects[0] :
                        (_subjects.contains(_selectedSubject) ? _selectedSubject : null),
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        isExpanded: true,
                        items: [
                          ..._subjects.map((subject) => DropdownMenuItem(
                            value: subject,
                            child: Text(subject),
                          )).toList(),
                          DropdownMenuItem(
                            value: "Others",
                            child: Text("Others"),
                          ),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            if (newValue == "Others") {
                              _showAddNewSubject = true;
                              _showAddNewSubjectCode = true;
                            } else {
                              _selectedSubject = newValue!;
                              _selectedSubjectCode = '';
                              _showAddNewSubject = false;
                            }
                          });
                        },
                      ),
                    ),

                    // Add New Subject field (only shown when "Others" is selected)
                    if (_showAddNewSubject)
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Add New Subject',
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
                      margin: EdgeInsets.symmetric(vertical: 8),
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
                              decoration: InputDecoration(
                                labelText: 'Add New Subject Code',
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

                    // Subject Code dropdown with "Others" option
                    if (_selectedSubject != 'DEFAULT_VALUE' && !_showAddNewSubject)
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _subjectCodes[_selectedSubject]?.contains(_selectedSubjectCode) ?? false
                              ? _selectedSubjectCode : null,
                          decoration: InputDecoration(
                            labelText: 'Subject Code',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          isExpanded: true,
                          items: [
                            ...(_subjectCodes[_selectedSubject] ?? []).map((code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            )).toList(),
                            DropdownMenuItem(
                              value: "Others",
                              child: Text("Others"),
                            ),
                          ],
                          onChanged: (newValue) {
                            setState(() {
                              if (newValue == "Others") {
                                _showAddNewSubjectCode_ = true;
                              } else {
                                _selectedSubjectCode = newValue!;
                                _showAddNewSubjectCode = false;
                              }
                            });
                          },
                        ),
                      ),

                    // Add New Subject Code field (only shown when "Others" is selected in Subject Code)
                    if (_showAddNewSubjectCode_)
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Add New Subject Code',
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
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: TextFormField(
                        decoration: InputDecoration(
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
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: TextFormField(
                        controller: _initiationdateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Select Initial Date',
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
                    RevisionFrequencyDropdown(
                      revisionFrequency: _revisionFrequency,
                      onChanged: (String? newValue) {
                        setState(() {
                          _revisionFrequency = newValue!;
                        });
                        _setScheduledDate();
                      },
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: TextFormField(
                        controller: _scheduleddateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Select Reminder Date',
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
                          if (dateScheduled == null) {
                            return 'Date Scheduled';
                          }
                          return null;
                        },
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: TextFormField(
                        decoration: InputDecoration(
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
                      ],
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
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
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
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
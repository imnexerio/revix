import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:retracker/Utils/date_utils.dart';
import 'package:retracker/widgets/LectureTypeDropdown.dart';
import 'package:retracker/widgets/RevisionFrequencyDropdown.dart';
import 'package:retracker/widgets/SubjectCodeDropdown.dart';
import 'package:retracker/widgets/SubjectDropdown.dart';

import 'Utils/CustomSnackBar.dart';

class AddLectureForm extends StatefulWidget {
  @override
  _AddLectureFormState createState() => _AddLectureFormState();
}

class _AddLectureFormState extends State<AddLectureForm> {
  final _formKey = GlobalKey<FormState>();
  String _selectedSubject = '';
  String _selectedSubjectCode = '';
  String _lectureType = 'Lectures';
  String _lectureNo = '';
  String _description = '';
  String _revisionFrequency = 'Default';
  bool isEnabled = true;
  List<String> _subjects = [];
  Map<String, List<String>> _subjectCodes = {};

  @override
  void initState() {
    super.initState();
    _loadSubjectsAndCodes();
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
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        customSnackBar(
          context: context,
          message: 'Error loading subjects and codes: $e',
        ),
      );
    }
  }

  Future<void> _addNewSubject(String newSubject) async {
    try {
      setState(() {
        _subjects.add(newSubject);
        _subjectCodes[newSubject] = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        customSnackBar(
          context: context,
          message: 'Error adding new subject: $e',
        ),
      );
    }
  }

  Future<void> _addNewSubjectCode(String subject, String newCode) async {
    try {
      setState(() {
        _subjectCodes[subject]!.add(newCode);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        customSnackBar(
          context: context,
          message: 'Error adding new subject code: $e',
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

      String todayDate = DateTime.now().toIso8601String().split('T')[0];

      String dateScheduled = (await DateNextRevision.calculateNextRevisionDate(
        DateTime.now(),
        _revisionFrequency,
        0,
      )).toIso8601String().split('T')[0];

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
                    SubjectDropdown(
                      subjects: _subjects,
                      selectedSubject: _selectedSubject,
                      onChanged: (String? newValue) {
                        setState(() {
                          if (newValue == 'Others') {
                            _selectedSubject = '';
                          } else {
                            _selectedSubject = newValue!;
                            _selectedSubjectCode = '';
                          }
                        });
                      },
                    ),
                    if (_selectedSubject.isEmpty)
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Or Add New Subject',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onFieldSubmitted: (value) {
                            if (value.isNotEmpty && !_subjects.contains(value)) {
                              _addNewSubject(value);
                              setState(() {
                                _selectedSubject = value;
                                _selectedSubjectCode = '';
                              });
                            }
                          },
                        ),
                      ),
                    SubjectCodeDropdown(
                      subjectCodes: _subjectCodes,
                      selectedSubject: _selectedSubject,
                      selectedSubjectCode: _selectedSubjectCode,
                      onChanged: (String? newValue) {
                        setState(() {
                          if (newValue == 'Others') {
                            _selectedSubjectCode = '';
                          } else {
                            _selectedSubjectCode = newValue!;
                          }
                        });
                      },
                    ),
                    if (_selectedSubjectCode.isEmpty && _selectedSubject.isNotEmpty)
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Or Add New Subject Code',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSaved: (value) {
                            if (value != null && value.isNotEmpty && !_subjectCodes[_selectedSubject]!.contains(value)) {
                              _addNewSubjectCode(_selectedSubject, value);
                              setState(() {
                                _selectedSubjectCode = value;
                              });
                            }
                          },
                        ),
                      ),
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
                    RevisionFrequencyDropdown(
                      revisionFrequency: _revisionFrequency,
                      onChanged: (String? newValue) {
                        setState(() {
                          _revisionFrequency = newValue!;
                        });
                      },
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
                                    customSnackBar(
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
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref();
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
      // print('Error loading subjects and codes: $e');
    }
  }

  Future<void> _addNewSubject(String newSubject) async {
    try {
      setState(() {
        _subjects.add(newSubject);
        _subjectCodes[newSubject] = [];
      });
    } catch (e) {
      // print('Error adding new subject: $e');
    }
  }

  Future<void> _addNewSubjectCode(String subject, String newCode) async {
    try {
      setState(() {
        _subjectCodes[subject]!.add(newCode);
      });
    } catch (e) {
      // print('Error adding new subject code: $e');
    }
  }

  DateTime _calculateScheduledDate(String frequency) {
    DateTime today = DateTime.now();
    switch (frequency) {
      case 'Daily':
        return today.add(Duration(days: 1));
      case '2 Day':
        return today.add(Duration(days: 2));
      case '3 Day':
        return today.add(Duration(days: 3));
      case 'Weekly':
        return today.add(Duration(days: 7));
      case 'Default':
      default:
        return today.add(Duration(days: 1));
    }
  }


  Future<void> _saveToFirebase() async {
    try {
      String todayDate = DateTime.now().toIso8601String().split('T')[0];
      String dateScheduled = _calculateScheduledDate(_revisionFrequency)
          .toIso8601String()
          .split('T')[0];

      DatabaseReference ref = FirebaseDatabase.instance
          .ref()
          .child(_selectedSubject)
          .child(_selectedSubjectCode)
          // .child(_lectureType)
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
    } catch (e) {
      // print('Error saving to Firebase: $e');
      throw Exception('Failed to save lecture');
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
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Subject',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        value: _selectedSubject.isEmpty ? null : _selectedSubject,
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
                        items: [
                          ..._subjects.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          DropdownMenuItem<String>(
                            value: 'Others',
                            child: Text('Others'),
                          ),
                        ],
                        validator: (value) => value == null ? 'Please select a subject' : null,
                      ),
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
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Subject Code',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        value: _selectedSubjectCode.isEmpty ? null : _selectedSubjectCode,
                        onChanged: (String? newValue) {
                          setState(() {
                            if (newValue == 'Others') {
                              _selectedSubjectCode = '';
                            } else {
                              _selectedSubjectCode = newValue!;
                            }
                          });
                        },
                        items: _selectedSubject.isEmpty
                            ? []
                            : [
                          ..._subjectCodes[_selectedSubject]!.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          DropdownMenuItem<String>(
                            value: 'Others',
                            child: Text('Others'),
                          ),
                        ],
                        validator: (value) => value == null ? 'Please select a subject code' : null,
                      ),
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

                    // Container(
                    //   margin: EdgeInsets.symmetric(vertical: 8),
                    //   decoration: BoxDecoration(
                    //     borderRadius: BorderRadius.circular(12),
                    //     color: Theme.of(context).cardColor,
                    //     border: Border.all(color: Theme.of(context).dividerColor),
                    //   ),
                    //   child: TextFormField(
                    //     decoration: InputDecoration(
                    //       labelText: 'Description',
                    //       border: InputBorder.none,
                    //       contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    //     ),
                    //     maxLines: 3,
                    //     onSaved: (value) {
                    //       _description = value!;
                    //     },
                    //     validator: (value) {
                    //       if (value == null || value.isEmpty) {
                    //         return 'Please enter a description';
                    //       }
                    //       return null;
                    //     },
                    //   ),
                    // ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Type',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        value: _lectureType,
                        onChanged: (String? newValue) {
                          setState(() {
                            _lectureType = newValue!;
                          });
                        },
                        items: [
                          DropdownMenuItem<String>(
                            value: 'Lectures',
                            child: Text('Lectures'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Handouts',
                            child: Text('Handouts'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'NCERTs',
                            child: Text('NCERTs'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Others',
                            child: Text('Others'),
                          ),
                        ],
                        validator: (value) => value == null ? 'Please select a type' : null,
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
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Revision Frequency',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        value: _revisionFrequency,
                        onChanged: (String? newValue) {
                          setState(() {
                            _revisionFrequency = newValue!;
                          });
                        },
                        items: [
                          DropdownMenuItem<String>(
                            value: 'Daily',
                            child: Text('Daily'),
                          ),
                          DropdownMenuItem<String>(
                            value: '2 Day',
                            child: Text('2 Day'),
                          ),
                          DropdownMenuItem<String>(
                            value: '3 Day',
                            child: Text('3 Day'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Weekly',
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Default',
                            child: Text('Default'),
                          ),
                        ],
                        validator: (value) => value == null ? 'Please select a revision frequency' : null,
                      ),
                    ),
                    // Row(
                    //   margin: EdgeInsets.symmetric(vertical: 8),
                    //   decoration: BoxDecoration(
                    //     borderRadius: BorderRadius.circular(12),
                    //     color: Theme.of(context).cardColor,
                    //     border: Border.all(color: Theme.of(context).dividerColor),
                    //   ),
                    //   child:
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
                    // ),

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
                                  await _saveToFirebase();
                                  Navigator.of(context).pop();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to save lecture: $e'),
                                      backgroundColor: Colors.red,
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
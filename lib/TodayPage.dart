import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'UpdateRecords.dart';
import 'widgets/date_utils.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  // Add a future variable to store the current records fetch operation
  late Future<Map<String, List<Map<String, dynamic>>>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _getRecords();
  }

  // Add a refresh method
  Future<void> _refreshRecords() async {
    setState(() {
      _recordsFuture = _getRecords();
    });
  }

  void _showLectureDetails(BuildContext context, dynamic details) {
    if (details is! Map<String, dynamic>) {
      details = Map<String, dynamic>.from(details);
    }

    String revisionFrequency = details['revision_frequency'];
    int noRevision = details['no_revision'];
    bool isEnabled = details['status'] == 'Enabled';
    String lectureNo = details['lecture_no'];
    String selectedSubject = details['subject'];
    String selectedSubjectCode = details['subject_code'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$selectedSubject $selectedSubjectCode $lectureNo Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow("Type", details['lecture_type']),
                            _detailRow('Subject', selectedSubject),
                            _detailRow('Subject Code', selectedSubjectCode),
                            _detailRow('Lecture No', lectureNo),
                            _detailRow('Date Learned', details['date_learnt']),
                            _detailRow('Date Revised', details['date_revised']),
                            _detailRow('Scheduled Date', details['date_scheduled']),
                            _detailRow('Revision Frequency', revisionFrequency),
                            _detailRow('No. of Revisions', details['no_revision'].toString()),
                            _detailRow('Next Revision', details['date_scheduled']),
                            _detailRow('Missed Revisions', details['missed_revision'].toString()),
                            _detailRow('Description', details['description']),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.add),
                                    label: Text('Add Revision'),
                                    onPressed: () async {
                                      try {
                                        // Show loading indicator
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (BuildContext context) {
                                            return Center(
                                              child: CircularProgressIndicator(),
                                            );
                                          },
                                        );

                                        String dateRevised = DateTime.now().toIso8601String().split('T')[0];
                                        int missedRevision = (details['missed_revision'] as num).toInt();
                                        DateTime scheduledDate = DateTime.parse(details['date_scheduled'].toString());
                                        String dateScheduled = DateNextRevision.calculateNextRevisionDate(
                                          scheduledDate,
                                          revisionFrequency,
                                          noRevision + 1,
                                        ).toIso8601String().split('T')[0];

                                        if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised) < 0) {
                                          missedRevision += 1;
                                        }

                                        // Wait for the update to complete
                                        await UpdateRecords(
                                          selectedSubject,
                                          selectedSubjectCode,
                                          lectureNo,
                                          dateRevised,
                                          noRevision + 1,
                                          dateScheduled,
                                          missedRevision,
                                          revisionFrequency,
                                          isEnabled ? 'Enabled' : 'Disabled',
                                        );

                                        // Close loading indicator
                                        Navigator.pop(context);
                                        // Close bottom sheet
                                        Navigator.pop(context);

                                        // Refresh the records
                                        await _refreshRecords();

                                        // Show success message
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text('Revision added successfully'),
                                              ],
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        // Close loading indicator if it's showing
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }

                                        // Show error message
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(Icons.error_outline, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text('Failed to add revision: ${e.toString()}'),
                                              ],
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 3),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getRecords() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    String uid = user.uid;
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
      DataSnapshot snapshot = await ref.get();

      if (!snapshot.exists) {
        return {'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []};
      }

      Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;
      List<Map<String, dynamic>> todayRecords = [];
      List<Map<String, dynamic>> missedRecords = [];
      List<Map<String, dynamic>> nextDayRecords = [];
      List<Map<String, dynamic>> next7DaysRecords = [];
      List<Map<String, dynamic>> todayAddedRecords = [];
      DateTime today = DateTime.now();
      DateTime nextDay = today.add(Duration(days: 1));
      DateTime next7Days = today.add(Duration(days: 7));
      String todayStr = today.toIso8601String().split('T')[0];
      String nextDayStr = nextDay.toIso8601String().split('T')[0];

      rawData.forEach((subjectKey, subjectValue) {
        if (subjectValue is Map) {
          (subjectValue).forEach((codeKey, codeValue) {
            if (codeValue is Map) {
              (codeValue).forEach((recordKey, recordValue) {
                if (recordValue is Map) {
                  var dateScheduled = recordValue['date_scheduled'];
                  var dateLearnt = recordValue['date_learnt'];
                  var status = recordValue['status'];

                  if (dateScheduled != null && status == 'Enabled') {
                    DateTime scheduledDate = DateTime.parse(dateScheduled.toString());
                    Map<String, dynamic> record = {
                      'subject': subjectKey.toString(),
                      'subject_code': codeKey.toString(),
                      'lecture_no': recordKey.toString(),
                      'date_scheduled': dateScheduled.toString(),
                      'lecture_type': recordValue['lecture_type'],
                      'date_learnt': recordValue['date_learnt'],
                      'date_revised': recordValue['date_revised'],
                      'description': recordValue['description'],
                      'missed_revision': recordValue['missed_revision'],
                      'no_revision': recordValue['no_revision'],
                      'revision_frequency': recordValue['revision_frequency'],
                      'status': recordValue['status'],

                    };

                    if (scheduledDate.toIso8601String().split('T')[0] == todayStr) {
                      todayRecords.add(record);
                    } else if (scheduledDate.isBefore(today)) {
                      missedRecords.add(record);
                    } else if (DateTime.parse(dateLearnt.toString()).toIso8601String().split('T')[0] == todayStr) {
                      todayAddedRecords.add(record);
                    } else if (scheduledDate.toIso8601String().split('T')[0] == nextDayStr) {
                      nextDayRecords.add(record);
                    } else if (scheduledDate.isAfter(today) && scheduledDate.isBefore(next7Days)) {
                      next7DaysRecords.add(record);
                    }
                  }

                }
              });
            }
          });
        }
      });

      return {
        'today': todayRecords,
        'missed': missedRecords,
        'nextDay': nextDayRecords,
        'next7Days': next7DaysRecords,
        'todayAdded': todayAddedRecords,
      };
    } catch (e) {
      throw Exception('Failed to fetch records');
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator( // Wrap with RefreshIndicator
        onRefresh: _refreshRecords,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                future: _recordsFuture, // Use the stored future
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
                  } else if (snapshot.hasError) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                        SizedBox(height: 16),
                        Text('Error: ${snapshot.error}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[400],
                          ),
                        ),
                      ],
                    ),
                    );
                  } else if (!snapshot.hasData || (snapshot.data!['today']!.isEmpty && snapshot.data!['missed']!.isEmpty && snapshot.data!['nextDay']!.isEmpty && snapshot.data!['next7Days']!.isEmpty && snapshot.data!['todayAdded']!.isEmpty)) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No scheduled found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    );
                  } else {
                    List<Map<String, dynamic>> todayRecords = snapshot.data!['today']!;
                    List<Map<String, dynamic>> missedRecords = snapshot.data!['missed']!;
                    List<Map<String, dynamic>> nextDayRecords = snapshot.data!['nextDay']!;
                    List<Map<String, dynamic>> next7DaysRecords = snapshot.data!['next7Days']!;
                    List<Map<String, dynamic>> todayAddedRecords = snapshot.data!['todayAdded']!;
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          if (missedRecords.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Missed Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        showCheckboxColumn: false,
                                        columns: [
                                          DataColumn(label: Text('Subject', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Subject Code', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Lecture No', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Date Scheduled', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          // DataColumn(label: Text('Actions', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                        ],
                                        rows: missedRecords.map((record) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(record['subject'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['subject_code'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['lecture_no'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['date_scheduled'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),

                                            ],
                                            onSelectChanged: (_) => _showLectureDetails(context, record),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (todayRecords.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Today\'s Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        showCheckboxColumn: false,
                                        columns: [
                                          DataColumn(label: Text('Subject', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Subject Code', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Lecture No', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Date Scheduled', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          // DataColumn(label: Text('Actions', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                        ],
                                        rows: todayRecords.map((record) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(record['subject'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['subject_code'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['lecture_no'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['date_scheduled'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),

                                            ],
                                            onSelectChanged: (_) => _showLectureDetails(context, record),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (todayAddedRecords.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Today\'s Added Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        showCheckboxColumn: false,
                                        columns: [
                                          DataColumn(label: Text('Subject', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Subject Code', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Lecture No', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Date Learnt', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          // DataColumn(label: Text('Actions', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                        ],
                                        rows: todayAddedRecords.map((record) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(record['subject'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['subject_code'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['lecture_no'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                              DataCell(Text(record['date_learnt'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),

                                            ],

                                            onSelectChanged: (_) => _showLectureDetails(context, record),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (nextDayRecords.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Next Day Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        showCheckboxColumn: false,
                                        columns: [
                                          DataColumn(label: Text('Subject', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Subject Code', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Lecture No', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Date Scheduled', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          // DataColumn(label: Text('Actions', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                        ],
                                        rows: nextDayRecords.map((record) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(record['subject'])),
                                              DataCell(Text(record['subject_code'])),
                                              DataCell(Text(record['lecture_no'])),
                                              DataCell(Text(record['date_scheduled'])),


                                            ],
                                            onSelectChanged: (_) => _showLectureDetails(context, record),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (next7DaysRecords.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Next 7 Days Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Theme.of(context).textTheme.titleLarge?.color)),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        showCheckboxColumn: false,
                                        columns: [
                                          DataColumn(label: Text('Subject', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Subject Code', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Lecture No', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          DataColumn(label: Text('Date Scheduled', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                          // DataColumn(label: Text('Actions', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                                        ],
                                        rows: next7DaysRecords.map((record) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(record['subject'])),
                                              DataCell(Text(record['subject_code'])),
                                              DataCell(Text(record['lecture_no'])),
                                              DataCell(Text(record['date_scheduled'])),

                                            ],
                                            onSelectChanged: (_) => _showLectureDetails(context, record),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
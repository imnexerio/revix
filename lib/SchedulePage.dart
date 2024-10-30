import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SchedulePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<SchedulePage> {
  Future<Map<String, List<Map<String, dynamic>>>> _getRecords() async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref();
      DataSnapshot snapshot = await ref.get();

      if (!snapshot.exists) {
        return {'today': [], 'missed': [], 'nextDay': [], 'next7Days': []};
      }

      Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;
      List<Map<String, dynamic>> todayRecords = [];
      List<Map<String, dynamic>> missedRecords = [];
      List<Map<String, dynamic>> nextDayRecords = [];
      List<Map<String, dynamic>> next7DaysRecords = [];
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
                  var status = recordValue['status'];

                  if (dateScheduled != null && status == 'Enabled') {
                    DateTime scheduledDate = DateTime.parse(dateScheduled.toString());
                    Map<String, dynamic> record = {
                      'subject': subjectKey.toString(),
                      'subject_code': codeKey.toString(),
                      'lecture_no': recordKey.toString(),
                      'date_scheduled': dateScheduled.toString(),
                      'details': Map<String, dynamic>.from({
                        'date_learnt': recordValue['date_learnt'],
                        'date_revised': recordValue['date_revised'],
                        'date_scheduled': recordValue['date_scheduled'],
                        'description': recordValue['description'],
                        'missed_revision': recordValue['missed_revision'],
                        'no_revision': recordValue['no_revision'],
                        'revision_frequency': recordValue['revision_frequency'],
                        'status': recordValue['status'],
                      }),
                    };

                    if (scheduledDate.toIso8601String().split('T')[0] == todayStr) {
                      todayRecords.add(record);
                    } else if (scheduledDate.isBefore(today)) {
                      missedRecords.add(record);
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

      return {'today': todayRecords, 'missed': missedRecords, 'nextDay': nextDayRecords, 'next7Days': next7DaysRecords};
    } catch (e) {
      // print('Error fetching records: $e');
      throw Exception('Failed to fetch records');
    }
  }

  Future<void> _addRevision(String subject, String subjectCode, String lectureNo, Map<String, dynamic> details) async {
    try {
      int noRevision = (details['no_revision'] as num).toInt() + 1;
      String revisionFrequency = details['revision_frequency'].toString();
      bool isEnabled = details['status'].toString() == 'Enabled';

      String dateRevised = DateTime.now().toIso8601String().split('T')[0];

      int missedRevision = (details['missed_revision'] as num).toInt();
      DateTime scheduledDate = DateTime.parse(details['date_scheduled'].toString());
      String dateScheduled = _calculateScheduledDate(scheduledDate, revisionFrequency, noRevision).toIso8601String().split('T')[0];
      if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised) < 0) {
        missedRevision += 1;
      }

      DatabaseReference ref = FirebaseDatabase.instance.ref()
          .child(subject)
          .child(subjectCode)
          .child(lectureNo);

      await ref.update({
        'date_revised': dateRevised,
        'no_revision': noRevision,
        'date_scheduled': dateScheduled,
        'missed_revision': missedRevision,
        'revision_frequency': revisionFrequency,
        'status': isEnabled ? 'Enabled' : 'Disabled',
      });

      setState(() {});
    } catch (e) {
      // print('Error updating revision: $e');
      throw Exception('Failed to update revision');
    }
  }

  DateTime _calculateScheduledDate(DateTime scheduledDate, String frequency, int noRevision) {
    switch (frequency) {
      case 'Daily':
        return scheduledDate.add(Duration(days: 1));
      case '2 Day':
        return scheduledDate.add(Duration(days: 2));
      case '3 Day':
        return scheduledDate.add(Duration(days: 3));
      case 'Weekly':
        return scheduledDate.add(Duration(days: 7));
      case 'Default':
      default:
        List<int> intervals = [1, 3, 7, 15, 30];
        int additionalDays = 0;
        for (int i = 0; i <= noRevision; i++) {
          additionalDays += (i < intervals.length) ? intervals[i] : 30;
        }
        return scheduledDate.add(Duration(days: additionalDays));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Add padding here
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
              future: _getRecords(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || (snapshot.data!['today']!.isEmpty && snapshot.data!['missed']!.isEmpty && snapshot.data!['nextDay']!.isEmpty && snapshot.data!['next7Days']!.isEmpty)) {
                  return Center(child: Text('No records scheduled.'));
                } else {
                  List<Map<String, dynamic>> todayRecords = snapshot.data!['today']!;
                  List<Map<String, dynamic>> missedRecords = snapshot.data!['missed']!;
                  List<Map<String, dynamic>> nextDayRecords = snapshot.data!['nextDay']!;
                  List<Map<String, dynamic>> next7DaysRecords = snapshot.data!['next7Days']!;
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        if (nextDayRecords.isNotEmpty) ...[
                          SizedBox(height: 20),
                          Text('Next Day Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                columns: [
                                  DataColumn(label: Text('Subject')),
                                  DataColumn(label: Text('Subject Code')),
                                  DataColumn(label: Text('Lecture No')),
                                  DataColumn(label: Text('Date Scheduled')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: nextDayRecords.map((record) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(record['subject'])),
                                      DataCell(Text(record['subject_code'])),
                                      DataCell(Text(record['lecture_no'])),
                                      DataCell(Text(record['date_scheduled'])),
                                      DataCell(
                                        ElevatedButton(
                                          onPressed: () {
                                            _addRevision(
                                              record['subject'],
                                              record['subject_code'],
                                              record['lecture_no'],
                                              record['details'],
                                            );
                                          },
                                          child: Text('Add Revision (+)'),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                        if (next7DaysRecords.isNotEmpty) ...[
                          SizedBox(height: 20),
                          Text('Next 7 Days Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                columns: [
                                  DataColumn(label: Text('Subject')),
                                  DataColumn(label: Text('Subject Code')),
                                  DataColumn(label: Text('Lecture No')),
                                  DataColumn(label: Text('Date Scheduled')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: next7DaysRecords.map((record) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(record['subject'])),
                                      DataCell(Text(record['subject_code'])),
                                      DataCell(Text(record['lecture_no'])),
                                      DataCell(Text(record['date_scheduled'])),
                                      DataCell(
                                        ElevatedButton(
                                          onPressed: () {
                                            _addRevision(
                                              record['subject'],
                                              record['subject_code'],
                                              record['lecture_no'],
                                              record['details'],
                                            );
                                          },
                                          child: Text('Add Revision (+)'),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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
    );
  }}
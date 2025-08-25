import 'FirebaseDatabaseService.dart';

Future<void> UpdateRecords(
    String selectedCategory,
    String selectedCategoryCode,
    String lectureNo,
    String dateRevised,
    String description,
    String reminderTime,
    int noRevision,
    String dateScheduled,
    List<String> datesRevised,
    int missedRevision,
    List<String> datesMissedRevisions,
    String revisionFrequency,
    String status,
    Map<String, dynamic> revisionData,
    Map<String, dynamic> durationData,
    int alarmType,
    String entryType
    ) async {
  
  final firebaseService = FirebaseDatabaseService();
  
  // Prepare update data
  Map<String, dynamic> updateData = {
    'reminder_time': reminderTime,
    'date_updated': dateRevised,
    'completion_counts': noRevision,
    'scheduled_date': dateScheduled,
    'missed_counts': missedRevision,
    'dates_missed_revisions': datesMissedRevisions,
    'recurrence_frequency': revisionFrequency,
    'status': status,
    'dates_updated': datesRevised,
    'description': description,
    'recurrence_data': revisionData,
    'duration': durationData,
    'alarm_type': alarmType,
    'entry_type': entryType,
  };
  
  // Update record using centralized service
  bool success = await firebaseService.updateRecord(selectedCategory, selectedCategoryCode, lectureNo, updateData);
  if (!success) {
    throw Exception('Failed to update record');
  }
}



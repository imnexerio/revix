import 'FirebaseDatabaseService.dart';

Future<void> UpdateRecords(
    String selectedSubject,
    String selectedSubjectCode,
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
    Map<String, dynamic> durationData
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
  };
  
  // Update record using centralized service
  bool success = await firebaseService.updateRecord(selectedSubject, selectedSubjectCode, lectureNo, updateData);
  if (!success) {
    throw Exception('Failed to update record');
  }
}

Future<void> moveToDeletedData(
    String selectedSubject,
    String selectedSubjectCode,
    String lectureNo,
    Map<String, dynamic> lectureData,
) async {
  
  final firebaseService = FirebaseDatabaseService();
  
  // Move to deleted data using centralized service
  bool success = await firebaseService.moveToDeletedData(selectedSubject, selectedSubjectCode, lectureNo, lectureData);
  if (!success) {
    throw Exception('Failed to move record to deleted data');
  }
}

Future<void> UpdateRecordsRevision(
    String selectedSubject,
    String selectedSubjectCode,
    String lectureNo,
    String dateRevised,
    String description,
    String reminderTime,
    int noRevision,
    String dateScheduled,
    List<String> datesRevised,
    int missedRevision,
    List<String> datesMissedRevisions,
    String status,
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
    'dates_updated': datesRevised,
    'description': description,
    'status': status,
  };
  
  // Update record using centralized service
  bool success = await firebaseService.updateRecord(selectedSubject, selectedSubjectCode, lectureNo, updateData);
  if (!success) {
    throw Exception('Failed to update record revision');
  }
}

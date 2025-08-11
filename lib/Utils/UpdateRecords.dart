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

Future<void> moveToDeletedData(
    String selectedCategory,
    String selectedCategoryCode,
    String lectureNo,
    Map<String, dynamic> lectureData,
) async {
  
  final firebaseService = FirebaseDatabaseService();
  
  // Move to deleted data using centralized service
  bool success = await firebaseService.moveToDeletedData(selectedCategory, selectedCategoryCode, lectureNo, lectureData);
  if (!success) {
    throw Exception('Failed to move record to deleted data');
  }
}

Future<void> UpdateRecordsRevision(
    String selectedCategory,
    String selectedCategoryCode,
    String lectureNo,
    String dateRevised,
    int noRevision,
    String dateScheduled,
    List<String> datesRevised,
    int missedRevision,
    List<String> datesMissedRevisions,
    ) async {
  
  final firebaseService = FirebaseDatabaseService();
  
  // Prepare update data
  Map<String, dynamic> updateData = {
    'date_updated': dateRevised,
    'completion_counts': noRevision,
    'scheduled_date': dateScheduled,
    'missed_counts': missedRevision,
    'dates_missed_revisions': datesMissedRevisions,
    'dates_updated': datesRevised,
  };
  
  // Update record using centralized service
  bool success = await firebaseService.updateRecord(selectedCategory, selectedCategoryCode, lectureNo, updateData);
  if (!success) {
    throw Exception('Failed to update record revision');
  }
}

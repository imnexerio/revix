import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';

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
  
  // Check if user is in guest mode
  if (await GuestAuthService.isGuestMode()) {
    // Use local database for guest users
    final localDb = LocalDatabaseService();
    
    // Prepare update data
    Map<String, dynamic> updateData = {
      'reminder_time': reminderTime,
      'date_revised': dateRevised,
      'no_revision': noRevision,
      'date_scheduled': dateScheduled,
      'missed_revision': missedRevision,
      'dates_missed_revisions': datesMissedRevisions,
      'revision_frequency': revisionFrequency,
      'status': status,
      'dates_revised': datesRevised,
      'description': description,
      'revision_data': revisionData,
      'duration': durationData,
    };
    
    // Update record in local database
    bool success = await localDb.updateRecord(selectedSubject, selectedSubjectCode, lectureNo, updateData);
    if (!success) {
      throw Exception('Failed to update record in local database');
    }
    return;
  }

  // Original Firebase logic for authenticated users
  // Get the currently authenticated user
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }
  String uid = user.uid;

  // Update the database reference to include the user's UID
  DatabaseReference ref = FirebaseDatabase.instance
      .ref('users/$uid/user_data')
      .child(selectedSubject)
      .child(selectedSubjectCode)
      .child(lectureNo);

  // Perform the update operation
  await ref.update({
    'reminder_time': reminderTime,
    'date_revised': dateRevised,
    'no_revision': noRevision,
    'date_scheduled': dateScheduled,
    'missed_revision': missedRevision,
    'dates_missed_revisions': datesMissedRevisions,
    'revision_frequency': revisionFrequency,
    'status': status,
    'dates_revised': datesRevised,
    'description': description,
    'revision_data': revisionData,
    'duration': durationData,
  });
}

Future<void> moveToDeletedData(
    String selectedSubject,
    String selectedSubjectCode,
    String lectureNo,
    Map<String, dynamic> lectureData,
) async {
  
  // Check if user is in guest mode
  if (await GuestAuthService.isGuestMode()) {
    // Use local database for guest users
    final localDb = LocalDatabaseService();
    
    // Add deletion timestamp to the data
    Map<String, dynamic> deletedData = Map<String, dynamic>.from(lectureData);
    deletedData['deleted_at'] = DateTime.now().toIso8601String();
    
    // Save to deleted data in local database
    bool success = await localDb.saveDeletedRecord(selectedSubject, selectedSubjectCode, lectureNo, deletedData);
    if (!success) {
      throw Exception('Failed to move record to deleted data in local database');
    }
    
    // Remove from original location in local database
    bool removeSuccess = await localDb.deleteRecord(selectedSubject, selectedSubjectCode, lectureNo);
    if (!removeSuccess) {
      throw Exception('Failed to remove record from original location in local database');
    }
    return;
  }

  // Original Firebase logic for authenticated users
  // Get the currently authenticated user
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }
  String uid = user.uid;

  // Update the database reference to include the user's UID
  DatabaseReference ref = FirebaseDatabase.instance
      .ref('users/$uid/deleted_user_data')
      .child(selectedSubject)
      .child(selectedSubjectCode)
      .child(lectureNo);

  // Perform the update operation
  // Perform the update operation
  await ref.update({
    ...lectureData,
    'deleted_at': DateTime.now().toIso8601String()
  });
  // Optionally, you can also remove the record from the original location
  DatabaseReference originalRef = FirebaseDatabase.instance
      .ref('users/$uid/user_data')
      .child(selectedSubject)
      .child(selectedSubjectCode)
      .child(lectureNo);
  await originalRef.remove();
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
  
  // Check if user is in guest mode
  if (await GuestAuthService.isGuestMode()) {
    // Use local database for guest users
    final localDb = LocalDatabaseService();
    
    // Prepare update data
    Map<String, dynamic> updateData = {
      'reminder_time': reminderTime,
      'date_revised': dateRevised,
      'no_revision': noRevision,
      'date_scheduled': dateScheduled,
      'missed_revision': missedRevision,
      'dates_missed_revisions': datesMissedRevisions,
      'dates_revised': datesRevised,
      'description': description,
      'status': status,
    };
    
    // Update record in local database
    bool success = await localDb.updateRecord(selectedSubject, selectedSubjectCode, lectureNo, updateData);
    if (!success) {
      throw Exception('Failed to update record revision in local database');
    }
    return;
  }

  // Original Firebase logic for authenticated users
  // Get the currently authenticated user
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }
  String uid = user.uid;

  // Update the database reference to include the user's UID
  DatabaseReference ref = FirebaseDatabase.instance
      .ref('users/$uid/user_data')
      .child(selectedSubject)
      .child(selectedSubjectCode)
      .child(lectureNo);

  // Perform the update operation
  await ref.update({
    'reminder_time': reminderTime,
    'date_revised': dateRevised,
    'no_revision': noRevision,
    'date_scheduled': dateScheduled,
    'missed_revision': missedRevision,
    'dates_missed_revisions': datesMissedRevisions,
    'dates_revised': datesRevised,
    'description': description,
    'status': status,
  });
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


Future<void> UpdateRecords(
    String selectedSubject,
    String selectedSubjectCode,
    String lectureNo,
    String dateRevised,
    int noRevision,
    String dateScheduled,
    int missedRevision,
    String revisionFrequency,
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

  // Retrieve the existing dates_revised list
  DataSnapshot snapshot = await ref.child('dates_revised').get();
  List<String> datesRevised = [];
  if (snapshot.exists && snapshot.value is List) {
    datesRevised = List<String>.from(snapshot.value as List);
  }

  // Add the new date to the list
  datesRevised.add(dateRevised);

  List<String> datesMissed = [];

  // Perform the update operation
  await ref.update({
    'date_revised': dateRevised,
    'no_revision': noRevision,
    'date_scheduled': dateScheduled,
    'missed_revision': missedRevision,
    'revision_frequency': revisionFrequency,
    'status': status,
    'dates_revised': datesRevised,
  });
}
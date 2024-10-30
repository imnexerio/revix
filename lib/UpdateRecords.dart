import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void UpdateRecords(
  String selectedSubject,
  String selectedSubjectCode,
  String lectureNo,
  String dateRevised,
  int noRevision,
  String dateScheduled,
  int missedRevision,
  String revisionFrequency,
  String status, // New field
) {
  DatabaseReference ref = FirebaseDatabase.instance.refFromURL(
    "${DefaultFirebaseOptions.currentPlatform.databaseURL}/$selectedSubject/$selectedSubjectCode/$lectureNo"
  );
  ref.update({
    "date_revised": dateRevised,
    "no_revision": noRevision,
    "date_scheduled": dateScheduled,
    "missed_revision": missedRevision,
    "revision_frequency": revisionFrequency,
    "status": status, // New field
  });
}
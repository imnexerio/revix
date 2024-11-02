import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:retracker/widgets/date_utils.dart';


Future<void> AddRecords(

  String _selectedSubject,
      _selectedSubjectCode,
      _lectureNo,
      _lectureType,
      _description,
      _revisionFrequency,
      isEnabled,)
      async {

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    String uid = user.uid;

    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    String dateScheduled = DateNextRevision.calculateFirstScheduledDate(_revisionFrequency)
        .toIso8601String()
        .split('T')[0];

    DatabaseReference ref = FirebaseDatabase.instance
        .ref('users/$uid/user_data')
        .child(_selectedSubject)
        .child(_selectedSubjectCode)
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
      'status': isEnabled ,
    });
}

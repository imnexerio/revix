import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DateNextRevision {
  static Future<DateTime> calculateNextRevisionDate(DateTime scheduledDate, String frequency, int noRevision) async {
    List<Map<String, String>> frequencies = await fetchFrequencies();

    // Check if the frequency is in the fetched frequencies
    Map<String, String>? customFrequency = frequencies.firstWhere(
          (freq) => freq['title'] == frequency,
      orElse: () => {'title': '', 'frequency': ''},
    );

    if (customFrequency['title']!.isNotEmpty) {
      List<int> intervals = customFrequency['frequency']!.split(',').map((e) => int.parse(e.trim())).toList();
      int additionalDays = (noRevision < intervals.length) ? intervals[noRevision] : intervals.last;
      return scheduledDate.add(Duration(days: additionalDays));
    }

    return scheduledDate;
  }

  static Future<List<Map<String, String>>> fetchFrequencies() async {
    List<Map<String, String>> frequencies = [];
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_frequencies');
      DataSnapshot snapshot = await databaseRef.get();
      if (snapshot.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        frequencies = data.entries.map((entry) {
          return {
            'title': entry.key,
            'frequency': (entry.value as List<dynamic>).join(', '),
          };
        }).toList();
      }
    } catch (e) {
      // Handle error
    }
    return frequencies;
  }


  static DateTime calculateFirstScheduledDate(String frequency) {
    DateTime today = DateTime.now();
    switch (frequency) {
      case 'Daily':
        return today.add(Duration(days: 1));
      case '2 Day':
        return today.add(Duration(days: 1));
      case '3 Day':
        return today.add(Duration(days: 1));
      case 'Weekly':
        return today.add(Duration(days: 1));
      case 'Default':
      default:
        return today.add(Duration(days: 1));
    }
  }
}
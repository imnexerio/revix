import 'FirebaseDatabaseService.dart';

class DateNextRevision {
  static Future<DateTime> calculateNextRecurrenceDate(DateTime scheduledDate, String frequency, int completionCount) async {
    List<Map<String, String>> frequencies = await fetchFrequencies();

    // Check if the frequency is in the fetched frequencies
    Map<String, String>? customFrequency = frequencies.firstWhere(
          (freq) => freq['title'] == frequency,
      orElse: () => {'title': '', 'frequency': ''},
    );

    if (customFrequency['title']!.isNotEmpty) {
      List<int> intervals = customFrequency['frequency']!.split(',').map((e) => int.parse(e.trim())).toList();
      int additionalDays = (completionCount < intervals.length) ? intervals[completionCount] : intervals.last;
      return scheduledDate.add(Duration(days: additionalDays));
    }

    return scheduledDate;
  }
  
  static Future<List<Map<String, String>>> fetchFrequencies() async {
    try {
      return await FirebaseDatabaseService().fetchFrequenciesForDateCalculation();
    } catch (e) {
      print('Error fetching frequencies: $e');
      return [];
    }
  }
}
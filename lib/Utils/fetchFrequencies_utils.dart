import 'FirebaseDatabaseService.dart';

class FetchFrequenciesUtils {
  static Future<Map<String, dynamic>> fetchFrequencies() async {
    try {
      return await FirebaseDatabaseService().fetchCustomFrequencies();
    } catch (e) {
      print('Error fetching frequencies: $e');
      return {};
    }
  }
}
import 'FirebaseDatabaseService.dart';

class FetchtrackingTypeUtils {
  static Future<List<String>> fetchtrackingType() async {
    try {
      return await FirebaseDatabaseService().fetchCustomTrackingTypes();
    } catch (e) {
      print('Error fetching tracking types: $e');
      return [];
    }
  }
}
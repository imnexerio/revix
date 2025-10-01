import 'package:http/http.dart' as http;
import 'dart:convert';
import 'FirebaseDatabaseService.dart';
import 'UnifiedDatabaseService.dart';

/// Service to fetch public holidays from Nager.Date API
/// and save them to the database in the app's record format
class PublicHolidayFetcher {
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  final UnifiedDatabaseService _unifiedDatabaseService = UnifiedDatabaseService();
  
  static const String API_BASE_URL = 'https://date.nager.at/api/v3';
  
  /// Popular countries for quick selection
  static const List<Map<String, String>> POPULAR_COUNTRIES = [
    {'code': 'IN', 'name': 'India'},
    {'code': 'US', 'name': 'United States'},
    {'code': 'GB', 'name': 'United Kingdom'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'AU', 'name': 'Australia'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'JP', 'name': 'Japan'},
    {'code': 'CN', 'name': 'China'},
    {'code': 'BR', 'name': 'Brazil'},
    {'code': 'MX', 'name': 'Mexico'},
    {'code': 'IT', 'name': 'Italy'},
    {'code': 'ES', 'name': 'Spain'},
    {'code': 'KR', 'name': 'South Korea'},
    {'code': 'NL', 'name': 'Netherlands'},
  ];
  
  /// Fetch available countries from API
  Future<List<Map<String, String>>> fetchAvailableCountries() async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/AvailableCountries'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => {
          'code': item['countryCode'].toString(),
          'name': item['name'].toString(),
        }).toList();
      }
      
      // Fallback to popular countries if API fails
      return POPULAR_COUNTRIES;
    } catch (e) {
      print('Error fetching countries: $e');
      // Return popular countries as fallback
      return POPULAR_COUNTRIES;
    }
  }
  
  /// Fetch holidays from API (returns raw list for preview)
  Future<List<Map<String, dynamic>>> fetchHolidaysFromAPI({
    required String countryCode,
    required int year,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/PublicHolidays/$year/$countryCode'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((item) => {
          'name': item['name']?.toString() ?? item['localName']?.toString() ?? 'Unknown',
          'localName': item['localName']?.toString() ?? item['name']?.toString() ?? 'Unknown',
          'date': item['date']?.toString() ?? '',
          'countryCode': item['countryCode']?.toString() ?? countryCode,
          'global': item['global'] ?? true,
          'types': item['types'] ?? ['Public'],
        }).toList();
      } else if (response.statusCode == 404) {
        throw Exception('No holidays found for $countryCode in $year');
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching holidays from API: $e');
      rethrow;
    }
  }
  
  /// Convert API response to app's record format
  Map<String, Map<String, dynamic>> convertToRecords(
    List<Map<String, dynamic>> apiHolidays,
    String countryCode,
  ) {
    final Map<String, Map<String, dynamic>> records = {};
    final now = DateTime.now();
    
    for (var holiday in apiHolidays) {
      try {
        final name = holiday['name'] as String;
        final date = holiday['date'] as String; // "2025-01-01"
        final localName = holiday['localName'] as String;
        
        // Create unique key: Name_YYYYMMDD
        final sanitizedName = _sanitizeHolidayName(name);
        final dateKey = date.replaceAll('-', ''); // "20250101"
        final recordKey = '${sanitizedName}_$dateKey';
        
        // Create record in app's format
        final recordData = {
          'start_timestamp': '${date}T00:00',
          'reminder_time': 'All Day',
          'alarm_type': 0,
          'entry_type': 'HOLIDAY',
          'date_initiated': date,
          'date_updated': now.toIso8601String().split('.')[0],
          'scheduled_date': date,
          'description': localName,
          'missed_counts': 0,
          'completion_counts': -1,
          'recurrence_frequency': 'No Repetition',
          'recurrence_data': {
            'frequency': 'No Repetition'
          },
          'status': 'Enabled',
          'duration': {
            'type': 'forever',
            'numberOfTimes': null,
            'endDate': null
          }
        };
        
        records[recordKey] = recordData;
      } catch (e) {
        print('Error converting holiday ${holiday['name']}: $e');
        continue;
      }
    }
    
    return records;
  }
  
  /// Fetch and save holidays in bulk
  Future<Map<String, int>> fetchAndSaveHolidays({
    required String countryCode,
    required int year,
  }) async {
    try {
      // 1. Fetch from API
      final apiHolidays = await fetchHolidaysFromAPI(
        countryCode: countryCode,
        year: year,
      );
      
      if (apiHolidays.isEmpty) {
        return {'success': 0, 'failed': 0, 'total': 0};
      }
      
      // 2. Convert to records
      final records = convertToRecords(apiHolidays, countryCode);
      
      if (records.isEmpty) {
        return {'success': 0, 'failed': 0, 'total': 0};
      }
      
      // 3. Ensure HOLIDAY tracking type exists
      await ensureHolidayTrackingType();
      
      // 4. Bulk save to database
      final result = await _unifiedDatabaseService.bulkSaveRecords(
        category: 'HOLIDAY',
        subCategory: countryCode,
        records: records,
      );
      
      return result;
    } catch (e) {
      print('Error in fetchAndSaveHolidays: $e');
      rethrow;
    }
  }


  /// Ensure HOLIDAY tracking type exists in custom_trackingType
  Future<void> ensureHolidayTrackingType() async {
    try {
      final trackingTypes = await _databaseService.fetchCustomTrackingTypes();

      if (!trackingTypes.contains('HOLIDAY')) {
        trackingTypes.add('HOLIDAY');
        await _databaseService.saveCustomTrackingTypes(trackingTypes);
        print('Added HOLIDAY to tracking types');
      }
    } catch (e) {
      print('Error ensuring holiday tracking type: $e');
      // Non-critical error, continue
    }
  }
  
  /// Sanitize holiday name for use as database key
  String _sanitizeHolidayName(String name) {
    // Replace spaces and special characters with underscores
    String sanitized = name
      .replaceAll(' ', '_')
      .replaceAll("'", '')
      .replaceAll('"', '')
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll('/', '_')
      .replaceAll('\\', '_')
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'_{2,}'), '_')
      .trim();
    
    // Remove trailing/leading underscores
    while (sanitized.startsWith('_')) {
      sanitized = sanitized.substring(1);
    }
    while (sanitized.endsWith('_')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    
    return sanitized;
  }
}

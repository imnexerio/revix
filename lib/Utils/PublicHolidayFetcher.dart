import 'package:http/http.dart' as http;
import 'dart:convert';
import 'FirebaseDatabaseService.dart';
import 'UnifiedDatabaseService.dart';

class PublicHolidayFetcher {
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  final UnifiedDatabaseService _unifiedDatabaseService = UnifiedDatabaseService();

  static const String GOOGLE_API_KEY = 'AIzaSyDuk2CHTqC9SfjvP6DnFgHoH1odomSJZkE';  //'YOUR_API_KEY_HERE';
  static const String API_BASE_URL = 'https://www.googleapis.com/calendar/v3/calendars';

  
  /// Popular countries - Always available (no API call needed)
  /// Popular countries - Always available (no API call needed)
  static const Map<String, Map<String, String>> POPULAR_COUNTRIES = {
    'IN': {
      'name': 'India',
      'calendarId': 'en.indian#holiday@group.v.calendar.google.com',
    },
    'US': {
      'name': 'United States',
      'calendarId': 'en.usa#holiday@group.v.calendar.google.com',
    },
    'GB': {
      'name': 'United Kingdom',
      'calendarId': 'en.uk#holiday@group.v.calendar.google.com',
    },
    'CA': {
      'name': 'Canada',
      'calendarId': 'en.canadian#holiday@group.v.calendar.google.com',
    },
    'AU': {
      'name': 'Australia',
      'calendarId': 'en.australian#holiday@group.v.calendar.google.com',
    },
  };
  
  /// Additional countries - Loaded on demand when user clicks "Load More Countries"
  static const Map<String, Map<String, String>> ADDITIONAL_COUNTRIES = {
    'DE': {
      'name': 'Germany',
      'calendarId': 'en.german#holiday@group.v.calendar.google.com',
    },
    'FR': {
      'name': 'France',
      'calendarId': 'en.french#holiday@group.v.calendar.google.com',
    },
    'JP': {
      'name': 'Japan',
      'calendarId': 'en.japanese#holiday@group.v.calendar.google.com',
    },
    'CN': {
      'name': 'China',
      'calendarId': 'en.china#holiday@group.v.calendar.google.com',
    },
    'BR': {
      'name': 'Brazil',
      'calendarId': 'en.brazilian#holiday@group.v.calendar.google.com',
    },
    'MX': {
      'name': 'Mexico',
      'calendarId': 'en.mexican#holiday@group.v.calendar.google.com',
    },
    'IT': {
      'name': 'Italy',
      'calendarId': 'en.italian#holiday@group.v.calendar.google.com',
    },
    'ES': {
      'name': 'Spain',
      'calendarId': 'en.spanish#holiday@group.v.calendar.google.com',
    },
    'KR': {
      'name': 'South Korea',
      'calendarId': 'en.south_korea#holiday@group.v.calendar.google.com',
    },
    'NL': {
      'name': 'Netherlands',
      'calendarId': 'en.dutch#holiday@group.v.calendar.google.com',
    },
    'PK': {
      'name': 'Pakistan',
      'calendarId': 'en.pk#holiday@group.v.calendar.google.com',
    },
    'BD': {
      'name': 'Bangladesh',
      'calendarId': 'en.bd#holiday@group.v.calendar.google.com',
    },
    'SG': {
      'name': 'Singapore',
      'calendarId': 'en.singapore#holiday@group.v.calendar.google.com',
    },
    'MY': {
      'name': 'Malaysia',
      'calendarId': 'en.malaysia#holiday@group.v.calendar.google.com',
    },
    'ID': {
      'name': 'Indonesia',
      'calendarId': 'en.indonesian#holiday@group.v.calendar.google.com',
    },
    'TH': {
      'name': 'Thailand',
      'calendarId': 'en.th#holiday@group.v.calendar.google.com',
    },
    'VN': {
      'name': 'Vietnam',
      'calendarId': 'en.vietnamese#holiday@group.v.calendar.google.com',
    },
    'PH': {
      'name': 'Philippines',
      'calendarId': 'en.philippines#holiday@group.v.calendar.google.com',
    },
    'ZA': {
      'name': 'South Africa',
      'calendarId': 'en.sa#holiday@group.v.calendar.google.com',
    },
    'AE': {
      'name': 'UAE',
      'calendarId': 'en.ae#holiday@group.v.calendar.google.com',
    },
  };

  static Map<String, Map<String, String>> get ALL_COUNTRIES {
    return {...POPULAR_COUNTRIES, ...ADDITIONAL_COUNTRIES};
  }
  

  Future<List<Map<String, String>>> fetchAvailableCountries({
    bool loadAll = false,
  }) async {
    final countriesToShow = loadAll ? ALL_COUNTRIES : POPULAR_COUNTRIES;
    
    return countriesToShow.entries.map((entry) => {
      'code': entry.key,
      'name': entry.value['name']!,
    }).toList();
  }
  
  /// Fetch holidays from Google Calendar API (returns raw list for preview)
  Future<List<Map<String, dynamic>>> fetchHolidaysFromAPI({
    required String countryCode,
    required int year,
  }) async {
    try {
      // Check if API key is configured
      if (GOOGLE_API_KEY == 'YOUR_API_KEY_HERE') {
        throw Exception('Google Calendar API key not configured. Please add your API key in PublicHolidayFetcher.dart');
      }
      
      // Get calendar ID for country
      final countryData = ALL_COUNTRIES[countryCode];
      if (countryData == null) {
        throw Exception('Country $countryCode not supported');
      }
      
      final calendarId = countryData['calendarId']!;

      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 365));
      
      // Build API URL with query parameters
      final url = Uri.parse(
        '$API_BASE_URL/${Uri.encodeComponent(calendarId)}/events'
      ).replace(queryParameters: {
        'key': GOOGLE_API_KEY,
        
        'timeMin': startDate.toUtc().toIso8601String(),  // Start: today
        'timeMax': endDate.toUtc().toIso8601String(),    // End: today + 365 days
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'maxResults': '250',
      });

      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        
        return items.map((item) {
          final summary = item['summary']?.toString() ?? 'Unknown';
          final start = item['start'];
          final date = start['date']?.toString() ?? start['dateTime']?.toString().split('T')[0] ?? '';
          
          return {
            'name': summary,
            'localName': summary,
            'date': date,
            'countryCode': countryCode,
            'global': true,
            'types': ['Public'],
          };
        }).toList();
      } else if (response.statusCode == 403) {
        // Parse error details
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['error']['message'] ?? 'Unknown error';
          throw Exception('API Error 403: $errorMessage');
        } catch (e) {
          throw Exception('API key invalid or quota exceeded. Response: ${response.body}');
        }
      } else if (response.statusCode == 404) {
        throw Exception('No holidays found for $countryCode in $year');
      } else {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching holidays from Google Calendar API: $e');
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

        final dateKey = date.replaceAll('-', ''); // "20250101"
        final recordKey = '${name} $dateKey';
        
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
          'completion_counts': 0,
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

}

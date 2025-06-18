import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../Utils/LocalDatabaseService.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/platform_utils.dart';
import '../Utils/MarkAsDoneService.dart';
import '../Utils/AlarmManagerService.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
class HomeWidgetService {
  static const String appGroupId = 'HomeWidgetPreferences';
  static const String todayRecordsKey = 'todayRecords';
  static const String missedRecordsKey = 'missedRecords';
  static const String noReminderDateRecordsKey = 'noreminderdate';
  static const String isLoggedInKey = 'isLoggedIn';
  static const String frequencyDataKey = 'frequencyData';
  static const String trackingTypesKey = 'trackingTypes';
  static const String categoriesDataKey = 'categoriesData';
  static bool _isInitialized = false;
  static bool _isBackgroundInitialized = false;
  static final CombinedDatabaseService _databaseService = CombinedDatabaseService();  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Simple initialization (same as main.dart)
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await Hive.initFlutter();

      HomeWidget.setAppGroupId(appGroupId);
      // Set up widget background callback handling
      HomeWidget.registerInteractivityCallback(backgroundCallback);
      await _databaseService.initialize();

      // Initialize alarm manager service
      await AlarmManagerService.initialize();

      // Give a small delay for the service to initialize properly
      await Future.delayed(const Duration(milliseconds: 100));

      await _initializeWidgetData();

      _isInitialized = true;
    } catch (e) {
      if (e.toString().contains('already initialized')) {
        _isInitialized = true;
        print('Services already initialized');
      } else {
        print('Error initializing HomeWidgetService: $e');
        throw e;
      }
    }
  }

  // Simplified background initialization - mirrors main.dart approach
  static Future<void> _initializeBackgroundContext() async {
    if (_isBackgroundInitialized) return;

    try {
      // Ensure Flutter engine is initialized for background work
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      // Initialize PlatformUtils
      PlatformUtils.init();

      // Simple Firebase initialization (same as main.dart)
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      
      // Simple Hive initialization (same as main.dart)
      await Hive.initFlutter();

      // Initialize database services
      await LocalDatabaseService.initialize();

      _isBackgroundInitialized = true;
      print('Background context initialized successfully');
    } catch (e) {
      if (e.toString().contains('already initialized')) {
        _isBackgroundInitialized = true;
        print('Background services already initialized');
      } else {
        print('Error initializing background context: $e');
        _isBackgroundInitialized = false;
      }
    }  
    }

  // Initialize all widget data using existing database services
  static Future<void> _initializeWidgetData() async {
    try {
      // Initialize frequency data for AddLectureActivity access
      await _updateFrequencyDataFromService();

      // Initialize tracking types data for AddLectureActivity access
      await _updateTrackingTypesFromService();

      // Initialize categories data for AddLectureActivity access
      await _updateCategoriesFromService();
    } catch (e) {
      print('Error initializing widget data: $e');
    }
  }

  // Update frequency data using existing FirebaseDatabaseService
  static Future<void> _updateFrequencyDataFromService() async {
    try {
      Map<String, dynamic> frequencyData = {};

      // Use existing FirebaseDatabaseService method
      final firebaseService = FirebaseDatabaseService();
      final customFrequencies = await firebaseService.fetchCustomFrequencies();
      frequencyData.addAll(customFrequencies);

      await HomeWidget.saveWidgetData(frequencyDataKey, jsonEncode(frequencyData));
    } catch (e) {
      print('Error updating frequency data from service: $e');
    }
  }

  // Update tracking types using existing FirebaseDatabaseService
  static Future<void> _updateTrackingTypesFromService() async {
    try {
      // Use existing FirebaseDatabaseService method
      final firebaseService = FirebaseDatabaseService();
      List<String> trackingTypes = await firebaseService.fetchCustomTrackingTypes();

      // Remove duplicates
      trackingTypes = trackingTypes.toSet().toList();

      await HomeWidget.saveWidgetData(trackingTypesKey, jsonEncode(trackingTypes));
    } catch (e) {
      print('Error updating tracking types from service: $e');
    }
  }

  // Update categories using existing UnifiedDatabaseService
  static Future<void> _updateCategoriesFromService() async {
    try {
      // Use existing UnifiedDatabaseService method
      final categoriesData = await _databaseService.fetchCategoriesAndSubCategories();

      await HomeWidget.saveWidgetData(categoriesDataKey, jsonEncode(categoriesData));
    } catch (e) {
      print('Error updating categories from service: $e');
    }
  }
  // This callback will be called when the widget triggers a refresh
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    print('Background callback triggered: ${uri?.host}');

    // Initialize background context
    await _initializeBackgroundContext();
    if (!_isBackgroundInitialized) {
      print('Background initialization failed');
      await _updateWidgetWithEmptyData();
      return;
    }

    if (uri?.host == 'widget_refresh') {
      try {
        print('Starting widget background refresh...');

        final service = CombinedDatabaseService();
        print('CombinedDatabaseService created');

        await service.initialize();
        print('Service initialized');

        await service.forceDataReprocessing();
        print('Data reprocessing completed');

        // Get the processed data from the service
        final categorizedData = service.currentCategorizedData;
        print('Categorized data retrieved: ${categorizedData?.keys.toList()}');

        if (categorizedData != null) {
          final todayRecords = categorizedData['today'] ?? [];
          final missedRecords = categorizedData['missed'] ?? [];
          final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];

          print('Records found - Today: ${todayRecords.length}, Missed: ${missedRecords.length}, No reminder: ${noReminderDateRecords.length}');          // Update widget with the new data
          await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
          
          // Schedule alarms for today's records
          await _scheduleAlarmsForTodayRecords(todayRecords);
          
          print('Widget background refresh completed with data');
        } else {
          print('No categorized data available, using empty data');
          // Fallback to empty data if no data available
          await _updateWidgetWithEmptyData();
          print('Widget background refresh completed with empty data');
        }
      } catch (e) {
        print('Error in background widget refresh: $e');
        print('Error details: ${e.toString()}');
        // Fallback to empty data
        await _updateWidgetWithEmptyData();
      }
    } else if (uri?.host == 'frequency_refresh') {
      try {
        print('Starting frequency data refresh...');

        // Update all widget data using existing database services
        await _initializeWidgetData();
        print('All widget data refresh completed');
      } catch (e) {
        print('Error in widget data refresh: $e');
      }
    }
    else if (uri?.host == 'record_update') {
      try {
        print('Starting record update background processing...');

        // Extract parameters from URI
        final category = uri?.queryParameters['category'] ?? '';
        final subCategory = uri?.queryParameters['sub_category'] ?? '';
        final recordTitle = uri?.queryParameters['record_title'] ?? '';
        final requestId = uri?.queryParameters['requestId'] ?? '';

        print('Updating record: $category - $subCategory - $recordTitle (RequestID: $requestId)');

        String updateResult = 'SUCCESS';

        try {
            final service = CombinedDatabaseService();
            await service.initialize();

            try {
              print('All services ready, updating record using MarkAsDoneService...');

              await MarkAsDoneService.markAsDone(
                context: null, // Background processing - no UI context
                category: category,
                subCategory: subCategory,
                lectureNo: recordTitle,
              );

              print('Record update completed successfully using MarkAsDoneService');

              // Refresh widget data after update
              await service.forceDataReprocessing();
              final categorizedData = service.currentCategorizedData;
              if (categorizedData != null) {
                final todayRecords = categorizedData['today'] ?? [];
                final missedRecords = categorizedData['missed'] ?? [];
                final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];

                await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
                
                // Re-schedule alarms for today's records after successful update
                await _scheduleAlarmsForTodayRecords(todayRecords);
                
                print('Widget refreshed after record update');
              }
            } catch (e) {
              updateResult = 'ERROR:${e.toString()}';
              print('Record update failed: $e');
            }
        } catch (e) {
          print('Error in background record update: $e');
          updateResult = 'ERROR:${e.toString()}';
        }

        // Save the result to SharedPreferences for the Android side to read
        if (requestId.isNotEmpty) {
          await HomeWidget.saveWidgetData('record_update_result_$requestId', updateResult);
          print('Update result stored for requestId $requestId: $updateResult');
        }

      } catch (e) {
        print('Error in record update background callback: $e');

        // If we have a requestId, save the error result
        final requestId = uri?.queryParameters['requestId'] ?? '';
        if (requestId.isNotEmpty) {
          await HomeWidget.saveWidgetData('record_update_result_$requestId', 'ERROR:${e.toString()}');
        }
      }
    } else if (uri?.host == 'record_check') {
      try {
        print('Starting record check background processing...');

        final category = uri?.queryParameters['category'] ?? '';
        final subCategory = uri?.queryParameters['sub_category'] ?? '';
        final recordTitle = uri?.queryParameters['record_title'] ?? '';

        print('Checking record: $category - $subCategory - $recordTitle');

        // Initialize database service to check current status
        final service = CombinedDatabaseService();
        await service.initialize();

        // Force data refresh to get latest status
        await service.forceDataReprocessing();
        final categorizedData = service.currentCategorizedData;

        if (categorizedData != null) {
          final todayRecords = categorizedData['today'] ?? [];
          
          // Check if the record still exists in today's records
          final recordExists = todayRecords.any((record) =>
            record['category'] == category &&
            record['sub_category'] == subCategory &&
            record['record_title'] == recordTitle
          );

          if (recordExists) {
            print('Record still pending - precheck completed');
            // Record is still pending, alarm will be triggered at scheduled time
          } else {
            print('Record already completed or moved - cancelling related alarms');
            // Record has been completed or moved, so no need for the main alarm
          }

          // Update widget data with latest information
          final missedRecords = categorizedData['missed'] ?? [];
          final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];
          await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
        }

      } catch (e) {
        print('Error in record check background callback: $e');
      }
    }
    else if (uri?.host == 'record_create') {
      try {
        print('Starting record creation background processing...');

        // Extract parameters from URI query parameters
        final selectedCategory = uri?.queryParameters['selectedCategory'] ?? '';
        final selectedCategoryCode = uri?.queryParameters['selectedCategoryCode'] ?? '';
        final title = uri?.queryParameters['title'] ?? '';
        final startTimestamp = uri?.queryParameters['startTimestamp'] ?? '';
        final reminderTime = uri?.queryParameters['reminderTime'] ?? '';
        final lectureType = uri?.queryParameters['lectureType'] ?? '';
        final todayDate = uri?.queryParameters['todayDate'] ?? '';
        final dateScheduled = uri?.queryParameters['dateScheduled'] ?? '';
        final description = uri?.queryParameters['description'] ?? '';
        final revisionFrequency = uri?.queryParameters['revisionFrequency'] ?? '';
        final durationDataStr = uri?.queryParameters['durationData'] ?? '{}';
        final customFrequencyParamsStr = uri?.queryParameters['customFrequencyParams'] ?? '{}';
        final alarmTypeStr = uri?.queryParameters['alarmType'] ?? '0';
        final requestId = uri?.queryParameters['requestId'] ?? '';

        print('Creating record: $selectedCategory - $selectedCategoryCode - $title (RequestID: $requestId)');

        String saveResult = 'SUCCESS';

        try {
          // Parse JSON data
          Map<String, dynamic> durationData = {};
          Map<String, dynamic> customFrequencyParams = {};
          int alarmType = 0;
          try {
            durationData = Map<String, dynamic>.from(json.decode(durationDataStr) as Map);
            customFrequencyParams = Map<String, dynamic>.from(json.decode(customFrequencyParamsStr) as Map);
            alarmType = int.tryParse(alarmTypeStr) ?? 0;
          } catch (e) {
            print('Error parsing JSON data: $e');
            saveResult = 'ERROR:Failed to parse save data';
          }

          if (saveResult == 'SUCCESS') {
            try {
              print('Initializing database service for record creation...');

              final service = CombinedDatabaseService();
              await service.initialize();

              print('Database service ready, creating record...');

              // Add an extra safety delay to ensure all initialization is complete
              await Future.delayed(const Duration(milliseconds: 250));

              // Create the record using updateRecordsWithoutContext
              await service.updateRecordsWithoutContext(
                selectedCategory,
                selectedCategoryCode,
                title,
                startTimestamp,
                reminderTime,
                lectureType,
                todayDate,
                dateScheduled,
                description,
                revisionFrequency,
                durationData,
                customFrequencyParams,
                alarmType,
              );

              print('Record creation completed successfully');

              // Refresh widget data after creation
              await service.forceDataReprocessing();
              final categorizedData = service.currentCategorizedData;              if (categorizedData != null) {
                final todayRecords = categorizedData['today'] ?? [];
                final missedRecords = categorizedData['missed'] ?? [];
                final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];

                await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
                
                // Schedule alarms for today's records after successful creation
                await _scheduleAlarmsForTodayRecords(todayRecords);
                
                print('Widget refreshed after record creation');
              }
            } catch (e) {
              saveResult = 'ERROR:${e.toString()}';
              print('Record creation failed: $e');
            }
          }
        } catch (e) {
          print('Error in background record creation: $e');
          saveResult = 'ERROR:${e.toString()}';
        }

        // Save the result to SharedPreferences for the Android side to read
        if (requestId.isNotEmpty) {
          await HomeWidget.saveWidgetData('record_save_result_$requestId', saveResult);
          print('Save result stored for requestId $requestId: $saveResult');
        }

      } catch (e) {
        print('Error in record creation background callback: $e');

        // If we have a requestId, save the error result
        final requestId = uri?.queryParameters['requestId'] ?? '';
        if (requestId.isNotEmpty) {
          await HomeWidget.saveWidgetData('record_save_result_$requestId', 'ERROR:${e.toString()}');
        }
      }
    }
  }

  static Future<void> _updateWidgetSilently() async {
    await HomeWidget.updateWidget(
      name: 'TodayWidget',
      androidName: 'TodayWidget',
      iOSName: 'TodayWidget',
    );
  }
  static Future<void> _updateWidgetWithEmptyData() async {
    await _ensureInitialized();

    await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData('lastUpdated', DateTime.now().millisecondsSinceEpoch);
    await _updateWidgetSilently();
  }

  static Future<void> updateWidgetData(
      List<Map<String, dynamic>> todayRecords,
      List<Map<String, dynamic>> missedRecords,
      List<Map<String, dynamic>> noReminderDateRecords,
      ) async {
    try {
      // Format and save all three data categories
      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode(_formatRecords(todayRecords)),
      );

      await HomeWidget.saveWidgetData(
        missedRecordsKey,
        jsonEncode(_formatRecords(missedRecords)),
      );

      await HomeWidget.saveWidgetData(
        noReminderDateRecordsKey,
        jsonEncode(_formatRecords(noReminderDateRecords)),
      );

      // Add timestamp to update the "last updated" time in widget
      await HomeWidget.saveWidgetData(
        'lastUpdated',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Schedule alarms for today's records
      await _scheduleAlarmsForTodayRecords(todayRecords);

      // Request widget update
      await _updateWidget();
    } catch (e) {
      debugPrint('Error updating widget data: $e');
    }
  }

  // Helper method to schedule alarms for today's records
  static Future<void> _scheduleAlarmsForTodayRecords(List<Map<String, dynamic>> todayRecords) async {
    try {
      if (PlatformUtils.instance.isAndroid) {
        await AlarmManagerService.scheduleAlarmsForTodayRecords(todayRecords);
        print('Scheduled alarms for ${todayRecords.length} today records');
      }
    } catch (e) {
      print('Error scheduling alarms: $e');
    }
  }

  static List<Map<String, dynamic>> _formatRecords(
      List<Map<String, dynamic>> records) {
    return records.map((record) {
      // Return the entire record with all fields
      // This ensures future additions will be available without code changes
      Map<String, dynamic> formattedRecord = {};

      // Convert all values to strings for consistency
      record.forEach((key, value) {
        formattedRecord[key] = value?.toString() ?? '';
      });

      return formattedRecord;
    }).toList();
  }

  static Future<void> _updateWidget() async {
    await HomeWidget.updateWidget(
      name: 'TodayWidget',
      androidName: 'TodayWidget',
      iOSName: 'TodayWidget',
    );

    // Note: Method channel notifications are not available in background contexts
    // The HomeWidget.updateWidget() call above already handles the native widget update
    print('Widget updated via HomeWidget package');
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      HomeWidget.setAppGroupId(appGroupId);
      _isInitialized = true;
    }
  }

  // Method to update login status in widget
  static Future<void> updateWidgetLoginStatus(bool isLoggedIn) async {
    try {
      await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);
      
      if (!isLoggedIn) {
        // Clear widget data when logging out
        await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
        await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
        await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
      }
      
      await _updateWidget();
    } catch (e) {
      print('Error updating widget login status: $e');
    }
  }
}
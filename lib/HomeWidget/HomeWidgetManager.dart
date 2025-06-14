import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';

import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/GuestAuthService.dart';
import '../Utils/platform_utils.dart';
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
  static final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  static Future<void> initialize() async {
    if (_isInitialized) return;

    HomeWidget.setAppGroupId(appGroupId);    
    // Set up widget background callback handling
    HomeWidget.registerBackgroundCallback(backgroundCallback);

    final bool isLoggedIn = _databaseService.isAuthenticated;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);    // Initialize frequency data for AddLectureActivity access
    await _updateFrequencyData();
    
    // Initialize tracking types data for AddLectureActivity access
    await _updateTrackingTypesData();
    
    // Initialize categories data for AddLectureActivity access
    await _updateCategoriesData();
    
    // Check for any pending frequency data requests
    await monitorFrequencyDataRequests();

    if (!isLoggedIn) {
      await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
      await _updateWidget();
    }

    _isInitialized = true;
  }
  
  // Update frequency data in SharedPreferences for native access
  static Future<void> _updateFrequencyData() async {
    try {
      final frequencyData = await _databaseService.fetchCustomFrequencies();
      await HomeWidget.saveWidgetData(frequencyDataKey, jsonEncode(frequencyData));
    } catch (e) {
      print('Error updating frequency data: $e');
      // Save empty data as fallback
      await HomeWidget.saveWidgetData(frequencyDataKey, jsonEncode({}));
    }
  }
  
  // Update tracking types data in SharedPreferences for native access
  static Future<void> _updateTrackingTypesData() async {
    try {
      final trackingTypes = await _databaseService.fetchCustomTrackingTypes();
      await HomeWidget.saveWidgetData(trackingTypesKey, jsonEncode(trackingTypes));
    } catch (e) {
      print('Error updating tracking types data: $e');
      // Save empty data as fallback
      await HomeWidget.saveWidgetData(trackingTypesKey, jsonEncode([]));
    }
  }
  // Update categories data in SharedPreferences for native access
  static Future<void> _updateCategoriesData() async {
    try {
      // Get all user data and extract categories
      final allUserData = await _databaseService.fetchAllUserData();
      
      // Extract categories and subcategories from user data
      List<String> subjects = [];
      Map<String, List<String>> subCategories = {};
      
      for (String category in allUserData.keys) {
        subjects.add(category);
        subCategories[category] = [];
        
        if (allUserData[category] is Map) {
          Map<String, dynamic> categoryData = Map<String, dynamic>.from(allUserData[category]);
          for (String subCategory in categoryData.keys) {
            subCategories[category]!.add(subCategory);
          }
        }
      }
      
      final categoriesData = {
        'subjects': subjects,
        'subCategories': subCategories,
      };
      
      await HomeWidget.saveWidgetData(categoriesDataKey, jsonEncode(categoriesData));
    } catch (e) {
      print('Error updating categories data: $e');
      // Save empty data as fallback
      await HomeWidget.saveWidgetData(categoriesDataKey, jsonEncode({
        'subjects': [],
        'subCategories': {},
      }));
    }
  }
  /// Public method to update frequency data - can be called from other parts of the app
  static Future<void> updateFrequencyDataStatic() async {
    await _updateFrequencyData();
    await _updateCategoriesData();
  }
  // This callback will be called when the widget triggers a refresh
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    print('Background callback triggered: ${uri?.host}');    // Ensure Flutter engine is initialized for background work
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Initialize PlatformUtils for background context
    PlatformUtils.init();    // Initialize Firebase for background context
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('Firebase initialized in background context');
    } catch (e) {
      if (e.toString().contains('already initialized')) {
        print('Firebase already initialized');
      } else {
        print('Error initializing Firebase: $e');
        await _updateWidgetWithEmptyData();
        return;
      }
    }
    
    // Give Firebase a moment to fully initialize
    await Future.delayed(Duration(milliseconds: 300));

    if (uri?.host == 'widget_refresh') {
      try {
        print('Starting widget background refresh...');
        
        // Check for frequency data update requests from native code
        await monitorFrequencyDataRequests();
        
        // First, let's check what authentication state we have
        final firebaseService = FirebaseDatabaseService();
        final isFirebaseAuthenticated = firebaseService.isAuthenticated;
        print('Firebase authenticated: $isFirebaseAuthenticated');
        
        // Check guest mode
        final isGuestMode = await GuestAuthService.isGuestMode();
        print('Guest mode: $isGuestMode');
        
        // Initialize and process data using CombinedDatabaseService without launching app
        final service = CombinedDatabaseService();
        print('CombinedDatabaseService created');
        
        // Initialize the service first
        service.initialize();
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
          
          print('Records found - Today: ${todayRecords.length}, Missed: ${missedRecords.length}, No reminder: ${noReminderDateRecords.length}');
          
          // Update widget with the new data
          await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
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
      }    } else if (uri?.host == 'frequency_refresh') {
      try {
        print('Starting frequency data refresh...');
        
        // Update both frequency data and tracking types
        await _updateFrequencyData();
        await _updateTrackingTypesData();
        await _updateCategoriesData();
        print('Frequency, tracking types, and categories data refresh completed');
      } catch (e) {
        print('Error in frequency data refresh: $e');
      }    } else if (uri?.host == 'record_delete') {
      try {
        print('Starting record deletion background processing...');
        
        // Extract parameters from URI
        final category = uri?.queryParameters['category'] ?? '';
        final subCategory = uri?.queryParameters['sub_category'] ?? '';
        final recordTitle = uri?.queryParameters['record_title'] ?? '';
        final action = uri?.queryParameters['action'] ?? 'deleted';
        final requestId = uri?.queryParameters['requestId'] ?? '';
        
        print('Deleting record: $category - $subCategory - $recordTitle (RequestID: $requestId)');
        
        String deleteResult = 'SUCCESS';
        String errorMessage = '';
          try {
          // Initialize database service with retry logic
          final service = CombinedDatabaseService();
          service.initialize();
          
          // Wait a moment for Firebase to be fully ready
          await Future.delayed(Duration(milliseconds: 500));
          
          // Ensure Firebase is authenticated before proceeding
          int retryCount = 0;
          const maxRetries = 3;
          bool operationSuccessful = false;
          
          while (retryCount < maxRetries && !operationSuccessful) {
            try {
              print('Attempting record deletion (attempt ${retryCount + 1}/$maxRetries)');
              
              // Move record to deleted data
              await service.moveToDeletedData(category, subCategory, recordTitle);
              
              operationSuccessful = true;
              print('Record deletion completed successfully');
              
              // Refresh widget data after deletion
              await service.forceDataReprocessing();
              final categorizedData = service.currentCategorizedData;
              
              if (categorizedData != null) {
                final todayRecords = categorizedData['today'] ?? [];
                final missedRecords = categorizedData['missed'] ?? [];
                final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];
                
                await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
                print('Widget refreshed after record deletion');
              }
            } catch (e) {
              retryCount++;
              print('Record deletion attempt $retryCount failed: $e');
              
              if (retryCount < maxRetries) {
                print('Retrying in ${retryCount * 1000}ms...');
                await Future.delayed(Duration(milliseconds: retryCount * 1000));
              } else {
                throw e; // Re-throw on final failure
              }
            }
          }
        } catch (e) {
          print('Error in background record deletion: $e');
          deleteResult = 'ERROR:${e.toString()}';
          errorMessage = e.toString();
        }
          // Save the result to SharedPreferences for the Android side to read
        if (requestId.isNotEmpty) {
          await HomeWidget.saveWidgetData('record_delete_result_$requestId', deleteResult);
          print('Delete result stored for requestId $requestId: $deleteResult');
        }
        
      } catch (e) {
        print('Error in record deletion background callback: $e');
        
        // If we have a requestId, save the error result
        final requestId = uri?.queryParameters['requestId'] ?? '';
        if (requestId.isNotEmpty) {
          await HomeWidget.saveWidgetData('record_delete_result_$requestId', 'ERROR:${e.toString()}');
        }
      }} else if (uri?.host == 'record_update') {
      try {
        print('Starting record update background processing...');
        
        // Extract parameters from URI
        final category = uri?.queryParameters['category'] ?? '';
        final subCategory = uri?.queryParameters['sub_category'] ?? '';
        final recordTitle = uri?.queryParameters['record_title'] ?? '';
        final nextRevisionDate = uri?.queryParameters['next_revision_date'] ?? '';
        final updateDataStr = uri?.queryParameters['update_data'] ?? '{}';
        final requestId = uri?.queryParameters['requestId'] ?? '';
        
        print('Updating record: $category - $subCategory - $recordTitle (RequestID: $requestId)');
        print('Next revision date: $nextRevisionDate');
        
        String updateResult = 'SUCCESS';
        String errorMessage = '';
        
        try {
          // Parse update data
          Map<String, dynamic> updateData = {};
          try {
            updateData = Map<String, dynamic>.from(
              json.decode(updateDataStr) as Map
            );
          } catch (e) {
            print('Error parsing update data: $e');
            updateResult = 'ERROR:Failed to parse update data';
            errorMessage = 'Failed to parse update data: $e';
          }
            if (updateResult == 'SUCCESS') {
            // Initialize database service with retry logic
            final service = CombinedDatabaseService();
            service.initialize();
            
            // Wait a moment for Firebase to be fully ready
            await Future.delayed(Duration(milliseconds: 500));
            
            // Ensure Firebase is authenticated before proceeding
            int retryCount = 0;
            const maxRetries = 3;
            bool operationSuccessful = false;
            
            while (retryCount < maxRetries && !operationSuccessful) {
              try {
                print('Attempting record update (attempt ${retryCount + 1}/$maxRetries)');
                
                // Update the record
                await service.updateRecordRevision(
                  category,
                  subCategory,
                  recordTitle,
                  updateData['date_updated']?.toString() ?? '',
                  '', // description - not changed during revision
                  '', // reminder_time - not changed during revision
                  updateData['completion_counts'] as int? ?? 0,
                  updateData['scheduled_date']?.toString() ?? '',
                  List<String>.from(updateData['dates_updated'] ?? []),
                  updateData['missed_counts'] as int? ?? 0,
                  List<String>.from(updateData['dates_missed_revisions'] ?? []),
                  updateData['status']?.toString() ?? 'Enabled',
                );
                
                operationSuccessful = true;
                print('Record update completed successfully');
                
                // Refresh widget data after update
                await service.forceDataReprocessing();
                final categorizedData = service.currentCategorizedData;
                
                if (categorizedData != null) {
                  final todayRecords = categorizedData['today'] ?? [];
                  final missedRecords = categorizedData['missed'] ?? [];
                  final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];
                  
                  await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
                  print('Widget refreshed after record update');
                }
              } catch (e) {
                retryCount++;
                print('Record update attempt $retryCount failed: $e');
                
                if (retryCount < maxRetries) {
                  print('Retrying in ${retryCount * 1000}ms...');
                  await Future.delayed(Duration(milliseconds: retryCount * 1000));
                } else {
                  throw e; // Re-throw on final failure
                }
              }
            }
            await service.forceDataReprocessing();
            final categorizedData = service.currentCategorizedData;
            
            if (categorizedData != null) {
              final todayRecords = categorizedData['today'] ?? [];
              final missedRecords = categorizedData['missed'] ?? [];
              final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];
              
              await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
              print('Widget refreshed after record update');
            }
          }
        } catch (e) {
          print('Error in background record update: $e');
          updateResult = 'ERROR:${e.toString()}';
          errorMessage = e.toString();
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
      }} else if (uri?.host == 'record_create') {
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
        final requestId = uri?.queryParameters['requestId'] ?? '';
        
        print('Creating record: $selectedCategory - $selectedCategoryCode - $title (RequestID: $requestId)');
        
        String saveResult = 'SUCCESS';
        String errorMessage = '';
        
        try {
          // Parse JSON data
          Map<String, dynamic> durationData = {};
          Map<String, dynamic> customFrequencyParams = {};
          try {
            durationData = Map<String, dynamic>.from(json.decode(durationDataStr) as Map);
            customFrequencyParams = Map<String, dynamic>.from(json.decode(customFrequencyParamsStr) as Map);
          } catch (e) {
            print('Error parsing JSON data: $e');
            saveResult = 'ERROR:Failed to parse save data';
            errorMessage = 'Failed to parse save data: $e';
          }
            if (saveResult == 'SUCCESS') {
            // Initialize database service with retry logic
            final service = CombinedDatabaseService();
            service.initialize();
            
            // Wait a moment for Firebase to be fully ready
            await Future.delayed(Duration(milliseconds: 500));
            
            // Ensure Firebase is authenticated before proceeding
            int retryCount = 0;
            const maxRetries = 3;
            bool operationSuccessful = false;
            
            while (retryCount < maxRetries && !operationSuccessful) {
              try {
                print('Attempting record creation (attempt ${retryCount + 1}/$maxRetries)');
                
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
                );
                
                operationSuccessful = true;
                print('Record creation completed successfully');
                
                // Refresh widget data after creation
                await service.forceDataReprocessing();
                final categorizedData = service.currentCategorizedData;
                
                if (categorizedData != null) {
                  final todayRecords = categorizedData['today'] ?? [];
                  final missedRecords = categorizedData['missed'] ?? [];
                  final noReminderDateRecords = categorizedData['noreminderdate'] ?? [];
                  
                  await updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
                  print('Widget refreshed after record creation');
                }
              } catch (e) {
                retryCount++;
                print('Record creation attempt $retryCount failed: $e');
                
                if (retryCount < maxRetries) {
                  print('Retrying in ${retryCount * 1000}ms...');
                  await Future.delayed(Duration(milliseconds: retryCount * 1000));
                } else {
                  throw e; // Re-throw on final failure
                }
              }
            }
          }
        } catch (e) {
          print('Error in background record creation: $e');
          saveResult = 'ERROR:${e.toString()}';
          errorMessage = e.toString();
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

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      HomeWidget.setAppGroupId(appGroupId);
      _isInitialized = true;
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
    
    // Check both Firebase authentication and guest mode
    final bool isFirebaseAuthenticated = _databaseService.isAuthenticated;
    final bool isGuestMode = await GuestAuthService.isGuestMode();
    final bool isLoggedIn = isFirebaseAuthenticated || isGuestMode;
    
    print('Widget empty data update - Firebase auth: $isFirebaseAuthenticated, Guest mode: $isGuestMode, Final logged in: $isLoggedIn');
    
    await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);
    await HomeWidget.saveWidgetData('lastUpdated', DateTime.now().millisecondsSinceEpoch);
    await _updateWidgetSilently();
  }
  static Future<void> updateWidgetData(
    List<Map<String, dynamic>> todayRecords,
    List<Map<String, dynamic>> missedRecords,
    List<Map<String, dynamic>> noReminderDateRecords,
  ) async {
    try {
      // Check both Firebase authentication and guest mode
      final bool isFirebaseAuthenticated = _databaseService.isAuthenticated;
      final bool isGuestMode = await GuestAuthService.isGuestMode();
      final bool isLoggedIn = isFirebaseAuthenticated || isGuestMode;
        print('Widget update - Firebase auth: $isFirebaseAuthenticated, Guest mode: $isGuestMode, Final logged in: $isLoggedIn');
        await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);      // Update frequency data for AddLectureActivity access
      await _updateFrequencyData();
      
      // Update tracking types data for AddLectureActivity access
      await _updateTrackingTypesData();
      
      // Update categories data for AddLectureActivity access
      await _updateCategoriesData();

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

      // Request widget update
      await _updateWidget();
    } catch (e) {
      // debugPrint('Error updating widget data: $e');
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

    // Notify the native side that data was updated from Flutter
    var platform = MethodChannel('com.imnexerio.revix/widget_refresh');
    try {
      await platform.invokeMethod('refreshCompleted');
    } catch (e) {
      // Channel might not be initialized yet, which is fine
    }
  }

  static Future<void> updateLoginStatus() async {
    final bool isLoggedIn = _databaseService.isAuthenticated;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);
    await _updateWidget();
    // debugPrint('Login status updated: $isLoggedIn');
  }

  static Future<void> refreshWidgetFromExternal() async {
    await initialize();
    final user = _databaseService.currentUser;
    final bool isLoggedIn = user != null;

    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

    if (!isLoggedIn) {
      await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
      await _updateWidget();
      return;
    }

    // The actual refresh will happen in the Kotlin service
    await _updateWidget();
  }

  /// Method to monitor and respond to frequency data requests from native code
  static Future<void> monitorFrequencyDataRequests() async {
    try {
      // Check if native code has requested frequency data update
      final prefs = await SharedPreferences.getInstance();
      final requestTime = prefs.getInt('frequencyDataRequested');
      final lastUpdateTime = prefs.getInt('frequencyDataLastUpdated') ?? 0;
        if (requestTime != null && requestTime > lastUpdateTime) {
        print('Frequency data update requested by native code');
        await _updateFrequencyData();
        await _updateCategoriesData();
        await prefs.setInt('frequencyDataLastUpdated', DateTime.now().millisecondsSinceEpoch);
        print('Frequency and categories data updated in response to native request');
      }
    } catch (e) {
      print('Error monitoring frequency data requests: $e');
    }
  }
}
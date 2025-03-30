import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
import 'UnifiedDatabaseService.dart';

class SubjectDataProvider {
  static final SubjectDataProvider _instance = SubjectDataProvider._internal();
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  // Reference to the UnifiedDatabaseService
  final UnifiedDatabaseService _databaseService = UnifiedDatabaseService();

  // Stream controllers to broadcast data changes
  final _subjectsController = StreamController<Map<String, dynamic>>.broadcast();
  final _rawDataController = StreamController<dynamic>.broadcast();

  // Cached data
  Map<String, dynamic>? _cachedData;
  dynamic _cachedRawData;

  // Subscriptions to UnifiedDatabaseService streams
  StreamSubscription? _allRecordsSubscription;

  // Factory constructor
  factory SubjectDataProvider() {
    return _instance;
  }

  // Private constructor
  SubjectDataProvider._internal() {
    // Initialize the listener when the auth state changes
    _auth.authStateChanges().listen((User? user) {
      _cleanupCurrentListener();
      if (user != null) {
        _setupServiceListener();
      } else {
        _cachedData = null;
        _cachedRawData = null;
      }
    });
  }

  // Setup listeners to the UnifiedDatabaseService
  void _setupServiceListener() {
    // Initialize the UnifiedDatabaseService if not already
    _databaseService.initialize();

    // Subscribe to the allRecordsStream
    _allRecordsSubscription = _databaseService.allRecordsStream.listen((allRecordsData) {
      // Get the raw data from allRecordsData
      List<Map<String, dynamic>> records = allRecordsData['allRecords'] ?? [];

      // Convert to the structure needed for raw data
      if (records.isNotEmpty) {
        // Reconstruct the raw data structure from the records
        Map<String, Map<String, Map<String, dynamic>>> rawData = {};

        for (var record in records) {
          String subject = record['subject'];
          String subjectCode = record['subject_code'];
          String lectureNo = record['lecture_no'];
          Map<String, dynamic> details = record['details'];

          // Create subject if it doesn't exist
          rawData[subject] ??= {};

          // Create subject code if it doesn't exist
          rawData[subject]![subjectCode] ??= {};

          // Add lecture details
          rawData[subject]![subjectCode]![lectureNo] = details;
        }

        // Cache and broadcast the raw data
        _cachedRawData = rawData;
        _rawDataController.add(_cachedRawData);

        // Process for subjects and subject codes
        List<String> subjects = rawData.keys.toList();
        Map<String, List<String>> subjectCodes = {};

        rawData.forEach((subject, value) {
          subjectCodes[subject] = value.keys.toList();
        });

        _cachedData = {
          'subjects': subjects,
          'subjectCodes': subjectCodes,
        };

        // Broadcast the changes
        _subjectsController.add(_cachedData!);
      } else {
        _cachedRawData = null;
        _rawDataController.add(null);

        _cachedData = {'subjects': [], 'subjectCodes': {}};
        _subjectsController.add(_cachedData!);
      }
    }, onError: (error) {
      _subjectsController.addError(error);
      _rawDataController.addError(error);
    });
  }

  // Get the stream that will emit data when changes occur
  Stream<Map<String, dynamic>> get subjectsStream => _subjectsController.stream;

  // Get the stream that will emit raw user_data when changes occur
  Stream<dynamic> get rawDataStream => _rawDataController.stream;

  // Get current data immediately (from cache if available)
  Map<String, dynamic>? get currentData => _cachedData;

  // Get current raw data immediately (from cache if available)
  dynamic get currentRawData => _cachedRawData;

  // Get schedule data as string
  String getScheduleData() {
    if (_cachedRawData != null) {
      return _cachedRawData.toString();
    }
    return 'No schedule data available';
  }

  // Clean up current listener to prevent memory leaks
  void _cleanupCurrentListener() {
    _allRecordsSubscription?.cancel();
    _allRecordsSubscription = null;
  }

  // Manual fetch method (fallback or for initial load)
  Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // Force a refresh from the UnifiedDatabaseService
    await _databaseService.forceDataReprocessing();

    // If we still don't have cached data, return empty result
    if (_cachedData == null) {
      return {'subjects': [], 'subjectCodes': {}};
    }

    return _cachedData!;
  }

  // Fetch only raw data (when needed)
  Future<dynamic> fetchRawData() async {
    if (_cachedRawData != null) {
      return _cachedRawData;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // Force a refresh from the UnifiedDatabaseService
    await _databaseService.forceDataReprocessing();

    return _cachedRawData;
  }

  // Dispose method to clean up resources
  void dispose() {
    _cleanupCurrentListener();
    _subjectsController.close();
    _rawDataController.close();
    // Note: Don't dispose the _databaseService here as it might be used elsewhere
  }
}

// Backward compatibility function that uses the singleton provider
Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
  return await SubjectDataProvider().fetchSubjectsAndCodes();
}

// Get the stream directly
Stream<Map<String, dynamic>> getSubjectsStream() {
  return SubjectDataProvider().subjectsStream;
}
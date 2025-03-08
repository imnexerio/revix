import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class SubjectDataProvider {
  static final SubjectDataProvider _instance = SubjectDataProvider._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Stream controllers to broadcast data changes
  final _subjectsController = StreamController<Map<String, dynamic>>.broadcast();

  // Cached data
  Map<String, dynamic>? _cachedData;

  // Database reference and subscription
  DatabaseReference? _databaseRef;
  StreamSubscription<DatabaseEvent>? _subscription;

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
        _setupDatabaseListener(user.uid);
      } else {
        _cachedData = null;
      }
    });
  }

  // Get the stream that will emit data when changes occur
  Stream<Map<String, dynamic>> get subjectsStream => _subjectsController.stream;

  // Get current data immediately (from cache if available)
  Map<String, dynamic>? get currentData => _cachedData;

  // Setup the database listener
  void _setupDatabaseListener(String uid) {
    _databaseRef = _database.ref('users/$uid/user_data');

    // Optimize by setting keep-sync to true for offline capabilities
    _databaseRef!.keepSynced(true);

    // Listen for changes
    _subscription = _databaseRef!.onValue.listen((event) {
      if (event.snapshot.exists) {
        Map<Object?, Object?> subject_data_util =
        event.snapshot.value as Map<Object?, Object?>;

        List<String> subjects = subject_data_util.keys
            .map((key) => key.toString())
            .toList();

        Map<String, List<String>> subjectCodes = {};

        subject_data_util.forEach((subject, value) {
          if (value is Map) {
            subjectCodes[subject.toString()] =
                value.keys.map((code) => code.toString()).toList();
          }
        });

        _cachedData = {
          'subjects': subjects,
          'subjectCodes': subjectCodes,
        };

        // Broadcast the changes
        _subjectsController.add(_cachedData!);
      } else {
        _cachedData = {'subjects': [], 'subjectCodes': {}};
        _subjectsController.add(_cachedData!);
      }
    }, onError: (error) {
      _subjectsController.addError(error);
    });
  }

  // Clean up current listener to prevent memory leaks
  void _cleanupCurrentListener() {
    _subscription?.cancel();
    _subscription = null;
    _databaseRef = null;
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

    String uid = user.uid;
    DatabaseReference ref = _database.ref('users/$uid/user_data');
    DataSnapshot snapshot = await ref.get();

    if (snapshot.exists) {
      Map<Object?, Object?> subject_data_util = snapshot.value as Map<Object?, Object?>;
      List<String> subjects = subject_data_util.keys
          .map((key) => key.toString())
          .toList();

      Map<String, List<String>> subjectCodes = {};

      subject_data_util.forEach((subject, value) {
        if (value is Map) {
          subjectCodes[subject.toString()] =
              value.keys.map((code) => code.toString()).toList();
        }
      });

      _cachedData = {
        'subjects': subjects,
        'subjectCodes': subjectCodes,
      };

      return _cachedData!;
    } else {
      return {'subjects': [], 'subjectCodes': {}};
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    _cleanupCurrentListener();
    _subjectsController.close();
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
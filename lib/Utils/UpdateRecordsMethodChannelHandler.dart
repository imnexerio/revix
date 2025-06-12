import 'package:flutter/services.dart';
import 'UpdateRecords.dart';

/// Method channel handler for update records communication between native code and Flutter
class UpdateRecordsMethodChannelHandler {
  static const MethodChannel _channel = MethodChannel('revix/update_records');
  
  /// Initialize the method channel handler
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'moveToDeletedData':
          return await _moveToDeletedData(call.arguments);
        case 'updateRecordsRevision':
          return await _updateRecordsRevision(call.arguments);
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Method ${call.method} is not implemented',
          );
      }
    } catch (e) {
      print('Error handling method call ${call.method}: $e');
      throw PlatformException(
        code: 'ERROR',
        message: 'Error executing ${call.method}: $e',
      );
    }
  }
  
  /// Call the Dart moveToDeletedData function
  static Future<bool> _moveToDeletedData(dynamic arguments) async {
    try {
      final Map<String, dynamic> args = Map<String, dynamic>.from(arguments);
      final String category = args['category'];
      final String subCategory = args['subCategory'];
      final String lectureNo = args['lectureNo'];
      final Map<String, dynamic> lectureData = Map<String, dynamic>.from(args['lectureData']);
      
      await moveToDeletedData(category, subCategory, lectureNo, lectureData);
      return true;
    } catch (e) {
      print('Error in moveToDeletedData: $e');
      return false;
    }
  }
  
  /// Call the Dart UpdateRecordsRevision function
  static Future<bool> _updateRecordsRevision(dynamic arguments) async {
    try {
      final Map<String, dynamic> args = Map<String, dynamic>.from(arguments);
      final String category = args['category'];
      final String subCategory = args['subCategory'];
      final String lectureNo = args['lectureNo'];
      final String dateRevised = args['dateRevised'];
      final String description = args['description'];
      final String reminderTime = args['reminderTime'];
      final int noRevision = args['noRevision'];
      final String dateScheduled = args['dateScheduled'];
      final List<String> datesRevised = List<String>.from(args['datesRevised']);
      final int missedRevision = args['missedRevision'];
      final List<String> datesMissedRevisions = List<String>.from(args['datesMissedRevisions']);
      final String status = args['status'];
      
      await UpdateRecordsRevision(
        category,
        subCategory,
        lectureNo,
        dateRevised,
        description,
        reminderTime,
        noRevision,
        dateScheduled,
        datesRevised,
        missedRevision,
        datesMissedRevisions,
        status,
      );
      return true;
    } catch (e) {
      print('Error in UpdateRecordsRevision: $e');
      return false;
    }
  }
}

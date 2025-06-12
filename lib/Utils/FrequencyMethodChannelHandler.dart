import 'package:flutter/services.dart';
import 'FirebaseDatabaseService.dart';

/// Method channel handler for frequency and tracking type data communication between Flutter and native code
class FrequencyMethodChannelHandler {
  static const MethodChannel _channel = MethodChannel('revix/frequency_data');
  static final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  
  /// Initialize the method channel handler
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'getFrequencyData':
          return await _getFrequencyData();
        case 'getFrequencyNames':
          return await _getFrequencyNames();
        case 'getTrackingTypes':
          return await _getTrackingTypes();
        case 'getDefaultFrequencies':
          return _getDefaultFrequencies();
        case 'getDefaultTrackingTypes':
          return _getDefaultTrackingTypes();
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
  
  /// Fetch frequency data from Firebase/Local database
  static Future<Map<String, dynamic>> _getFrequencyData() async {
    try {
      final frequencyData = await _databaseService.fetchCustomFrequencies();
      
      // Convert the data to the format expected by Kotlin
      Map<String, List<int>> convertedData = {};
      
      frequencyData.forEach((key, value) {
        if (value is List) {
          // Convert to List<int>
          List<int> intList = value.map((item) {
            if (item is int) return item;
            if (item is double) return item.toInt();
            if (item is String) return int.tryParse(item) ?? 0;
            return 0;
          }).toList();
          convertedData[key] = intList;
        } else if (value is String) {
          // If it's a string representation of a list, try to parse it
          try {
            // Handle string representations like "[1, 3, 7, 14]"
            String cleanValue = value.replaceAll(RegExp(r'[\[\]]'), '');
            List<String> parts = cleanValue.split(',').map((s) => s.trim()).toList();
            List<int> intList = parts.map((s) => int.tryParse(s) ?? 0).toList();
            convertedData[key] = intList;
          } catch (e) {
            print('Error parsing frequency value for $key: $value');
            convertedData[key] = [];
          }
        }
      });
      
      // Add default frequencies if none exist
      if (convertedData.isEmpty) {
        convertedData = _getDefaultFrequencies();
      }
      
      return convertedData.map((key, value) => MapEntry(key, value));
    } catch (e) {
      print('Error fetching frequency data: $e');
      return _getDefaultFrequencies().map((key, value) => MapEntry(key, value));
    }
  }
  
  /// Get just the frequency names
  static Future<List<String>> _getFrequencyNames() async {
    try {
      final frequencyData = await _getFrequencyData();
      List<String> names = frequencyData.keys.toList();
      
      // Add standard options
      names.addAll(['Custom', 'No Repetition']);
      
      return names;
    } catch (e) {
      print('Error getting frequency names: $e');
      return ['Custom', 'No Repetition'];
    }
  }
  
  /// Get tracking types from Firebase/Local database
  static Future<List<String>> _getTrackingTypes() async {
    try {
      final trackingTypes = await _databaseService.fetchCustomTrackingTypes();
      
      // If no custom tracking types exist, provide defaults
      if (trackingTypes.isEmpty) {
        return _getDefaultTrackingTypes();
      }
      
      return trackingTypes;
    } catch (e) {
      print('Error fetching tracking types: $e');
      return _getDefaultTrackingTypes();
    }
  }
  
  /// Get default frequencies when no custom ones are available
  static Map<String, List<int>> _getDefaultFrequencies() {
    return {
      'Default': [1, 3, 7, 14, 30],
      'Intensive': [1, 2, 4, 8, 16],
      'Relaxed': [3, 7, 21, 45, 90],
      'Weekly': [7, 14, 28, 56],
      'Monthly': [30, 60, 90, 180],
    };
  }
  
  /// Get default tracking types when no custom ones are available
  static List<String> _getDefaultTrackingTypes() {
    return ['Lectures', 'Handouts', 'Others'];
  }
  
  /// Static method to call from native code for getting frequency data
  static Future<Map<String, List<int>>> getFrequencyDataStatic() async {
    final data = await _getFrequencyData();
    return data.map((key, value) => MapEntry(key, List<int>.from(value)));
  }
  
  /// Static method to call from native code for getting frequency names
  static Future<List<String>> getFrequencyNamesStatic() async {
    return await _getFrequencyNames();
  }
  
  /// Static method to call from native code for getting tracking types
  static Future<List<String>> getTrackingTypesStatic() async {
    return await _getTrackingTypes();
  }
}

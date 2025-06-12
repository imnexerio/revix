import 'package:flutter/services.dart';
import 'UnifiedDatabaseService.dart';

/// Method channel handler for categories and subcategories data communication between Flutter and native code
class CategoriesMethodChannelHandler {
  static const MethodChannel _channel = MethodChannel('revix/categories_data');
  static final UnifiedDatabaseService _databaseService = UnifiedDatabaseService();
  
  /// Initialize the method channel handler
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'getCategoriesAndSubCategories':
          return await _getCategoriesAndSubCategories();
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
  
  /// Fetch categories and subcategories data from unified database service
  static Future<Map<String, dynamic>> _getCategoriesAndSubCategories() async {
    try {
      final categoriesData = await _databaseService.loadCategoriesAndSubCategories();
      
      // Convert the data to the format expected by Kotlin
      Map<String, dynamic> convertedData = {
        'subjects': categoriesData['subjects'] ?? [],
        'subCategories': {},
      };
      
      // Convert subcategories map to the format expected by native code
      Map<String, List<String>> subCategoriesMap = Map<String, List<String>>.from(categoriesData['subCategories'] ?? {});
      convertedData['subCategories'] = subCategoriesMap;
      
      print('CategoriesMethodChannelHandler: Returning categories data: $convertedData');
      return convertedData;
    } catch (e) {
      print('Error fetching categories data: $e');
      // Return empty data structure in case of error
      return {
        'subjects': <String>[],
        'subCategories': <String, List<String>>{},
      };
    }
  }
}

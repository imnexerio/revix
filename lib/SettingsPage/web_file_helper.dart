import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class FileHelper {
  /// Save file using native file picker on all platforms
  static Future<String?> saveToFile(String data, String filename) async {
    try {
      // Use file_picker for all platforms - it handles web, mobile, and desktop
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save your data backup',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(data)), // Use UTF-8 encoding for proper Unicode support
      );

      if (outputFile != null) {
        // For mobile/desktop platforms, write to the selected file
        final file = File(outputFile);
        await file.writeAsString(data);
        return file.path;
      }
      
      return null; // User canceled the save dialog
    } catch (e) {
      throw Exception('Error saving file: $e');
    }
  }
  
  /// Pick and read a file using native file picker on all platforms
  static Future<String?> pickAndReadFile() async {
    try {
      // Use file_picker for all platforms
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: true, // This loads file content for web
      );

      if (result != null) {
        final file = result.files.single;
        
        // For web, use the bytes directly
        if (file.bytes != null) {
          return String.fromCharCodes(file.bytes!);
        }
        
        // For mobile/desktop, read from file path
        if (file.path != null) {
          final fileObj = File(file.path!);
          return await fileObj.readAsString();
        }
      }
      
      return null; // User canceled the picker
    } catch (e) {
      throw Exception('Error picking file: $e');
    }
  }
  
  /// Read from file path (mainly for fallback scenarios)
  static Future<String?> readFromFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      return await file.readAsString();
    } catch (e) {
      throw Exception('Error reading file: $e');
    }
  }
  
  /// Get hint text for manual file path entry (fallback only)
  static String getHintText() {
    return 'Use the file picker to select your exported JSON file';
  }
  
  /// Download file (legacy method for compatibility)
  static Future<void> downloadFile(String data, String filename) async {
    // Use saveToFile instead - it works on all platforms
    await saveToFile(data, filename);
  }
}

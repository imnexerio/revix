import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        // Platform-specific handling
        if (kIsWeb) {
          // On web, the file is automatically downloaded when bytes are provided
          // Return a user-friendly message since we can't get the actual file path
          return filename; // Return the filename for user feedback
        } else {
          // On mobile/desktop platforms
          // The file might already be saved by the picker when bytes are provided
          // Try to write to the file only if it looks like a valid file path
          try {
            // Check if it's a proper file path (not a content URI)
            if (outputFile.startsWith('/') || outputFile.contains('\\') || 
                (outputFile.contains(':/') && !outputFile.startsWith('content:'))) {
              // Looks like a proper file path, try to write
              final file = File(outputFile);
              if (await file.parent.exists()) {
                await file.writeAsString(data, encoding: utf8);
              }
            }
            // Return the path/URI regardless - the file has been saved by the picker
            return outputFile;
          } catch (e) {
            // If writing fails, that's okay - the file picker already saved the file
            // Just return the path for user information
            return outputFile;
          }
        }
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
        withData: true, // This loads file content for web and provides fallback for mobile
      );

      if (result != null) {
        final file = result.files.single;
        
        // Try bytes first (works on all platforms, required for web)
        if (file.bytes != null) {
          return utf8.decode(file.bytes!);
        }
        
        // Fallback to file path for mobile/desktop when bytes aren't available
        if (!kIsWeb && file.path != null) {
          final fileObj = File(file.path!);
          return await fileObj.readAsString(encoding: utf8);
        }
        
        // If we reach here, something went wrong
        throw Exception('Unable to read file content');
      }
      
      return null; // User canceled the picker
    } catch (e) {
      throw Exception('Error picking file: $e');
    }
  }
  
  /// Read from file path (mainly for fallback scenarios)
  static Future<String?> readFromFile(String filePath) async {
    // This method is mainly for desktop platforms or when file paths are manually entered
    if (kIsWeb) {
      throw Exception('File path reading is not supported on web. Use the file picker instead.');
    }
    
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      return await file.readAsString(encoding: utf8);
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

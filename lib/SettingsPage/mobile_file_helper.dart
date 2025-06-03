import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileHelper {
  static Future<String?> saveToFile(String data, String filename) async {
    try {
      Directory? directory;
      
      if (Platform.isAndroid) {
        // For Android, use the Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        // For iOS, use the Documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // For other platforms (Windows, macOS, Linux), use Downloads
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('Unable to access storage directory');
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsString(data);
      
      return file.path;
    } catch (e) {
      throw Exception('Error saving file: $e');
    }
  }
  
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
  
  static String getHintText() {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download/retracker_data_xxxxx.json';
    } else if (Platform.isIOS) {
      return 'Documents/retracker_data_xxxxx.json';
    } else if (Platform.isWindows) {
      return 'C:\\Users\\YourName\\Downloads\\retracker_data_xxxxx.json';
    } else {
      return '/Users/YourName/Downloads/retracker_data_xxxxx.json';
    }
  }
  
  // Mobile doesn't use these methods but need them for compatibility
  static Future<void> downloadFile(String data, String filename) async {
    throw UnsupportedError('Use saveToFile for mobile');
  }
  
  static Future<String?> pickAndReadFile() async {
    throw UnsupportedError('Use file path input for mobile');
  }
}

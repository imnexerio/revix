import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class FileHelper {
  static Future<void> downloadFile(String data, String filename) async {
    final bytes = utf8.encode(data);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    
    html.Url.revokeObjectUrl(url);
  }
  
  static Future<String?> pickAndReadFile() async {
    final input = html.FileUploadInputElement()
      ..accept = '.json'
      ..click();

    await input.onChange.first;
    
    if (input.files?.isNotEmpty ?? false) {
      final file = input.files!.first;
      final reader = html.FileReader();
      
      // Use a completer to handle the async file reading
      final completer = Completer<String>();
      
      reader.onLoadEnd.listen((e) {
        completer.complete(reader.result as String);
      });
      
      reader.onError.listen((e) {
        completer.completeError('Error reading file');
      });
      
      reader.readAsText(file);
      return await completer.future;
    }
    
    return null;
  }
  
  // Web doesn't use these methods but need them for compatibility
  static Future<String?> saveToFile(String data, String filename) async {
    throw UnsupportedError('Use downloadFile for web');
  }
  
  static Future<String?> readFromFile(String filePath) async {
    throw UnsupportedError('Use pickAndReadFile for web');
  }
  
  static String getHintText() {
    return 'Select a JSON file from your computer';
  }
}

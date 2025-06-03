import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:retracker/Utils/DataMigrationService.dart';
import 'package:retracker/Utils/GuestAuthService.dart';
// Web-specific imports - only imported when compiled for web
import 'dart:html' as html show AnchorElement, FileReader, File, FileUploadInputElement, Blob, Url;

/// Widget for managing guest user data with options to:
/// 1. Create a new account and automatically upload data to Firebase
/// 2. Export data manually as JSON
/// 3. Import data manually from JSON
/// 
/// The "Create Account" feature provides a seamless way for guest users
/// to transition to a permanent account without losing their data.
class GuestDataManagementWidget extends StatefulWidget {
  const GuestDataManagementWidget({Key? key}) : super(key: key);

  @override
  _GuestDataManagementWidgetState createState() => _GuestDataManagementWidgetState();
}

class _GuestDataManagementWidgetState extends State<GuestDataManagementWidget> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCreatingAccount = false;
  final TextEditingController _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }  Future<void> _exportGuestData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final data = await DataMigrationService.exportGuestData();
      setState(() {
        _isExporting = false;
      });

      if (data != null) {
        if (kIsWeb) {
          await _downloadDataOnWeb(data);
        } else {
          await _saveDataToFile(data);
        }
      } else {
        _showSnackBar('No data to export');
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      _showSnackBar('Error exporting data: $e');
    }
  }

  Future<void> _downloadDataOnWeb(String data) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'retracker_data_$timestamp.json';
      
      final bytes = utf8.encode(data);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      
      html.Url.revokeObjectUrl(url);
      
      _showSnackBar('Data exported successfully! Check your Downloads folder for $filename');
    } catch (e) {
      _showSnackBar('Error downloading file: $e');
    }
  }
  Future<void> _saveDataToFile(String data) async {
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
        _showSnackBar('Unable to access storage directory');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'retracker_data_$timestamp.json';
      final file = File('${directory.path}/$filename');
      
      await file.writeAsString(data);
      
      await _showExportSuccessDialog(file.path);
    } catch (e) {
      _showSnackBar('Error saving file: $e');
    }
  }

  Future<void> _showExportSuccessDialog(String filePath) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your data has been exported successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('File saved to:'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Text(
                filePath,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Keep this file safe. You can use it to restore your data later.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
              _showSnackBar('File path copied to clipboard');
            },
            child: const Text('Copy Path'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }  Future<void> _showImportDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how you want to import your data:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (kIsWeb) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickFileOnWeb();
                  },
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Select File'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickAndImportFile();
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select File'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'OR',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showPasteDataDialog();
                },
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste Data'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  Future<void> _pickAndImportFile() async {
    try {
      // Create a simple file picker dialog for non-web platforms
      await _showFilePickerDialog();
    } catch (e) {
      _showSnackBar('Error picking file: $e');
    }
  }

  Future<void> _pickFileOnWeb() async {
    try {
      final input = html.FileUploadInputElement()
        ..accept = '.json'
        ..click();

      await input.onChange.first;
      
      if (input.files?.isNotEmpty ?? false) {
        final file = input.files!.first;
        final reader = html.FileReader();
        
        reader.onLoadEnd.listen((e) async {
          final content = reader.result as String;
          await _importGuestData(content);
        });
        
        reader.onError.listen((e) {
          _showSnackBar('Error reading file');
        });
        
        reader.readAsText(file);
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e');
    }
  }

  Future<void> _showFilePickerDialog() async {
    _importController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter File Path'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the full path to your exported JSON file:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),            TextField(
              controller: _importController,
              decoration: InputDecoration(
                hintText: Platform.isAndroid 
                    ? '/storage/emulated/0/Download/retracker_data_xxxxx.json'
                    : Platform.isIOS
                        ? 'Documents/retracker_data_xxxxx.json'
                        : Platform.isWindows
                            ? 'C:\\Users\\YourName\\Downloads\\retracker_data_xxxxx.json'
                            : '/Users/YourName/Downloads/retracker_data_xxxxx.json',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
                filled: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: You can find the file path from the export success message',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (_importController.text.isEmpty) {
                _showSnackBar('Please enter file path');
                return;
              }
              Navigator.pop(context);
              await _importFromFile(_importController.text.trim());
            },
            icon: const Icon(Icons.upload),
            label: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFile(String filePath) async {
    setState(() {
      _isImporting = true;
    });

    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        _showSnackBar('File not found: $filePath');
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final data = await file.readAsString();
      
      // Validate JSON format
      try {
        json.decode(data);
      } catch (e) {
        _showSnackBar('Invalid JSON format in file');
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final success = await DataMigrationService.importGuestData(data);
      setState(() {
        _isImporting = false;
      });

      if (success) {
        _showSnackBar('Data imported successfully from file');
      } else {
        _showSnackBar('Failed to import data from file');
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      _showSnackBar('Error reading file: $e');
    }
  }

  Future<void> _showPasteDataDialog() async {
    _importController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste your previously exported data here.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _importController,
              decoration: InputDecoration(
                hintText: 'Paste data here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
                filled: true,
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (_importController.text.isEmpty) {
                _showSnackBar('Please paste data to import');
                return;
              }
              Navigator.pop(context);
              await _importGuestData(_importController.text);
            },
            icon: const Icon(Icons.upload),
            label: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _importGuestData(String data) async {
    setState(() {
      _isImporting = true;
    });

    try {
      // Validate JSON format
      try {
        json.decode(data);
      } catch (e) {
        _showSnackBar('Invalid data format');
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final success = await DataMigrationService.importGuestData(data);
      setState(() {
        _isImporting = false;
      });

      if (success) {
        _showSnackBar('Data imported successfully');
      } else {
        _showSnackBar('Failed to import data');
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      _showSnackBar('Error importing data: $e');
    }
  }
  Future<void> _createAccountAndMigrate() async {
    setState(() {
      _isCreatingAccount = true;
    });

    try {
      await DataMigrationService.createAccountAndMigrateData(context);
      setState(() {
        _isCreatingAccount = false;
      });

      // Note: If successful, the user will be navigated to the login page
      // so this setState might not execute if the widget is disposed
    } catch (e) {
      setState(() {
        _isCreatingAccount = false;
      });
      _showSnackBar('Error creating account: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: GuestAuthService.isGuestMode(),
      builder: (context, snapshot) {
        final isGuestMode = snapshot.data ?? false;
        
        if (!isGuestMode) {
          return const SizedBox.shrink();
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.storage,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Guest Data Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),                const SizedBox(height: 16),                const Text(
                  'In guest mode, all your data is stored locally on this device. '
                  'Create an account to sync your data to the cloud, or export your data as a file for backup.',
                ),
                const SizedBox(height: 16),
                
                // Create Account Button (Primary Action)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingAccount ? null : _createAccountAndMigrate,
                    icon: _isCreatingAccount
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.person_add),
                    label: const Text('Create Account & Upload Data'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Divider with text
                Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Manual Export/Import Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _exportGuestData,
                        icon: _isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: const Text('Export as File'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isImporting ? null : _showImportDialog,
                        icon: _isImporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.upload),
                        label: const Text('Import from File'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

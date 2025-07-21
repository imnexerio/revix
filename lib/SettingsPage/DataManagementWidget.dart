import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:revix/Utils/CustomSnackBar.dart';
import 'package:revix/Utils/customSnackBar_error.dart';
import 'package:revix/Utils/DataMigrationService.dart';
import 'package:revix/Utils/GuestAuthService.dart';
import 'package:revix/Utils/FirebaseDatabaseService.dart';
import 'package:revix/Utils/LocalDatabaseService.dart';

// Conditional imports for platform-specific functionality
import 'web_file_helper.dart' if (dart.library.io) 'mobile_file_helper.dart' as file_helper;

/// Universal Data Management Widget for both guest and authenticated users
/// Features:
/// - Export user data as JSON (works for both guest and authenticated users)
/// - Import data from JSON (works for both guest and authenticated users)
/// - For guest users: Create account and migrate data to Firebase
/// - For authenticated users: Manual backup and restore capabilities
class DataManagementWidget extends StatefulWidget {
  const DataManagementWidget({Key? key}) : super(key: key);

  @override
  _DataManagementWidgetState createState() => _DataManagementWidgetState();
}

class _DataManagementWidgetState extends State<DataManagementWidget> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCreatingAccount = false;
  final TextEditingController _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }
  
  /// Export user data - works for both guest and authenticated users
  Future<void> _exportUserData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final isGuestMode = await GuestAuthService.isGuestMode();
      String? data;
      
      if (isGuestMode) {
        // Use existing guest export functionality
        data = await DataMigrationService.exportGuestData();
      } else {
        // Export authenticated user data
        data = await _exportAuthenticatedUserData();
      }
      
      setState(() {
        _isExporting = false;
      });

      if (data != null) {
        // Format the JSON data with proper indentation
        String formattedData;
        try {
          final jsonData = json.decode(data);
          const encoder = JsonEncoder.withIndent('  '); // 2 spaces indentation
          formattedData = encoder.convert(jsonData);
        } catch (e) {
          // If JSON parsing fails, use original data
          formattedData = data;
        }
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final userType = isGuestMode ? 'guest' : 'user';
        final filename = 'revix_${userType}_data_$timestamp.json';
        
        if (kIsWeb) {
          await file_helper.FileHelper.downloadFile(formattedData, filename);
          customSnackBar(
            context: context,
            message: 'Data exported successfully! Check your Downloads folder for $filename'
          );
        } else {
          final filePath = await file_helper.FileHelper.saveToFile(formattedData, filename);
          if (filePath != null) {
            await _showExportSuccessDialog(filePath);
          }
        }
      } else {
        customSnackBar_error(
          context: context,
          message: 'No data to export'
        );
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      customSnackBar_error(
        context: context,
        message: 'Error exporting data: $e'
      );
    }
  }

  /// Export data for authenticated users
  Future<String?> _exportAuthenticatedUserData() async {
    try {
      final firebaseService = FirebaseDatabaseService();
      final userId = firebaseService.currentUserId;
      
      if (userId == null) {
        return null;
      }
      
      // Get user data from Firebase
      final userData = await firebaseService.getUserData(userId);
      final profileData = await firebaseService.getProfileData(userId);
      
      if (userData == null && profileData == null) {
        return null; // No data to export
      }
      
      // Create export data structure
      Map<String, dynamic> exportData = {
        'user_data': userData ?? {},
        'profile_data': profileData ?? {},
        'export_info': {
          'user_id': userId,
          'export_date': DateTime.now().toIso8601String(),
          'user_type': 'authenticated'
        }
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      print("Error exporting authenticated user data: $e");
      return null;
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
              customSnackBar(
                context: context,
                message: 'File path copied to clipboard'
              );
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
  }

  Future<void> _showImportDialog() async {
    final isGuestMode = await GuestAuthService.isGuestMode();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isGuestMode 
                ? 'Choose how you want to import your data:'
                : 'Import data from a previously exported backup file:',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
      await _showFilePickerDialog();
    } catch (e) {
      customSnackBar_error(
        context: context,
        message: 'Error picking file: $e'
      );
    }
  }

  Future<void> _pickFileOnWeb() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final content = await file_helper.FileHelper.pickAndReadFile();
      
      setState(() {
        _isImporting = false;
      });
      
      if (content != null) {
        await _importUserData(content);
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      customSnackBar_error(
        context: context,
        message: 'Error picking file: $e'
      );
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
            const SizedBox(height: 12),
            TextField(
              controller: _importController,
              decoration: InputDecoration(
                hintText: file_helper.FileHelper.getHintText(),
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
                customSnackBar_error(
                  context: context,
                  message: 'Please enter file path'
                );
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
      final data = await file_helper.FileHelper.readFromFile(filePath);
      if (data != null) {
        // Validate JSON format
        try {
          json.decode(data);
        } catch (e) {
          customSnackBar_error(
            context: context,
            message: 'Invalid JSON format in file'
          );
          setState(() {
            _isImporting = false;
          });
          return;
        }

        await _importUserData(data);
      } else {
        setState(() {
          _isImporting = false;
        });
        customSnackBar_error(
          context: context,
          message: 'Could not read file'
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      customSnackBar_error(
        context: context,
        message: 'Error reading file: $e'
      );
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
                customSnackBar_error(
                  context: context,
                  message: 'Please paste data to import'
                );
                return;
              }
              Navigator.pop(context);
              await _importUserData(_importController.text);
            },
            icon: const Icon(Icons.upload),
            label: const Text('Import'),
          ),
        ],
      ),
    );
  }

  /// Import user data - works for both guest and authenticated users
  Future<void> _importUserData(String data) async {
    setState(() {
      _isImporting = true;
    });

    try {
      // Validate JSON format
      Map<String, dynamic> importData;
      try {
        importData = json.decode(data);
      } catch (e) {
        customSnackBar_error(
          context: context,
          message: 'Invalid data format'
        );
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final isGuestMode = await GuestAuthService.isGuestMode();
      bool success = false;
      
      if (isGuestMode) {
        // Use existing guest import functionality
        success = await DataMigrationService.importGuestData(data);
      } else {
        // Import for authenticated users
        success = await _importAuthenticatedUserData(importData);
      }

      setState(() {
        _isImporting = false;
      });
      
      if (success) {
        customSnackBar(
          context: context,
          message: 'Data imported successfully'
        );
      } else {
        customSnackBar_error(
          context: context,
          message: 'Failed to import data'
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      customSnackBar_error(
        context: context,
        message: 'Error importing data: $e'
      );
    }
  }

  /// Import data for authenticated users
  Future<bool> _importAuthenticatedUserData(Map<String, dynamic> importData) async {
    try {
      final firebaseService = FirebaseDatabaseService();
      final userId = firebaseService.currentUserId;
      
      if (userId == null) {
        return false;
      }
      
      if (!importData.containsKey('user_data')) {
        return false; // Invalid import data
      }
      
      // Show confirmation dialog for authenticated users
      final confirmed = await _showImportConfirmationDialog();
      if (!confirmed) {
        return false;
      }
      
      // Import user data to Firebase
      if (importData['user_data'] != null) {
        await firebaseService.setUserData(userId, importData['user_data']);
      }
      
      // Import profile data if available
      if (importData['profile_data'] != null) {
        await firebaseService.setProfileData(userId, importData['profile_data']);
      }
      
      return true;
    } catch (e) {
      print("Error importing authenticated user data: $e");
      return false;
    }
  }

  Future<bool> _showImportConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Confirm Import'),
          ],
        ),
        content: const Text(
          'This will replace your current data with the imported data. '
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    return result ?? false;
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
    } catch (e) {
      setState(() {
        _isCreatingAccount = false;
      });
      customSnackBar_error(
        context: context, 
        message: 'Error creating account: $e'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: GuestAuthService.isGuestMode(),
      builder: (context, snapshot) {
        final isGuestMode = snapshot.data ?? false;
        
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
                      'Data Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Different descriptions based on user type
                Text(
                  isGuestMode
                      ? 'In guest mode, all your data is stored locally on this device. '
                        'Create an account to sync your data to the cloud, or export your data as a file for backup.'
                      : 'Backup and restore your data. Export your data as a file for safekeeping, '
                        'or import data from a previous backup.',
                ),
                const SizedBox(height: 16),
                
                // Create Account Button (Only for guest users)
                if (isGuestMode) ...[
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
                ],
                
                // Export/Import Buttons (Available for all users)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _exportUserData,
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
                        label: const Text('Export Data'),
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
                        label: const Text('Import Data'),
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

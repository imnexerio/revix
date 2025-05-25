import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:retracker/Utils/DataMigrationService.dart';
import 'package:retracker/Utils/GuestAuthService.dart';

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
  }
  Future<void> _exportGuestData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final data = await DataMigrationService.exportGuestData();
      setState(() {
        _isExporting = false;
      });

      if (data != null) {
        await _showExportDialog(data);
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

  Future<void> _showExportDialog(String data) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy this data to save your records. You can import it later.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      data.length > 100 
                          ? '${data.substring(0, 100)}...' 
                          : data,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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
            onPressed: () {
              Clipboard.setData(ClipboardData(text: data));
              _showSnackBar('Data copied to clipboard');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    _importController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
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
                ),                const SizedBox(height: 16),
                const Text(
                  'In guest mode, all your data is stored locally on this device. '
                  'Create an account to sync your data to the cloud and access it from any device.',
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

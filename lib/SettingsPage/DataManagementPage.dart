import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:revix/Utils/CustomSnackBar.dart';
import 'package:revix/Utils/customSnackBar_error.dart';
import 'package:revix/Utils/DataMigrationService.dart';
import 'package:revix/Utils/GuestAuthService.dart';
import 'package:revix/Utils/FirebaseDatabaseService.dart';
import 'package:revix/Utils/LocalDatabaseService.dart';
import 'package:revix/Utils/PublicHolidayFetcher.dart';
import 'file_helper.dart' as file_helper;

/// Features:
/// - Export user data as JSON (works for both guest and authenticated users)
/// - Import data from JSON (works for both guest and authenticated users)
/// - For guest users: Create account and migrate data to Firebase
/// - For authenticated users: Manual backup and restore capabilities
class DataManagementPage extends StatefulWidget {
  const DataManagementPage({Key? key}) : super(key: key);

  @override
  _DataManagementPageState createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCreatingAccount = false;
  final TextEditingController _importController = TextEditingController();
  
  // Cache guest mode status to avoid repeated FutureBuilder calls
  bool? _isGuestMode;
  bool _isLoadingGuestMode = true;
  
  // Public Holidays state
  final PublicHolidayFetcher _holidayFetcher = PublicHolidayFetcher();
  bool _isLoadingCountries = false;
  bool _isFetchingHolidays = false;
  bool _isImportingHolidays = false;
  List<Map<String, String>> _availableCountries = [];
  List<Map<String, dynamic>> _fetchedHolidays = [];
  String? _selectedCountryCode;
  String? _selectedCountryName;
  int _selectedYear = DateTime.now().year;
  bool _showHolidayPreview = false;
  Map<String, dynamic> _holidayFetchHistory = {};

  @override
  void initState() {
    super.initState();
    _loadGuestModeStatus();
    _loadCountries();
    _loadHolidayFetchHistory();
  }

  Future<void> _loadGuestModeStatus() async {
    try {
      final isGuest = await GuestAuthService.isGuestMode();
      if (mounted) {
        setState(() {
          _isGuestMode = isGuest;
          _isLoadingGuestMode = false;
        });
      }
    } catch (e) {
      print('Error loading guest mode status: $e');
      if (mounted) {
        setState(() {
          _isGuestMode = false;
          _isLoadingGuestMode = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCountries() async {
    setState(() => _isLoadingCountries = true);
    
    try {
      _availableCountries = await _holidayFetcher.fetchAvailableCountries();
      
      // Set default to India
      final india = _availableCountries.firstWhere(
        (c) => c['code'] == 'IN',
        orElse: () => _availableCountries.first,
      );
      
      setState(() {
        _selectedCountryCode = india['code'];
        _selectedCountryName = india['name'];
        _isLoadingCountries = false;
      });
    } catch (e) {
      setState(() => _isLoadingCountries = false);
      customSnackBar_error(
        context: context,
        message: 'Error loading countries: $e',
      );
    }
  }
  
  Future<void> _loadHolidayFetchHistory() async {
    try {
      final history = await FirebaseDatabaseService().fetchHolidayFetchHistory();
      print('DEBUG: Loaded holiday history: $history');
      setState(() {
        _holidayFetchHistory = history;
      });
      print('DEBUG: History is empty: ${_holidayFetchHistory.isEmpty}');
    } catch (e) {
      print('Error loading holiday fetch history: $e');
    }
  }
  
  Future<void> _fetchHolidays() async {
    if (_selectedCountryCode == null) {
      customSnackBar_error(
        context: context,
        message: 'Please select a country',
      );
      return;
    }
    
    setState(() {
      _isFetchingHolidays = true;
      _showHolidayPreview = false;
      _fetchedHolidays = [];
    });
    
    try {
      final holidays = await _holidayFetcher.fetchHolidaysFromAPI(
        countryCode: _selectedCountryCode!,
        year: _selectedYear,
      );
      
      setState(() {
        _fetchedHolidays = holidays;
        _isFetchingHolidays = false;
        _showHolidayPreview = holidays.isNotEmpty;
      });
      
      if (holidays.isEmpty) {
        customSnackBar_error(
          context: context,
          message: 'No holidays found for $_selectedCountryName $_selectedYear',
        );
      }
    } catch (e) {
      setState(() {
        _isFetchingHolidays = false;
        _showHolidayPreview = false;
      });
      
      customSnackBar_error(
        context: context,
        message: 'Error fetching holidays: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }
  
  Future<void> _importHolidays() async {
    if (_fetchedHolidays.isEmpty || _selectedCountryCode == null) return;
    
    setState(() => _isImportingHolidays = true);
    
    try {
      final result = await _holidayFetcher.fetchAndSaveHolidays(
        countryCode: _selectedCountryCode!,
        year: _selectedYear,
      );
      
      setState(() {
        _isImportingHolidays = false;
        _showHolidayPreview = false;
        _fetchedHolidays = [];
      });
      
      final success = result['success'] ?? 0;
      final failed = result['failed'] ?? 0;
      final total = result['total'] ?? 0;
      
      if (success > 0) {
        // Save to history on successful import
        final updatedHistory = Map<String, dynamic>.from(_holidayFetchHistory);
        updatedHistory[_selectedCountryCode!] = {
          'date': DateTime.now().toIso8601String(),
          'count': success,
        };
        
        await FirebaseDatabaseService().saveHolidayFetchHistory(updatedHistory);
        await _loadHolidayFetchHistory();
        
        customSnackBar(
          context: context,
          message: failed > 0
            ? '✅ Imported $success/$total holidays ($failed failed)'
            : '✅ Successfully imported $success holidays!',
        );
      } else {
        customSnackBar_error(
          context: context,
          message: 'Failed to import holidays',
        );
      }
    } catch (e) {
      setState(() => _isImportingHolidays = false);
      
      customSnackBar_error(
        context: context,
        message: 'Error importing holidays: $e',
      );
    }
  }
  
  void _cancelHolidayPreview() {
    setState(() {
      _showHolidayPreview = false;
      _fetchedHolidays = [];
    });
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

      if (data != null && data.trim().isNotEmpty) {
        // Validate that the data is actually valid JSON before formatting
        String formattedData;
        try {
          final jsonData = json.decode(data);
          // Ensure we have actual data to export
          if (jsonData is Map && jsonData.isEmpty) {
            customSnackBar_error(
              context: context,
              message: 'No data available to export'
            );
            return;
          }
          const encoder = JsonEncoder.withIndent('  '); // 2 spaces indentation
          formattedData = encoder.convert(jsonData);
        } catch (e) {
          // If JSON parsing fails, it means our export data is corrupted
          customSnackBar_error(
            context: context,
            message: 'Error formatting export data: $e'
          );
          return;
        }
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final userType = isGuestMode ? 'guest' : 'user';
        final filename = 'revix_${userType}_data_$timestamp.json';
        
        // Use unified file picker for all platforms
        final filePath = await file_helper.FileHelper.saveToFile(formattedData, filename);
        if (filePath != null) {
          await _showExportSuccessDialog(filePath, filename);
        } else {
          // User canceled the save dialog
          customSnackBar(
            context: context,
            message: 'Export canceled'
          );
        }
      } else {
        customSnackBar_error(
          context: context,
          message: 'No data to export'
        );
      }
    } catch (e) {
      print("Error exporting user data: $e");
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
      
      // Get all user data from Firebase in a single call
      final allUserData = await firebaseService.getAllUserData(userId);
      
      if (allUserData == null || allUserData.isEmpty) {
        return null; // No data to export
      }

      
      return jsonEncode(allUserData);
    } catch (e) {
      print("Error exporting authenticated user data: $e");
      return null;
    }
  }

  Future<void> _showExportSuccessDialog(String filePath, String filename) async {
    // Check if the path is a URI/content path or a regular file path
    final bool isReadablePath = filePath.startsWith('/') || filePath.contains('\\') || filePath.contains(':/');
    final String displayPath = isReadablePath ? filePath : 'Downloaded to your device as: $filename';
    
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
            Text(isReadablePath ? 'File saved to:' : 'File saved:'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Text(
                displayPath,
                style: TextStyle(
                  fontFamily: isReadablePath ? 'monospace' : null,
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
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    setState(() {
      _isImporting = true;
    });

    try {
      // Use the mobile file helper to pick and read file directly with native file picker
      final content = await file_helper.FileHelper.pickAndReadFile();
      
      setState(() {
        _isImporting = false;
      });
      
      if (content != null) {
        await _importUserData(content);
      } else {
        // User canceled the file picker
        customSnackBar(
          context: context,
          message: 'File selection canceled'
        );
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
      // Validate input data
      if (data.trim().isEmpty) {
        customSnackBar_error(
          context: context,
          message: 'Empty file or no data found'
        );
        setState(() {
          _isImporting = false;
        });
        return;
      }

      // Validate JSON format with detailed error reporting
      Map<String, dynamic> importData;
      try {
        importData = json.decode(data);
      } catch (e) {
        String errorMessage = 'Invalid JSON format';
        if (e is FormatException) {
          errorMessage = 'Invalid JSON format: ${e.message}';
        }
        customSnackBar_error(
          context: context,
          message: errorMessage
        );
        setState(() {
          _isImporting = false;
        });
        return;
      }

      // Additional validation: ensure we have valid data structure
      if (importData.isEmpty) {
        customSnackBar_error(
          context: context,
          message: 'File contains no data to import'
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
      
      // Remove export_info if it exists (it's metadata, not user data)
      Map<String, dynamic> cleanedData = Map.from(importData);
      cleanedData.remove('export_info');
      
      if (cleanedData.isEmpty) {
        return false; // No valid data to import
      }
      
      // Show confirmation dialog for authenticated users
      final confirmed = await _showImportConfirmationDialog();
      if (!confirmed) {
        return false;
      }
      
      // Import all user data to Firebase in a single call
      await firebaseService.setAllUserData(userId, cleanedData);
      
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
    // Use cached guest mode status instead of FutureBuilder
    if (_isLoadingGuestMode) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final isGuestMode = _isGuestMode ?? false;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Data Management Card
          Card(
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
                          onPressed: _isImporting ? null : _pickAndImportFile,
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
          ),
          
          // Public Holidays Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.celebration,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Public Holidays',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fetch public holidays from around the world. Holidays will automatically appear in your calendar and schedule.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_showHolidayPreview)
                    _buildHolidayPreviewSection()
                  else
                    _buildHolidayFetchSection(),
                ],
              ),
            ),
          ),
          
          // Holiday Import History Section
          if (_holidayFetchHistory.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Holiday Import History',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._buildHistoryList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildHolidayFetchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country Dropdown
        _isLoadingCountries
          ? Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.public),
              ),
              value: _selectedCountryCode,
              isExpanded: true,
              items: _availableCountries.map((country) {
                return DropdownMenuItem(
                  value: country['code'],
                  child: Text('${country['name']} (${country['code']})'),
                );
              }).toList(),
              onChanged: (value) {
                final country = _availableCountries.firstWhere(
                  (c) => c['code'] == value,
                );
                setState(() {
                  _selectedCountryCode = value;
                  _selectedCountryName = country['name'];
                });
              },
            ),
        
        const SizedBox(height: 16),
        
        // Year Display (Current Year Only)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Year',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    _selectedYear.toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Current Year',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Fetch Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isFetchingHolidays ? null : _fetchHolidays,
            icon: _isFetchingHolidays
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.download),
            label: Text(_isFetchingHolidays ? 'Fetching...' : 'Fetch Holidays'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHolidayPreviewSection() {
    return Column(
      children: [
        // Preview Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.preview,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview Holidays',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Found ${_fetchedHolidays.length} holidays for $_selectedCountryName for next 365 days',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Holidays List (Max height with scrolling)
        Container(
          constraints: BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _fetchedHolidays.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final holiday = _fetchedHolidays[index];
              final name = holiday['name'] ?? 'Unknown';
              final localName = holiday['localName'] ?? name;
              final date = holiday['date'] ?? '';
              
              // Parse and format date
              String formattedDate = date;
              try {
                final dateTime = DateTime.parse(date);
                final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                               'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                formattedDate = '${months[dateTime.month]} ${dateTime.day}, ${dateTime.year}';
              } catch (e) {
                // Keep original if parsing fails
              }
              
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.event,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (localName != name) ...[
                      SizedBox(height: 2),
                      Text(
                        localName,
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                    SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                isThreeLine: localName != name,
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isImportingHolidays ? null : _cancelHolidayPreview,
                child: Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _isImportingHolidays ? null : _importHolidays,
                icon: _isImportingHolidays
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.check, size: 20),
                label: Text(
                  _isImportingHolidays 
                    ? 'Importing...' 
                    : 'Import All (${_fetchedHolidays.length})',
                  style: TextStyle(fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// Build list of holiday import history items
  List<Widget> _buildHistoryList() {
    final List<Widget> historyWidgets = [];
    
    // Sort by date (most recent first)
    final sortedEntries = _holidayFetchHistory.entries.toList()
      ..sort((a, b) {
        try {
          final dateA = DateTime.parse(a.value['date']);
          final dateB = DateTime.parse(b.value['date']);
          return dateB.compareTo(dateA); // Descending order
        } catch (e) {
          return 0;
        }
      });
    
    for (var entry in sortedEntries) {
      final countryCode = entry.key;
      final historyData = entry.value;
      final date = historyData['date'] ?? '';
      final count = historyData['count'] ?? 0;
      
      // Get country name from ALL_COUNTRIES
      final countryName = PublicHolidayFetcher.ALL_COUNTRIES[countryCode]?['name'] ?? countryCode;
      
      historyWidgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$countryName ($countryCode)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count holidays imported',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatRelativeTime(date),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return historyWidgets;
  }
  
  /// Format date as relative time (e.g., "2 hours ago")
  String _formatRelativeTime(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      
      // If more than a year, show date
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }
}

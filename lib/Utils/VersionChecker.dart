import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'CustomSnackBar.dart';
import 'customSnackBar_error.dart';
// Conditional import: web_refresh.dart for web, web_refresh_stub.dart for mobile
import 'web_refresh.dart' if (dart.library.io) 'web_refresh_stub.dart';

enum UpdateType { optional, important, critical }

class VersionInfo {
  final String version;
  final String title;
  final String description;
  final String downloadUrl;
  final UpdateType type;

  VersionInfo({
    required this.version,
    required this.title,
    required this.description,
    required this.downloadUrl,
    required this.type,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final description = json['body'] ?? '';
    
    // Determine update type based on description content
    UpdateType type = UpdateType.optional;
    if (description.contains('🚨 CRITICAL_UPDATE') || description.contains('CRITICAL_UPDATE')) {
      type = UpdateType.critical;
    } else if (description.contains('⚠️ IMPORTANT_UPDATE') || description.contains('IMPORTANT_UPDATE')) {
      type = UpdateType.important;
    }

    return VersionInfo(
      version: json['tag_name']?.replaceFirst('v', '') ?? '',
      title: json['name'] ?? 'New Version Available',
      description: description,
      downloadUrl: json['html_url'] ?? '',
      type: type,
    );
  }
}

class VersionChecker {
  static const String _githubApiUrl = 'https://api.github.com/repos/imnexerio/revix/releases/latest';
  static const String _dismissedVersionKey = 'dismissed_version';
  
  /// Check for app updates and show dialog if newer version is available
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch latest version from GitHub
      final latestVersionInfo = await _fetchLatestVersion();
      if (latestVersionInfo == null) return;

      // Compare versions
      if (_isNewerVersion(latestVersionInfo.version, currentVersion)) {
        // Check if user already dismissed this version (only for non-critical updates)
        if (latestVersionInfo.type != UpdateType.critical && 
            await _isVersionDismissed(latestVersionInfo.version)) {
          return;
        }

        // Show update dialog
        if (context.mounted) {
          await _showUpdateDialog(context, currentVersion, latestVersionInfo);
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  /// Fetch the latest version information from GitHub
  static Future<VersionInfo?> _fetchLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return VersionInfo.fromJson(data);
      }
    } catch (e) {
      print('Error fetching latest version: $e');
    }
    return null;
  }

  /// Check if a specific version was dismissed by the user
  static Future<bool> _isVersionDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedVersionKey);
    return dismissedVersion == version;
  }

  /// Mark a version as dismissed
  static Future<void> _dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  /// Compare two version strings (returns true if latestVersion is newer)
  static bool _isNewerVersion(String latestVersion, String currentVersion) {
    try {
      final latest = _parseVersion(latestVersion);
      final current = _parseVersion(currentVersion);
      
      for (int i = 0; i < 3; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      return false;
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }

  /// Parse version string into list of integers
  static List<int> _parseVersion(String version) {
    return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  /// Show the update dialog
  static Future<void> _showUpdateDialog(
    BuildContext context, 
    String currentVersion, 
    VersionInfo versionInfo
  ) async {
    final theme = Theme.of(context);
    
    // Determine dialog styling based on update type
    Color? titleColor;
    String titlePrefix = '';
    bool isDismissible = true;
    
    switch (versionInfo.type) {
      case UpdateType.critical:
        titleColor = Colors.red;
        titlePrefix = '🚨 Critical Update Required';
        isDismissible = false;
        break;
      case UpdateType.important:
        titleColor = Colors.orange;
        titlePrefix = '⚠️ Important Update Available';
        break;
      case UpdateType.optional:
        titlePrefix = '✨ New Version Available';
        break;
    }

    // On web, make all dialogs non-dismissible since updates are instant
    if (kIsWeb) {
      isDismissible = false;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => isDismissible,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titlePrefix,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor ?? theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  versionInfo.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Version',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              'v$currentVersion',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward,
                          color: theme.colorScheme.primary,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Latest Version',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              'v${versionInfo.version}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (versionInfo.description.isNotEmpty) ...[
                    Text(
                      'What\'s New:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Text(
                          _cleanupReleaseNotes(versionInfo.description),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!kIsWeb && isDismissible) ...[
                TextButton(
                  onPressed: () {
                    _dismissVersion(versionInfo.version);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Not Now'),
                ),
              ],
              if (!kIsWeb && isDismissible && versionInfo.type == UpdateType.optional) ...[
                TextButton(
                  onPressed: () {
                    _dismissVersion(versionInfo.version);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Skip This Version'),
                ),
              ],
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (kIsWeb) {
                    await _handleWebUpdate(context, versionInfo);
                  } else {
                    await _launchUpdateUrl(versionInfo.downloadUrl);
                  }
                },
                child: Text(kIsWeb 
                    ? 'Update'
                    : (versionInfo.type == UpdateType.critical ? 'Update Now' : 'Download')),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Clean up release notes for better display
  static String _cleanupReleaseNotes(String description) {
    return description
        .replaceAll('🚨 CRITICAL_UPDATE', '')
        .replaceAll('⚠️ IMPORTANT_UPDATE', '')
        .replaceAll('✨ OPTIONAL_UPDATE', '')
        .replaceAll('CRITICAL_UPDATE', '')
        .replaceAll('IMPORTANT_UPDATE', '')
        .replaceAll('OPTIONAL_UPDATE', '')
        .trim();
  }

  /// Launch the update URL
  static Future<void> _launchUpdateUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error launching update URL: $e');
    }
  }

  /// Handle web app update with direct refresh
  static Future<void> _handleWebUpdate(BuildContext context, VersionInfo versionInfo) async {
    // For all update types on web, refresh directly
    _refreshWebApp();
  }

  /// Refresh the web application
  static void _refreshWebApp() {
    if (kIsWeb) {
      // Use a slight delay to ensure dialog closes properly
      Future.delayed(const Duration(milliseconds: 500), () {
        refreshWebPage(); // Uses conditional import - real refresh on web, no-op on mobile
      });
    }
  }

  /// Manual update check (for settings page)
  static Future<void> checkForUpdatesManually(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Fetch latest version info
      final latestVersionInfo = await _fetchLatestVersion();
      Navigator.of(context).pop(); // Close loading indicator
      
      // Check if update is available
      if (latestVersionInfo != null && _isNewerVersion(latestVersionInfo.version, currentVersion)) {
        // Check if dismissed (for non-critical updates)
        if (latestVersionInfo.type != UpdateType.critical && 
            await _isVersionDismissed(latestVersionInfo.version)) {
          customSnackBar(
            context: context,
            message: 'You are using the latest version!',
            duration: const Duration(seconds: 3),
          );
          return;
        }
        
        // Show update dialog
        if (context.mounted) {
          await _showUpdateDialog(context, currentVersion, latestVersionInfo);
        }
      } else {
        // No update available
        customSnackBar(
          context: context,
          message: 'You are using the latest version!',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading indicator
      customSnackBar_error(
        context: context,
        message: 'Failed to check for updates',
        duration: const Duration(seconds: 3),
      );
    }
  }
}

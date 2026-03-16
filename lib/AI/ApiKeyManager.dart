import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/UrlLauncher.dart';

class ApiKeyManager {
  static const String apiKeyPrefKey = 'gemini_api_key';
  static const String geminiApiUrl = 'https://aistudio.google.com/apikey';

  // Cached instances for performance
  static SharedPreferences? _prefs;
  static String? _cachedApiKey;
  static bool _initialized = false;

  // Initialize cache (call once at app startup)
  static Future<void> initialize() async {
    if (_initialized) return;
    _prefs ??= await SharedPreferences.getInstance();
    _cachedApiKey = _prefs!.getString(apiKeyPrefKey);
    _initialized = true;
  }

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Check if API key exists (sync if initialized)
  static bool get hasApiKeySync => _cachedApiKey != null && _cachedApiKey!.isNotEmpty;

  static Future<bool> hasApiKey() async {
    if (_initialized) return hasApiKeySync;
    await initialize();
    return hasApiKeySync;
  }

  // Get the saved API key (sync if initialized)
  static String? get apiKeySync => _cachedApiKey;

  static Future<String?> getApiKey() async {
    if (_initialized) return _cachedApiKey;
    await initialize();
    return _cachedApiKey;
  }

  // Save the API key
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await _instance;
    await prefs.setString(apiKeyPrefKey, apiKey);
    _cachedApiKey = apiKey; // Update cache immediately
  }

  // Delete the API key
  static Future<void> deleteApiKey() async {
    final prefs = await _instance;
    await prefs.remove(apiKeyPrefKey);
    _cachedApiKey = null; // Clear cache
  }

  // Show dialog to enter API key
  static Future<String?> showApiKeyDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    String? savedKey = await getApiKey();
    if (savedKey != null) {
      controller.text = savedKey;
    }

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gemini API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your Gemini API key to enable AI features.',
              ),
              // SizedBox(height: 8),

              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Enter your API key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Get API Key'),
              onPressed: () {
                UrlLauncher.launchURL(context, geminiApiUrl);
              },
            ),
            TextButton(
              child: const Text('SKIP'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: const Text('SAVE'),
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
            ),
          ],
        );
      },
    );
  }
}
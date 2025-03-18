import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../LoginSignupPage/UrlLauncher.dart';

class ApiKeyManager {
  static const String apiKeyPrefKey = 'gemini_api_key';
  static const String geminiApiUrl = 'https://aistudio.google.com/apikey';

  // Check if API key exists
  static Future<bool> hasApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(apiKeyPrefKey);
    return key != null && key.isNotEmpty;
  }

  // Get the saved API key
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(apiKeyPrefKey);
  }

  // Save the API key
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiKeyPrefKey, apiKey);
  }

  // Delete the API key
  static Future<void> deleteApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(apiKeyPrefKey);
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
          title: Text('Gemini API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your Gemini API key to enable AI features.',
              ),
              // SizedBox(height: 8),

              SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter your API key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton.icon(
              icon: Icon(Icons.open_in_new),
              label: Text('Get API Key'),
              onPressed: () {
                UrlLauncher.launchURL(context, geminiApiUrl);
              },
            ),
            TextButton(
              child: Text('SKIP'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: Text('SAVE'),
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
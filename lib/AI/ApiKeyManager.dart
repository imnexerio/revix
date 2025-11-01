import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/UrlLauncher.dart';

class ApiKeyManager {
  static const String apiKeyPrefKey = 'gemini_api_key';
  static const String geminiApiUrl = 'https://aistudio.google.com/apikey';
  
  // Gemini API keys start with "AIza" and are typically 39 characters
  static const int minKeyLength = 35;
  static const String keyPrefix = 'AIza';

  // Validate API key format
  static bool isValidApiKey(String? key) {
    if (key == null || key.trim().isEmpty) {
      return false;
    }
    
    final trimmedKey = key.trim();
    
    // Check minimum length
    if (trimmedKey.length < minKeyLength) {
      return false;
    }
    
    // Check if it starts with expected prefix
    if (!trimmedKey.startsWith(keyPrefix)) {
      return false;
    }
    
    // Check if contains only alphanumeric characters, hyphens, and underscores
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmedKey)) {
      return false;
    }
    
    return true;
  }

  // Check if API key exists and is valid
  static Future<bool> hasApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(apiKeyPrefKey);
    return isValidApiKey(key);
  }

  // Get the saved API key
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(apiKeyPrefKey);
    
    // Return null if invalid
    if (key != null && !isValidApiKey(key)) {
      return null;
    }
    
    return key?.trim();
  }

  // Save the API key (with validation)
  static Future<bool> saveApiKey(String apiKey) async {
    final trimmedKey = apiKey.trim();
    
    if (!isValidApiKey(trimmedKey)) {
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiKeyPrefKey, trimmedKey);
    return true;
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
    
    String? errorMessage;
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Gemini API Key'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your Gemini API key to enable AI features.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'AIza...',
                        border: const OutlineInputBorder(),
                        errorText: errorMessage,
                        errorMaxLines: 3,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                      ),
                      obscureText: obscureText,
                      onChanged: (value) {
                        // Clear error when user types
                        if (errorMessage != null) {
                          setState(() {
                            errorMessage = null;
                          });
                        }
                      },
                    ),
                    if (errorMessage == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'API keys start with "AIza" and are ~39 characters long',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
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
                FilledButton(
                  child: const Text('SAVE'),
                  onPressed: () {
                    final key = controller.text.trim();
                    
                    // Validate
                    if (key.isEmpty) {
                      setState(() {
                        errorMessage = 'Please enter an API key';
                      });
                      return;
                    }
                    
                    if (!isValidApiKey(key)) {
                      setState(() {
                        if (key.length < minKeyLength) {
                          errorMessage = 'API key is too short. It should be at least $minKeyLength characters.';
                        } else if (!key.startsWith(keyPrefix)) {
                          errorMessage = 'Invalid API key format. Keys should start with "$keyPrefix"';
                        } else {
                          errorMessage = 'Invalid API key format. Please check and try again.';
                        }
                      });
                      return;
                    }
                    
                    Navigator.of(context).pop(key);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
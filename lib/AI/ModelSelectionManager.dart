import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ModelSelectionManager - Manages user selection of Gemini AI models
/// 
/// This class provides:
/// - A curated list of available Gemini models with descriptions
/// - Persistent storage of user's selected model
/// - A dialog UI for model selection
/// - Utility methods for model information
/// 
/// Usage:
/// 1. Call showModelSelectionDialog() to let user choose a model
/// 2. Use getSelectedModel() to get the currently selected model
/// 3. Use saveSelectedModel() to programmatically set a model
///
/// The selected model is automatically used by GeminiService when creating
/// new GenerativeModel instances.
class ModelSelectionManager {
  static const String selectedModelPrefKey = 'selected_gemini_model';
  static const String defaultModel = 'gemini-2.0-flash';

  // Available Gemini models with descriptions
  static const Map<String, Map<String, String>> availableModels = {
    'gemini-2.5-flash-preview-05-20': {
      'name': 'Gemini 2.5 Flash',
      'description': 'Best price-performance with adaptive thinking',
      'category': 'Latest',
    },
    'gemini-2.5-pro-preview-06-05': {
      'name': 'Gemini 2.5 Pro',
      'description': 'Most powerful thinking model with maximum accuracy',
      'category': 'Latest',
    },
    'gemini-2.0-flash': {
      'name': 'Gemini 2.0 Flash',
      'description': 'Next-gen features, low latency, enhanced performance',
      'category': 'Stable',
    },
    'gemini-2.0-flash-lite': {
      'name': 'Gemini 2.0 Flash Lite',
      'description': 'Cost efficient and low latency',
      'category': 'Stable',
    },
    'gemini-1.5-flash': {
      'name': 'Gemini 1.5 Flash',
      'description': 'Fast and versatile for diverse tasks',
      'category': 'Stable',
    },
    'gemini-1.5-flash-8b': {
      'name': 'Gemini 1.5 Flash 8B',
      'description': 'High volume, lower intelligence tasks',
      'category': 'Stable',
    },
    'gemini-1.5-pro': {
      'name': 'Gemini 1.5 Pro',
      'description': 'Complex reasoning tasks requiring more intelligence',
      'category': 'Stable',
    },
  };

  // Get the saved model
  static Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedModelPrefKey) ?? defaultModel;
  }

  // Save the selected model
  static Future<void> saveSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedModelPrefKey, model);
  }

  // Get model display name
  static String getModelDisplayName(String modelKey) {
    return availableModels[modelKey]?['name'] ?? modelKey;
  }

  // Get model description
  static String getModelDescription(String modelKey) {
    return availableModels[modelKey]?['description'] ?? 'No description available';
  }

  // Get model category
  static String getModelCategory(String modelKey) {
    return availableModels[modelKey]?['category'] ?? 'Other';
  }

  // Get all available models as a list
  static List<String> getAllModelKeys() {
    return availableModels.keys.toList();
  }

  // Get models grouped by category
  static Map<String, List<String>> getModelsGroupedByCategory() {
    Map<String, List<String>> grouped = {};
    for (String modelKey in availableModels.keys) {
      String category = getModelCategory(modelKey);
      grouped[category] ??= [];
      grouped[category]!.add(modelKey);
    }
    return grouped;
  }

  // Check if a model key is valid
  static bool isValidModel(String modelKey) {
    return availableModels.containsKey(modelKey);
  }

  // Show model selection dialog
  static Future<String?> showModelSelectionDialog(BuildContext context) async {
    String currentModel = await getSelectedModel();
    String? selectedModel = currentModel;

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Group models by category
            Map<String, List<String>> groupedModels = {};
            for (String modelKey in availableModels.keys) {
              String category = getModelCategory(modelKey);
              groupedModels[category] ??= [];
              groupedModels[category]!.add(modelKey);
            }

            return AlertDialog(
              title: const Text('Select AI Model'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Choose the AI model for your chat assistant:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: groupedModels.entries.map((entry) {
                            String category = entry.key;
                            List<String> models = entry.value;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    category,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                ...models.map((modelKey) {
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    child: RadioListTile<String>(
                                      title: Text(
                                        getModelDisplayName(modelKey),
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        getModelDescription(modelKey),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      value: modelKey,
                                      groupValue: selectedModel,
                                      onChanged: (String? value) {
                                        setState(() {
                                          selectedModel = value;
                                        });
                                      },
                                      dense: true,
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 8),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                ),
                FilledButton(
                  child: const Text('SELECT'),
                  onPressed: () {
                    Navigator.of(context).pop(selectedModel);
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

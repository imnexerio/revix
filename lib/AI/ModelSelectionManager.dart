import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ModelSelectionManager - Manages user selection of Gemini AI models
/// 
/// This class provides:
/// - Dynamic fetching of available models from Gemini API
/// - Permanent caching until manual refresh
/// - Persistent storage of user's selected model
/// - A dialog UI for model selection
/// - Utility methods for model information
/// 
/// Usage:
/// 1. Call showModelSelectionDialog() to let user choose a model
/// 2. Use getSelectedModel() to get the currently selected model
/// 3. Use saveSelectedModel() to programmatically set a model
/// 4. Call fetchAvailableModels() to refresh models from API
///
/// The selected model is automatically used by GeminiService when creating
/// new GenerativeModel instances.
class ModelSelectionManager {
  static const String selectedModelPrefKey = 'selected_gemini_model';
  static const String cachedModelsPrefKey = 'cached_gemini_models';
  static const String defaultModel = 'gemini-2.5-flash';

  // Cached models fetched from API (in-memory)
  static Map<String, Map<String, String>>? _cachedApiModels;

  // Get available models from cache
  static Map<String, Map<String, String>> get availableModels {
    return _cachedApiModels ?? {};
  }

  // Check if models have been loaded from API
  static bool get hasModels => _cachedApiModels != null && _cachedApiModels!.isNotEmpty;

  // Initialize - load cached models from storage
  static Future<void> initialize() async {
    if (_cachedApiModels == null) {
      _cachedApiModels = await _loadCachedModels();
    }
  }

  // Fetch available models from Gemini API (force refresh)
  static Future<Map<String, Map<String, String>>?> fetchAvailableModels(String apiKey, {bool forceRefresh = false}) async {
    if (apiKey.isEmpty) return null;

    try {
      // Use cache if available and not forcing refresh
      if (!forceRefresh && _cachedApiModels != null && _cachedApiModels!.isNotEmpty) {
        return _cachedApiModels;
      }

      // Load from persistent storage if not in memory
      if (!forceRefresh) {
        final cachedModels = await _loadCachedModels();
        if (cachedModels != null && cachedModels.isNotEmpty) {
          _cachedApiModels = cachedModels;
          return cachedModels;
        }
      }

      // Fetch from API with pagination support
      final Map<String, Map<String, String>> allModels = {};
      String? pageToken;
      
      do {
        final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models')
            .replace(queryParameters: {
          'key': apiKey,
          'pageSize': '100',
          if (pageToken != null) 'pageToken': pageToken,
        });
        
        final response = await http.get(uri).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final models = _parseModelsResponse(data);
          allModels.addAll(models);
          pageToken = data['nextPageToken'];
        } else {
          break;
        }
      } while (pageToken != null);

      if (allModels.isNotEmpty) {
        _cachedApiModels = allModels;
        await _saveCachedModels(allModels);
        return allModels;
      }
    } catch (e) {
      print('Error fetching models: $e');
    }
    
    return _cachedApiModels;
  }

  // Parse API response - filter for text-capable models only
  static Map<String, Map<String, String>> _parseModelsResponse(Map<String, dynamic> data) {
    final Map<String, Map<String, String>> models = {};
    final Set<String> seenBaseModels = {};
    final List<dynamic> modelList = data['models'] ?? [];

    for (final model in modelList) {
      final String name = model['name'] ?? '';
      final String baseModelId = model['baseModelId'] ?? '';
      final String displayName = model['displayName'] ?? '';
      final String description = model['description'] ?? '';
      final List<dynamic> supportedMethods = model['supportedGenerationMethods'] ?? [];

      // Only include models that support generateContent (text generation)
      if (!supportedMethods.contains('generateContent')) continue;

      // Use baseModelId if available, otherwise extract from name
      String modelId = baseModelId.isNotEmpty 
          ? baseModelId 
          : name.replaceFirst('models/', '');

      // Skip if we've already seen this base model
      if (seenBaseModels.contains(modelId)) continue;

      // Skip non-Gemini models
      if (!modelId.startsWith('gemini')) continue;
      
      // Skip non-text specialized models
      if (modelId.contains('embedding')) continue;
      if (modelId.contains('aqa')) continue;
      if (modelId.contains('image')) continue;      // Image generation models
      if (modelId.contains('vision')) continue;     // Vision-only models  
      if (modelId.contains('video')) continue;      // Video models
      if (modelId.contains('veo')) continue;        // Veo video models
      if (modelId.contains('imagen')) continue;     // Imagen models
      if (modelId.contains('tts')) continue;        // Text-to-speech models
      if (modelId.contains('audio')) continue;      // Audio models
      if (modelId.contains('live')) continue;       // Live API models
      if (modelId.contains('music')) continue;      // Music models
      if (modelId.contains('robotics')) continue;   // Robotics models
      if (modelId.contains('computer-use')) continue; // Computer use models

      // Skip experimental/preview versioned models (keep only base names)
      // e.g., skip "gemini-2.5-flash-preview-05-20" but keep "gemini-2.5-flash"
      if (RegExp(r'-\d{2}-\d{2,4}$').hasMatch(modelId)) continue;
      if (RegExp(r'-\d{3}$').hasMatch(modelId)) continue; // Skip -001, -002 versions

      // Determine category based on model name
      String category;
      if (modelId.contains('gemini-3')) {
        category = 'Latest';
      } else if (modelId.contains('gemini-2.5')) {
        category = 'Stable';
      } else if (modelId.contains('gemini-2.0') || modelId.contains('gemini-1.')) {
        continue; // Skip older models
      } else {
        category = 'Other';
      }

      seenBaseModels.add(modelId);
      
      // Clean up display name
      String cleanDisplayName = displayName.isNotEmpty ? displayName : modelId;
      
      // Truncate long descriptions
      String cleanDescription = description.isNotEmpty 
          ? (description.length > 100 ? '${description.substring(0, 97)}...' : description)
          : 'Gemini AI model';

      models[modelId] = {
        'name': cleanDisplayName,
        'description': cleanDescription,
        'category': category,
      };
    }

    return models;
  }

  // Load cached models from SharedPreferences (permanent cache)
  static Future<Map<String, Map<String, String>>?> _loadCachedModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cachedModelsPrefKey);
      if (cachedJson != null) {
        final decoded = json.decode(cachedJson) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(
          key,
          Map<String, String>.from(value as Map),
        ));
      }
    } catch (e) {
      print('Error loading cached models: $e');
    }
    return null;
  }

  // Save models to cache (permanent until manual refresh)
  static Future<void> _saveCachedModels(Map<String, Map<String, String>> models) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cachedModelsPrefKey, json.encode(models));
    } catch (e) {
      print('Error saving cached models: $e');
    }
  }

  // Clear cached models (called before manual refresh)
  static Future<void> clearCache() async {
    try {
      _cachedApiModels = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cachedModelsPrefKey);
    } catch (e) {
      print('Error clearing model cache: $e');
    }
  }

  // Get the saved model with validation
  static Future<String> getSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString(selectedModelPrefKey);
      
      // If no models cached, return saved model or default
      if (!hasModels) {
        return savedModel ?? defaultModel;
      }
      
      // Validate saved model exists in available models
      if (savedModel != null && isValidModel(savedModel)) {
        return savedModel;
      }
      
      // Fallback to default if saved model is invalid
      return defaultModel;
    } catch (e) {
      print('Error getting selected model: $e');
      return defaultModel;
    }
  }

  // Save the selected model (allows any model string)
  static Future<bool> saveSelectedModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(selectedModelPrefKey, model);
      return true;
    } catch (e) {
      print('Error saving selected model: $e');
      return false;
    }
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

  // Show model selection dialog with refresh capability
  static Future<String?> showModelSelectionDialog(BuildContext context, {String? apiKey}) async {
    String currentModel = await getSelectedModel();
    String? selectedModel = currentModel;
    bool isLoading = false;
    String? errorMessage;
    bool autoFetchTriggered = false;
    
    // Load cached models if not already loaded
    await initialize();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Auto-fetch models on first open if no models cached and API key available
            if (!autoFetchTriggered && !hasModels && apiKey != null && apiKey.isNotEmpty) {
              autoFetchTriggered = true;
              // Trigger async fetch
              Future.microtask(() async {
                setState(() => isLoading = true);
                await fetchAvailableModels(apiKey, forceRefresh: true);
                if (context.mounted) {
                  setState(() => isLoading = false);
                }
              });
            }
            
            // Group models by category
            Map<String, List<String>> groupedModels = {};
            for (String modelKey in availableModels.keys) {
              String category = getModelCategory(modelKey);
              groupedModels[category] ??= [];
              groupedModels[category]!.add(modelKey);
            }

            // Sort categories: Latest first, then Stable, then Others
            final sortedCategories = groupedModels.keys.toList()
              ..sort((a, b) {
                const order = {'Latest': 0, 'Stable': 1, 'Other': 2};
                return (order[a] ?? 3).compareTo(order[b] ?? 3);
              });

            final bool showEmptyState = !hasModels && !isLoading;

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select AI Model'),
                  if (apiKey != null && apiKey.isNotEmpty)
                    IconButton(
                      icon: isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                      tooltip: 'Refresh models from API',
                      onPressed: isLoading ? null : () async {
                        setState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                        
                        await clearCache();
                        final models = await fetchAvailableModels(apiKey, forceRefresh: true);
                        
                        setState(() {
                          isLoading = false;
                          if (models == null || models.isEmpty) {
                            errorMessage = 'Could not fetch models. Check your API key.';
                          } else {
                            // Auto-select default if current selection is invalid
                            if (!isValidModel(selectedModel ?? '')) {
                              selectedModel = defaultModel;
                            }
                          }
                        });
                      },
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showEmptyState) ...[
                      const SizedBox(height: 24),
                      Icon(
                        Icons.cloud_download_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No models loaded',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the refresh button to fetch available models from the Gemini API.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const Text(
                        'Choose the AI model for your chat assistant:',
                        style: TextStyle(fontSize: 14),
                      ),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sortedCategories.map((category) {
                              List<String> models = groupedModels[category]!;
                              
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
                                  }),
                                  const SizedBox(height: 8),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
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
                if (!showEmptyState)
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

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatStorage {
  static const String _activeConversationKey = 'active_conversation';
  static const String _conversationsKey = 'conversations';

  // Save the current conversation to local storage
  static Future<void> saveConversation(
      String conversationId, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'conversation_$conversationId', jsonEncode(messages));

    // Get the list of all conversation IDs
    final conversationIds = await getConversationIds();
    if (!conversationIds.contains(conversationId)) {
      conversationIds.add(conversationId);
      await prefs.setStringList(_conversationsKey, conversationIds);
    }

    // Set this as the active conversation
    await prefs.setString(_activeConversationKey, conversationId);
  }

  static Future<bool> conversationExists(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('chat_$conversationId');
  }

  // Load a specific conversation from local storage
  static Future<List<Map<String, dynamic>>> loadConversation(
      String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('conversation_$conversationId');
    if (data == null) {
      return [];
    }
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  // Get the ID of the last active conversation
  static Future<String?> getActiveConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeConversationKey);
  }

  // Get a list of all saved conversation IDs
  static Future<List<String>> getConversationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_conversationsKey) ?? [];
  }

  // Delete a conversation
  static Future<void> deleteConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('conversation_$conversationId');

    // Remove from the list of conversation IDs
    final conversationIds = await getConversationIds();
    conversationIds.remove(conversationId);
    await prefs.setStringList(_conversationsKey, conversationIds);

    // If this was the active conversation, clear the active conversation
    final activeId = await getActiveConversationId();
    if (activeId == conversationId) {
      await prefs.remove(_activeConversationKey);
    }
  }
  
  // Clear all conversations (used during logout)
  static Future<void> clearAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final conversationIds = await getConversationIds();
    
    // Delete each conversation
    for (final id in conversationIds) {
      await prefs.remove('conversation_$id');
    }
    
    // Clear the list of conversation IDs
    await prefs.remove(_conversationsKey);
    
    // Clear the active conversation reference
    await prefs.remove(_activeConversationKey);
  }
}
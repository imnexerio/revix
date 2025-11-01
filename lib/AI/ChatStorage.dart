import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ChatMessage.dart';

class ChatStorage {
  static const String _activeConversationKey = 'active_conversation';
  static const String _conversationsKey = 'conversations';
  static const String _conversationPrefix = 'conversation_';
  static const int _storageVersion = 1;

  // Save the current conversation to local storage with error handling
  static Future<bool> saveConversation(
      String conversationId, List<Map<String, dynamic>> messages) async {
    try {
      // Validate inputs
      if (conversationId.trim().isEmpty) {
        throw ArgumentError('Conversation ID cannot be empty');
      }

      if (messages.isEmpty) {
        throw ArgumentError('Cannot save empty conversation');
      }

      // Validate all messages can be serialized
      for (final msg in messages) {
        try {
          ChatMessage.fromMap(msg);
        } catch (e) {
          throw ArgumentError('Invalid message format in conversation: $e');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Create conversation data with metadata
      final conversationData = {
        'version': _storageVersion,
        'id': conversationId,
        'messages': messages,
        'lastModified': DateTime.now().millisecondsSinceEpoch,
      };

      // Save conversation
      final success = await prefs.setString(
        '$_conversationPrefix$conversationId',
        jsonEncode(conversationData),
      );

      if (!success) {
        return false;
      }

      // Update conversation IDs list
      final conversationIds = await getConversationIds();
      if (!conversationIds.contains(conversationId)) {
        conversationIds.add(conversationId);
        await prefs.setStringList(_conversationsKey, conversationIds);
      }

      // Set this as the active conversation
      await prefs.setString(_activeConversationKey, conversationId);

      return true;
    } catch (e) {
      print('Error saving conversation: $e');
      return false;
    }
  }

  // Check if conversation exists
  static Future<bool> conversationExists(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('$_conversationPrefix$conversationId');
    } catch (e) {
      print('Error checking conversation existence: $e');
      return false;
    }
  }

  // Load a specific conversation from local storage with error recovery
  static Future<List<Map<String, dynamic>>> loadConversation(
      String conversationId) async {
    try {
      // Validate input
      if (conversationId.trim().isEmpty) {
        throw ArgumentError('Conversation ID cannot be empty');
      }

      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_conversationPrefix$conversationId');
      
      if (data == null || data.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(data);
      
      // Handle old format (direct array)
      if (decoded is List) {
        return _validateAndRecoverMessages(decoded);
      }
      
      // Handle new format (with metadata)
      if (decoded is Map<String, dynamic>) {
        final messages = decoded['messages'];
        if (messages is List) {
          return _validateAndRecoverMessages(messages);
        }
      }

      return [];
    } catch (e) {
      print('Error loading conversation $conversationId: $e');
      // Try to recover by cleaning corrupted data
      await _cleanupCorruptedConversation(conversationId);
      return [];
    }
  }

  // Validate and recover messages from corrupted data
  static List<Map<String, dynamic>> _validateAndRecoverMessages(List messages) {
    final validMessages = <Map<String, dynamic>>[];
    
    for (final msg in messages) {
      if (msg is! Map<String, dynamic>) {
        continue;
      }

      try {
        // Try to create ChatMessage to validate
        ChatMessage.fromMap(msg);
        validMessages.add(msg);
      } catch (e) {
        // Skip invalid messages
        print('Skipping invalid message during recovery: $e');
        continue;
      }
    }

    return validMessages;
  }

  // Clean up corrupted conversation
  static Future<void> _cleanupCorruptedConversation(String conversationId) async {
    try {
      await deleteConversation(conversationId);
      print('Cleaned up corrupted conversation: $conversationId');
    } catch (e) {
      print('Error cleaning up corrupted conversation: $e');
    }
  }

  // Get the ID of the last active conversation
  static Future<String?> getActiveConversationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activeConversationKey);
    } catch (e) {
      print('Error getting active conversation ID: $e');
      return null;
    }
  }

  // Get a list of all saved conversation IDs
  static Future<List<String>> getConversationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_conversationsKey) ?? [];
    } catch (e) {
      print('Error getting conversation IDs: $e');
      return [];
    }
  }

  // Delete a conversation safely
  static Future<bool> deleteConversation(String conversationId) async {
    try {
      if (conversationId.trim().isEmpty) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_conversationPrefix$conversationId');

      // Remove from the list of conversation IDs
      final conversationIds = await getConversationIds();
      conversationIds.remove(conversationId);
      await prefs.setStringList(_conversationsKey, conversationIds);

      // If this was the active conversation, clear the active conversation
      final activeId = await getActiveConversationId();
      if (activeId == conversationId) {
        await prefs.remove(_activeConversationKey);
      }

      return true;
    } catch (e) {
      print('Error deleting conversation: $e');
      return false;
    }
  }
  
  // Clear all conversations (used during logout)
  static Future<bool> clearAllConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationIds = await getConversationIds();
      
      // Delete each conversation
      for (final id in conversationIds) {
        await prefs.remove('$_conversationPrefix$id');
      }
      
      // Clear the list of conversation IDs
      await prefs.remove(_conversationsKey);
      
      // Clear the active conversation reference
      await prefs.remove(_activeConversationKey);

      return true;
    } catch (e) {
      print('Error clearing all conversations: $e');
      return false;
    }
  }

  // Get all conversations with metadata (for history drawer)
  static Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      final conversationIds = await getConversationIds();
      final List<Map<String, dynamic>> conversations = [];

      for (final id in conversationIds) {
        try {
          final messages = await loadConversation(id);
          
          if (messages.isEmpty) {
            // Clean up empty conversations
            await deleteConversation(id);
            continue;
          }

          // Get timestamp from first message or use 0
          int timestamp = 0;
          if (messages.isNotEmpty && messages.first['timestamp'] != null) {
            final ts = messages.first['timestamp'];
            timestamp = ts is int ? ts : 0;
          }

          // Get preview text from first user message
          String preview = 'Empty conversation';
          for (final msg in messages) {
            if (msg['isUser'] == true && msg['text'] != null) {
              final text = msg['text'] as String;
              preview = text.length > 100 ? '${text.substring(0, 100)}...' : text;
              break;
            }
          }

          conversations.add({
            'id': id,
            'messages': messages,
            'timestamp': timestamp,
            'preview': preview,
            'messageCount': messages.length,
          });
        } catch (e) {
          print('Error loading conversation $id: $e');
          // Clean up corrupted conversation
          await deleteConversation(id);
          continue;
        }
      }

      // Sort by timestamp (most recent first)
      conversations.sort((a, b) {
        final aTime = a['timestamp'] as int? ?? 0;
        final bTime = b['timestamp'] as int? ?? 0;
        return bTime.compareTo(aTime);
      });

      return conversations;
    } catch (e) {
      print('Error getting all conversations: $e');
      return [];
    }
  }

  // Cleanup orphaned data (conversations not in ID list)
  static Future<int> cleanupOrphanedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationIds = await getConversationIds();
      final allKeys = prefs.getKeys();
      
      int cleanedCount = 0;
      
      for (final key in allKeys) {
        if (key.startsWith(_conversationPrefix)) {
          final id = key.substring(_conversationPrefix.length);
          if (!conversationIds.contains(id)) {
            await prefs.remove(key);
            cleanedCount++;
          }
        }
      }

      return cleanedCount;
    } catch (e) {
      print('Error cleaning up orphaned data: $e');
      return 0;
    }
  }
}
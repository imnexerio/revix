import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ChatStorage.dart';
import 'ChatMessage.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({Key? key}) : super(key: key);

  @override
  _ChatHistoryPageState createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  List<String> _conversationIds = [];
  Map<String, List<ChatMessage>> _conversationPreviews = {};
  bool _isLoading = true;
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get active conversation ID
      _activeConversationId = await ChatStorage.getActiveConversationId();

      // Get all conversation IDs
      _conversationIds = await ChatStorage.getConversationIds();

      // Sort newest first (assuming IDs are UUID v4, we'll replace with timestamp data)
      _conversationIds.sort((a, b) => b.compareTo(a));

      // Load preview of each conversation (just first few messages)
      for (final id in _conversationIds) {
        final messagesData = await ChatStorage.loadConversation(id);
        final messages = messagesData.map((m) => ChatMessage.fromMap(m)).toList();

        // Store just the first few messages as a preview
        _conversationPreviews[id] = messages.take(3).toList();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getConversationPreview(String conversationId) {
    final messages = _conversationPreviews[conversationId];
    if (messages == null || messages.isEmpty) {
      return 'Empty conversation';
    }

    // Find the first user message
    final userMessage = messages.firstWhere(
            (msg) => msg.isUser,
        orElse: () => messages.first
    );

    return userMessage.text.length > 50
        ? '${userMessage.text.substring(0, 50)}...'
        : userMessage.text;
  }

  String _getConversationDate(String conversationId) {
    final messages = _conversationPreviews[conversationId];
    if (messages == null || messages.isEmpty) {
      return '';
    }

    // Sort to get the most recent message
    final latestMessage = List.of(messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final formatter = DateFormat('MMM d, h:mm a');
    return formatter.format(latestMessage.first.timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Conversation History'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _conversationIds.isEmpty
          ? Center(
        child: Text(
          'No previous conversations found',
          style: theme.textTheme.bodyLarge,
        ),
      )
          : ListView.builder(
        itemCount: _conversationIds.length,
        itemBuilder: (context, index) {
          final id = _conversationIds[index];
          final isActive = id == _activeConversationId;

          return Dismissible(
            key: Key(id),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Delete Conversation'),
                  content: Text('Are you sure you want to delete this conversation?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('DELETE'),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              await ChatStorage.deleteConversation(id);
              setState(() {
                _conversationIds.removeAt(index);
                _conversationPreviews.remove(id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Conversation deleted')),
              );
            },
            child: ListTile(
              title: Text(
                _getConversationPreview(id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_getConversationDate(id)),
              leading: CircleAvatar(
                backgroundColor: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                child: Icon(
                  Icons.chat,
                  color: isActive
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
              trailing: isActive
                  ? Chip(
                label: Text('Active'),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              )
                  : null,
              onTap: () {
                // Return the ID to the previous screen
                Navigator.pop(context, id);
              },
            ),
          );
        },
      ),
    );
  }
}
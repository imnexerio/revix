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
      // print('Error loading conversations: $e');
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // App bar section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: colorScheme.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer.withOpacity(0.8),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 12),

                  // Title
                  Expanded(
                    child: Text(
                      'Conversation History',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading conversations...',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
                  : _conversationIds.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 60,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No previous conversations found',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a new chat to begin',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _conversationIds.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final id = _conversationIds[index];
                  final isActive = id == _activeConversationId;

                  return Dismissible(
                    key: Key(id),
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.delete, color: colorScheme.onError),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Conversation'),
                          content: const Text('Are you sure you want to delete this conversation?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('CANCEL'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                              ),
                              child: const Text('DELETE'),
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
                        SnackBar(
                          content: const Text('Conversation deleted'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isActive
                              ? colorScheme.primary.withOpacity(0.5)
                              : colorScheme.outlineVariant.withOpacity(0.2),
                          width: isActive ? 1.5 : 0.5,
                        ),
                      ),
                      color: isActive
                          ? colorScheme.primaryContainer.withOpacity(0.2)
                          : colorScheme.surface,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        onTap: () {
                          // Return the ID to the previous screen
                          Navigator.pop(context, id);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Chat icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isActive
                                          ? colorScheme.primary.withOpacity(0.3)
                                          : colorScheme.shadow.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.chat_rounded,
                                  color: isActive
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Chat preview
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getConversationPreview(id),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getConversationDate(id),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Active chip if this is the active conversation
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                              // Drag hint
                              if (!isActive)
                                Icon(
                                  Icons.chevron_left,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
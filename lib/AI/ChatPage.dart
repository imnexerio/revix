import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:revix/AI/gemini_service.dart';
import 'package:uuid/uuid.dart';
import '../Utils/UnifiedDatabaseService.dart';
import 'ApiKeyManager.dart';
import 'ChatMessage.dart';
import 'ChatStorage.dart';
import 'ModelSelectionManager.dart';

class ChatPage extends StatefulWidget {
  final String? conversationId;

  const ChatPage({Key? key, this.conversationId}) : super(key: key);
  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late GeminiService _geminiService;
  bool _isLoading = false;
  String _currentConversationId = '';
  bool _isInitialized = false;
  bool _aiEnabled = false;
  bool _isViewingOldConversation = false; // Track if viewing old history

  // Store schedule data directly
  String? _scheduleData;

  // Expose AI enabled status for parent widget
  bool get isAiEnabled => _aiEnabled;

  // Method to open drawer from parent
  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  // Expose dialog methods for parent widget
  void showApiKeyDialog() {
    _showApiKeyDialog();
  }

  void showModelSelectionDialog() {
    _showModelSelectionDialog();
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  Future<void> _fetchScheduleData() async {
    try {
      // UnifiedDatabaseService keeps data updated via listeners
      // Just get the latest cached data
      final service = UnifiedDatabaseService();
      _scheduleData = service.getScheduleData();

      // If no cached data, try to fetch once
      if (_scheduleData == 'No schedule data available') {
        await service.fetchRawData();
        _scheduleData = service.getScheduleData();
      }
    } catch (e) {
      _scheduleData = 'No schedule data available';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }


  Future<void> _initializeGeminiService() async {
    final apiKey = await ApiKeyManager.getApiKey();
    final selectedModel = await ModelSelectionManager.getSelectedModel();
    if (apiKey != null && apiKey.isNotEmpty) {
      _geminiService = GeminiService(apiKey: apiKey, modelName: selectedModel);
      _aiEnabled = _geminiService.isAvailable;
    }
  }
  Future<void> _showApiKeyDialog() async {
    final apiKey = await ApiKeyManager.showApiKeyDialog(context);
    if (apiKey != null && apiKey.isNotEmpty) {
      await ApiKeyManager.saveApiKey(apiKey);
      // Reinitialize the service with the new API key and selected model
      final selectedModel = await ModelSelectionManager.getSelectedModel();
      setState(() {
        _geminiService = GeminiService(apiKey: apiKey, modelName: selectedModel);
        _aiEnabled = _geminiService.isAvailable;
      });
      
      // ✅ API KEY SET - Start fresh conversation with data
      if (_aiEnabled) {
        await _fetchScheduleData(); // Get latest data
        await _startNewConversation(); // This will send data
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('API key saved, AI features enabled'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI features disabled'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showModelSelectionDialog() async {
    final selectedModel = await ModelSelectionManager.showModelSelectionDialog(context);
    if (selectedModel != null) {
      await ModelSelectionManager.saveSelectedModel(selectedModel);
      
      // Reinitialize the service with the new model if API key exists
      final apiKey = await ApiKeyManager.getApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        setState(() {
          _geminiService = GeminiService(apiKey: apiKey, modelName: selectedModel);
          _aiEnabled = _geminiService.isAvailable;
        });
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Model changed to ${ModelSelectionManager.getModelDisplayName(selectedModel)}'),
                Text(
                  ModelSelectionManager.getModelDescription(selectedModel),
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadConversation(String conversationId) async {
    try {
      if (conversationId.trim().isEmpty) {
        throw ArgumentError('Invalid conversation ID');
      }

      print('Loading conversation: $conversationId');

      // Load conversation from storage
      final messagesData = await ChatStorage.loadConversation(conversationId);

      print('Loaded ${messagesData.length} messages from storage');

      if (messagesData.isEmpty) {
        // No messages found, start new conversation instead
        await _startNewConversation();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation not found. Started a new one.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Clear current messages
      _messages.clear();

      // Convert Map data to ChatMessage objects with validation
      int validMessageCount = 0;
      for (var messageData in messagesData) {
        try {
          _messages.add(ChatMessage.fromMap(messageData));
          validMessageCount++;
        } catch (e) {
          print('Skipping invalid message: $e');
          continue;
        }
      }

      print('Loaded $validMessageCount valid messages');

      if (validMessageCount == 0) {
        // No valid messages, start new conversation
        await _startNewConversation();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation data corrupted. Started a new one.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      _currentConversationId = conversationId;
      
      // Mark as viewing old conversation (disable sending)
      _isViewingOldConversation = true;

      // Load the messages into the Gemini chat session if AI is enabled
      if (_aiEnabled) {
        try {
          await _geminiService.loadChatHistory(_messages);
          print('Chat history loaded into Gemini service');
        } catch (e) {
          print('Error loading chat history into Gemini: $e');
          // Continue anyway, conversation is loaded in UI
        }
      }

      // Force UI update
      if (mounted) {
        setState(() {});
        
        // Scroll to bottom after a short delay to ensure list is built
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scrollToBottom();
          }
        });
      }
      
      print('Conversation loaded successfully. Messages: ${_messages.length}, Viewing old: $_isViewingOldConversation');
    } catch (e) {
      print('Error loading conversation $conversationId: $e');
      
      // If there's an error, start a new conversation
      await _startNewConversation();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading conversation: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }
  // In _ChatPageState class, modify the _initializeApp method
  Future<void> _initializeApp() async {
    try {
      // Initialize with null API key first (model doesn't matter yet)
      _geminiService = GeminiService(apiKey: null);

      // Check if API key exists and initialize Gemini if it does
      await _initializeGeminiService();

      // Load conversation if ID provided
      if (widget.conversationId != null) {
        await _loadConversation(widget.conversationId!);
      } else {
        // If no conversation ID provided, just fetch fresh data
        // but don't save a new conversation yet
        await _fetchScheduleData();

        // Generate a new conversation ID but don't save it yet
        final uuid = const Uuid();
        _currentConversationId = uuid.v4();

        // Add welcome message to UI but don't save to storage yet
        _messages.add(ChatMessage(
          text: _aiEnabled
              ? "Hi there! I can help you understand your schedule. What would you like to know?"
              : "Welcome to your revAIx. AI features are currently disabled. You can enable them by setting your Gemini API key.",
          isUser: false,
        ));
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // If initialization fails, still show the UI with error state
      setState(() {
        _isInitialized = true;
        _messages.add(ChatMessage(
          text: "There was an error initializing the app. Please try again or check your connection.",
          isUser: false,
        ));
      });
    }
  }

// Modify _sendMessage to use streaming for real-time responses
  void _sendMessage(String text) async {
    // Prevent multiple simultaneous sends
    if (text.trim().isEmpty || !_aiEnabled || _isLoading) return;

    final userMessage = text.trim();
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    // Check if this is the first message in a new conversation
    bool isFirstMessageInNewConversation = !await ChatStorage.conversationExists(_currentConversationId);

    // Save the conversation with the user message
    await _saveConversation();

    // Prepare index for AI response (will be added when first chunk arrives)
    int aiMessageIndex = -1;

    try {
      // Use streaming for real-time response
      // Schedule data is already sent when conversation started
      StringBuffer fullResponse = StringBuffer();
      bool hasReceivedChunk = false;
      
      await for (final chunk in _geminiService.askAboutScheduleStream(userMessage)) {
        if (!mounted) return; // Safety check
        
        hasReceivedChunk = true;
        fullResponse.write(chunk);
        
        setState(() {
          // Add message on first chunk, update on subsequent chunks
          if (aiMessageIndex == -1) {
            aiMessageIndex = _messages.length;
            _messages.add(ChatMessage(
              text: fullResponse.toString(),
              isUser: false,
            ));
          } else {
            _messages[aiMessageIndex] = ChatMessage(
              text: fullResponse.toString(),
              isUser: false,
              timestamp: _messages[aiMessageIndex].timestamp,
            );
          }
          _isLoading = false;
        });

        _scrollToBottom();
      }

      // Handle case where stream completes without any chunks
      if (!hasReceivedChunk && mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "I received your message but couldn't generate a response. Please try again.",
            isUser: false,
          ));
          _isLoading = false;
        });
      }

      // Save conversation with assistant's response
      await _saveConversation();
    } catch (e) {
      if (!mounted) return; // Safety check
      
      String errorMessage;
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        errorMessage = "⚠️ Rate limit reached. Please wait a moment and try again.";
      } else if (e.toString().contains('NetworkException') || e.toString().contains('SocketException')) {
        errorMessage = "⚠️ Network error. Please check your connection and try again.";
      } else if (e.toString().contains('API key')) {
        errorMessage = "⚠️ API key issue. Please check your API key in settings.";
      } else {
        errorMessage = "⚠️ Something went wrong. Please try again.\n\nError: ${e.toString()}";
      }
      
      setState(() {
        // Add error message if no message was created yet
        if (aiMessageIndex == -1) {
          _messages.add(ChatMessage(
            text: errorMessage,
            isUser: false,
          ));
        } else {
          _messages[aiMessageIndex] = ChatMessage(
            text: "Sorry, I encountered an error. Please try again or check your connection.\n\nError: ${e.toString()}",
            isUser: false,
            timestamp: _messages[aiMessageIndex].timestamp,
          );
        }
        _isLoading = false;
      });

      // Save conversation with error message
      _saveConversation();
    }
  }

  Future<void> _startNewConversation() async {
    try {
      // Generate a new UUID for the conversation
      final uuid = const Uuid();
      _currentConversationId = uuid.v4();

      // Clear messages
      _messages.clear();
      
      // Clear old conversation flag (enable sending)
      _isViewingOldConversation = false;

      // Reset the Gemini chat session if AI is enabled
      if (_aiEnabled) {
        try {
          _geminiService.resetChat();

          // ✅ SEND SCHEDULE DATA - This is a new chat
          if (_scheduleData != null) {
            await _geminiService.setScheduleData(_scheduleData!);
          }
        } catch (e) {
          print('Error resetting chat or setting schedule data: $e');
          // Continue anyway, user can still chat
        }
      }

      // Add welcome message but don't save it yet
      String welcomeMessage = _aiEnabled
          ? "Hi there! I can help you understand your schedule. What would you like to know?"
          : "Welcome to your revAIx. AI features are currently disabled. You can enable them by setting your Gemini API key.";

      _messages.add(ChatMessage(
        text: welcomeMessage,
        isUser: false,
      ));

      // Refresh UI
      if (mounted) {
        setState(() {});
      }

      // No _saveConversation() call here - we'll save only when user interacts
    } catch (e) {
      print('Error starting new conversation: $e');
      
      // Fallback: create minimal conversation
      final uuid = const Uuid();
      _currentConversationId = uuid.v4();
      _messages.clear();
      _isViewingOldConversation = false;
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _saveConversation() async {
    try {
      // Don't save if viewing old conversation (read-only mode)
      if (_isViewingOldConversation && _messages.isNotEmpty) {
        return;
      }

      // Don't save empty conversations
      if (_messages.isEmpty) {
        return;
      }

      // Convert messages to Map
      final messagesData = _messages.map((msg) => msg.toMap()).toList();

      // Save to storage
      final success = await ChatStorage.saveConversation(_currentConversationId, messagesData);
      
      if (!success) {
        print('Failed to save conversation ${_currentConversationId}');
      }
    } catch (e) {
      print('Error saving conversation: $e');
      // Don't show error to user, just log it
    }
  }

  // Get current model display name for UI
  Future<String> _getCurrentModelDisplay() async {
    final currentModel = await ModelSelectionManager.getSelectedModel();
    return ModelSelectionManager.getModelDisplayName(currentModel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading your assistant...',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.background,
      // Add drawer for chat history
      drawer: Drawer(
        width: MediaQuery.of(context).size.width > 600 ? 350 : 280,
        child: _buildChatHistoryDrawer(context, theme, colorScheme),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_aiEnabled)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI chat features are disabled. Tap the key icon to set your Gemini API key.',
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),

            // Chat messages
            Expanded(
              child: Container(
                child: ListView.builder(
                  key: ValueKey('messages_${_currentConversationId}_${_messages.length}'),
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading dots as last item when loading
                    if (_isLoading && index == _messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _AnimatedDot(delay: 0),
                              const SizedBox(width: 4),
                              _AnimatedDot(delay: 200),
                              const SizedBox(width: 4),
                              _AnimatedDot(delay: 400),
                            ],
                          ),
                        ),
                      );
                    }

                    final message = _messages[index];
                    final isLastMessage = index == _messages.length - 1;

                    return ChatBubble(
                      message: message,
                      isLastMessage: isLastMessage,
                    );
                  },
                ),
              ),
            ),

            // Input area
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // New chat button
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: colorScheme.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Start New Chat'),
                          content: const Text('Are you sure you want to start a new chat? This will refresh your schedule data.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CANCEL'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                // Fetch fresh data when starting a new chat
                                await _fetchScheduleData();
                                _startNewConversation();
                                setState(() {}); // Refresh UI
                              },
                              child: const Text('NEW CHAT'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _isViewingOldConversation
                            ? 'Start a new chat to continue...'
                            : (_aiEnabled
                                ? 'Ask about your schedule...'
                                : 'AI is disabled. Set API key to chat...'),
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withOpacity(0.4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        isDense: true,
                      ),
                      onSubmitted: _sendMessage,
                      enabled: _aiEnabled && !_isViewingOldConversation && !_isLoading,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: (_aiEnabled && !_isViewingOldConversation && !_isLoading)
                          ? colorScheme.primary
                          : colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: (_aiEnabled && !_isViewingOldConversation && !_isLoading) ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: (_aiEnabled && !_isViewingOldConversation && !_isLoading)
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant.withOpacity(0.4),
                        size: 20,
                      ),
                      onPressed: (_aiEnabled && !_isViewingOldConversation && !_isLoading)
                          ? () => _sendMessage(_controller.text)
                          : (_isViewingOldConversation
                              ? null  // Disabled - viewing old conversation
                              : () => _showApiKeyDialog()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build chat history drawer
  Widget _buildChatHistoryDrawer(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Drawer header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Chat History',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your conversations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // New Chat button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context); // Close drawer
                await _fetchScheduleData();
                await _startNewConversation();
                setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant,
          ),
          
          // Chat history list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ChatStorage.getAllConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chat history yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a new conversation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final conversations = snapshot.data!;
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final conversationId = conversation['id'] as String;
                    final messages = conversation['messages'] as List;
                    final timestamp = conversation['timestamp'] as int;
                    
                    // Get first user message for title
                    String title = 'New Conversation';
                    if (messages.isNotEmpty) {
                      for (var msg in messages) {
                        if (msg['isUser'] == true) {
                          title = msg['text'].toString();
                          if (title.length > 40) {
                            title = '${title.substring(0, 40)}...';
                          }
                          break;
                        }
                      }
                    }
                    
                    final isCurrentConversation = conversationId == _currentConversationId;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrentConversation
                            ? colorScheme.primaryContainer.withOpacity(0.5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCurrentConversation
                                ? colorScheme.primary.withOpacity(0.2)
                                : colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: isCurrentConversation
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isCurrentConversation ? FontWeight.w600 : FontWeight.normal,
                            color: isCurrentConversation
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatTimestamp(timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                            size: 20,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Conversation'),
                                content: const Text('Are you sure you want to delete this conversation?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('CANCEL'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.error,
                                    ),
                                    child: const Text('DELETE'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirm == true) {
                              final deletedId = conversationId;
                              final success = await ChatStorage.deleteConversation(deletedId);
                              
                              if (success && mounted) {
                                // Refresh drawer immediately
                                setState(() {});
                                
                                // If deleted current conversation, start new one
                                if (deletedId == _currentConversationId) {
                                  await _startNewConversation();
                                }
                                
                                // Show confirmation
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Conversation deleted'),
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: 'OK',
                                      onPressed: () {},
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () async {
                          // Don't reload if already viewing this conversation
                          if (conversationId == _currentConversationId) {
                            Navigator.pop(context); // Just close drawer
                            return;
                          }
                          
                          Navigator.pop(context); // Close drawer first
                          
                          // Show loading indicator
                          if (mounted) {
                            setState(() {
                              _isLoading = true;
                            });
                          }
                          
                          try {
                            await _loadConversation(conversationId);
                          } catch (e) {
                            print('Error in onTap loadConversation: $e');
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Format timestamp for history items
  String _formatTimestamp(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Animated Dot Widget for loading indicator
class _AnimatedDot extends StatefulWidget {
  final int delay;

  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation with delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLastMessage;

  const ChatBubble({
    Key? key,
    required this.message,
    this.isLastMessage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: isLastMessage ? 8 : 4,
      ),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assistant,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
            ),

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: message.isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(18),
                  bottomLeft: message.isUser ? const Radius.circular(18) : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: message.isUser
                  ? Text(
                message.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary,
                ),
              )
                  : MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  code: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
                    color: colorScheme.onSurface,
                  ),
                  blockquote: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),

          if (message.isUser)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 8, bottom: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }
}
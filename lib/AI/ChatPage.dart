import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:revix/AI/gemini_service.dart';
import 'package:uuid/uuid.dart';
import '../Utils/UnifiedDatabaseService.dart';
import 'ApiKeyManager.dart';
import 'ChatHistoryPage.dart';
import 'ChatMessage.dart';
import 'ChatStorage.dart';
import 'ModelSelectionManager.dart';

class ChatPage extends StatefulWidget {
  final String? conversationId;

  const ChatPage({Key? key, this.conversationId}) : super(key: key);
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  late GeminiService _geminiService;
  bool _isLoading = false;
  String _currentConversationId = '';
  bool _isInitialized = false;
  bool _aiEnabled = false;

  // Store schedule data directly
  String? _scheduleData;

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
      // Use the new categoryDataProvider instead of ScheduleDataProvider
      _scheduleData = categoryDataProvider().getScheduleData();

      // If the data isn't already in cache, try to fetch it
      if (_scheduleData == 'No schedule data available') {
        await categoryDataProvider().fetchRawData();
        _scheduleData = categoryDataProvider().getScheduleData();
      }

      // Update the Gemini service with the new schedule data
      if (_scheduleData != null && _aiEnabled) {
        _geminiService.setScheduleData(_scheduleData!);
      }

      // Optional: Subscribe to raw data changes to keep the schedule data updated
      categoryDataProvider().rawDataStream.listen((data) {
        if (data != null) {
          _scheduleData = data.toString();

          // Update the Gemini service with the new schedule data
          if (_scheduleData != null && _aiEnabled) {
            _geminiService.setScheduleData(_scheduleData!);
          }
        } else {
          _scheduleData = 'No schedule data available';
        }
      });
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
      // Load conversation from storage
      final messagesData = await ChatStorage.loadConversation(conversationId);

      // Clear current messages
      _messages.clear();

      // Convert Map data to ChatMessage objects
      for (var messageData in messagesData) {
        _messages.add(ChatMessage.fromMap(messageData));
      }

      _currentConversationId = conversationId;

      // Load the messages into the Gemini chat session if AI is enabled
      if (_aiEnabled) {
        await _geminiService.loadChatHistory(_messages);
      }
    } catch (e) {
      // If there's an error, fetch fresh data and start a new conversation
      await _fetchScheduleData();
      _startNewConversation();
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
              : "Welcome to your reTrAIcker. AI features are currently disabled. You can enable them by setting your Gemini API key.",
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

// Modify _sendMessage to save the conversation only when the user actually sends a message
  void _sendMessage(String text) async {
    if (text.trim().isEmpty || !_aiEnabled) return;

    final userMessage = text;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    // First, check if this is the first message in a new conversation
    bool isFirstMessageInNewConversation = !await ChatStorage.conversationExists(_currentConversationId);

    // Now save the conversation with the user message - this will be the first save for a new conversation
    _saveConversation();

    try {
      // Ensure the Gemini service has the schedule data
      if (_scheduleData != null) {
        _geminiService.setScheduleData(_scheduleData!);
      }

      // Determine if this is the first user message
      final isFirstUserMessage = _messages.where((msg) => msg.isUser).length == 1;

      // Send message to Gemini
      final response = await _geminiService.askAboutSchedule(
        userMessage,
        _scheduleData ?? 'No schedule data available',
        withContext: isFirstUserMessage, // Only send context with first message
      );

      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });

      _scrollToBottom();

      // Save conversation with assistant's response
      _saveConversation();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I encountered an error. Please try again or check your connection.",
          isUser: false,
        ));
        _isLoading = false;
      });

      // Save conversation with error message
      _saveConversation();
    }
  }

  Future<void> _startNewConversation() async {
    // Generate a new UUID for the conversation
    final uuid = const Uuid();
    _currentConversationId = uuid.v4();

    // Clear messages
    _messages.clear();

    // Reset the Gemini chat session if AI is enabled
    if (_aiEnabled) {
      _geminiService.resetChat();

      // Set the schedule data in the Gemini service
      if (_scheduleData != null) {
        _geminiService.setScheduleData(_scheduleData!);
      }
    }

    // Add welcome message but don't save it yet
    String welcomeMessage = _aiEnabled
        ? "Hi there! I can help you understand your schedule. What would you like to know?"
        : "Welcome to your reTrAIcker. AI features are currently disabled. You can enable them by setting your Gemini API key.";

    _messages.add(ChatMessage(
      text: welcomeMessage,
      isUser: false,
    ));

    // No _saveConversation() call here - we'll save only when user interacts
  }

  Future<void> _saveConversation() async {
    // Convert messages to Map
    final messagesData = _messages.map((msg) => msg.toMap()).toList();

    // Save to storage
    ChatStorage.saveConversation(_currentConversationId, messagesData);
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
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Expanded(
                    child: Text(
                      'reTrAIcker',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // API key button
                  Material(
                    borderRadius: BorderRadius.circular(20),
                    color: _aiEnabled
                        ? colorScheme.primaryContainer.withOpacity(0.8)
                        : colorScheme.errorContainer.withOpacity(0.8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _showApiKeyDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _aiEnabled ? Icons.key : Icons.key_off,
                              size: 16,
                              color: _aiEnabled
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _aiEnabled ? 'API Key' : 'Set Key',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _aiEnabled
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),                  // Model selection button
                  FutureBuilder<String>(
                    future: _getCurrentModelDisplay(),
                    builder: (context, snapshot) {
                      String currentModel = snapshot.data ?? 'Loading...';
                      return Tooltip(
                        message: 'Current model: $currentModel\nTap to change',
                        child: Material(
                          borderRadius: BorderRadius.circular(20),
                          color: colorScheme.secondaryContainer.withOpacity(0.8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _showModelSelectionDialog,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.psychology,
                                    size: 16,
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Model',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // History button
                  IconButton(
                    icon: Icon(
                      Icons.history,
                      color: colorScheme.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer.withOpacity(0.8),
                    ),
                    onPressed: () async {
                      // Navigate to chat history page
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatHistoryPage(),
                        ),
                      );

                      // If a conversation ID was returned, load it
                      if (result != null && result is String) {
                        await _loadConversation(result);
                        setState(() {}); // Refresh UI
                      }
                    },
                  ),
                ],
              ),
            ),

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
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
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

            // Loading indicator
            if (_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Thinking...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                        hintText: _aiEnabled
                            ? 'Ask about your schedule...'
                            : 'AI is disabled. Set API key to chat...',
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
                      enabled: _aiEnabled,
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
                      color: _aiEnabled ? colorScheme.primary : colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: _aiEnabled ? [
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
                        color: _aiEnabled
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant.withOpacity(0.4),
                        size: 20,
                      ),
                      onPressed: _aiEnabled
                          ? () => _sendMessage(_controller.text)
                          : () => _showApiKeyDialog(),
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
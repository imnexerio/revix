import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:retracker/AI/gemini_service.dart';
import 'package:retracker/AI/schedule_data_provider.dart';
import 'package:uuid/uuid.dart';
import 'ApiKeyManager.dart';
import 'ChatHistoryPage.dart';
import 'ChatMessage.dart';
import 'ChatStorage.dart';

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

  // Cache for schedule data with better expiration handling
  String? _cachedScheduleData;
  DateTime? _lastScheduleDataFetch;
  static const int _cacheExpirationMinutes = 15; // Reduced from 30

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

  Future<void> _initializeApp() async {
    try {
      // Initialize with null API key first
      _geminiService = GeminiService(apiKey: null);

      // Check if API key exists and initialize Gemini if it does
      await _initializeGeminiService();

      // Load conversation and fetch schedule data in parallel
      await Future.wait([
        _loadConversationData(),
        _fetchAndCacheScheduleData(),
      ]);

      // Set the schedule data in the Gemini service
      if (_cachedScheduleData != null && _aiEnabled) {
        _geminiService.setScheduleData(_cachedScheduleData!);
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

  Future<void> _loadConversationData() async {
    // Load the specific conversation if provided, otherwise load the last active or create new
    if (widget.conversationId != null) {
      await _loadConversation(widget.conversationId!);
    } else {
      await _loadOrCreateConversation();
    }
  }

  Future<void> _fetchAndCacheScheduleData() async {
    try {
      final scheduleDataProvider = ScheduleDataProvider();
      _cachedScheduleData = await scheduleDataProvider.getScheduleData();
      _lastScheduleDataFetch = DateTime.now();

      // Update the Gemini service with the new schedule data
      if (_cachedScheduleData != null && _aiEnabled) {
        _geminiService.setScheduleData(_cachedScheduleData!);
      }
    } catch (e) {
      _cachedScheduleData = 'No schedule data available';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty || !_aiEnabled) return;

    final userMessage = text;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    // Save the conversation with the new user message - do this in background
    _saveConversation();

    try {
      // Get schedule data (from cache if available)
      final scheduleData = await _getScheduleData();

      // Ensure the Gemini service has the latest schedule data
      _geminiService.setScheduleData(scheduleData);

      // Determine if this is the first user message
      final isFirstUserMessage = _messages.where((msg) => msg.isUser).length == 1;

      // Send message to Gemini
      final response = await _geminiService.askAboutSchedule(
        userMessage,
        scheduleData,
        withContext: isFirstUserMessage, // Only send context with first message
      );

      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });

      _scrollToBottom();

      // Save conversation with assistant's response - do this in background
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

  Future<void> _initializeGeminiService() async {
    final apiKey = await ApiKeyManager.getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      _geminiService = GeminiService(apiKey: apiKey);
      _aiEnabled = _geminiService.isAvailable;
    }
  }

  Future<void> _showApiKeyDialog() async {
    final apiKey = await ApiKeyManager.showApiKeyDialog(context);
    if (apiKey != null && apiKey.isNotEmpty) {
      await ApiKeyManager.saveApiKey(apiKey);
      // Reinitialize the service with the new API key
      setState(() {
        _geminiService = GeminiService(apiKey: apiKey);
        _aiEnabled = _geminiService.isAvailable;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API key saved, AI features enabled'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI features disabled'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // Get schedule data (from cache if available and recent)
  Future<String> _getScheduleData() async {
    // If we have cached data that's less than 15 minutes old, use it
    if (_cachedScheduleData != null && _lastScheduleDataFetch != null) {
      final difference = DateTime.now().difference(_lastScheduleDataFetch!);
      if (difference.inMinutes < _cacheExpirationMinutes) {
        return _cachedScheduleData!;
      }
    }

    // Otherwise, fetch fresh data
    await _fetchAndCacheScheduleData();
    return _cachedScheduleData ?? 'No schedule data available';
  }

  Future<void> _loadOrCreateConversation() async {
    // If a specific conversation ID was provided, use that
    if (widget.conversationId != null) {
      await _loadConversation(widget.conversationId!);
      return;
    }

    // Otherwise try to get the last active conversation
    final activeConversationId = await ChatStorage.getActiveConversationId();

    if (activeConversationId != null) {
      // Load the last active conversation
      await _loadConversation(activeConversationId);
    } else {
      // Start a new conversation
      _startNewConversation();
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
      // If there's an error, start a new conversation
      _startNewConversation();
    }
  }

  Future<void> _startNewConversation() async {
    // Refresh schedule data in the background
    _fetchAndCacheScheduleData();

    // Generate a new UUID for the conversation
    final uuid = Uuid();
    _currentConversationId = uuid.v4();

    // Clear messages
    _messages.clear();

    // Reset the Gemini chat session if AI is enabled
    if (_aiEnabled) {
      _geminiService.resetChat();

      // Set the fresh schedule data in the Gemini service
      if (_cachedScheduleData != null) {
        _geminiService.setScheduleData(_cachedScheduleData!);
      }
    }

    // Add welcome message
    String welcomeMessage = _aiEnabled
        ? "Hi there! I can help you understand your schedule. What would you like to know?"
        : "Welcome to your reTrAIcker. AI features are currently disabled. You can enable them by setting your Gemini API key.";

    _messages.add(ChatMessage(
      text: welcomeMessage,
      isUser: false,
    ));

    // Save this new conversation
    _saveConversation();
  }

  Future<void> _saveConversation() async {
    // Convert messages to Map
    final messagesData = _messages.map((msg) => msg.toMap()).toList();

    // Save to storage
    ChatStorage.saveConversation(_currentConversationId, messagesData);
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
              CircularProgressIndicator(),
              SizedBox(height: 16),
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 1),
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
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            SizedBox(width: 4),
                            Text(
                              _aiEnabled ? 'API Key' : 'Set Key',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _aiEnabled
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
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
                          builder: (context) => ChatHistoryPage(),
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
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.error),
                    SizedBox(width: 8),
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
                // decoration: BoxDecoration(
                //   color: colorScheme.background,
                //   image: DecorationImage(
                //     image: AssetImage('assets/chat_bg.png'), // Optional subtle pattern
                //     opacity: 0.05,
                //     repeat: ImageRepeat.repeat,
                //   ),
                // ),
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
                    SizedBox(width: 12),
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
                    offset: Offset(0, -2),
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
                          title: Text('Start New Chat'),
                          content: Text('Are you sure you want to start a new chat? This will refresh your schedule data.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('CANCEL'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _startNewConversation();
                                setState(() {}); // Refresh UI
                              },
                              child: Text('NEW CHAT'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 8),

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
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        isDense: true,
                      ),
                      onSubmitted: _sendMessage,
                      enabled: _aiEnabled,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  SizedBox(width: 8),

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
                          offset: Offset(0, 2),
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
              margin: EdgeInsets.only(right: 8, bottom: 4),
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
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: message.isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: message.isUser ? Radius.circular(4) : Radius.circular(18),
                  bottomLeft: message.isUser ? Radius.circular(18) : Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.08),
                    blurRadius: 4,
                    offset: Offset(0, 1),
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
              margin: EdgeInsets.only(left: 8, bottom: 4),
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
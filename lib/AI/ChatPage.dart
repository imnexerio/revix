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
  final String? conversationId; // Add this parameter to load a specific conversation

  const ChatPage({Key? key, this.conversationId}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  late GeminiService _geminiService;
  bool _isLoading = false;
  String _currentConversationId = '';
  bool _isInitialized = false;
  bool _aiEnabled = false;

  // Cache for schedule data
  String? _cachedScheduleData;
  DateTime? _lastScheduleDataFetch;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize with null API key first
    _geminiService = GeminiService(apiKey: null);

    // Check if API key exists and initialize Gemini if it does
    await _initializeGeminiService();

    // Load the specific conversation if provided, otherwise load the last active or create new
    if (widget.conversationId != null) {
      _loadConversation(widget.conversationId!);
    } else {
      _loadOrCreateConversation();
    }

    // Fetch schedule data once at startup
    await _fetchAndCacheScheduleData();

    // Set the schedule data in the Gemini service
    if (_cachedScheduleData != null && _aiEnabled) {
      _geminiService.setScheduleData(_cachedScheduleData!);
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
      // print('Error fetching schedule data: $e');
      _cachedScheduleData = 'No schedule data available';
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

    // Save the conversation with the new user message
    await _saveConversation();

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

      // Save conversation with assistant's response
      await _saveConversation();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "Sorry, I encountered an error: $e", isUser: false));
        _isLoading = false;
      });

      // Save conversation with error message
      await _saveConversation();
    }
  }

  Future<void> _initializeGeminiService() async {
    final apiKey = await ApiKeyManager.getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      _geminiService = GeminiService(apiKey: apiKey);
      setState(() {
        _aiEnabled = _geminiService.isAvailable;
      });
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
        SnackBar(content: Text('API key saved, AI features enabled')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI features disabled')),
      );
    }
  }

  // Get schedule data (from cache if available and recent)
  Future<String> _getScheduleData() async {
    // If we have cached data that's less than 30 minutes old, use it
    if (_cachedScheduleData != null && _lastScheduleDataFetch != null) {
      final difference = DateTime.now().difference(_lastScheduleDataFetch!);
      if (difference.inMinutes < 30) {
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
    setState(() {
      _isLoading = true;
    });

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

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    } catch (e) {
      // print('Error loading conversation: $e');
      // If there's an error, start a new conversation
      _startNewConversation();
    }
  }

  Future<void> _startNewConversation() async {
    setState(() {
      _isLoading = true;
    });

    // Refresh schedule data first
    await _fetchAndCacheScheduleData();

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
        : "Welcome to your Schedule Assistant. AI features are currently disabled. You can enable them by setting your Gemini API key.";

    _messages.add(ChatMessage(
      text: welcomeMessage,
      isUser: false,
    ));

    // Save this new conversation
    await _saveConversation();

    setState(() {
      _isInitialized = true;
      _isLoading = false;
    });
  }

  Future<void> _saveConversation() async {
    // Convert messages to Map
    final messagesData = _messages.map((msg) => msg.toMap()).toList();

    // Save to storage
    await ChatStorage.saveConversation(_currentConversationId, messagesData);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.background,
            ],
          ),
        ),
        child: SafeArea( // Added SafeArea to maintain proper spacing at the top
          child: Column(
            children: [
              // Control buttons row that was previously in the AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // API key button
                    IconButton(
                      icon: Icon(
                        _aiEnabled ? Icons.key : Icons.key_off,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: _showApiKeyDialog,
                    ),
                    // History button
                    IconButton(
                      icon: Icon(
                        Icons.history,
                        color: theme.colorScheme.primary,
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
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber[800]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI chat features are disabled. Tap the key icon to set your Gemini API key.',
                          style: TextStyle(color: Colors.amber[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return ChatBubble(
                      message: message,
                      theme: theme,
                    );
                  },
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(),
                ),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          prefixIcon: IconButton(
                            icon: Icon(
                              Icons.add,
                              color: theme.colorScheme.primary,
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
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _startNewConversation();
                                      },
                                      child: Text('NEW CHAT'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          hintText: _aiEnabled
                              ? 'Ask about your schedule...'
                              : 'AI is disabled. Set API key to chat...',
                          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onSubmitted: _sendMessage,
                        enabled: _aiEnabled,
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _aiEnabled ? theme.colorScheme.primary : Colors.grey,
                            _aiEnabled ? theme.colorScheme.secondary : Colors.grey.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _aiEnabled
                                ? theme.colorScheme.primary.withOpacity(0.4)
                                : Colors.transparent,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: _aiEnabled
                              ? theme.colorScheme.onPrimary
                              : Colors.grey.shade300,
                          size: 22,
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
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final ThemeData theme;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: message.isUser ? Radius.circular(4) : Radius.circular(20),
            bottomLeft: message.isUser ? Radius.circular(20) : Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: message.isUser
            ? Text(
          message.text,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 15,
          ),
        )
            : MarkdownBody(
          data: message.text,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
  }
}
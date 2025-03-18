import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:retracker/AI/gemini_service.dart';
import 'package:retracker/AI/schedule_data_provider.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  late GeminiService _geminiService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final apiKey = "AIzaSyBWEzIjMNIWoT0z0kITPjm3N5Vnx8RgMSY"; // Store this securely!
    _geminiService = GeminiService(apiKey: apiKey);
    _initChat();
  }

  void _initChat() {
    setState(() {
      _messages.add(ChatMessage(
        text: "Hi there! I can help you understand your schedule. What would you like to know?",
        isUser: false,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Assistant'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Column(
        children: [
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
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about your schedule...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send_rounded, color: theme.colorScheme.onPrimary),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = text;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });

    try {
      // Ensure ScheduleDataProvider is properly instantiated
      final scheduleDataProvider = ScheduleDataProvider();
      final scheduleData = await scheduleDataProvider.getScheduleData();
      print('Schedule data: $scheduleData');

      final response = await _geminiService.askAboutSchedule(userMessage, scheduleData);

      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "Sorry, I encountered an error: $e", isUser: false));
        _isLoading = false;
      });
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
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
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: message.isUser
            ? Text(
          message.text,
          style: TextStyle(color: theme.colorScheme.onPrimary),
        )
            : MarkdownBody(
          data: message.text,
          styleSheet: MarkdownStyleSheet.fromTheme(theme),
        ),
      ),
    );
  }
}
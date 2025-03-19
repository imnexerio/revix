import 'package:google_generative_ai/google_generative_ai.dart';
import 'ChatMessage.dart';

class GeminiService {
  final String? apiKey;
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool isAvailable = false;
  String? _currentScheduleData;

  GeminiService({this.apiKey}) {
    if (apiKey != null && apiKey!.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey!,
      );
      isAvailable = true;
      _initChatSession();
    }
  }

  void _initChatSession() {
    if (_model != null) {
      // Create a chat history object
      final history = [];

      const systemPrompt = '''You are a helpful schedule assistant. You can ONLY answer questions related to the user's schedule data that has been provided to you.
If the user asks questions that are not related to their schedule data, politely inform them that you can only answer questions about their schedule.
Do not make up information that is not present in the schedule data.
When in doubt, ask for clarification about what part of the schedule they are inquiring about.''';

      // Start the chat session with the model
      _chatSession = _model!.startChat(
        // Use history if your version supports it
        // history: history,
      );

      // Send the system instruction as the first message if needed
      if (_chatSession != null) {
        try {
          // This is an alternative approach - send the system instruction as a hidden context message
          _chatSession!.sendMessage(Content.text(
              "SYSTEM INSTRUCTION (not visible to user): $systemPrompt"
          ));
        } catch (e) {
          // Handle any error silently
          print("Could not set system instruction: $e");
        }
      }
    }
  }

  // Store schedule data for reference
  void setScheduleData(String scheduleData) {
    _currentScheduleData = scheduleData;
  }

  // Manually reset the chat session
  void resetChat() {
    if (isAvailable) {
      _initChatSession();
      _currentScheduleData = null;
    }
  }

  // Send a message within the chat session
  Future<String> sendMessage(String message) async {
    if (!isAvailable) {
      return "AI features are not available. Please set your Gemini API key in settings.";
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      return response.text ?? "No response received";
    } catch (e) {
      return "Error: $e";
    }
  }

  // Provide the user's schedule data context to Gemini
  Future<String> askAboutSchedule(String question, String scheduleData, {bool withContext = false}) async {
    if (!isAvailable) {
      return "AI features are not available. Please set your Gemini API key in settings.";
    }

    try {
      // Always store the latest schedule data
      _currentScheduleData = scheduleData;

      String prompt;

      if (withContext) {
        // Only add context if this is a new question that needs schedule data
        prompt = '''I'm going to share my schedule data with you. Please only answer questions related to this data and decline to answer anything that's not directly related to this schedule.

SCHEDULE DATA:
$scheduleData

My question is: $question''';
      } else {
        // For follow-up questions, remind the model to stick to schedule data
        prompt = '''Remember to only answer questions about my schedule data that I shared earlier.

My follow-up question is: $question''';
      }

      final response = await _chatSession!.sendMessage(Content.text(prompt));
      return response.text ?? "No response received";
    } catch (e) {
      return "Error: $e";
    }
  }

  // Load a chat history into the session
  Future<void> loadChatHistory(List<ChatMessage> messages) async {
    if (!isAvailable) return;

    // Reset the chat
    resetChat();

    // Skip the first assistant message as it's the initial greeting
    bool isFirstAssistantMessage = true;
    bool hasLoadedScheduleContext = false;

    // Add each message to recreate the conversation
    for (final message in messages) {
      if (message.isUser) {
        // If this is the first user message and we need to inject schedule context
        if (!hasLoadedScheduleContext && _currentScheduleData != null) {
          // Send a hidden system message with schedule data before the first user message
          await _chatSession!.sendMessage(Content.text(
              "Here is the user's schedule data: $_currentScheduleData\n\nRemember to ONLY answer questions related to this schedule data."
          ));
          hasLoadedScheduleContext = true;
        }

        await _chatSession!.sendMessage(Content.text(message.text));
      } else if (!isFirstAssistantMessage) {
        // We don't need to send assistant messages, but we could use history if the API supports it
      } else {
        isFirstAssistantMessage = false;
      }
    }
  }
}
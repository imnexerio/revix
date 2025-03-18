import 'package:google_generative_ai/google_generative_ai.dart';
import 'ChatMessage.dart';

class GeminiService {
  final String? apiKey;
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool isAvailable = false;

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
      _chatSession = _model!.startChat();
    }
  }

  // Manually reset the chat session
  void resetChat() {
    if (isAvailable) {
      _initChatSession();
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
      String prompt;

      if (withContext) {
        // Only add context if this is a new question that needs schedule data
        prompt = "Here is my current schedule data: $scheduleData\n\nBased on this schedule, please answer the following question: $question";
      } else {
        // For follow-up questions, just send the question directly
        prompt = question;
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

    // Add each message to recreate the conversation
    for (final message in messages) {
      if (message.isUser) {
        await _chatSession!.sendMessage(Content.text(message.text));
      } else if (!isFirstAssistantMessage) {
        // We don't need to send assistant messages, but we could use history if the API supports it
      } else {
        isFirstAssistantMessage = false;
      }
    }
  }
}
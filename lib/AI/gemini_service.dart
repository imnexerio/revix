import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final GenerativeModel _model;
  GenerativeModel? _chatModel;

  GeminiService({required String apiKey})
      : _model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: apiKey,
  );

  // Initialize a chat model
  GenerativeModel getModel() {
    return _model;
  }

  // Send a message and get a response
  Future<String> sendMessage(String message) async {
    try {
      final content = [Content.text(message)];
      final response = await _model.generateContent(content);
      return response.text ?? "No response received";
    } catch (e) {
      return "Error: $e";
    }
  }

  // Provide the user's schedule data context to Gemini
  Future<String> askAboutSchedule(String question, String scheduleData) async {
    try {
      // Create content with context about the schedule and the question
      final content = [
        Content.text(
            "Here is my current schedule data: $scheduleData\n\nBased on this schedule, please answer the following question: $question"
        )
      ];

      // Generate response
      final response = await _model.generateContent(content);
      return response.text ?? "No response received";
    } catch (e) {
      return "Error: $e";
    }
  }
}
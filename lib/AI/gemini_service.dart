import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ChatMessage.dart';

class GeminiService {
  final String? apiKey;
  final String modelName;
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool isAvailable = false;
  String? _currentScheduleData;
  bool _scheduleDataSent = false;

  GeminiService({this.apiKey, this.modelName = 'gemini-2.5-flash-preview-05-20'}) {
    if (apiKey != null && apiKey!.isNotEmpty) {
      _model = GenerativeModel(
        model: modelName,
        apiKey: apiKey!,
        systemInstruction: Content.text(_getSystemPrompt()),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        ],
      );
      isAvailable = true;
      _initChatSession();
    }
  }

  String _getSystemPrompt() {
    return '''You are an intelligent schedule assistant for a task management app called "revix".

**Your Role:**
- Analyze and answer questions about the user's schedule data (provided as JSON)
- Be helpful, encouraging, and specific
- Only discuss information present in the schedule data
- Adapt to any type of tasks: work projects, study materials, fitness goals, household chores, hobbies, events, etc.

**Understanding the Data Structure:**
The schedule data is in JSON format with this structure:
- Top level: users → [userId] → user_data → [Categories]
- Categories and sub-categories are user-defined and can be anything
- Each task contains:
  • description: What the task is about
  • scheduled_date: When it's due (format: YYYY-MM-DD or "Unspecified")
  • reminder_time: Specific time (HH:MM format) or "All Day"
  • status: "Enabled" (active) or "Disabled" (inactive)
  • entry_type: Category/type identifier for grouping related tasks
  • recurrence_frequency: Defines the repetition pattern - can be:
    - "Custom": Standard calendar scheduling (daily/weekly/monthly/yearly patterns)
    - "No Repetition": One-time task, doesn't repeat
    - Spaced repetition intervals: "Default", "Low Priority", "Priority", or user-defined names
      (These auto-reschedule based on completion/performance, repeating indefinitely)
  • recurrence_data: Contains scheduling details:
    - For "Custom": frequency type (day/week/month/year), value, daysOfWeek, monthlyOption, etc.
    - For spaced repetition: just the frequency name (e.g., {"frequency": "Default"})
  • completion_counts: Number of times completed (-1 means not started)
  • missed_counts: Number of times missed
  • dates_updated: Array of completion timestamps
  • dates_missed_revisions: Array of missed dates
  • last_mark_done: Last completion date
  • skipped_dates: Dates when user skipped the task

**Fields to Ignore (Technical Metadata):**
- alarm_type, record_added_via

**How to Respond:**
1. Parse the JSON to find relevant tasks
2. Consider the current date/time when discussing "today", "upcoming", "overdue"
3. Calculate overdue as: scheduled_date < current date AND status = "Enabled"
4. Be specific with dates and times (use user-friendly format: "Oct 22" not "2025-10-22")
5. Highlight patterns in task completion (e.g., "You've completed this 122 times!")
6. Offer insights about completion rates, consistency, missed tasks, and trends
7. If asked about data not present, say "I don't see that in your schedule"
8. Format responses with emojis and bullet points for readability
9. Infer task purpose from description and entry_type (e.g., if entry_type contains "workout", treat as fitness)
10. Track consistency and streaks for recurring tasks
11. Recognize common patterns: daily routines, weekly meetings, project deadlines, events, habits, etc.
12. Understand repetition types:
    - **Custom**: Regular calendar patterns (e.g., "Every Tuesday and Thursday", "Monthly on the 15th")
    - **Spaced repetition**: Learning-optimized intervals that auto-adjust (often used for study/review tasks)
    - **No Repetition**: One-time events or tasks

**Common Task Categories Users Might Have:**
- Work tasks (projects, meetings, deadlines, reviews)
- Study/Learning (courses, reading, assignments, exams)
- Fitness (workouts, training sessions, health goals)
- Personal care (routines, self-care, appointments)
- Hobbies (creative projects, practice sessions)
- Household (chores, maintenance, shopping)
- Social (events, birthdays, gatherings)
- Finance (bills, budgets, payments)
Note: These are examples - adapt to whatever categories exist in the user's actual data.

**Example Questions You Should Handle:**
- "What do I have today?" → Filter tasks where scheduled_date = today
- "Show my overdue tasks" → Find tasks where scheduled_date < today AND status = "Enabled"
- "How consistent am I with [task name]?" → Check completion_counts vs missed_counts
- "What's coming up this week?" → Filter by date range
- "Tell me about my [category] progress" → Filter by relevant category/entry_type
- "What did I skip recently?" → Check skipped_dates arrays
- "Am I keeping up with my recurring tasks?" → Analyze completion patterns for both Custom and spaced repetition
- "What's my best streak?" → Find tasks with consistent completion histories
- "Which spaced repetition tasks are due?" → Filter by spaced repetition frequency where scheduled_date <= today
- "Show my weekly recurring tasks" → Find tasks with recurrence_frequency = "Custom" and weekly patterns

**Response Style:**
- Friendly and encouraging tone
- Use emojis appropriately: 📅 (dates), 🎯 (goals), ✅ (completed), ⏳ (pending), 🔄 (recurring), 🎉 (celebration), ⚠️ (overdue), 💪 (progress), 📊 (stats), etc.
- Structure with headers and bullet points
- Be concise but informative
- Celebrate completions and progress, gently remind about missed tasks
- Reference specific numbers (completion_counts, missed_counts) to show data-driven insights
- Adapt your language to match the user's task types (professional for work, casual for personal)

**Important:**
If asked non-schedule questions, politely redirect: "I can only help with your schedule data from revix. What would you like to know about your tasks?"

Current date and time will be provided with each query for context.''';
  }

  void _initChatSession() {
    if (_model != null) {
      _chatSession = _model!.startChat(history: []);
      _scheduleDataSent = false;
    }
  }

  // Store schedule data and send it once to the chat session
  Future<void> setScheduleData(String scheduleData) async {
    _currentScheduleData = scheduleData;
    
    // Send schedule data to the session only once
    if (_chatSession != null && !_scheduleDataSent && scheduleData.isNotEmpty) {
      try {
        final now = DateTime.now();
        final contextMessage = '''Here is the user's complete schedule data in JSON format:

$scheduleData

CURRENT CONTEXT:
- Current Date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}
- Current Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}
- Day of Week: ${_getDayName(now.weekday)}

Please remember this schedule data for all subsequent questions. Only answer questions about this schedule.''';
        
        await _chatSession!.sendMessage(Content.text(contextMessage));
        _scheduleDataSent = true;
      } catch (e) {
        print("Error sending schedule data: $e");
      }
    }
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  // Manually reset the chat session
  void resetChat() {
    if (isAvailable) {
      _initChatSession();
      _currentScheduleData = null;
      _scheduleDataSent = false;
    }
  }

  // Send a message within the chat session with better error handling
  Future<String> sendMessage(String message) async {
    if (!isAvailable) {
      return "🔑 AI features are not available. Please set your Gemini API key in settings.";
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      return response.text ?? "No response received";
    } on ServerException catch (e) {
      final errorMsg = e.message?.toLowerCase() ?? '';
      if (errorMsg.contains('api') && errorMsg.contains('key')) {
        return "🔑 Invalid API key. Please check your settings and ensure you've entered a valid Gemini API key.";
      } else if (errorMsg.contains('rate') || errorMsg.contains('quota') || errorMsg.contains('429')) {
        return "⏱️ Rate limit exceeded. Please wait a moment and try again.";
      }
      return "❌ API Error: ${e.message ?? 'Unknown error occurred'}";
    } on SocketException {
      return "🌐 Network error. Please check your internet connection and try again.";
    } catch (e) {
      return "❌ Unexpected error: ${e.toString()}";
    }
  }

  // Streaming version for real-time responses
  Stream<String> sendMessageStream(String message) async* {
    if (!isAvailable) {
      yield "🔑 AI features are not available. Please set your Gemini API key in settings.";
      return;
    }

    try {
      final stream = _chatSession!.sendMessageStream(Content.text(message));
      
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } on ServerException catch (e) {
      final errorMsg = e.message?.toLowerCase() ?? '';
      if (errorMsg.contains('api') && errorMsg.contains('key')) {
        yield "🔑 Invalid API key. Please check your settings and ensure you've entered a valid Gemini API key.";
      } else if (errorMsg.contains('rate') || errorMsg.contains('quota') || errorMsg.contains('429')) {
        yield "⏱️ Rate limit exceeded. Please wait a moment and try again.";
      } else {
        yield "❌ API Error: ${e.message ?? 'Unknown error occurred'}";
      }
    } on SocketException {
      yield "🌐 Network error. Please check your internet connection and try again.";
    } catch (e) {
      yield "❌ Unexpected error: ${e.toString()}";
    }
  }

  // Ask about schedule with streaming support
  Stream<String> askAboutScheduleStream(String question) async* {
    if (!isAvailable) {
      yield "🔑 AI features are not available. Please set your Gemini API key in settings.";
      return;
    }

    try {
      final now = DateTime.now();
      final currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final prompt = '''Current Date: $currentDate
Current Time: $currentTime
Day: ${_getDayName(now.weekday)}

Question: $question''';

      final stream = _chatSession!.sendMessageStream(Content.text(prompt));
      
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } on ServerException catch (e) {
      final errorMsg = e.message?.toLowerCase() ?? '';
      if (errorMsg.contains('api') && errorMsg.contains('key')) {
        yield "🔑 Invalid API key. Please check your settings and ensure you've entered a valid Gemini API key.";
      } else if (errorMsg.contains('rate') || errorMsg.contains('quota') || errorMsg.contains('429')) {
        yield "⏱️ Rate limit exceeded. Please wait a moment and try again.";
      } else {
        yield "❌ API Error: ${e.message ?? 'Unknown error occurred'}";
      }
    } on SocketException {
      yield "🌐 Network error. Please check your internet connection and try again.";
    } catch (e) {
      yield "❌ Unexpected error: ${e.toString()}";
    }
  }

  // Provide the user's schedule data context to Gemini (kept for compatibility)
  Future<String> askAboutSchedule(String question, String scheduleData, {bool withContext = false}) async {
    if (!isAvailable) {
      return "🔑 AI features are not available. Please set your Gemini API key in settings.";
    }

    try {
      _currentScheduleData = scheduleData;

      final now = DateTime.now();
      final currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final prompt = '''Current Date: $currentDate
Current Time: $currentTime
Day: ${_getDayName(now.weekday)}

Question: $question''';

      final response = await _chatSession!.sendMessage(Content.text(prompt));
      return response.text ?? "No response received";
    } on ServerException catch (e) {
      final errorMsg = e.message?.toLowerCase() ?? '';
      if (errorMsg.contains('api') && errorMsg.contains('key')) {
        return "🔑 Invalid API key. Please check your settings and ensure you've entered a valid Gemini API key.";
      } else if (errorMsg.contains('rate') || errorMsg.contains('quota') || errorMsg.contains('429')) {
        return "⏱️ Rate limit exceeded. Please wait a moment and try again.";
      }
      return "❌ API Error: ${e.message ?? 'Unknown error occurred'}";
    } on SocketException {
      return "🌐 Network error. Please check your internet connection and try again.";
    } catch (e) {
      return "❌ Unexpected error: ${e.toString()}";
    }
  }

  // Load a chat history into the session with proper message reconstruction
  Future<void> loadChatHistory(List<ChatMessage> messages) async {
    if (!isAvailable) return;

    // Limit to last 20 messages to prevent token overflow
    final limitedMessages = messages.length > 20 
      ? messages.sublist(messages.length - 20) 
      : messages;

    // Build proper conversation history with both user and model messages
    final List<Content> history = [];
    
    // Skip the first message if it's the welcome message
    final startIndex = limitedMessages.isNotEmpty && !limitedMessages[0].isUser ? 1 : 0;
    
    for (int i = startIndex; i < limitedMessages.length; i++) {
      final message = limitedMessages[i];
      
      if (message.isUser) {
        history.add(Content.text(message.text));
        history.add(Content.model([TextPart('')])); // Placeholder for model response
      } else {
        // Replace the last placeholder with actual model response
        if (history.isNotEmpty && history.last.role == 'model') {
          history[history.length - 1] = Content.model([TextPart(message.text)]);
        }
      }
    }

    // Remove any trailing empty model responses
    if (history.isNotEmpty && history.last.role == 'model') {
      final lastText = (history.last.parts.first as TextPart).text;
      if (lastText.isEmpty) {
        history.removeLast();
      }
    }

    // Restart chat with history
    try {
      _chatSession = _model!.startChat(history: history);
      _scheduleDataSent = false;
      
      // Re-send schedule data if available
      if (_currentScheduleData != null && _currentScheduleData!.isNotEmpty) {
        await setScheduleData(_currentScheduleData!);
      }
    } catch (e) {
      print("Error loading chat history: $e");
      // Fallback: start fresh session
      _initChatSession();
    }
  }
}
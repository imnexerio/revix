class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now() {
    // Validation
    if (text.trim().isEmpty) {
      throw ArgumentError('Message text cannot be empty');
    }
  }

  // Convert to Map for storage (with validation)
  Map<String, dynamic> toMap() {
    try {
      return {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
    } catch (e) {
      throw Exception('Failed to serialize ChatMessage: $e');
    }
  }

  // Create from Map with null safety and validation
  factory ChatMessage.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      throw ArgumentError('Cannot create ChatMessage from null map');
    }

    try {
      // Validate required fields exist
      if (!map.containsKey('text') || !map.containsKey('isUser')) {
        throw ArgumentError('Missing required fields in ChatMessage map');
      }

      final text = map['text'];
      final isUser = map['isUser'];

      // Type validation
      if (text is! String) {
        throw ArgumentError('text must be a String, got ${text.runtimeType}');
      }
      
      if (isUser is! bool) {
        throw ArgumentError('isUser must be a bool, got ${isUser.runtimeType}');
      }

      if (text.trim().isEmpty) {
        throw ArgumentError('Message text cannot be empty');
      }

      // Parse timestamp with fallback
      DateTime timestamp;
      try {
        final timestampValue = map['timestamp'];
        if (timestampValue is int) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
        } else {
          timestamp = DateTime.now();
        }
      } catch (e) {
        // Fallback to current time if parsing fails
        timestamp = DateTime.now();
      }

      return ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: timestamp,
      );
    } catch (e) {
      throw Exception('Failed to deserialize ChatMessage: $e');
    }
  }

  // Create a copy with updated fields
  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(text: ${text.length > 50 ? text.substring(0, 50) + '...' : text}, isUser: $isUser, timestamp: $timestamp)';
  }
}
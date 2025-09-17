// lib/models/thread_message_model.dart
import 'package:flutter/foundation.dart'; // For @required on older Flutter versions, or just for clarity

class ThreadMessage {
  final String id; // Unique ID for the message itself
  final String threadId; // Foreign key linking to the parent SupportThread
  final String senderId; // UUID of the user or admin who sent the message
  final String senderRole; // 'user' or 'admin'
  final String messageContent; // <<< THIS LINE WAS MISSING THE `final String` part or was misplaced
  final DateTime createdAt; // When the message was sent

  // Optional: Denormalized sender data for easier display in chat bubbles
  final String? senderUsername;
  // final String? senderAvatarUrl; // If you have avatars

  ThreadMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    required this.messageContent, // Used here
    required this.createdAt,
    this.senderUsername,
    // this.senderAvatarUrl,
  });

  factory ThreadMessage.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? senderProfileData}) {
    return ThreadMessage(
      id: map['id'] as String,
      threadId: map['thread_id'] as String,
      senderId: map['sender_id'] as String,
      senderRole: map['sender_role'] as String,
      messageContent: map['message_content'] as String, // Used here
      createdAt: DateTime.parse(map['created_at'] as String),
      senderUsername: senderProfileData?['username'] as String?,
      // senderAvatarUrl: senderProfileData?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'thread_id': threadId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message_content': messageContent, // Used here
      'created_at': createdAt.toIso8601String(),
    };
  }
}

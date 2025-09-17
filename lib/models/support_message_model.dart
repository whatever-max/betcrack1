// lib/models/support_message_model.dart  <-- THIS IS THE SINGLE SOURCE OF TRUTH
import 'package:flutter/foundation.dart'; // For @required if using older Flutter, or just for clarity

class SupportMessage { // <<<--- RENAMED THE CLASS
  final String id;
  final String userId;
  final String? userPhone;
  final String messageContent;
  String status;
  final DateTime createdAt;
  final String? adminReply;
  final DateTime? repliedAt;
  final String? adminIdReplied;
  final String? userEmail;

  SupportMessage({ // <<<--- Constructor updated
    required this.id,
    required this.userId,
    this.userPhone,
    required this.messageContent,
    required this.status,
    required this.createdAt,
    this.adminReply,
    this.repliedAt,
    this.adminIdReplied,
    this.userEmail,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map, {String? userEmail}) { // <<<--- Factory updated
    return SupportMessage(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userPhone: map['user_phone'] as String?,
      messageContent: map['message_content'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      adminReply: map['admin_reply'] as String?,
      repliedAt: map['replied_at'] != null ? DateTime.parse(map['replied_at'] as String) : null,
      adminIdReplied: map['admin_id_replied'] as String?,
      userEmail: userEmail,
    );
  }
}

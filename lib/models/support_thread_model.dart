// lib/models/support_thread_model.dart
class SupportThread {
  final String id;
  final String userId;
  final String? subject;
  String status;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastMessageAt;
  String? lastMessagePreview;
  bool isReadByUser;
  bool isReadByAdmin;

  // Optional: To hold the count of unread messages for the current user
  int unreadMessagesCountForUser;


  SupportThread({
    required this.id,
    required this.userId,
    this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.isReadByUser,
    required this.isReadByAdmin,
    this.unreadMessagesCountForUser = 0, // Default for now
  });

  factory SupportThread.fromMap(Map<String, dynamic> map) {
    return SupportThread(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      subject: map['subject'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastMessageAt: map['last_message_at'] != null ? DateTime.parse(map['last_message_at'] as String) : null,
      lastMessagePreview: map['last_message_preview'] as String?,
      isReadByUser: map['is_read_by_user'] as bool? ?? true, // Default to true if somehow null
      isReadByAdmin: map['is_read_by_admin'] as bool? ?? false, // Default to false if somehow null
    );
  }

  // Method to update status locally for UI responsiveness
  void updateLocalStatus(String newStatus) {
    status = newStatus;
    updatedAt = DateTime.now(); // Reflect change locally
  }
}

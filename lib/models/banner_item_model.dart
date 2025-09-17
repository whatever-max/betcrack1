// lib/models/banner_item_model.dart

class BannerItem {
  final String id;
  final String imageUrl;
  final String? title;
  final String? actionUrl;
  final bool isActive;
  final DateTime createdAt;
  final String? adminId; // Make sure this is in your DB schema for banners if you use it

  BannerItem({
    required this.id,
    required this.imageUrl,
    this.title,
    this.actionUrl,
    required this.isActive,
    required this.createdAt,
    this.adminId,
  });

  factory BannerItem.fromMap(Map<String, dynamic> map) {
    return BannerItem(
      id: map['id'] as String,
      imageUrl: map['image_url'] as String,
      title: map['title'] as String?,
      actionUrl: map['action_url'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      adminId: map['admin_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_url': imageUrl,
      'title': title,
      'action_url': actionUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'admin_id': adminId,
    };
  }
}

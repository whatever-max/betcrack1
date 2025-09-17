// lib/models/profile_model.dart
import 'package:flutter/foundation.dart';

@immutable
class Profile {
  final String id; // Corresponds to auth.users.id and profiles.id
  final String username;
  final String phone;
  final String role; // e.g., 'user', 'super_admin'
  final DateTime createdAt;
  final String? email; // Optional, as per your schema

  const Profile({
    required this.id,
    required this.username,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.email,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      username: map['username'] as String? ?? 'Unknown User', // Provide default
      phone: map['phone'] as String? ?? 'No phone', // Provide default
      role: map['role'] as String? ?? 'user', // Default role
      createdAt: DateTime.parse(map['created_at'] as String),
      email: map['email'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'phone': phone,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'email': email,
    };
  }
}


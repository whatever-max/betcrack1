// lib/models/betslip.dart

class Betslip {
  final String id;
  final String title;
  final String imageUrl;
  final bool isPaid;
  final int price;
  final DateTime? createdAt;
  final String? bookingCode;

  // New fields
  final DateTime? validUntil;
  final String? odds;
  final String? companyName;
  final DateTime? autoUnlockAt; // For client-side logic to treat as free after this time

  Betslip({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.isPaid,
    required this.price,
    this.createdAt,
    this.bookingCode,
    // New fields
    this.validUntil,
    this.odds,
    this.companyName,
    this.autoUnlockAt,
  });

  factory Betslip.fromJson(Map<String, dynamic> json) {
    return Betslip(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'No Title',
      imageUrl: json['image_url'] as String? ?? '',
      isPaid: json['is_paid'] as bool? ?? false,
      price: json['price'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String? ?? '')
          : null,
      bookingCode: json['booking_code'] as String?,
      // New fields
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'] as String? ?? '')
          : null,
      odds: json['odds'] as String?,
      companyName: json['company_name'] as String?,
      autoUnlockAt: json['auto_unlock_at'] != null
          ? DateTime.tryParse(json['auto_unlock_at'] as String? ?? '')
          : null,
    );
  }

  // Helper to determine if the slip should be considered effectively free based on autoUnlockAt
  bool get isEffectivelyFreeNow {
    if (!isPaid) return true; // Already free
    if (autoUnlockAt != null && DateTime.now().isAfter(autoUnlockAt!)) {
      return true; // Auto-unlock time has passed
    }
    return false; // Still paid and locked (or no auto-unlock time)
  }
}

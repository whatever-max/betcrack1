// lib/models/betslip.dart
import 'package:intl/intl.dart';

class Betslip {
  final String id;
  final String title;
  final String imageUrl;
  final bool isPaid;
  final int price;
  final String? postedBy;
  final DateTime? createdAt;
  final String? bookingCode;
  final DateTime? validUntil;
  final String? odds;
  final String? companyName;
  final DateTime? autoUnlockAt; // Used for both regular paid and premium

  final bool isPremium;
  final int packagePrice;
  final int refundAmountIfLost;
  final int refundPercentageBonus;

  Betslip({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.isPaid = false,
    this.price = 0,
    this.postedBy,
    this.createdAt,
    this.bookingCode,
    this.validUntil,
    this.odds,
    this.companyName,
    this.autoUnlockAt, // Initialize this
    this.isPremium = false,
    this.packagePrice = 0,
    this.refundAmountIfLost = 0,
    this.refundPercentageBonus = 0,
  });

  factory Betslip.fromJson(Map<String, dynamic> json) {
    return Betslip(
      id: json['id'] as String,
      title: json['title'] as String,
      imageUrl: json['image_url'] as String,
      isPaid: json['is_paid'] as bool? ?? false,
      price: json['price'] as int? ?? 0,
      postedBy: json['posted_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      bookingCode: json['booking_code'] as String?,
      validUntil: json['valid_until'] == null
          ? null
          : DateTime.parse(json['valid_until'] as String),
      odds: json['odds'] as String?,
      companyName: json['company_name'] as String?,
      autoUnlockAt: json['auto_unlock_at'] == null // Parse this
          ? null
          : DateTime.parse(json['auto_unlock_at'] as String),
      isPremium: json['is_premium'] as bool? ?? false,
      packagePrice: json['package_price'] as int? ?? 0,
      refundAmountIfLost: json['refund_amount_if_lost'] as int? ?? 0,
      refundPercentageBonus: json['refund_percentage_bonus'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'image_url': imageUrl,
    'is_paid': isPaid,
    'price': price, // For regular slips, or base price if premium also uses it
    'posted_by': postedBy,
    'created_at': createdAt?.toIso8601String(),
    'booking_code': bookingCode,
    'valid_until': validUntil?.toIso8601String(),
    'odds': odds,
    'company_name': companyName,
    'auto_unlock_at': autoUnlockAt?.toIso8601String(), // Serialize this
    'is_premium': isPremium,
    'package_price': packagePrice,
    'refund_amount_if_lost': refundAmountIfLost,
    'refund_percentage_bonus': refundPercentageBonus,
  };

  bool get isExpired {
    return validUntil != null && validUntil!.isBefore(DateTime.now());
  }

  bool get isEffectivelyFreeNow {
    // A slip is effectively free if:
    // 1. It was never paid/premium to begin with.
    // 2. Or, it was paid (regular or premium) AND its autoUnlockAt time has passed.
    if (!isPaid && !isPremium) return true;
    if (autoUnlockAt != null && autoUnlockAt!.isBefore(DateTime.now())) {
      return true;
    }
    return false;
  }

  double get calculatedTotalRefund {
    if (!isPremium) return 0;
    double bonusAmount = refundAmountIfLost * (refundPercentageBonus / 100.0);
    return refundAmountIfLost + bonusAmount;
  }

  String get formattedCalculatedTotalRefund {
    final currencyFormat = NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);
    return currencyFormat.format(calculatedTotalRefund);
  }

  String get formattedPackagePrice {
    final currencyFormat = NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);
    return currencyFormat.format(packagePrice);
  }

  String get formattedPrice { // For regular paid slips
    final currencyFormat = NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);
    return currencyFormat.format(price);
  }

  String get formattedRefundAmountIfLost {
    final currencyFormat = NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);
    return currencyFormat.format(refundAmountIfLost);
  }
}


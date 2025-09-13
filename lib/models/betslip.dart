class Betslip {
  final String id;
  final String title;
  final String imageUrl;
  final bool isPaid;
  final int price;

  Betslip({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.isPaid,
    required this.price,
  });

  factory Betslip.fromJson(Map<String, dynamic> json) {
    return Betslip(
      id: json['id'],
      title: json['title'],
      imageUrl: json['image_url'],
      isPaid: json['is_paid'] ?? false,
      price: json['price'] ?? 0,
    );
  }
}

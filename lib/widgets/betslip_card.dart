import 'package:flutter/material.dart';
import '../models/betslip.dart';

class BetslipCard extends StatelessWidget {
  final Betslip betslip;
  final bool isPurchased;
  final VoidCallback? onTapLocked;

  const BetslipCard({
    super.key,
    required this.betslip,
    this.isPurchased = false,
    this.onTapLocked,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      betslip.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 200,
    );

    final blurredImage = Stack(
      children: [
        image,
        Container(
          width: double.infinity,
          height: 200,
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.lock, color: Colors.white, size: 40),
              onPressed: onTapLocked,
            ),
          ),
        )
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          betslip.isPaid && !isPurchased ? blurredImage : image,
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              betslip.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (betslip.isPaid && !isPurchased)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: Text(
                "Price: ${betslip.price} TZS",
                style: TextStyle(color: Colors.redAccent.shade700),
              ),
            ),
        ],
      ),
    );
  }
}

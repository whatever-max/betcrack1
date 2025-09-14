// lib/screens/betslip_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../models/betslip.dart';
import 'payment_methods_screen.dart'; // <<<--- ADD THIS IMPORT

// You might want to use a package like photo_view for zoomable images
// import 'package:photo_view/photo_view.dart';

class BetslipDetailScreen extends StatelessWidget {
  final Betslip betslip;
  final bool isPurchased; // Indicates if the current user has purchased THIS slip

  const BetslipDetailScreen({
    super.key,
    required this.betslip,
    required this.isPurchased,
  });

  void _copyToClipboard(String text, BuildContext context) {
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "No booking code to copy.");
      return;
    }
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      Fluttertoast.showToast(
        msg: "Booking code copied!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        textColor: Theme.of(context).colorScheme.onPrimaryContainer,
      );
    });
  }

  String _formatValidityDetail(BuildContext context, Betslip betslip) {
    if (betslip.validUntil == null) return "Not specified";
    final now = DateTime.now();
    if (betslip.validUntil!.isBefore(now)) {
      return "Expired on ${DateFormat('EEE, MMM d, yyyy HH:mm').format(betslip.validUntil!)}";
    }
    final difference = betslip.validUntil!.difference(now);
    String validStr = "Valid until: ${DateFormat('EEE, MMM d, yyyy HH:mm').format(betslip.validUntil!)}";
    String remainingStr = "";
    if (difference.inDays > 0) {
      remainingStr = " (${difference.inDays}d ${difference.inHours.remainder(24)}h left)";
    } else if (difference.inHours > 0) {
      remainingStr = " (${difference.inHours}h ${difference.inMinutes.remainder(60)}m left)";
    } else if (difference.inMinutes > 0) {
      remainingStr = " (${difference.inMinutes}m left)";
    } else {
      remainingStr = " (Expiring soon)";
    }
    return "$validStr$remainingStr";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canViewDetails = !betslip.isPaid || isPurchased || betslip.isEffectivelyFreeNow;

    return Scaffold(
      appBar: AppBar(
        title: Text(betslip.title, style: const TextStyle(fontSize: 18)),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(0), // No padding on body, sections will handle it
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Image Section ---
            if (betslip.imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () {
                  // Optional: Show full-screen interactive image viewer
                  if (canViewDetails) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(imageUrl: betslip.imageUrl),
                      fullscreenDialog: true,
                    ));
                  }
                },
                child: Hero(
                  tag: 'betslipImage_${betslip.id}', // Unique tag for Hero animation
                  child: Image.network(
                    betslip.imageUrl,
                    fit: BoxFit.cover,
                    height: MediaQuery.of(context).size.height * 0.35, // Adjust height
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.35,
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.35,
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        child: Center(child: Icon(Icons.broken_image_outlined, size: 60, color: theme.colorScheme.outline)),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                height: MediaQuery.of(context).size.height * 0.3,
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                child: Center(child: Icon(Icons.image_not_supported_outlined, size: 60, color: theme.colorScheme.outline)),
              ),

            // --- Locked Overlay ---
            if (!canViewDetails && betslip.isPaid) // Show lock only if paid and cannot view
              Container(
                height: MediaQuery.of(context).size.height * 0.35, // Match image height
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        "Purchase to View Details",
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "TZS ${NumberFormat.decimalPattern().format(betslip.price)}",
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.shopping_cart_checkout_rounded, color: theme.colorScheme.onPrimary),
                        label: Text("Unlock Now", style: TextStyle(color: theme.colorScheme.onPrimary)),
                        onPressed: () {
                          Navigator.pop(context); // Pop detail screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentMethodsScreen(betslipToPurchase: betslip), // This line caused the error if no import
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                      )
                    ],
                  ),
                ),
              ),

            // --- Details Section (Only if viewable) ---
            if (canViewDetails)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      betslip.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(theme, Icons.show_chart_rounded, "Odds", betslip.odds ?? "N/A"),
                    _buildDetailRow(theme, Icons.business_center_outlined, "Company", betslip.companyName ?? "N/A"),
                    if (betslip.bookingCode != null && betslip.bookingCode!.isNotEmpty)
                      _buildDetailRow(
                        theme,
                        Icons.qr_code_scanner_rounded,
                        "Booking Code",
                        betslip.bookingCode!,
                        isCopyable: true,
                        onCopy: () => _copyToClipboard(betslip.bookingCode!, context),
                      ),
                    _buildDetailRow(theme, Icons.timer_outlined, "Validity", _formatValidityDetail(context, betslip)),
                    _buildDetailRow(theme, Icons.access_time_filled_rounded, "Posted At",
                        betslip.createdAt != null ? DateFormat('EEE, MMM d, yyyy HH:mm').format(betslip.createdAt!) : "N/A"),

                    const SizedBox(height: 12),
                    if (betslip.isPaid)
                      Chip(
                        avatar: Icon(isPurchased ? Icons.check_circle_rounded : Icons.lock_open_rounded,
                            color: isPurchased ? theme.colorScheme.primary : theme.colorScheme.secondary, size: 18),
                        label: Text(isPurchased ? "Purchased" : (betslip.isEffectivelyFreeNow ? "Unlocked (Auto)" : "Paid Tip"),
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: isPurchased ? theme.colorScheme.primary : theme.colorScheme.secondary)),
                        backgroundColor: (isPurchased ? theme.colorScheme.primary : theme.colorScheme.secondary).withOpacity(0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      )
                    else
                      Chip(
                        avatar: Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 18),
                        label: Text("Free Tip", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.secondary)),
                        backgroundColor: theme.colorScheme.secondary.withOpacity(0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, IconData icon, String label, String value, {bool isCopyable = false, VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary.withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (isCopyable)
            IconButton(
              icon: Icon(Icons.copy_all_outlined, size: 20, color: theme.colorScheme.secondary),
              onPressed: onCopy,
              tooltip: "Copy $label",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// Simple FullScreenImageViewer (can be moved to its own file)
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Back button white
      ),
      body: Center(
        child: InteractiveViewer( // Allows pinch-to-zoom and pan
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain, // Show full image
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
            },
            errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.error_outline, color: Colors.white, size: 50)),
          ),
        ),
      ),
    );
  }
}


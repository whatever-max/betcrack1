// lib/screens/betslip_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart'; // Keep for consistency, though not used for single image

import '../models/betslip.dart';
import 'payment_methods_screen.dart';

class BetslipDetailScreen extends StatefulWidget {
  final Betslip betslip;
  final bool isPurchased;

  const BetslipDetailScreen({
    super.key,
    required this.betslip,
    required this.isPurchased,
  });

  @override
  State<BetslipDetailScreen> createState() => _BetslipDetailScreenState();
}

class _BetslipDetailScreenState extends State<BetslipDetailScreen> {
  late bool _currentIsPurchased;

  @override
  void initState() {
    super.initState();
    _currentIsPurchased = widget.isPurchased;
  }

  void _copyToClipboard(String text, String message, BuildContext context) {
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "Nothing to copy.");
      return;
    }
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        textColor: Theme.of(context).colorScheme.onPrimaryContainer,
      );
    });
  }

  void _handlePurchase(Betslip slip) {
    if (slip.isExpired) {
      Fluttertoast.showToast(
          msg: slip.isPremium
              ? "This premium package has expired and cannot be purchased."
              : "This tip has expired and cannot be purchased.");
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PaymentMethodsScreen(betslipToPurchase: slip)),
    ).then((paymentResult) {
      if (paymentResult == true && mounted) {
        setState(() {
          _currentIsPurchased = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchase successful! Details unlocked.'),
              backgroundColor: Colors.green),
        );
      }
    });
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.9),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: PhotoViewGestureDetectorScope( // Use this scope for better gesture handling
            // The 'axisPointers' parameter is not a direct member here.
            // PhotoView handles standard gestures automatically.
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 60),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 2.5,
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
              enableRotation: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final betslip = widget.betslip;
    final bool canStillPurchase = !betslip.isExpired;

    final bool canViewDetails = (!betslip.isPaid && !betslip.isPremium) ||
        (betslip.isPaid &&
            !betslip.isPremium &&
            (_currentIsPurchased || betslip.isEffectivelyFreeNow)) ||
        (betslip.isPremium &&
            (_currentIsPurchased || betslip.isEffectivelyFreeNow));

    // final currencyFormat = NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);

    // Ensure heroTag is unique, especially if imageUrl can be empty or non-unique across different betslips
    final String imageHeroTag = betslip.imageUrl.isNotEmpty ? "betslip_image_hero_${betslip.id}_${betslip.imageUrl.hashCode}" : "betslip_image_hero_${betslip.id}";


    return Scaffold(
      appBar: AppBar(
        title: Text(betslip.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (canViewDetails &&
              betslip.bookingCode != null &&
              betslip.bookingCode!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: "Copy Booking Code",
              onPressed: () => _copyToClipboard(
                  betslip.bookingCode!, "Booking code copied!", context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (betslip.isPremium)
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.8),
                        theme.colorScheme.primaryContainer.withOpacity(0.7)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3))
                    ]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border_purple500_outlined,
                        color: theme.colorScheme.onPrimary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "PREMIUM PACKAGE DETAILS",
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            GestureDetector(
              onTap: () {
                if (betslip.imageUrl.isNotEmpty) {
                  _showFullScreenImage(context, betslip.imageUrl, imageHeroTag);
                } else {
                  Fluttertoast.showToast(msg: "No image available to view.");
                }
              },
              child: Hero(
                tag: imageHeroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: betslip.imageUrl.isNotEmpty
                      ? Image.network(
                    betslip.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.35,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                          height: MediaQuery.of(context).size.height * 0.35,
                          color: theme.colorScheme.surfaceVariant,
                          child: const Center(
                              child: CircularProgressIndicator()));
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        Container(
                            height: MediaQuery.of(context).size.height * 0.35,
                            color: theme.colorScheme.surfaceVariant,
                            child: const Center(
                                child: Icon(Icons.broken_image, size: 50))),
                  )
                      : Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50))),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(betslip.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 8),

            if (canViewDetails) ...[
              _buildDetailRow(
                  theme,
                  Icons.notes_outlined,
                  "Details:",
                  "This section would contain more specific information about the betslip if provided. Since the slip is unlocked, all available details are shown."),
              const Divider(height: 24),
            ] else if (canStillPurchase) ...[
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 40,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(height: 12),
                      Text(
                        betslip.isPremium
                            ? "This is a Premium Package!"
                            : "This Tip is Locked!",
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        betslip.isPremium
                            ? "Purchase for ${betslip.formattedPackagePrice} to view details and booking code."
                            : "Purchase for ${betslip.formattedPrice} to view details and booking code.",
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onErrorContainer
                                .withOpacity(0.9)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                          icon: Icon(betslip.isPremium
                              ? Icons.star_purple500_outlined
                              : Icons.shopping_cart_checkout_rounded),
                          label: Text(betslip.isPremium
                              ? "Unlock Premium Package"
                              : "Unlock Tip Now"),
                          onPressed: () => _handlePurchase(betslip),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ))
                    ],
                  )),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color:
                      theme.colorScheme.surfaceVariant.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      Icon(Icons.timer_off_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        betslip.isPremium
                            ? "Premium Package Expired"
                            : "Tip Expired",
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This item is no longer available for purchase and details are hidden.",
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.9)),
                        textAlign: TextAlign.center,
                      ),
                      if (betslip.autoUnlockAt != null &&
                          betslip.autoUnlockAt!.isAfter(DateTime.now())) ...[
                        const SizedBox(height: 10),
                        Text(
                          "It will automatically unlock on: ${DateFormat('MMM d, HH:mm').format(betslip.autoUnlockAt!)}",
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.secondary),
                          textAlign: TextAlign.center,
                        ),
                      ]
                    ],
                  )),
              const SizedBox(height: 16),
            ],

            if (betslip.isPremium && canViewDetails) ...[
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Refund Guarantee Information",
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      const Divider(height: 12),
                      _buildDetailRow(
                          theme,
                          Icons.attach_money_rounded,
                          "Package Price:",
                          betslip.formattedPackagePrice),
                      _buildDetailRow(
                          theme,
                          Icons.replay_circle_filled_rounded,
                          "Stake Refund if Lost:",
                          betslip.formattedRefundAmountIfLost),
                      if (betslip.refundPercentageBonus > 0)
                        _buildDetailRow(
                            theme,
                            Icons.add_reaction_outlined,
                            "Additional Bonus:",
                            "${betslip.refundPercentageBonus}%"),
                      _buildDetailRow(theme, Icons.request_quote_outlined,
                          "Total Potential Refund:", betslip.formattedCalculatedTotalRefund,
                          valueStyle: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (betslip.bookingCode != null &&
                          betslip.bookingCode!.isNotEmpty &&
                          canViewDetails) ...[
                        _buildDetailRow(theme, Icons.qr_code_2_rounded,
                            "Booking Code:", betslip.bookingCode!,
                            isCopyable: true,
                            copyMessage: "Booking code copied!"),
                        const Divider(height: 12),
                      ],
                      if (!betslip.isPremium ||
                          (betslip.isPremium && canViewDetails)) ...[
                        if (betslip.odds != null &&
                            betslip.odds!.isNotEmpty) ...[
                          _buildDetailRow(theme, Icons.show_chart_rounded,
                              "Total Odds:", betslip.odds!),
                          const Divider(height: 12),
                        ],
                        if (betslip.companyName != null &&
                            betslip.companyName!.isNotEmpty) ...[
                          _buildDetailRow(
                              theme,
                              Icons.business_center_outlined,
                              "Betting Company:",
                              betslip.companyName!),
                          const Divider(height: 12),
                        ],
                      ],
                      if (betslip.validUntil != null) ...[
                        _buildDetailRow(
                            theme,
                            Icons.timer_outlined,
                            "Valid Until:",
                            DateFormat('EEE, MMM d, yyyy HH:mm')
                                .format(betslip.validUntil!)),
                        const Divider(height: 12),
                      ],
                      if (betslip.createdAt != null)
                        _buildDetailRow(
                            theme,
                            Icons.access_time_filled,
                            "Posted On:",
                            DateFormat('EEE, MMM d, yyyy HH:mm')
                                .format(betslip.createdAt!)),
                    ],
                  ),
                )),
            const SizedBox(height: 20),

            if (!canViewDetails &&
                canStillPurchase &&
                (betslip.isPaid || betslip.isPremium) &&
                !_currentIsPurchased)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: TextButton.icon(
                    icon: Icon(Icons.help_outline_rounded,
                        color: theme.colorScheme.secondary),
                    label: Text("Why is this locked?",
                        style:
                        TextStyle(color: theme.colorScheme.secondary)),
                    onPressed: () {
                      bool isSwahili = Localizations.localeOf(context)
                          .languageCode ==
                          'sw';
                      String titleText = isSwahili
                          ? "Maudhui Yamefungwa"
                          : "Content Locked";
                      String contentText;

                      if (betslip.isPremium) {
                        contentText = isSwahili
                            ? "Kifurushi hiki cha premium kinahitaji ununuzi ili kuona nambari ya ubashiri na maelezo mengine maalum. Pia utafaidika na dhamana ya kurejeshewa pesa! Iwapo mchezo utawekwa kama batili (void), hautakuwa na matokeo, au hautachezwa, marejesho yatatolewa lakini yanaweza kupungua kutokana na mabadiliko ya odds."
                            : "This premium package requires a purchase to view the booking code and other specific details. You'll also benefit from the refund guarantee! If the game has been placed as void, has no results, or has not been played, the refund will be made but it may decrease due to odds changes.";
                      } else {
                        contentText = isSwahili
                            ? "Dokezo hili linahitaji ununuzi ili kuona nambari ya ubashiri na maelezo mengine maalum."
                            : "This tip requires a purchase to view the booking code and other specific details.";
                      }
                      String okButtonText = isSwahili ? "SAWA" : "OK";

                      showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(titleText),
                            content: SingleChildScrollView(
                                child: Text(contentText)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(okButtonText))
                            ],
                          ));
                    },
                  ),
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      ThemeData theme, IconData icon, String label, String value,
      {bool isCopyable = false,
        String? copyMessage,
        TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18, color: theme.colorScheme.primary.withOpacity(0.8)),
          const SizedBox(width: 10),
          Text("$label ",
              style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          Expanded(
              child: Text(value,
                  style: valueStyle ??
                      theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          if (isCopyable)
            IconButton(
              icon: Icon(Icons.copy_rounded,
                  size: 18, color: theme.colorScheme.secondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Copy $label",
              onPressed: () => _copyToClipboard(
                  value, copyMessage ?? "$label copied!", context),
            )
        ],
      ),
    );
  }
}

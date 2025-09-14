// lib/widgets/betslip_card.dart
import 'dart:async'; // For Timer (though not actively used for live countdown on card yet)
import 'dart:ui'; // For ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:fluttertoast/fluttertoast.dart'; // For copy confirmation
import 'package:intl/intl.dart';
import '../models/betslip.dart';
// If you decide to use a time_ago package for "expires in X hours":
// import 'package:timeago/timeago.dart' as timeago;

class BetslipCard extends StatefulWidget {
  final Betslip betslip;
  final bool isPurchased;
  final VoidCallback? onTapCard;
  final VoidCallback? onTapLocked;

  const BetslipCard({
    super.key,
    required this.betslip,
    this.isPurchased = false,
    this.onTapCard,
    this.onTapLocked,
  });

  @override
  State<BetslipCard> createState() => _BetslipCardState();
}

class _BetslipCardState extends State<BetslipCard> {
  // Timer _timer; // If implementing live countdown on card later
  // Duration _timeUntilValid; // If implementing live countdown

  @override
  void initState() {
    super.initState();
    // Example: Initialize timeago if you use it
    // timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
    // if (widget.betslip.validUntil != null && widget.betslip.validUntil.isAfter(DateTime.now())) {
    //   _timeUntilValid = widget.betslip.validUntil.difference(DateTime.now());
    //   // Potentially start a timer here if doing a live countdown on the card itself
    // }
  }

  @override
  void dispose() {
    // _timer?.cancel(); // Cancel timer if used
    super.dispose();
  }

  String _formatValidity(BuildContext context, Betslip betslip) {
    if (betslip.validUntil == null) return "Validity not set";

    final now = DateTime.now();
    if (betslip.validUntil!.isBefore(now)) {
      return "Expired: ${DateFormat('MMM d, HH:mm').format(betslip.validUntil!)}";
    }

    final difference = betslip.validUntil!.difference(now);

    if (difference.inDays >= 1) {
      return "Valid until: ${DateFormat('EEE, MMM d HH:mm').format(betslip.validUntil!)}";
    } else if (difference.inHours >= 1) {
      return "Expires in: ${difference.inHours}h ${difference.inMinutes.remainder(60)}m";
    } else if (difference.inMinutes >= 1) {
      return "Expires in: ${difference.inMinutes}m ${difference.inSeconds.remainder(60)}s";
    } else if (difference.inSeconds > 0) {
      return "Expires in: ${difference.inSeconds}s";
    }
    return "Expiring soon";
  }

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
        fontSize: 16.0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final betslip = widget.betslip; // Access betslip via widget.betslip in StatefulWidget
    final isEffectivelyLocked = betslip.isPaid && !widget.isPurchased && !betslip.isEffectivelyFreeNow;
    final screenWidth = MediaQuery.of(context).size.width;

    double imageContainerWidth = screenWidth - (2 * (theme.cardTheme.margin?.horizontal ?? 24.0) / 2) - (2 * 12.0) ; // approx card padding
    if (theme.cardTheme.margin != null) {
      final horizontalMargin = theme.cardTheme.margin!.horizontal;
      imageContainerWidth -= horizontalMargin;
    }

    double imageHeight = imageContainerWidth / 2.1;
    if (imageHeight > 200) imageHeight = 200;
    if (imageHeight < 140) imageHeight = 140;

    // --- Image Widget Definition (Restored Full Logic) ---
    Widget imageDisplayWidget = betslip.imageUrl.isNotEmpty
        ? Image.network(
      betslip.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: imageHeight,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: imageHeight,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null && loadingProgress.expectedTotalBytes! > 0
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2.5,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: imageHeight,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 36),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "Image failed to load",
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    )
        : Container( // Placeholder if no image URL
      width: double.infinity,
      height: imageHeight,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 36),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "No Image Available",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // --- Content for Locked State (Restored Full Logic) ---
    if (isEffectivelyLocked) {
      imageDisplayWidget = Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
            child: imageDisplayWidget,
          ),
          Container(
            width: double.infinity,
            height: imageHeight,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.60)),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_person_outlined, color: Colors.white.withOpacity(0.9), size: 32),
                const SizedBox(height: 6),
                Text(
                  "Pay ${NumberFormat.compactCurrency(decimalDigits: 0, symbol: 'TZS ').format(betslip.price)}",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "to Unlock Tip",
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.80)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    bool canShowBookingCode = !betslip.isPaid || widget.isPurchased || betslip.isEffectivelyFreeNow;

    return Card(
      // margin, shape, clipBehavior are inherited from CardThemeData
      child: InkWell(
        onTap: isEffectivelyLocked ? widget.onTapLocked : widget.onTapCard,
        borderRadius: (theme.cardTheme.shape as RoundedRectangleBorder?)?.borderRadius?.resolve(Directionality.of(context)) ?? BorderRadius.circular(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: (theme.cardTheme.shape as RoundedRectangleBorder?)?.borderRadius?.resolve(Directionality.of(context)).topLeft ?? const Radius.circular(12.0),
                topRight: (theme.cardTheme.shape as RoundedRectangleBorder?)?.borderRadius?.resolve(Directionality.of(context)).topRight ?? const Radius.circular(12.0),
              ),
              child: imageDisplayWidget,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    betslip.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // --- Odds & Company ---
                  if ((betslip.odds != null && betslip.odds!.isNotEmpty) || (betslip.companyName != null && betslip.companyName!.isNotEmpty)) ...[
                    Row(
                      children: [
                        if (betslip.odds != null && betslip.odds!.isNotEmpty)
                          Expanded(
                            flex: betslip.companyName != null && betslip.companyName!.isNotEmpty ? 1 : 2, // Adjust flex based on if company name exists
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.show_chart_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "Odds: ${betslip.odds}",
                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if ((betslip.odds != null && betslip.odds!.isNotEmpty) && (betslip.companyName != null && betslip.companyName!.isNotEmpty))
                          const SizedBox(width: 8), // Spacer only if both exist

                        if (betslip.companyName != null && betslip.companyName!.isNotEmpty)
                          Expanded(
                            flex: betslip.odds != null && betslip.odds!.isNotEmpty ? 1 : 2, // Adjust flex
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              // Align to end if odds also exist, otherwise start
                              mainAxisAlignment: (betslip.odds == null || betslip.odds!.isEmpty) ? MainAxisAlignment.start : MainAxisAlignment.end,
                              children: [
                                Icon(Icons.business_center_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    betslip.companyName!,
                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: (betslip.odds == null || betslip.odds!.isEmpty) ? TextAlign.start : TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // --- Booking Code & Price/Status ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: (betslip.bookingCode != null && betslip.bookingCode!.isNotEmpty && canShowBookingCode)
                            ? Material( // Added Material for InkWell splash effect to be visible
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _copyToClipboard(betslip.bookingCode!, context),
                            borderRadius: BorderRadius.circular(4),
                            splashColor: theme.colorScheme.primary.withOpacity(0.1),
                            highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0), // Minimal padding
                              child: Row(
                                mainAxisSize: MainAxisSize.min, // Fit content
                                children: [
                                  Icon(Icons.qr_code_scanner_outlined, size: 16, color: theme.colorScheme.primary), // Adjusted icon
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      betslip.bookingCode!,
                                      style: theme.textTheme.bodyLarge?.copyWith( // Made code more prominent
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.copy_rounded, size: 15, color: theme.colorScheme.primary.withOpacity(0.8)), // Adjusted icon
                                ],
                              ),
                            ),
                          ),
                        )
                            : const SizedBox.shrink(), // Takes no space if no booking code or not shown
                      ),
                      const SizedBox(width: 8), // Spacer
                      Flexible( // For Price/Status Chip
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildPriceOrStatusChip(context, theme, betslip),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)),
                  const SizedBox(height: 6),

                  // --- Validity & Posted Date ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible( // For validity text
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: betslip.validUntil != null && betslip.validUntil!.isBefore(DateTime.now())
                                  ? theme.colorScheme.error.withOpacity(0.8)
                                  : theme.colorScheme.secondary.withOpacity(0.9),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _formatValidity(context, betslip),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: betslip.validUntil != null && betslip.validUntil!.isBefore(DateTime.now())
                                      ? theme.colorScheme.error.withOpacity(0.9)
                                      : theme.colorScheme.secondary, // Use secondary for active validity
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11.5, // Slightly larger for validity
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row( // For posted date
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_filled_rounded, size: 13, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            betslip.createdAt != null ? DateFormat('MMM d, HH:mm').format(betslip.createdAt!) : '---',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceOrStatusChip(BuildContext context, ThemeData theme, Betslip betslip) {
    final numberFormat = NumberFormat.compactCurrency(
      decimalDigits: 0,
      symbol: 'TZS ',
    );

    if (betslip.isPaid && !widget.isPurchased && !betslip.isEffectivelyFreeNow) { // Strictly paid and locked
      return Text(
        numberFormat.format(betslip.price),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      );
    } else if (betslip.isPaid && (widget.isPurchased || betslip.isEffectivelyFreeNow)) { // Paid but purchased or auto-unlocked
      String labelText = widget.isPurchased ? 'Purchased' : 'Unlocked';
      IconData iconData = widget.isPurchased ? Icons.check_circle_rounded : Icons.lock_open_rounded;
      Color chipColor = widget.isPurchased ? theme.colorScheme.primary : theme.colorScheme.secondary;

      return Chip(
        avatar: Icon(iconData, color: chipColor, size: 15),
        label: Text(labelText, style: theme.textTheme.labelSmall?.copyWith(color: chipColor, fontWeight: FontWeight.w600)),
        backgroundColor: chipColor.withOpacity(0.15), // Use avatar color for background with opacity
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: 0.0, vertical: -1),
        side: BorderSide.none, // Or BorderSide(color: chipColor.withOpacity(0.3))
      );
    } else { // Not paid (Free)
      return Chip(
        avatar: Icon(Icons.star_border_rounded, color: theme.colorScheme.secondary, size: 16),
        label: Text('FREE', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: 0.0, vertical: -1),
        side: BorderSide.none,
      );
    }
  }
}

// lib/widgets/betslip_card.dart
import 'dart:async';
import 'dart:ui'; // For ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../models/betslip.dart';

class BetslipCard extends StatefulWidget {
  final Betslip betslip;
  final bool isPurchased;
  final VoidCallback? onTapCard;
  final VoidCallback? onTapLocked;
  final bool isAdminView; // ADDED
  final VoidCallback? onDelete;   // ADDED

  const BetslipCard({
    super.key,
    required this.betslip,
    this.isPurchased = false,
    this.onTapCard,
    this.onTapLocked,
    this.isAdminView = false, // ADDED - Default to false
    this.onDelete,           // ADDED
  });

  @override
  State<BetslipCard> createState() => _BetslipCardState();
}

class _BetslipCardState extends State<BetslipCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
    final betslip = widget.betslip;
    final isEffectivelyLocked = betslip.isPaid && !widget.isPurchased && !betslip.isEffectivelyFreeNow;
    final screenWidth = MediaQuery.of(context).size.width;

    double imageContainerWidth = screenWidth - (2 * (theme.cardTheme.margin?.horizontal ?? 24.0) / 2) - (2 * 12.0) ;
    if (theme.cardTheme.margin != null) {
      final horizontalMargin = theme.cardTheme.margin!.horizontal;
      imageContainerWidth -= horizontalMargin;
    }

    double imageHeight = imageContainerWidth / 2.1;
    if (imageHeight > 200) imageHeight = 200;
    if (imageHeight < 140) imageHeight = 140;

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
        : Container(
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

    if (isEffectivelyLocked && !widget.isAdminView) {
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

    bool canShowBookingCode = !betslip.isPaid || widget.isPurchased || betslip.isEffectivelyFreeNow || widget.isAdminView;

    return Card(
      child: InkWell(
        onTap: (isEffectivelyLocked && !widget.isAdminView) ? widget.onTapLocked : widget.onTapCard,
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
              padding: EdgeInsets.fromLTRB(12.0, 10.0, widget.isAdminView ? 0 : 12.0, 10.0), // Adjust right padding for admin delete button
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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

                        if ((betslip.odds != null && betslip.odds!.isNotEmpty) || (betslip.companyName != null && betslip.companyName!.isNotEmpty)) ...[
                          Row(
                            children: [
                              if (betslip.odds != null && betslip.odds!.isNotEmpty)
                                Expanded(
                                  flex: betslip.companyName != null && betslip.companyName!.isNotEmpty ? 1 : 2,
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
                                const SizedBox(width: 8),

                              if (betslip.companyName != null && betslip.companyName!.isNotEmpty)
                                Expanded(
                                  flex: betslip.odds != null && betslip.odds!.isNotEmpty ? 1 : 2,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 5,
                              child: (betslip.bookingCode != null && betslip.bookingCode!.isNotEmpty && canShowBookingCode)
                                  ? Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _copyToClipboard(betslip.bookingCode!, context),
                                  borderRadius: BorderRadius.circular(4),
                                  splashColor: theme.colorScheme.primary.withOpacity(0.1),
                                  highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.qr_code_scanner_outlined, size: 16, color: theme.colorScheme.primary),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            betslip.bookingCode!,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.copy_rounded, size: 15, color: theme.colorScheme.primary.withOpacity(0.8)),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
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
                                            : theme.colorScheme.secondary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
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
                  if (widget.isAdminView && widget.onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.error.withOpacity(0.8)),
                      tooltip: "Delete Slip",
                      padding: const EdgeInsets.all(12.0),
                      constraints: const BoxConstraints(),
                      onPressed: widget.onDelete,
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

    // If admin view, always show "Paid Tip" or "Free Tip", not the price as a lock.
    if (widget.isAdminView) {
      if (betslip.isPaid) {
        return Chip(
          avatar: Icon(Icons.monetization_on_outlined, color: theme.colorScheme.tertiary, size: 15),
          label: Text(betslip.isEffectivelyFreeNow ? "PAID (UNLOCKED)" : "PAID TIP", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary, fontWeight: FontWeight.w600)),
          backgroundColor: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      } else {
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

    // Original logic for non-admin view
    if (betslip.isPaid && !widget.isPurchased && !betslip.isEffectivelyFreeNow) {
      return Text(
        numberFormat.format(betslip.price),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      );
    } else if (betslip.isPaid && (widget.isPurchased || betslip.isEffectivelyFreeNow)) {
      String labelText = widget.isPurchased ? 'Purchased' : 'Unlocked';
      IconData iconData = widget.isPurchased ? Icons.check_circle_rounded : Icons.lock_open_rounded;
      Color chipColor = widget.isPurchased ? theme.colorScheme.primary : theme.colorScheme.secondary;

      return Chip(
        avatar: Icon(iconData, color: chipColor, size: 15),
        label: Text(labelText, style: theme.textTheme.labelSmall?.copyWith(color: chipColor, fontWeight: FontWeight.w600)),
        backgroundColor: chipColor.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: 0.0, vertical: -1),
        side: BorderSide.none,
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

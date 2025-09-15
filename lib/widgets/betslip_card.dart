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
  final bool isAdminView;
  final VoidCallback? onDelete;

  const BetslipCard({
    super.key,
    required this.betslip,
    this.isPurchased = false,
    this.onTapCard,
    this.onTapLocked,
    this.isAdminView = false,
    this.onDelete,
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
    if (betslip.isExpired) {
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

    final bool canStillPurchase = !betslip.isExpired;

    final bool isEffectivelyLockedForUser = (!widget.isAdminView) &&
        (((betslip.isPremium && !widget.isPurchased) ||
            (betslip.isPaid &&
                !betslip.isPremium &&
                !widget.isPurchased &&
                !betslip.isEffectivelyFreeNow))) &&
        canStillPurchase;

    final bool showExpiredNotPurchasedOverlay = !canStillPurchase &&
        !widget.isPurchased &&
        (betslip.isPaid || betslip.isPremium) &&
        !betslip.isEffectivelyFreeNow &&
        !widget.isAdminView;

    final screenWidth = MediaQuery.of(context).size.width;
    double imageContainerWidth = screenWidth -
        (2 * (theme.cardTheme.margin?.horizontal ?? 16.0)) -
        (2 * 12.0);

    double imageHeight = imageContainerWidth / 2.0;
    if (imageHeight > 220) imageHeight = 220;
    if (imageHeight < 150) imageHeight = 150;

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
                value: loadingProgress.expectedTotalBytes != null &&
                    loadingProgress.expectedTotalBytes! > 0
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              )),
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
              Icon(Icons.broken_image_outlined,
                  color:
                  theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  size: 36),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "Image failed to load",
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withOpacity(0.6)),
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
          Icon(Icons.image_not_supported_outlined,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              size: 36),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "No Image Available",
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant
                      .withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    if (isEffectivelyLockedForUser) {
      imageDisplayWidget = Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: imageDisplayWidget),
          Container(
              width: double.infinity,
              height: imageHeight,
              decoration:
              BoxDecoration(color: Colors.black.withOpacity(0.65))),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    betslip.isPremium
                        ? Icons.star_purple500_sharp
                        : Icons.lock_person_outlined,
                    color: Colors.white.withOpacity(0.9),
                    size: 32),
                const SizedBox(height: 6),
                Text(
                  "Pay ${betslip.isPremium ? betslip.formattedPackagePrice : betslip.formattedPrice}",
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                    betslip.isPremium
                        ? "to Unlock Premium Package"
                        : "to Unlock Tip",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white.withOpacity(0.80)),
                    textAlign: TextAlign.center),
                if (betslip.isPremium) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Refund: ${betslip.formattedRefundAmountIfLost} + ${betslip.refundPercentageBonus}% Bonus if Lost",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white.withOpacity(0.75)),
                    textAlign: TextAlign.center,
                  ),
                ]
              ],
            ),
          ),
        ],
      );
    } else if (showExpiredNotPurchasedOverlay) {
      imageDisplayWidget = Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: imageDisplayWidget),
          Container(
              width: double.infinity,
              height: imageHeight,
              decoration:
              BoxDecoration(color: Colors.black.withOpacity(0.70))),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_off_outlined,
                    color: Colors.white.withOpacity(0.9), size: 36),
                const SizedBox(height: 8),
                Text(
                  betslip.isPremium
                      ? "Premium Package Expired"
                      : "Tip Expired",
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "This item is no longer available for purchase.",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withOpacity(0.80)),
                  textAlign: TextAlign.center,
                ),
                if (betslip.autoUnlockAt != null &&
                    betslip.autoUnlockAt!.isAfter(DateTime.now()))
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      "Will unlock on: ${DateFormat('MMM d, HH:mm').format(betslip.autoUnlockAt!)}",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white.withOpacity(0.70)),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    bool shouldShowDetails = widget.isAdminView ||
        widget.isPurchased ||
        betslip.isEffectivelyFreeNow ||
        (!betslip.isPaid && !betslip.isPremium);

    bool canShowFullBookingCode = widget.isAdminView ||
        ((widget.isPurchased || betslip.isEffectivelyFreeNow) &&
            (betslip.isPaid || betslip.isPremium)) ||
        (!betslip.isPaid && !betslip.isPremium);

    return Card(
      elevation: betslip.isPremium ? 2.5 : 1.5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: betslip.isPremium
                ? theme.colorScheme.primary.withOpacity(0.6)
                : Colors.transparent,
            width: betslip.isPremium ? 1.5 : 0,
          )),
      child: InkWell(
        onTap: () {
          if (showExpiredNotPurchasedOverlay) {
            Fluttertoast.showToast(
                msg: betslip.isPremium
                    ? "This premium package has expired."
                    : "This tip has expired.");
            return;
          }
          if (isEffectivelyLockedForUser) {
            widget.onTapLocked?.call();
          } else {
            widget.onTapCard?.call();
          }
        },
        borderRadius: BorderRadius.circular(11.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (betslip.isPremium && !widget.isAdminView)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11.0),
                      topRight: Radius.circular(11.0),
                    )),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border_purple500_outlined,
                        color: theme.colorScheme.onPrimary, size: 18),
                    const SizedBox(width: 6),
                    Text("PREMIUM PACKAGE",
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: (betslip.isPremium && !widget.isAdminView)
                    ? Radius.zero
                    : const Radius.circular(11.0),
                topRight: (betslip.isPremium && !widget.isAdminView)
                    ? Radius.zero
                    : const Radius.circular(11.0),
              ),
              child: imageDisplayWidget,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  12.0,
                  betslip.isPremium && !widget.isAdminView ? 8.0 : 10.0,
                  widget.isAdminView ? 0 : 12.0,
                  10.0),
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
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (shouldShowDetails) ...[
                          if ((betslip.odds != null &&
                              betslip.odds!.isNotEmpty) ||
                              (betslip.companyName != null &&
                                  betslip.companyName!.isNotEmpty)) ...[
                            Row(
                              children: [
                                if (betslip.odds != null &&
                                    betslip.odds!.isNotEmpty)
                                  Expanded(
                                    flex: betslip.companyName != null &&
                                        betslip.companyName!.isNotEmpty
                                        ? 1
                                        : 2,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.show_chart_rounded,
                                            size: 14,
                                            color: theme
                                                .colorScheme.onSurfaceVariant
                                                .withOpacity(0.7)),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            "Odds: ${betslip.odds}",
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if ((betslip.odds != null &&
                                    betslip.odds!.isNotEmpty) &&
                                    (betslip.companyName != null &&
                                        betslip.companyName!.isNotEmpty))
                                  const SizedBox(width: 8),
                                if (betslip.companyName != null &&
                                    betslip.companyName!.isNotEmpty)
                                  Expanded(
                                    flex: betslip.odds != null &&
                                        betslip.odds!.isNotEmpty
                                        ? 1
                                        : 2,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: (betslip.odds ==
                                          null ||
                                          betslip.odds!.isEmpty)
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.business_center_outlined,
                                            size: 14,
                                            color: theme
                                                .colorScheme.onSurfaceVariant
                                                .withOpacity(0.7)),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            betslip.companyName!,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: (betslip.odds == null ||
                                                betslip.odds!.isEmpty)
                                                ? TextAlign.start
                                                : TextAlign.end,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 5,
                              child: (betslip.bookingCode != null &&
                                  betslip.bookingCode!.isNotEmpty &&
                                  canShowFullBookingCode)
                                  ? Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _copyToClipboard(
                                      betslip.bookingCode!, context),
                                  borderRadius: BorderRadius.circular(4),
                                  splashColor: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  highlightColor: theme
                                      .colorScheme.primary
                                      .withOpacity(0.05),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 3.0, horizontal: 2.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            Icons
                                                .qr_code_scanner_outlined,
                                            size: 16,
                                            color: theme
                                                .colorScheme.primary),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            betslip.bookingCode!,
                                            style: theme
                                                .textTheme.bodyLarge
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.copy_rounded,
                                            size: 15,
                                            color: theme
                                                .colorScheme.primary
                                                .withOpacity(0.8)),
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
                                child: _buildPriceOrStatusChip(
                                    context, theme, betslip, canStillPurchase),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (betslip.isPremium && shouldShowDetails)
                          Padding(
                            padding:
                            const EdgeInsets.only(top: 4.0, bottom: 6.0),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Refund Guarantee:",
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                          color: theme.colorScheme
                                              .onSecondaryContainer,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                          Icons
                                              .replay_circle_filled_rounded,
                                          color: theme.colorScheme.secondary,
                                          size: 15),
                                      const SizedBox(width: 5),
                                      Text("Stake Refund: ",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant)),
                                      Text(
                                          betslip
                                              .formattedRefundAmountIfLost,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme
                                                  .colorScheme.secondary)),
                                    ],
                                  ),
                                  if (betslip.refundPercentageBonus > 0) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.add_reaction_outlined,
                                            color: theme.colorScheme.secondary,
                                            size: 15),
                                        const SizedBox(width: 5),
                                        Text(
                                            "+${betslip.refundPercentageBonus}% Bonus = ",
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.85))),
                                        Text(
                                            betslip
                                                .formattedCalculatedTotalRefund,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme
                                                    .secondary)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        Divider(
                            height: 1,
                            thickness: 0.5,
                            color: theme.dividerColor.withOpacity(0.5)),
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
                                    color: betslip.isExpired
                                        ? theme.colorScheme.error
                                        .withOpacity(0.8)
                                        : theme.colorScheme.secondary
                                        .withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _formatValidity(context, betslip),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: betslip.isExpired
                                            ? theme.colorScheme.error
                                            .withOpacity(0.9)
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
                                Icon(Icons.access_time_filled_rounded,
                                    size: 13,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  betslip.createdAt != null
                                      ? DateFormat('MMM d, HH:mm')
                                      .format(betslip.createdAt!)
                                      : '---',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.7),
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
                      icon: Icon(Icons.delete_sweep_outlined,
                          color: theme.colorScheme.error.withOpacity(0.8)),
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

  Widget _buildPriceOrStatusChip(
      BuildContext context, ThemeData theme, Betslip betslip, bool canStillPurchase) {
    if (widget.isAdminView) {
      if (betslip.isPremium) {
        return Chip(
          avatar: Icon(Icons.star_purple500_sharp,
              color: theme.colorScheme.primary, size: 16),
          label: Text("PREMIUM (${betslip.formattedPackagePrice})",
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600)),
          backgroundColor:
          theme.colorScheme.primaryContainer.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity:
          const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      } else if (betslip.isPaid) {
        return Chip(
          avatar: Icon(Icons.monetization_on_outlined,
              color: theme.colorScheme.tertiary, size: 15),
          label: Text(
              betslip.isEffectivelyFreeNow
                  ? "PAID (UNLOCKED)"
                  : "PAID TIP (${betslip.formattedPrice})",
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600)),
          backgroundColor:
          theme.colorScheme.tertiaryContainer.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity:
          const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      } else {
        return Chip(
          avatar: Icon(Icons.check_circle_outline_rounded,
              color: theme.colorScheme.secondary, size: 16),
          label: Text('FREE TIP',
              style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold)),
          backgroundColor:
          theme.colorScheme.secondaryContainer.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity:
          const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      }
    }

    // User view
    if (betslip.isPremium) {
      if (widget.isPurchased || betslip.isEffectivelyFreeNow) {
        return Chip(
          avatar: Icon(Icons.star_purple500_sharp,
              color: theme.colorScheme.primary, size: 16),
          label: Text(
              betslip.isEffectivelyFreeNow && !widget.isPurchased
                  ? "PREMIUM (UNLOCKED)"
                  : "PREMIUM PURCHASED",
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600)),
          backgroundColor:
          theme.colorScheme.primaryContainer.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity:
          const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      } else if (canStillPurchase) {
        return Text(
          betslip.formattedPackagePrice,
          style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        );
      } else {
        // Premium, not purchased, and EXPIRED
        return Chip(
          avatar: Icon(Icons.timer_off_outlined,
              color: theme.colorScheme.error, size: 16),
          label: Text("EXPIRED",
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600)),
          backgroundColor:
          theme.colorScheme.errorContainer.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity:
          const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      }
    } else if (betslip.isPaid) {
      // Regular Paid Slip
      if (widget.isPurchased || betslip.isEffectivelyFreeNow) {
        String labelText = widget.isPurchased ? 'Purchased' : 'Unlocked';
        IconData iconData = widget.isPurchased
            ? Icons.check_circle_rounded
            : Icons.lock_open_rounded;
        return Chip(
          avatar:
          Icon(iconData, color: theme.colorScheme.secondary, size: 15),
          label: Text(labelText.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600)),
          backgroundColor:
          theme.colorScheme.secondaryContainer.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity:
          const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      } else if (canStillPurchase) {
        // Regular Paid, locked by user, but available
        return Text(
          betslip.formattedPrice,
          style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        );
      } else {
        // Regular Paid, locked, and EXPIRED
        return Chip(
          avatar: Icon(Icons.timer_off_outlined,
              color: theme.colorScheme.error, size: 16),
          label: Text("EXPIRED",
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600)),
          backgroundColor:
          theme.colorScheme.errorContainer.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity:
          const VisualDensity(horizontal: 0.0, vertical: -1),
          side: BorderSide.none,
        );
      }
    } else {
      // Regular Free
      return Chip(
        avatar: Icon(Icons.star_border_rounded,
            color: theme.colorScheme.secondary, size: 16),
        label: Text('FREE TIP',
            style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold)),
        backgroundColor:
        theme.colorScheme.secondaryContainer.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: 0.0, vertical: -1),
        side: BorderSide.none,
      );
    }
  }
}


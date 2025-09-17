// lib/admin/widgets/banner_list_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <<<--- ADDED IMPORT FOR DATEFORMAT
import '../../models/banner_item_model.dart';

typedef OnBannerAction = Future<void> Function(String bannerId);

class BannerListItem extends StatelessWidget {
  final BannerItem banner;
  final OnBannerAction onDelete;
  final OnBannerAction onToggleActive;
  final bool isDeleting;
  final bool isToggling;

  const BannerListItem({
    super.key,
    required this.banner,
    required this.onDelete,
    required this.onToggleActive,
    this.isDeleting = false,
    this.isToggling = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banner.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    banner.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.grey, size: 40)),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              banner.title ?? 'No Title',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (banner.actionUrl != null && banner.actionUrl!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      banner.actionUrl!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.secondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: Icon(
                    banner.isActive
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: banner.isActive
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    size: 18,
                  ),
                  label: Text(banner.isActive ? 'Active' : 'Inactive'),
                  backgroundColor: banner.isActive
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  labelStyle: TextStyle(
                      color: banner.isActive
                          ? Colors.green.shade800
                          : Colors.black54,
                      fontWeight: FontWeight.w500),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isToggling
                        ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                        CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                      icon: Icon(
                        banner.isActive
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: theme.colorScheme.secondary,
                      ),
                      tooltip:
                      banner.isActive ? 'Deactivate' : 'Activate',
                      onPressed: () => onToggleActive(banner.id), // Null check for id is handled by BannerItem model (non-nullable id)
                    ),
                    const SizedBox(width: 4),
                    isDeleting
                        ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                        CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                      icon: Icon(Icons.delete_sweep_outlined,
                          color: theme.colorScheme.error),
                      tooltip: 'Delete Banner',
                      onPressed: () => onDelete(banner.id), // Null check for id is handled by BannerItem model (non-nullable id)
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16, thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text( // Uses DateFormat
                    'Created: ${DateFormat.yMMMd().format(banner.createdAt.toLocal())}',
                    style: theme.textTheme.labelSmall),
                if (banner.adminId != null)
                  Text('By: ${banner.adminId!.substring(0, 8)}...', // Safe use of ! because of null check
                      style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

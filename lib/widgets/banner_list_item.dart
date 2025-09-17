import 'package:flutter/material.dart';
import '../models/banner_item_model.dart'; // We'll create this model

typedef OnBannerAction = Future<void> Function(String bannerId);

class BannerListItem extends StatelessWidget {
  final BannerItem banner;
  final OnBannerAction onDelete;
  final OnBannerAction onToggleActive; // To activate/deactivate
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banner.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  banner.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text(
              banner.title ?? 'No Title',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (banner.actionUrl != null && banner.actionUrl!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Action URL: ${banner.actionUrl}', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(banner.isActive ? 'Active' : 'Inactive'),
                  backgroundColor: banner.isActive ? Colors.green.shade100 : Colors.grey.shade300,
                  labelStyle: TextStyle(
                      color: banner.isActive ? Colors.green.shade800 : Colors.black54,
                      fontWeight: FontWeight.w500
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Row(
                  children: [
                    isToggling
                        ? const SizedBox(width:24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                      icon: Icon(
                        banner.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: theme.colorScheme.secondary,
                      ),
                      tooltip: banner.isActive ? 'Deactivate' : 'Activate',
                      onPressed: () => onToggleActive(banner.id),
                    ),
                    const SizedBox(width: 8),
                    isDeleting
                        ? const SizedBox(width:24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      tooltip: 'Delete Banner',
                      onPressed: () => onDelete(banner.id),
                    ),
                  ],
                ),
              ],
            ),
            if (banner.adminId != null) ...[
              const SizedBox(height: 4),
              Text('Posted by: ${banner.adminId!.substring(0,8)}...', style: theme.textTheme.labelSmall), // Show partial admin ID
            ]
          ],
        ),
      ),
    );
  }
}

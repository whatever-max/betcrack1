// lib/screens/banner_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <<< IMPORT ADDED
import 'package:url_launcher/url_launcher.dart';
import '../models/banner_item_model.dart'; // <<< Import the single source of truth

class BannerDetailScreen extends StatelessWidget {
  final BannerItem banner;

  const BannerDetailScreen({super.key, required this.banner});

  Future<void> _launchURL(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No action URL provided for this banner.')),
      );
      return;
    }
    if (!await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $urlString')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(banner.title ?? 'Banner Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Using a simple Image.network, Hero can be added back if desired
            Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
              height: 250,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 250,
                color: Colors.grey[300],
                child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[700])),
              ),              loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (banner.title != null && banner.title!.isNotEmpty) ...[
                    Text(
                      banner.title!,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Posted on: ${DateFormat.yMMMd().add_jm().format(banner.createdAt.toLocal())}',
                    style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Status: ${banner.isActive ? "Active" : "Inactive"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: banner.isActive ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.w500
                    ),
                  ),
                  if (banner.adminId != null) ...[ // Display admin ID if available
                    const SizedBox(height: 8),
                    Text(
                      'Admin ID: ${banner.adminId}',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (banner.actionUrl != null && banner.actionUrl!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Visit Link'),
                        onPressed: () => _launchURL(context, banner.actionUrl),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Center(child: Text("No action link for this banner.", style: theme.textTheme.bodyMedium)),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

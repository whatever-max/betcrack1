// lib/admin/widgets/support_message_list_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/support_message_model.dart'; // Should contain class 'SupportMessage'

// >>> इंश्योर करें कि इस फ़ाइल में 'SupportMessageDetailScreen' से संबंधित कोई और क्लास या एक्सपोर्ट नहीं है <<<
// >>> Ensure NO other class definitions or exports related to 'SupportMessageDetailScreen' are in THIS file <<<

class SupportMessageListItem extends StatelessWidget {
  final SupportMessage message;
  final VoidCallback onTap;

  const SupportMessageListItem({
    super.key,
    required this.message,
    required this.onTap,
  });

  Color _getStatusColor(String status, ThemeData theme) {
    // ... your _getStatusColor logic
    switch (status.toLowerCase()) {
      case 'pending':
        return theme.colorScheme.tertiaryContainer.withOpacity(0.7);
      case 'replied_by_admin':
        return theme.colorScheme.primaryContainer.withOpacity(0.7);
      case 'resolved':
      case 'closed_by_admin':
      case 'closed_by_user':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String status, ThemeData theme) {
    // ... your _getStatusTextColor logic
    switch (status.toLowerCase()) {
      case 'pending':
        return theme.colorScheme.onTertiaryContainer;
      case 'replied_by_admin':
        return theme.colorScheme.onPrimaryContainer;
      case 'resolved':
      case 'closed_by_admin':
      case 'closed_by_user':
        return Colors.green.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getStatusIcon(String status) {
    // ... your _getStatusIcon logic
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_top_outlined;
      case 'replied_by_admin':
        return Icons.quickreply_outlined;
      case 'resolved':
      case 'closed_by_admin':
      case 'closed_by_user':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.help_center_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(message.status, theme);
    final statusTextColor = _getStatusTextColor(message.status, theme);
    final statusIcon = _getStatusIcon(message.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      // ... your Card structure from the previous correct version ...
      // For brevity, I'm omitting the full Card UI here, but ensure it's the one you had
      // that correctly uses 'message.status', 'message.userPhone', etc.
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User: ${message.userPhone ?? message.userId.substring(0,8)+"..."}',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Received: ${DateFormat.yMMMd().add_jm().format(message.createdAt.toLocal())}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Icon(statusIcon, color: statusTextColor, size: 16),
                    label: Text(
                      message.status.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' '),
                    ),
                    backgroundColor: statusColor,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: statusTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Divider(height: 16, thickness: 0.5),
              Text(
                message.messageContent,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.black87,
                    height: 1.4
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (message.adminReply != null && message.adminReply!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.5))
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.admin_panel_settings_outlined, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text('Admin Reply:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.adminReply!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if(message.repliedAt != null) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('Replied: ${DateFormat.yMd().add_jm().format(message.repliedAt!.toLocal())}', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                        )
                      ]
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}


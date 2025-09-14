// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import '../screens/payment_history_screen.dart'; // Import new screen
import '../admin/admin_panel_screen.dart';
import '../services/auth_service.dart'; // For logout
import '../screens/login_screen.dart'; // For logout redirect
// TODO: Import SettingsScreen when created

class AppDrawer extends StatelessWidget {
  final String? username;
  final String? phone;
  final String? userRole;
  final bool isLoadingProfile;
  final VoidCallback onLogout;
  final VoidCallback onNavigateToAdminPanel; // Specific callback for admin panel
  final VoidCallback onNavigateToPaymentHistory;
  final VoidCallback onNavigateToSettings;


  const AppDrawer({
    super.key,
    required this.username,
    required this.phone,
    required this.userRole,
    required this.isLoadingProfile,
    required this.onLogout,
    required this.onNavigateToAdminPanel,
    required this.onNavigateToPaymentHistory,
    required this.onNavigateToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              isLoadingProfile ? "Loading..." : username ?? "BetCrack User",
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            accountEmail: Text(
              isLoadingProfile ? "" : phone ?? "",
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: isLoadingProfile
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                username?.isNotEmpty == true ? username![0].toUpperCase() : "BC",
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
          ),
          ListTile(
            leading: Icon(Icons.receipt_long_rounded, color: theme.listTileTheme.iconColor ?? theme.colorScheme.onSurfaceVariant),
            title: Text("My Purchases", style: theme.textTheme.titleMedium),
            onTap: onNavigateToPaymentHistory,
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: theme.listTileTheme.iconColor ?? theme.colorScheme.onSurfaceVariant),
            title: Text("Settings", style: theme.textTheme.titleMedium),
            onTap: onNavigateToSettings,
          ),
          if (userRole == 'super_admin') ...[
            const Divider(),
            ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined, color: theme.listTileTheme.iconColor ?? theme.colorScheme.onSurfaceVariant),
              title: Text("Admin Panel", style: theme.textTheme.titleMedium),
              onTap: onNavigateToAdminPanel,
            ),
          ],
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text("Log Out", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
            onTap: onLogout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

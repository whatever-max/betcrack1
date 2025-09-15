// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
// We will need to import screens the drawer navigates to.
// These imports will be added/checked as we create/confirm the screens.
import '../screens/home_screen.dart'; // For "User Mode"
import '../admin/app_management_screen.dart'; // For "App Management"
import '../screens/payment_history_screen.dart';
// import '../admin/admin_panel_screen.dart'; // This might be deprecated or changed
// TODO: Import SettingsScreen when created

class AppDrawer extends StatelessWidget {
  final String? username;
  final String? phone;
  final String? userRole;
  final bool isLoadingProfile;
  final VoidCallback onLogout;

  // Callbacks for navigation - to be managed by the screen that uses the drawer
  final VoidCallback? onNavigateToUserModeHome;
  final VoidCallback? onNavigateToAppManagement;
  final VoidCallback onNavigateToPaymentHistory;
  final VoidCallback onNavigateToSettings;

  const AppDrawer({
    super.key,
    required this.username,
    required this.phone,
    required this.userRole,
    required this.isLoadingProfile,
    required this.onLogout,
    this.onNavigateToUserModeHome, // Optional, only for admin
    this.onNavigateToAppManagement, // Optional, only for admin
    required this.onNavigateToPaymentHistory,
    required this.onNavigateToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSuperAdmin = userRole == 'super_admin';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              isLoadingProfile ? "Loading..." : username ?? "BetCrack User",
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            accountEmail: Text(
              isLoadingProfile ? "" : phone ?? "",
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: isLoadingProfile
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : Text(
                username?.isNotEmpty == true
                    ? username![0].toUpperCase()
                    : "BC",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
          ),

          // Common Items for ALL users
          ListTile(
            leading: Icon(Icons.receipt_long_rounded,
                color: theme.listTileTheme.iconColor ??
                    theme.colorScheme.onSurfaceVariant),
            title: Text("My Purchases", style: theme.textTheme.titleMedium),
            onTap: onNavigateToPaymentHistory,
          ),

          // Admin Specific Items
          if (isSuperAdmin) ...[
            const Divider(),
            ListTile(
              leading: Icon(Icons.home_work_outlined, // Icon for user mode
                  color: theme.listTileTheme.iconColor ??
                      theme.colorScheme.onSurfaceVariant),
              title: Text("User Mode (Home)", style: theme.textTheme.titleMedium),
              onTap: onNavigateToUserModeHome,
            ),
            ListTile(
              leading: Icon(Icons.settings_applications_rounded, // Icon for app management
                  color: theme.listTileTheme.iconColor ??
                      theme.colorScheme.onSurfaceVariant),
              title: Text("App Management", style: theme.textTheme.titleMedium),
              onTap: onNavigateToAppManagement,
            ),
            const Divider(),
          ],

          // Settings (can be common or admin-only, adjust as needed)
          ListTile(
            leading: Icon(Icons.settings_outlined,
                color: theme.listTileTheme.iconColor ??
                    theme.colorScheme.onSurfaceVariant),
            title: Text("Settings", style: theme.textTheme.titleMedium),
            onTap: onNavigateToSettings,
          ),

          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text("Log Out",
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.error)),
            onTap: onLogout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

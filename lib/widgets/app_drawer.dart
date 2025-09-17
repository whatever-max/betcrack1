// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';

// Import screens the drawer navigates to
import '../screens/home_screen.dart'; // For "User Mode" navigation if admin
import '../admin/app_management_screen.dart'; // For "App Management" if admin
import '../screens/payment_history_screen.dart';
import '../screens/my_support_threads_screen.dart'; // <<< For "My Support Threads"
import '../screens/settings_screen.dart'; // <<< For general settings

class AppDrawer extends StatelessWidget {
  final String? username;
  final String? phone;
  final String? userRole;
  final bool isLoadingProfile;
  final VoidCallback onLogout;

  // Callbacks for navigation
  final VoidCallback? onNavigateToUserModeHome;
  final VoidCallback? onNavigateToAppManagement;
  final VoidCallback onNavigateToPaymentHistory;
  final VoidCallback onNavigateToSettings;

  // Parameters for conditional support threads item
  final bool hasUnreadSupportThreads;
  final VoidCallback? onNavigateToMySupportThreads;

  const AppDrawer({
    super.key,
    required this.username,
    required this.phone,
    required this.userRole,
    required this.isLoadingProfile,
    required this.onLogout,
    this.onNavigateToUserModeHome,
    this.onNavigateToAppManagement,
    required this.onNavigateToPaymentHistory,
    required this.onNavigateToSettings,
    required this.hasUnreadSupportThreads,
    this.onNavigateToMySupportThreads,
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
              isLoadingProfile ? "" : phone ?? "No phone",
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
                      strokeWidth: 2.5, color: Colors.white))
                  : Text(
                username?.isNotEmpty == true
                    ? username![0].toUpperCase()
                    : "U", // Default to 'U' for User
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
          ),

          ListTile(
            leading: Icon(Icons.receipt_long_rounded,
                color: theme.listTileTheme.iconColor ?? theme.colorScheme.secondary),
            title: Text("My Purchases", style: theme.textTheme.titleMedium),
            onTap: onNavigateToPaymentHistory,
          ),

          // Conditionally show "My Support Threads"
          if (hasUnreadSupportThreads && onNavigateToMySupportThreads != null)
            ListTile(
              leading: Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
              title: Text('My Support Threads', style: theme.textTheme.titleMedium),
              trailing: CircleAvatar( // Always show dot if item is present (indicates active threads)
                  radius: 4,
                  backgroundColor: theme.colorScheme.error), // Could change color based on 'unread' specifically
              onTap: onNavigateToMySupportThreads,
            )
          else if (onNavigateToMySupportThreads != null && !isSuperAdmin) // Allow users to access it even if no unread, if callback provided
            ListTile(
              leading: Icon(Icons.forum_outlined, color: theme.colorScheme.secondary), // Slightly different color if no unread
              title: Text('My Support Threads', style: theme.textTheme.titleMedium),
              onTap: onNavigateToMySupportThreads,
            ),


          // Admin Specific Items
          if (isSuperAdmin) ...[
            const Divider(),
            ListTile(
              leading: Icon(Icons.home_work_outlined,
                  color: theme.listTileTheme.iconColor ?? theme.colorScheme.secondary),
              title: Text("User Mode (Home)", style: theme.textTheme.titleMedium),
              onTap: onNavigateToUserModeHome,
            ),
            ListTile(
              leading: Icon(Icons.settings_applications_rounded,
                  color: theme.listTileTheme.iconColor ?? theme.colorScheme.secondary),
              title: Text("App Management", style: theme.textTheme.titleMedium),
              onTap: onNavigateToAppManagement,
            ),
            // Admin might have a direct link to a list of ALL support threads
            // For now, this is handled within AppManagementScreen itself
            const Divider(),
          ],

          ListTile(
            leading: Icon(Icons.settings_outlined,
                color: theme.listTileTheme.iconColor ?? theme.colorScheme.secondary),
            title: Text("Settings", style: theme.textTheme.titleMedium),
            onTap: onNavigateToSettings,
          ),

          const Spacer(), // Pushes logout to the bottom
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text("Log Out",
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.error)),
            onTap: onLogout,
          ),
          const SizedBox(height: 8), // Some padding at the bottom
        ],
      ),
    );
  }
}

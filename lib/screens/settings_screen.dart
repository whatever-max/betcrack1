// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // If you need Supabase for user-specific settings later
import '../services/auth_service.dart'; // For logout functionality if placed here
// Potentially import other screens if settings navigate to them, e.g., ProfileEditScreen

class SettingsScreen extends StatefulWidget {
  static const String routeName = '/settings'; // Optional: for named routing

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final supabase = Supabase.instance.client;

  // Example: Placeholder for a user preference
  bool _enableNotifications = true;

  // Example: Fetch user-specific settings if stored in your database
  // Future<void> _loadUserSettings() async {
  //   final userId = supabase.auth.currentUser?.id;
  //   if (userId == null) return;
  //   try {
  //     // final data = await supabase.from('user_settings').select('enable_notifications').eq('user_id', userId).single();
  //     // if (mounted && data != null) {
  //     //   setState(() {
  //     //     _enableNotifications = data['enable_notifications'] as bool? ?? true;
  //     //   });
  //     // }
  //   } catch (e) {
  //     print("Error loading user settings: $e");
  //   }
  // }

  @override
  void initState() {
    super.initState();
    // if (_supabase.auth.currentUser != null) {
    //   _loadUserSettings();
    // }
  }

  void _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      print("SettingsScreen: Error during logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error logging out: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surfaceVariant, // Or primary
        // elevation: 1,
      ),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 10),
          // Example: Profile Section (can navigate to a dedicated profile edit screen)
          ListTile(
            leading: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary),
            title: Text('Profile', style: theme.textTheme.titleMedium),
            subtitle: const Text('View or edit your profile details'),
            onTap: () {
              // TODO: Navigate to Profile Screen or Profile Edit Screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile screen comming soon !')),
              );
            },
          ),
          const Divider(),

          // Example: Notification Settings
          SwitchListTile(
            secondary: Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary),
            title: Text('Enable Notifications', style: theme.textTheme.titleMedium),
            value: _enableNotifications,
            onChanged: (bool value) {
              setState(() {
                _enableNotifications = value;
                // TODO: Save this preference to local storage or backend
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications ${value ? "enabled" : "disabled"} (UI only).')),
              );
            },
            activeColor: theme.colorScheme.primary,
          ),
          const Divider(),

          // Example: App Theme (Light/Dark) - More complex to implement fully
          ListTile(
            leading: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary),
            title: Text('App Theme', style: theme.textTheme.titleMedium),
            subtitle: Text(Theme.of(context).brightness == Brightness.dark ? 'Dark Mode' : 'Light Mode'),
            onTap: () {
              // TODO: Implement theme switching logic (e.g., using a ThemeProvider)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme switching comming soon!.')),
              );
            },
          ),
          const Divider(),

          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
            title: Text('About BetCrack', style: theme.textTheme.titleMedium),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'BetCrack',
                applicationVersion: '1.0.0', // Replace with your actual version
                applicationLegalese: '©2025 BetCrack Company ', // Replace
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: Text(' App for amazing tips!'), // Replace
                  )
                ],
              );
            },
          ),
          const Divider(),

          // Placeholder for other settings
          // ListTile(
          //   leading: Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
          //   title: Text('Privacy Policy', style: theme.textTheme.titleMedium),
          //   onTap: () { /* TODO: Open Privacy Policy URL */ },
          // ),
          // const Divider(),

          // Logout (sometimes placed in settings, sometimes only in drawer)
          // If you want it here as well:
          // ListTile(
          //   leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
          //   title: Text('Log Out', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
          //   onTap: () {
          //     // Show confirmation dialog before logging out
          //     showDialog(
          //       context: context,
          //       builder: (BuildContext ctx) {
          //         return AlertDialog(
          //           title: const Text('Confirm Logout'),
          //           content: const Text('Are you sure you want to log out?'),
          //           actions: <Widget>[
          //             TextButton(
          //               child: const Text('Cancel'),
          //               onPressed: () => Navigator.of(ctx).pop(),
          //             ),
          //             TextButton(
          //               child: Text('Log Out', style: TextStyle(color: theme.colorScheme.error)),
          //               onPressed: () {
          //                 Navigator.of(ctx).pop(); // Close dialog
          //                 _logout();
          //               },
          //             ),
          //           ],
          //         );
          //       },
          //     );
          //   },
          // ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// lib/admin/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For formatting numbers

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // --- Analytics State ---
  int _totalUsers = 0;
  int _totalSlipsPosted = 0;
  int _totalFreeSlips = 0;
  int _totalPaidSlips = 0;
  int _totalPurchasedSlipsCount = 0;
  bool _isLoadingAnalytics = true;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoadingAnalytics = true;
      _isLoadingUsers = true;
    });
    await Future.wait([
      _fetchAnalytics(),
      _fetchUsers(),
    ]);
    if (mounted) {
      // isLoading states are set to false inside their respective fetch methods
    }
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    try {
      final List<Map<String, dynamic>> res = await supabase
          .from('profiles')
          .select('id, username, phone, role, created_at')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = res;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
      if (mounted) {
        setState(() => _isLoadingUsers = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching users: ${e.toString()}")));
      }
    }
  }

  Future<void> _fetchAnalytics() async {
    if (!mounted) return;
    try {
      // Fetch total users (This direct count method is reliable)
      _totalUsers = await supabase
          .from('profiles')
          .count(CountOption.exact);

      // Fetch total betslips and their types
      final List<Map<String, dynamic>> slipsData = await supabase
          .from('betslips')
          .select('id, is_paid');

      _totalSlipsPosted = slipsData.length;
      _totalFreeSlips = slipsData.where((s) => s['is_paid'] == false).length;
      _totalPaidSlips = slipsData.where((s) => s['is_paid'] == true).length;

      // Fetch total *completed* purchase transactions
      // SIMPLIFIED APPROACH: Fetch relevant records and count on the client.
      final List<Map<String, dynamic>> completedPurchases = await supabase
          .from('purchases')
          .select('id') // We only need something to count, 'id' is fine
          .eq('status', 'completed');
      _totalPurchasedSlipsCount = completedPurchases.length;


      if (mounted) {
        setState(() => _isLoadingAnalytics = false);
      }
    } catch (e, stacktrace) {
      print("Error fetching analytics: $e");
      print(stacktrace);
      if (mounted) {
        setState(() => _isLoadingAnalytics = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching analytics: ${e.toString()}")));
      }
    }
  }

  Future<void> _deleteUser(String userId, String username) async {
    if (userId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't delete yourself!")));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete User: $username"),
        content: const Text(
            "Are you sure you want to permanently remove this user's profile? Auth user needs separate deletion via Admin API/Dashboard."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete Profile", style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('profiles').delete().eq('id', userId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User profile for '$username' removed.")));
        _fetchAllData();
      } catch (e) {
        print("Error deleting user profile: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete user profile: ${e.toString()}")));
      }
    }
  }

  Widget _buildAnalyticsCard(BuildContext context,
      {required IconData icon, required String title, required String value, Color? iconColor, bool isLoading = false}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormatter = NumberFormat.compact();

    return Scaffold(
      appBar: AppBar(
        title: const Text("User & App Analytics"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoadingAnalytics || _isLoadingUsers ? null : _fetchAllData,
            tooltip: "Refresh Data",
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllData,
        color: theme.colorScheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text("App Analytics", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.4 : 1.2,
              children: [
                _buildAnalyticsCard(context,
                    icon: Icons.people_alt_outlined,
                    title: "Total Users",
                    value: _isLoadingAnalytics ? "..." : numberFormatter.format(_totalUsers),
                    isLoading: _isLoadingAnalytics),
                _buildAnalyticsCard(context,
                    icon: Icons.article_outlined,
                    title: "Slips Posted",
                    value: _isLoadingAnalytics ? "..." : numberFormatter.format(_totalSlipsPosted),
                    isLoading: _isLoadingAnalytics,
                    iconColor: theme.colorScheme.secondary),
                _buildAnalyticsCard(context,
                    icon: Icons.money_off_csred_outlined,
                    title: "Free Slips",
                    value: _isLoadingAnalytics ? "..." : numberFormatter.format(_totalFreeSlips),
                    isLoading: _isLoadingAnalytics,
                    iconColor: Colors.green[700]),
                _buildAnalyticsCard(context,
                    icon: Icons.paid_outlined,
                    title: "Paid Slips",
                    value: _isLoadingAnalytics ? "..." : numberFormatter.format(_totalPaidSlips),
                    isLoading: _isLoadingAnalytics,
                    iconColor: Colors.orange[800]),
                _buildAnalyticsCard(context,
                    icon: Icons.shopping_cart_checkout_rounded,
                    title: "Purchases Made",
                    value: _isLoadingAnalytics ? "..." : numberFormatter.format(_totalPurchasedSlipsCount),
                    isLoading: _isLoadingAnalytics,
                    iconColor: Colors.purple[600]),
                _buildAnalyticsCard(context,
                    icon: Icons.monetization_on_outlined,
                    title: "Total Revenue",
                    value: _isLoadingAnalytics ? "..." : "TZS ---", // Placeholder
                    isLoading: _isLoadingAnalytics,
                    iconColor: Colors.teal[600]),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("User Accounts", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            _isLoadingUsers
                ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32.0), child: CircularProgressIndicator()))
                : _users.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 32.0), child: Text("No users found", style: theme.textTheme.titleMedium)))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isSelf = user['id'] == _currentUserId;
                final userCreatedAt = user['created_at'] != null ? DateTime.tryParse(user['created_at']) : null;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        (user['username'] as String?)?.isNotEmpty == true ? (user['username'] as String)[0].toUpperCase() : "U",
                        style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(user['username'] as String? ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${user['phone'] ?? 'No phone'} — Role: ${user['role'] ?? 'user'}", style: theme.textTheme.bodyMedium),
                        if (userCreatedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text("Joined: ${DateFormat.yMMMd().add_jm().format(userCreatedAt)}", style: theme.textTheme.bodySmall),
                          )
                      ],
                    ),
                    trailing: isSelf
                        ? Chip(
                      label: Text("You", style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                    )
                        : PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.outline),
                      tooltip: "More options for ${user['username']}",
                      onSelected: (value) {
                        if (value == 'delete_profile') {
                          _deleteUser(user['id'] as String, user['username'] as String? ?? 'Unknown User');
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'delete_profile',
                          child: ListTile(leading: Icon(Icons.delete_forever_outlined, color: Colors.red), title: Text('Delete Profile')),
                        ),
                      ],
                    ),
                    onTap: () {
                      print("Tapped on user: ${user['username']}");
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

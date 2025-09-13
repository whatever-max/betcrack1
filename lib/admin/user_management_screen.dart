import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  bool isLoading = false;
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  Future<void> fetchUsers() async {
    setState(() => isLoading = true);

    try {
      final res = await supabase.from('profiles').select('id, username, phone, role');
      setState(() {
        users = res;
      });
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> deleteUser(String userId) async {
    if (userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't delete yourself!")),
      );
      return;
    }

    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User"),
        content: const Text("Are you sure you want to remove this user?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('profiles').delete().eq('id', userId);
        fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User removed")),
        );
      } catch (e) {
        debugPrint("Error deleting user: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete user")),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Management")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text("No users found"))
          : ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final isSelf = user['id'] == currentUserId;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(user['username'] ?? 'No Name'),
              subtitle: Text("${user['phone']} — ${user['role']}"),
              trailing: isSelf
                  ? const Text("You", style: TextStyle(color: Colors.grey))
                  : IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteUser(user['id']),
              ),
            ),
          );
        },
      ),
    );
  }
}

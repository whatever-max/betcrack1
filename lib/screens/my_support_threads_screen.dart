// lib/screens/my_support_threads_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/support_thread_model.dart'; // New model
import 'support_thread_detail_screen.dart'; // New detail screen
import 'create_new_thread_screen.dart'; // New create screen

class MySupportThreadsScreen extends StatefulWidget {
  const MySupportThreadsScreen({super.key});

  @override
  State<MySupportThreadsScreen> createState() => _MySupportThreadsScreenState();
}

class _MySupportThreadsScreenState extends State<MySupportThreadsScreen> {
  final _supabase = Supabase.instance.client;
  Stream<List<SupportThread>>? _threadsStream; // Changed to Stream for Realtime

  @override
  void initState() {
    super.initState();
    _initializeThreadsStream();
  }

  void _initializeThreadsStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        // This should ideally not happen if screen is protected
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('You need to be logged in.'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }
    // Listen to changes in real-time
    _threadsStream = _supabase
        .from('support_threads')
        .stream(primaryKey: ['id']) // Ensure 'id' is a PK
        .eq('user_id', userId)
        .order('updated_at', ascending: false) // Show most recently updated first
        .map((maps) => maps.map((map) => SupportThread.fromMap(map)).toList());

    // Initial fetch for _hasSupportMessages in AppDrawer (if still using that logic)
    // This is a bit redundant if stream starts immediately.
    // The conditional drawer item would ideally subscribe to a stream/notifier for hasSupportMessages.
    // For simplicity, we'll keep the one-time check in HomeScreen for now.
    // The list itself will be live.
  }

  Future<void> _refreshThreads() async {
    // With streams, manual refresh might not be strictly needed for data,
    // but can be kept for user to force a re-fetch or re-init of stream if something goes wrong.
    if (mounted) {
      setState(() {
        _initializeThreadsStream(); // Re-initialize the stream
      });
    }
  }

  void _navigateToDetailScreen(SupportThread thread) {
    // When navigating, mark the thread as read by the user if it wasn't
    if (!thread.isReadByUser) {
      _supabase
          .from('support_threads')
          .update({'is_read_by_user': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', thread.id)
          .eq('user_id', thread.userId) // Ensure user can only update their own
          .then((_) => print("Marked thread ${thread.id} as read by user."))
          .catchError((e) => print("Error marking thread as read: $e"));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportThreadDetailScreen(thread: thread),
      ),
    ).then((value) {
      // Stream will handle updates, but a manual refresh call could be added if needed
      // _refreshThreads();
    });
  }

  Color _getStatusColor(String status, ThemeData theme, {bool isRead = true}) {
    Color baseColor;
    switch (status.toLowerCase()) {
      case 'open':
      case 'pending_admin_reply':
        baseColor = theme.colorScheme.tertiaryContainer;
        break;
      case 'pending_user_reply':
        baseColor = theme.colorScheme.primaryContainer;
        break;
      case 'resolved_by_user':
      case 'resolved_by_admin':
      case 'closed_by_user':
      case 'closed_by_admin':
        baseColor = Colors.green.shade100;
        break;
      default:
        baseColor = Colors.grey.shade300;
    }
    return isRead ? baseColor.withOpacity(0.7) : baseColor; // More vibrant if unread
  }

  Color _getStatusTextColor(String status, ThemeData theme, {bool isRead = true}) {
    Color baseColor;
    switch (status.toLowerCase()) {
      case 'open':
      case 'pending_admin_reply':
        baseColor = theme.colorScheme.onTertiaryContainer;
        break;
      case 'pending_user_reply':
        baseColor = theme.colorScheme.onPrimaryContainer;
        break;
      case 'resolved_by_user':
      case 'resolved_by_admin':
      case 'closed_by_user':
      case 'closed_by_admin':
        baseColor = Colors.green.shade800;
        break;
      default:
        baseColor = Colors.grey.shade800;
    }
    return isRead ? baseColor : theme.colorScheme.error; // Indicate unread with different color if needed
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
      case 'pending_admin_reply':
        return Icons.hourglass_top_outlined;
      case 'pending_user_reply':
        return Icons.quickreply_outlined; // User needs to reply
      case 'resolved_by_user':
      case 'resolved_by_admin':
      case 'closed_by_user':
      case 'closed_by_admin':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.help_outline;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Support Threads'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshThreads,
        child: StreamBuilder<List<SupportThread>>(
          stream: _threadsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print("Error in StreamBuilder for threads: ${snapshot.error}");
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                      const SizedBox(height: 16),
                      Text('Error Loading Threads', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text("Could not fetch support threads. Please check your connection.", textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _refreshThreads)
                    ],
                  ),
                ),
              );
            }

            final threads = snapshot.data;
            if (threads == null || threads.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, size: 60, color: theme.colorScheme.secondary),
                      const SizedBox(height: 20),
                      Text('No Support Threads Yet', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text('Start a new conversation with our support team if you need help.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('Create New Thread'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateNewThreadScreen()))
                              .then((success) {
                            if (success == true) { // CreateNewThreadScreen pops with true on success
                              // Stream should pick it up, but a manual refresh can be an option
                              // _refreshThreads();
                            }
                          });
                        },
                      )
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];
                final bool isUnreadForUser = !thread.isReadByUser && thread.status == 'pending_user_reply';
                final statusColor = _getStatusColor(thread.status, theme, isRead: thread.isReadByUser);
                final statusTextColor = _getStatusTextColor(thread.status, theme, isRead: thread.isReadByUser);
                final statusIcon = _getStatusIcon(thread.status);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  elevation: isUnreadForUser ? 3 : 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isUnreadForUser ? BorderSide(color: theme.colorScheme.primary, width: 1.5) : BorderSide.none
                  ),
                  child: InkWell(
                    onTap: () => _navigateToDetailScreen(thread),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  thread.subject ?? 'Thread #${thread.id.substring(0, 8)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: isUnreadForUser ? FontWeight.bold : FontWeight.w600,
                                    color: isUnreadForUser ? theme.colorScheme.primary : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                avatar: Icon(statusIcon, color: statusTextColor, size: 16),
                                label: Text(
                                  thread.status.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' '),
                                ),
                                backgroundColor: statusColor,
                                labelStyle: theme.textTheme.labelSmall?.copyWith(color: statusTextColor, fontWeight: FontWeight.w600),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            thread.lastMessagePreview ?? "No messages yet.",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: isUnreadForUser ? theme.textTheme.bodyMedium?.color : theme.hintColor,
                                fontStyle: thread.lastMessagePreview == null ? FontStyle.italic : FontStyle.normal
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isUnreadForUser) ...[
                                Icon(Icons.circle, color: theme.colorScheme.primary, size: 10),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                'Last update: ${DateFormat.yMMMd().add_jm().format(thread.updatedAt.toLocal())}',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateNewThreadScreen()))
              .then((success) {
            if (success == true) { /* Stream handles it */ }
          });
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New Thread'),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
      ),
    );
  }
}


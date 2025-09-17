// lib/screens/my_support_tickets_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/support_message_model.dart'; // Your SupportMessage model
import 'support_ticket_detail_screen.dart';   // Screen to show details and replies
import 'send_support_sms_screen.dart';         // Screen to create a new ticket

class MySupportTicketsScreen extends StatefulWidget {
  const MySupportTicketsScreen({super.key});

  @override
  State<MySupportTicketsScreen> createState() => _MySupportTicketsScreenState();
}

class _MySupportTicketsScreenState extends State<MySupportTicketsScreen> {
  final _supabase = Supabase.instance.client;
  Future<List<SupportMessage>>? _ticketsFuture;

  @override // <<< CORRECTED TYPO HERE
  void initState() {
    super.initState();
    _fetchMyTickets();
  }

  void _fetchMyTickets() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _ticketsFuture = Future.value([]);
        });
        // Optionally show a message or navigate away if user shouldn't be here
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('You need to be logged in to view tickets.'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _ticketsFuture = _supabase
            .from('support_messages')
            .select() // Select all fields
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .then((data) {
          // Assuming your SupportMessage.fromMap does not require a separate userEmail here
          // as it's the user's own tickets. If userEmail was for the ADMIN who replied,
          // then the select might need to join with profiles on admin_id_replied.
          // For now, sticking to your model's current fromMap signature.
          return data
              .map((item) => SupportMessage.fromMap(item as Map<String, dynamic>))
              .toList();
        }).catchError((error) {
          print("Error fetching support tickets: $error");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Failed to load your tickets: ${error.toString()}'),
                  backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
          throw error; // Re-throw to be caught by FutureBuilder
        });
      });
    }
  }

  Future<void> _refreshTickets() async {
    _fetchMyTickets();
  }

  void _navigateToDetailScreen(SupportMessage ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportTicketDetailScreen(ticket: ticket),
      ),
    ).then((_) {
      // Optional: Refresh list if status might have changed (e.g., user closed it)
      _fetchMyTickets();
    });
  }

  Color _getStatusColor(String status, ThemeData theme) {
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
        return Icons.help_outline; // Changed to a more generic help icon
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Support Tickets'),
        // Consistent styling with SendSupportSmsScreen AppBar
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTickets,
        child: FutureBuilder<List<SupportMessage>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading Tickets',
                        style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Could not fetch your support tickets. Please check your connection and try again.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: _fetchMyTickets,
                      )
                    ],
                  ),
                ),
              );
            }

            final tickets = snapshot.data;
            if (tickets == null || tickets.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.support_agent_outlined, size: 60, color: theme.colorScheme.secondary),
                      const SizedBox(height: 20),
                      Text(
                        'No Support Tickets Yet',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'If you have an issue or question, feel free to create a new ticket.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('Create New Ticket'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SendSupportSmsScreen()),
                          ).then((_) {
                            // Refresh list after potentially creating a new ticket
                            _fetchMyTickets();
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
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final statusColor = _getStatusColor(ticket.status, theme);
                final statusTextColor = _getStatusTextColor(ticket.status, theme);
                final statusIcon = _getStatusIcon(ticket.status);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => _navigateToDetailScreen(ticket),
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
                                  'Ticket #${ticket.id.substring(0, 8)}', // Short ID
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                avatar: Icon(statusIcon, color: statusTextColor, size: 16),
                                label: Text(
                                  ticket.status.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' '),
                                ),
                                backgroundColor: statusColor,
                                labelStyle: theme.textTheme.labelSmall?.copyWith(
                                  color: statusTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ticket.messageContent,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.8)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (ticket.status.toLowerCase() == 'replied_by_admin' && ticket.adminReply != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mark_chat_read_rounded, size: 16, color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Admin Replied',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const SizedBox(), // For spacing if no reply indication
                              Text(
                                'Sent: ${DateFormat.yMMMd().add_jm().format(ticket.createdAt.toLocal())}',
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SendSupportSmsScreen()),
          ).then((_) {
            // Refresh list after potentially creating a new ticket
            // The .then() callback is executed when SendSupportSmsScreen is popped.
            _fetchMyTickets();
          });
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New Ticket'),
        backgroundColor: theme.colorScheme.secondary, // Or primary, your choice
        foregroundColor: theme.colorScheme.onSecondary,
      ),
    );
  }
}


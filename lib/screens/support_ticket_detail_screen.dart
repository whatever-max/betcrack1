// lib/screens/support_ticket_detail_screen.dart
import 'dart:io' show Platform; // For platform-specific toast/snackbar
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_message_model.dart'; // Your SupportMessage model

class SupportTicketDetailScreen extends StatefulWidget {
  final SupportMessage ticket;

  const SupportTicketDetailScreen({super.key, required this.ticket});

  @override
  State<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  late SupportMessage _currentTicket;
  final _supabase = Supabase.instance.client;
  bool _isUpdatingStatus = false;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _fetchLatestTicketDetails(); // Fetch latest details when screen opens
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    if (Platform.isAndroid || Platform.isIOS) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: isError ? Colors.red.shade700 : null,
        textColor: Colors.white,
      );
    } else {
      print("Feedback (${isError ? 'ERROR' : 'INFO'}): $message");
      if (mounted && context != null) { // Ensure context is valid
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
          ),
        );
      }
    }
  }

  Future<void> _fetchLatestTicketDetails() async {
    if (!mounted || _isLoadingDetails) return;
    setState(() => _isLoadingDetails = true);
    try {
      final response = await _supabase
          .from('support_messages')
          .select()
          .eq('id', _currentTicket.id)
          .single();

      if (mounted) {
        setState(() {
          // Assuming your SupportMessage.fromMap doesn't need external userEmail
          // when just fetching its own details. If it does, you'd need to
          // pass the existing _currentTicket.userEmail or fetch it again.
          _currentTicket = SupportMessage.fromMap(response, userEmail: _currentTicket.userEmail);
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
      print("Error fetching latest ticket details for ID ${_currentTicket.id}: $e");
      // Don't show feedback here to avoid being too noisy, unless critical
    }
  }

  Future<void> _updateTicketStatus(String newStatus) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      await _supabase
          .from('support_messages')
          .update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String()
      })
          .eq('id', _currentTicket.id);

      if (mounted) {
        setState(() {
          _currentTicket.status = newStatus;
          _isUpdatingStatus = false;
        });
        _showFeedback('Ticket status updated to "$newStatus".');
        // Consider Navigator.pop(context, true); if you want to signal update to previous screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
      print("Error updating ticket status for ID ${_currentTicket.id}: $e");
      String errorMessage = "Failed to update status. Please try again.";
      if (e is PostgrestException) {
        errorMessage = "Failed to update status: ${e.message}";
      }
      _showFeedback(errorMessage, isError: true);
    }
  }

  Widget _buildMessageCard(
      String title,
      String content,
      DateTime time, {
        bool isAdmin = false,
        String? avatarText,
        required ThemeData theme,
      }) {
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: isAdmin ? 1.8 : 1.2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: isAdmin
          ? (isDark ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.primaryContainer.withOpacity(0.6))
          : (isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.6) : theme.colorScheme.surfaceVariant),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isAdmin
              ? BorderSide(color: theme.colorScheme.primary.withOpacity(0.7), width: 0.8)
              : BorderSide(color: theme.dividerColor, width: 0.5)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAdmin ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  foregroundColor: isAdmin ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondary,
                  radius: 18,
                  child: Text(
                    avatarText ?? (isAdmin ? 'S' : 'U'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        DateFormat.yMMMd().add_jm().format(time.toLocal()),
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5, indent: 8, endIndent: 8,),
            SelectableText(
              content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool canUserClose = _currentTicket.status.toLowerCase() == 'pending' ||
        _currentTicket.status.toLowerCase() == 'replied_by_admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket #${_currentTicket.id.substring(0, 8)}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          if (_isLoadingDetails)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchLatestTicketDetails,
              tooltip: 'Refresh Ticket Details',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0.5,
              margin: const EdgeInsets.only(bottom: 16),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status:',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _currentTicket.status.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' '),
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _currentTicket.status.toLowerCase() == 'pending'
                              ? theme.colorScheme.tertiary
                              : (_currentTicket.status.toLowerCase() == 'replied_by_admin'
                              ? theme.colorScheme.primary
                              : ( _currentTicket.status.toLowerCase().contains('closed') || _currentTicket.status.toLowerCase() == 'resolved'
                              ? Colors.green.shade600
                              : theme.colorScheme.onSurface)
                          )
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildMessageCard(
              'Your Message',
              _currentTicket.messageContent,
              _currentTicket.createdAt,
              avatarText: 'You',
              theme: theme,
            ),

            if (_currentTicket.adminReply != null && _currentTicket.adminReply!.isNotEmpty)
              _buildMessageCard(
                'Admin Reply',
                _currentTicket.adminReply!,
                _currentTicket.repliedAt ?? _currentTicket.createdAt,
                isAdmin: true,
                avatarText: 'S',
                theme: theme,
              )
            else
              Card(
                elevation: 0.5,
                color: theme.scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.dividerColor.withOpacity(0.5))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty_rounded, color: theme.hintColor, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Waiting for admin reply...',
                        style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            if (canUserClose && !_isUpdatingStatus)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark as Resolved'),
                  onPressed: () => _updateTicketStatus('closed_by_user'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            if (_isUpdatingStatus)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              )),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

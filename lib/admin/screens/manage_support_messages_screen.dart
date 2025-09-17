// lib/admin/screens/manage_support_messages_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../../models/support_message_model.dart';
import '../widgets/support_message_list_item.dart';
import 'support_message_detail_screen.dart';

class ManageSupportMessagesScreen extends StatefulWidget {
  static const String routeName = '/admin/manage-support';
  const ManageSupportMessagesScreen({super.key});

  @override
  State<ManageSupportMessagesScreen> createState() =>
      _ManageSupportMessagesScreenState();
}

class _ManageSupportMessagesScreenState
    extends State<ManageSupportMessagesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<SupportMessage> _messages = [];
  String? _loadingError;
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchSupportMessages();
  }

  Future<void> _fetchSupportMessages({String? statusFilter}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingError = null;
    });

    try {
      PostgrestFilterBuilder queryBuilder = _supabase.from('support_messages').select();

      if (statusFilter != null && statusFilter != 'all') {
        queryBuilder = queryBuilder.eq('status', statusFilter);
      }

      // Explicitly type the response from Supabase
      final List<Map<String, dynamic>> response = await queryBuilder.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _messages = response
              .map((data) => SupportMessage.fromMap(data)) // 'data' is now Map<String, dynamic>
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching support messages: $e");
        setState(() {
          _isLoading = false;
          if (e.toString().contains("is not a subtype of type")) {
            _loadingError = "Data format error. Please check console.";
          } else {
            _loadingError = "Failed to load messages. Please try again.";
          }
        });
        // Avoid calling Fluttertoast if it's the source of a crash loop
        // Fluttertoast.showToast(msg: "Error loading messages. Try again.");
      }
    }
  }

  void _navigateToDetail(SupportMessage message) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SupportMessageDetailScreen(messageId: message.id),
      ),
    );
    if (result == true && mounted) {
      _fetchSupportMessages(statusFilter: _selectedStatusFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Inbox'),
        actions: [
          Tooltip(
            message: "Filter by Status",
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list_alt),
              onSelected: (String value) {
                setState(() {
                  _selectedStatusFilter = value;
                });
                _fetchSupportMessages(statusFilter: value);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'all', child: Text('All Messages')),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(value: 'pending', child: Text('Pending')),
                const PopupMenuItem<String>(value: 'replied_by_admin', child: Text('Replied')),
                const PopupMenuItem<String>(value: 'resolved', child: Text('Resolved')),
                const PopupMenuItem<String>(value: 'closed_by_user', child: Text('Closed by User')),
                const PopupMenuItem<String>(value: 'closed_by_admin', child: Text('Closed by Admin')),
              ],
            ),
          ),
          Tooltip(
              message: "Refresh List",
              child: IconButton(icon: const Icon(Icons.refresh), onPressed: () => _fetchSupportMessages(statusFilter: _selectedStatusFilter))),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchSupportMessages(statusFilter: _selectedStatusFilter),
        child: Column(
          children: [
            if (_selectedStatusFilter != 'all')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal:16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text('Filter: ${_selectedStatusFilter.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ')}'),
                    onDeleted: () {
                      setState(() => _selectedStatusFilter = 'all');
                      _fetchSupportMessages(statusFilter: 'all');
                    },
                    deleteIconColor: theme.colorScheme.onSecondaryContainer,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadingError != null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
                      const SizedBox(height: 8),
                      Text(_loadingError!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Retry"), onPressed:() => _fetchSupportMessages(statusFilter: _selectedStatusFilter))
                    ],
                  ),
                ),
              )
                  : _messages.isEmpty
                  ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _selectedStatusFilter == 'all'
                          ? 'No support messages found.'
                          : 'No messages match the current filter.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor),
                    ),
                  ))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final SupportMessage message = _messages[index];
                  return SupportMessageListItem(
                    message: message,
                    onTap: () => _navigateToDetail(message),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

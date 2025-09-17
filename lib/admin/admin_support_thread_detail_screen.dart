// lib/admin/admin_support_thread_detail_screen.dart
import 'dart:async';import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io' show Platform;

import '../models/support_thread_model.dart';
import '../models/thread_message_model.dart';

class AdminSupportThreadDetailScreen extends StatefulWidget {
  final SupportThread thread;

  const AdminSupportThreadDetailScreen({super.key, required this.thread});

  @override
  State<AdminSupportThreadDetailScreen> createState() =>
      _AdminSupportThreadDetailScreenState();
}

class _AdminSupportThreadDetailScreenState
    extends State<AdminSupportThreadDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingMessage = false;
  bool _isUpdatingStatus = false;

  late SupportThread _currentThreadData;
  String? _currentAdminId;
  String? _currentAdminUsername;

  List<ThreadMessage> _messages = [];
  bool _isLoadingInitialMessages = true;
  RealtimeChannel? _adminThreadMessagesChannel; // Used for realtime updates

  final List<String> _availableStatuses = [
    'open',
    'pending_user_reply',
    'pending_admin_reply',
    'resolved_by_admin',
    'closed_by_admin',
  ];

  @override
  void initState() {
    super.initState();
    _currentThreadData = widget.thread;
    _currentAdminId = _supabase.auth.currentUser?.id;
    _fetchCurrentAdminProfile();
    _initializeAndFetchMessages();
  }

  void _showFeedback(String message,
      {bool isError = false, BuildContext? contextForSnackBar}) {
    if (!mounted) return;
    if (Platform.isAndroid || Platform.isIOS) {
      Fluttertoast.showToast(
          msg: message,
          toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: isError ? Colors.red.shade700 : null,
          textColor: Colors.white);
    } else {
      print("Admin Feedback (${isError ? 'ERROR' : 'INFO'}): $message");
      final currentContext = contextForSnackBar ?? context;
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor:
            isError ? Theme.of(currentContext).colorScheme.error : null));
      }
    }
  }

  Future<void> _fetchCurrentAdminProfile() async {
    if (_currentAdminId == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', _currentAdminId!)
          .single();
      if (mounted) {
        setState(() => _currentAdminUsername = data['username'] as String?);
      }
    } catch (e) {
      print("Admin: Error fetching admin profile: $e");
    }
  }

  Future<void> _markThreadAsReadByAdmin() async {
    // Only mark if it's currently unread by admin
    if (_currentAdminId == null || _currentThreadData.isReadByAdmin) return;
    try {
      await _supabase
          .from('support_threads')
          .update({'is_read_by_admin': true})
          .eq('id', _currentThreadData.id);
      if (mounted) {
        setState(() {
          _currentThreadData.isReadByAdmin = true;
        });
      }
      print("Admin: Marked thread ${_currentThreadData.id} as read.");
    } catch (e) {
      print("Admin: Error marking thread as read: $e");
    }
  }

  Future<void> _initializeAndFetchMessages() async {
    if (!mounted) return;
    setState(() => _isLoadingInitialMessages = true);

    try {
      final initialData = await _supabase
          .from('thread_messages')
          .select('*, sender_profile:sender_id(username, id, role)')
          .eq('thread_id', _currentThreadData.id)
          .order('created_at', ascending: true);

      if (!mounted) return;
      final fetchedMessages = initialData.map((map) {
        final senderProfileData =
        map['sender_profile'] as Map<String, dynamic>?;
        return ThreadMessage.fromMap(map,
            senderProfileData: senderProfileData);
      }).toList();

      setState(() {
        _messages = fetchedMessages;
        _isLoadingInitialMessages = false;
      });
      _scrollToBottom(milliseconds: 500);
      _markThreadAsReadByAdmin();

      // Unsubscribe from any previous channel before creating a new one
      _adminThreadMessagesChannel?.unsubscribe();

      _adminThreadMessagesChannel = _supabase
          .channel(
          'public:thread_messages:admin:thread_id=eq.${_currentThreadData.id}')
          .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'thread_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: _currentThreadData.id),
        callback: (payload) async {
          final newMessageMap = payload.newRecord;
          if (newMessageMap != null && mounted) {
            if (_messages.any((m) => m.id == newMessageMap['id'])) return;

            Map<String, dynamic>? senderProfileData;
            final senderId = newMessageMap['sender_id'] as String?;
            if (senderId != null) {
              try {
                final profileData = await _supabase
                    .from('profiles')
                    .select('username, id, role')
                    .eq('id', senderId)
                    .single();
                senderProfileData = profileData;
              } catch (e) {
                print("Admin: Error fetching profile for RT message: $e");
              }
            }
            final newMessage = ThreadMessage.fromMap(newMessageMap,
                senderProfileData: senderProfileData);
            setState(() {
              _messages.add(newMessage);
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
            _scrollToBottom();
            if (newMessage.senderRole == 'user') {
              _markThreadAsReadByAdmin();
              try {
                final data = await _supabase
                    .from('support_threads')
                    .select()
                    .eq('id', _currentThreadData.id)
                    .single();
                if (mounted) {
                  setState(
                          () => _currentThreadData = SupportThread.fromMap(data));
                }
              } catch (e) {
                print(
                    "Admin: Error refreshing thread details after RT message: $e");
              }
            }
          }
        },
      ).subscribe((status, err) {
        if (err != null) {
          print('Admin Realtime subscription error: $err');
        } else {
          print(
              'Admin Realtime subscription status for thread_messages: $status');
        }
      });
    } catch (e) {
      print('Admin: Error initializing messages: $e');
      if (mounted) {
        setState(() => _isLoadingInitialMessages = false);
        _showFeedback("Error loading messages.", isError: true);
      }
    }
  }

  Future<void> _sendAdminReply() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSendingMessage || _currentAdminId == null) {
      return;
    }

    if (_currentThreadData.status.toLowerCase().contains('closed_by_user') ||
        _currentThreadData.status
            .toLowerCase()
            .contains('resolved_by_user')) {
      _showFeedback(
          "User has marked this thread as ${_currentThreadData.status.toLowerCase().replaceAll('_', ' ')}. Consider status before replying.",
          isError: false);
    }
    if (_currentThreadData.status.toLowerCase().contains('closed_by_admin') ||
        _currentThreadData.status
            .toLowerCase()
            .contains('resolved_by_admin')) {
      _showFeedback(
          "This thread is already ${_currentThreadData.status.toLowerCase().replaceAll('_', ' ')} by an admin.",
          isError: true);
      return;
    }

    setState(() => _isSendingMessage = true);
    try {
      await _supabase.from('thread_messages').insert({
        'thread_id': _currentThreadData.id,
        'sender_id': _currentAdminId!,
        'sender_role': 'admin',
        'message_content': messageText,
      });
      if (mounted) {
        _messageController.clear();
      }
    } catch (e) {
      print("Admin: Error sending reply: $e");
      if (mounted) {
        _showFeedback("Failed to send reply: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  Future<void> _updateThreadStatusOnServer(String newStatus) async {
    if (_isUpdatingStatus || newStatus == _currentThreadData.status) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final updatedThreadData = await _supabase
          .from('support_threads')
          .update({
        'status': newStatus,
        'is_read_by_admin': true,
      })
          .eq('id', _currentThreadData.id)
          .select()
          .single();

      if (mounted) {
        setState(() {
          _currentThreadData = SupportThread.fromMap(updatedThreadData);
        });
        _showFeedback('Thread status updated to "$newStatus".');
      }
    } catch (e) {
      print("Admin: Error updating ticket status: $e");
      if (mounted) {
        _showFeedback('Failed to update status: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _scrollToBottom({int milliseconds = 300}) {
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _adminThreadMessagesChannel?.unsubscribe(); // Correct way to clean up RealtimeChannel
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildAdminMessageBubble(ThreadMessage message, ThemeData theme) {
    final bool isAdminSender = message.senderRole == 'admin';
    final bool isThisAdmin =
        isAdminSender && message.senderId == _currentAdminId;
    final String senderNameDisplay = isAdminSender
        ? (isThisAdmin
        ? (_currentAdminUsername ?? "Me")
        : (message.senderUsername ?? "Support"))
        : (message.senderUsername ?? "User");

    return Align(
      alignment: isAdminSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
            color: isAdminSender
                ? (isThisAdmin
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.tertiaryContainer)
                : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isAdminSender
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isAdminSender
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]),
        child: Column(
          crossAxisAlignment:
          isAdminSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isThisAdmin || !isAdminSender)
              Padding(
                padding: const EdgeInsets.only(bottom: 3.0),
                child: Text(
                  senderNameDisplay,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: (isAdminSender
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSecondaryContainer)
                        .withOpacity(0.85),
                  ),
                ),
              ),
            SelectableText(
              message.messageContent,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: isAdminSender
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSecondaryContainer,
                  height: 1.4),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat.jm().format(message.createdAt.toLocal()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: (isAdminSender
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSecondaryContainer)
                    .withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canAdminActuallyReply = !(_currentThreadData.status
        .toLowerCase()
        .contains('closed_by_admin') ||
        _currentThreadData.status
            .toLowerCase()
            .contains('resolved_by_admin'));

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _currentThreadData.subject ??
                'Thread: ${_currentThreadData.id.substring(0, 8)}',
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingInitialMessages ||
                _isSendingMessage ||
                _isUpdatingStatus
                ? null
                : _initializeAndFetchMessages,
            tooltip: 'Refresh Conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _currentThreadData.status,
                      items: _availableStatuses.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((e) => e[0].toUpperCase() + e.substring(1))
                                .join(' '),
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _isUpdatingStatus
                          ? null
                          : (String? newStatus) {
                        if (newStatus != null &&
                            newStatus != _currentThreadData.status) {
                          _updateThreadStatusOnServer(newStatus);
                        }
                      },
                      hint: const Text("Set Status"),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text('User: ${widget.thread.userId.substring(0, 8)}...',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: (_isLoadingInitialMessages && _messages.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "No messages in this thread yet.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  vertical: 8.0, horizontal: 4.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                bool showDateHeader = false;
                if (index == 0) {
                  showDateHeader = true;
                } else {
                  final prevMessage = _messages[index - 1];
                  if (!DateUtils.isSameDay(
                      message.createdAt, prevMessage.createdAt)) {
                    showDateHeader = true;
                  }
                }
                return Column(
                  children: [
                    if (showDateHeader)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16.0),
                        child: Text(
                          DateFormat.yMMMMd()
                              .format(message.createdAt.toLocal()),
                          style: theme.textTheme.labelMedium
                              ?.copyWith(
                              color: theme.hintColor
                                  .withOpacity(0.8),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    _buildAdminMessageBubble(message, theme),
                  ],
                );
              },
            ),
          ),
          if (canAdminActuallyReply)
            Container(
              padding: EdgeInsets.only(
                  left: 12.0,
                  right: 8.0,
                  top: 8.0,
                  bottom: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 8.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border:
                Border(top: BorderSide(color: theme.dividerColor, width: 0.7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Type your reply as admin...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 10.0),
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                      onSubmitted: (_) =>
                      _isSendingMessage ? null : _sendAdminReply(),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  _isSendingMessage
                      ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                      : IconButton(
                    icon: Icon(Icons.send_rounded,
                        color: theme.colorScheme.primary, size: 28),
                    onPressed: _sendAdminReply,
                    padding: const EdgeInsets.all(12.0),
                    tooltip: 'Send Reply',
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              color: theme.cardColor,
              child: Text(
                "This thread is currently ${_currentThreadData.status.toLowerCase().replaceAll('_', ' ')}. No further admin replies allowed unless status changes.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic, color: theme.hintColor),
              ),
            ),
        ],
      ),
    );
  }
}


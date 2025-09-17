// lib/screens/support_thread_detail_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; // <<< ADD THIS
import 'dart:io' show Platform; // Keep for mobile
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';

import '../models/support_thread_model.dart';
import '../models/thread_message_model.dart';

const uuid = Uuid();

class SupportThreadDetailScreen extends StatefulWidget {
  final SupportThread thread;

  const SupportThreadDetailScreen({super.key, required this.thread});

  @override
  State<SupportThreadDetailScreen> createState() => _SupportThreadDetailScreenState();
}

class _SupportThreadDetailScreenState extends State<SupportThreadDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingMessage = false;
  bool _isUpdatingThreadStatus = false;

  late SupportThread _currentThread;
  String? _currentUserId;
  String? _currentUserUsername;

  StreamSubscription? _messagesStreamSubscription; // Not directly used in the current setup with onPostgresChanges
  List<ThreadMessage> _messages = [];
  bool _isLoadingInitialMessages = true;
  RealtimeChannel? _threadMessagesChannel;

  @override
  void initState() {
    super.initState();
    _currentThread = widget.thread;
    _currentUserId = _supabase.auth.currentUser?.id;
    _fetchCurrentUserProfile();
    _initializeAndFetchMessages();
    _markThreadAsReadByUser();
  }

  // MODIFIED _showFeedback
  void _showFeedback(String message, {bool isError = false, BuildContext? contextForSnackBar}) {
    if (!mounted) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Fluttertoast.showToast(
          msg: message,
          toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: isError ? Colors.red.shade700 : null,
          textColor: Colors.white);
    } else {
      // Web or other desktop platforms
      print("Feedback (${isError ? 'ERROR' : 'INFO'}): $message");
      final currentContext = contextForSnackBar ?? context;
      if (mounted && currentContext.findRenderObject() != null && currentContext.mounted) { // Check if context is still valid
        ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: isError ? Theme.of(currentContext).colorScheme.error : null));
      }
    }
  }

  Future<void> _fetchCurrentUserProfile() async {
    if (_currentUserId == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', _currentUserId!)
          .single();
      if (mounted) {
        setState(() {
          _currentUserUsername = data['username'] as String?;
        });
      }
    } catch (e) {
      print("Error fetching current user profile for chat: $e");
    }
  }

  Future<void> _markThreadAsReadByUser() async {
    if (_currentUserId == null || _currentThread.isReadByUser) return;

    try {
      await _supabase
          .from('support_threads')
          .update({'is_read_by_user': true})
          .eq('id', _currentThread.id)
          .eq('user_id', _currentUserId!); // Ensure user updates only their own thread

      if (mounted) {
        setState(() { // Also update local state to reflect immediately
          _currentThread.isReadByUser = true;
        });
      }
      print("Marked thread ${_currentThread.id} as read by user.");
    } catch (e) {
      print("Error marking thread as read: $e");
    }
  }

  Future<void> _refreshConversation() async {
    if (!mounted) return;
    setState(() => _isLoadingInitialMessages = true); // Indicate loading
    await _initializeAndFetchMessages();
    try {
      final data = await _supabase.from('support_threads').select().eq('id', _currentThread.id).single();
      if(mounted) {
        setState(() => _currentThread = SupportThread.fromMap(data));
      }
    } catch (e) {
      print("Error refreshing thread details: $e");
    }
    if(mounted) setState(() => _isLoadingInitialMessages = false);
  }


  Future<void> _initializeAndFetchMessages() async {
    if (!mounted) return;
    // Set loading true only if messages are empty, to avoid flicker on subsequent calls
    if (_messages.isEmpty) {
      setState(() => _isLoadingInitialMessages = true);
    }

    try {
      final initialData = await _supabase
          .from('thread_messages')
          .select('*, sender_profile:sender_id(username, id)')
          .eq('thread_id', _currentThread.id)
          .order('created_at', ascending: true);

      if (!mounted) return;

      final fetchedMessages = initialData.map((map) {
        final senderProfileData = map['sender_profile'] as Map<String, dynamic>?;
        return ThreadMessage.fromMap(map, senderProfileData: senderProfileData);
      }).toList();

      setState(() {
        _messages = fetchedMessages;
        _isLoadingInitialMessages = false;
      });
      _scrollToBottom(milliseconds: _messages.isEmpty ? 0 : 500); // Scroll only if there are messages

      // _messagesStreamSubscription?.cancel(); // Not used with current onPostgresChanges approach
      await _threadMessagesChannel?.unsubscribe(); // Use await for unsubscribe

      _threadMessagesChannel = _supabase
          .channel('public:thread_messages:thread_id=eq.${_currentThread.id}')
          .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'thread_messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'thread_id', value: _currentThread.id),
        callback: (payload) async {
          final newMessageMap = payload.newRecord;
          if (newMessageMap != null && mounted) {
            // Check if message already exists (e.g. from optimistic update or race condition)
            if (_messages.any((m) => m.id == newMessageMap['id'] as String?)) return;

            Map<String, dynamic>? senderProfileData;
            final senderId = newMessageMap['sender_id'] as String?;
            if (senderId != null) {
              try {
                // Fetch profile for the new message sender
                final profileData = await _supabase.from('profiles').select('username, id').eq('id', senderId).single();
                senderProfileData = profileData;
              } catch (e) { print("Error fetching profile for RT message: $e"); }
            }
            final newMessage = ThreadMessage.fromMap(newMessageMap, senderProfileData: senderProfileData);

            setState(() {
              _messages.add(newMessage);
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Ensure order
            });
            _scrollToBottom();

            // If the new message is not from the current user, mark thread as read
            // and refresh thread details as status/preview might change
            if (newMessage.senderId != _currentUserId) {
              _markThreadAsReadByUser();
              try {
                final threadData = await _supabase.from('support_threads').select().eq('id', _currentThread.id).single();
                if(mounted) setState(() => _currentThread = SupportThread.fromMap(threadData));
              } catch (e) {print("Error refreshing thread details after RT message: $e"); }
            }
          }
        },
      )
          .subscribe((status, err) {
        if (mounted) {
          if (err != null) {
            print('Realtime subscription error for thread_messages: $err');
            _showFeedback('Connection issue with messages. Try refreshing.', isError: true, contextForSnackBar: context);
          } else {
            print('Realtime subscription status for thread_messages: $status');
          }
        }
      });

    } catch (e) {
      print('Error initializing messages: $e');
      if (mounted) {
        setState(() => _isLoadingInitialMessages = false);
        _showFeedback("Error loading messages. $e", isError: true, contextForSnackBar: context);
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSendingMessage || _currentUserId == null) return;

    if (_currentThread.status.toLowerCase().contains('closed') || _currentThread.status.toLowerCase().contains('resolved')) {
      _showFeedback("This ticket is ${_currentThread.status.toLowerCase().replaceAll('_', ' ')} and cannot be replied to.", isError: true, contextForSnackBar: context);
      return;
    }

    setState(() => _isSendingMessage = true);

    final tempOptimisticId = uuid.v4(); // Temporary ID for optimistic update
    final optimisticMessage = ThreadMessage(
      id: tempOptimisticId, // Use temp ID
      threadId: _currentThread.id,
      senderId: _currentUserId!,
      senderRole: 'user', // Assuming user is sending
      messageContent: messageText,
      createdAt: DateTime.now(),
      senderUsername: _currentUserUsername ?? "You",
    );

    if (mounted) {
      setState(() {
        _messages.add(optimisticMessage);
        _messageController.clear();
      });
      _scrollToBottom();
    }

    try {
      final response = await _supabase.from('thread_messages').insert({
        'thread_id': _currentThread.id,
        'sender_id': _currentUserId!,
        'sender_role': 'user',
        'message_content': messageText,
      }).select().single(); // select the inserted row to get the real ID

      final serverMessageMap = response as Map<String, dynamic>;

      if (mounted) {
        // Remove optimistic message and add the one from server with real ID
        setState(() {
          _messages.removeWhere((m) => m.id == tempOptimisticId);
          // The Realtime listener should ideally pick this up, but this ensures it's there
          // if Realtime is slow or if we want to ensure the sender_profile is pre-fetched for it
          // For simplicity, we'll let Realtime handle adding it, or uncomment below if needed.
          // Map<String, dynamic>? senderProfileDataForServerMsg;
          // if (_currentUserId != null) {
          //    senderProfileDataForServerMsg = {'id': _currentUserId, 'username': _currentUserUsername};
          // }
          // final serverMessage = ThreadMessage.fromMap(serverMessageMap, senderProfileData: senderProfileDataForServerMsg);
          // if (!_messages.any((m) => m.id == serverMessage.id)) {
          //   _messages.add(serverMessage);
          //   _messages.sort((a,b) => a.createdAt.compareTo(b.createdAt));
          // }
        });
        // The realtime listener should ideally pick up the new message.
        // If not, a refresh of thread details might be needed if triggers update thread status/preview.
        // Fetching thread again to update preview/status
        final threadData = await _supabase.from('support_threads').select().eq('id', _currentThread.id).single();
        if(mounted) setState(() => _currentThread = SupportThread.fromMap(threadData));

      }
    } catch (e) {
      print("Error sending message: $e");
      if(mounted) {
        _showFeedback("Failed to send message. Please try again.", isError: true, contextForSnackBar: context);
        // Remove optimistic message on failure
        setState(() {
          _messages.removeWhere((m) => m.id == tempOptimisticId);
          _messageController.text = messageText; // Restore text
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  void _scrollToBottom({int milliseconds = 300}) {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(!mounted || !_scrollController.hasClients || !_scrollController.position.hasContentDimensions) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  Future<void> _updateThreadStatusOnServer(String newStatus) async {
    if (_currentUserId == null || _isUpdatingThreadStatus) return;
    setState(() => _isUpdatingThreadStatus = true);

    try {
      final data = await _supabase
          .from('support_threads')
          .update({
        'status': newStatus,
        // 'updated_at': DateTime.now().toIso8601String(), // Let trigger handle this
        // 'is_read_by_user': true, // User is acting, so mark as read by them
      })
          .eq('id', _currentThread.id)
          .eq('user_id', _currentUserId!) // Ensure only owner can update their status
          .select()
          .single();

      if (mounted) {
        setState(() {
          _currentThread = SupportThread.fromMap(data);
          _isUpdatingThreadStatus = false;
        });
        _showFeedback('Ticket marked as "${_currentThread.status.replaceAll('_', ' ')}".', contextForSnackBar: context);
        // Potentially pop if resolved, or let user navigate back.
        // if (newStatus.contains('resolved') || newStatus.contains('closed')) {
        //   Navigator.of(context).pop(true); // Pop and signal update
        // }
      }
    } catch (e) {
      print("Error updating ticket status on server: $e");
      if(mounted) {
        setState(() => _isUpdatingThreadStatus = false);
        _showFeedback('Failed to update ticket status. Please try again. Error: ${e.toString()}', isError: true, contextForSnackBar: context);
      }
    }
  }

  @override
  void dispose() {
    // Cancel subscriptions and dispose controllers
    // _messagesStreamSubscription?.cancel(); // Not directly used now
    _threadMessagesChannel?.unsubscribe().catchError((e) => print("Error unsubscribing channel: $e"));
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(ThreadMessage message, ThemeData theme) {
    final bool isMe = message.senderId == _currentUserId;
    final String senderNameDisplay = isMe
        ? (_currentUserUsername ?? "You")
        : (message.senderUsername ?? (message.senderRole == 'admin' ? 'Support Team' : 'User...'));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
            color: isMe ? theme.colorScheme.primary : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3.0),
                child: Text(
                  senderNameDisplay,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondaryContainer).withOpacity(0.85),
                  ),
                ),
              ),
            SelectableText(
              message.messageContent,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondaryContainer,
                  height: 1.4
              ),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat.jm().format(message.createdAt.toLocal()), // Show only time
              style: theme.textTheme.labelSmall?.copyWith(
                color: (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondaryContainer).withOpacity(0.65),
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
    final bool canUserReply = !(_currentThread.status.toLowerCase() == 'closed_by_user' ||
        _currentThread.status.toLowerCase() == 'closed_by_admin' ||
        _currentThread.status.toLowerCase() == 'resolved_by_user' ||
        _currentThread.status.toLowerCase() == 'resolved_by_admin');

    final bool canUserCloseOrResolve = canUserReply &&
        (_currentThread.status.toLowerCase() != 'resolved_by_user' &&
            _currentThread.status.toLowerCase() != 'closed_by_user');

    return Scaffold(
      appBar: AppBar( // <<< ENSURE AppBar IS PRESENT FOR BACK NAVIGATION
        title: Text(_currentThread.subject ?? 'Thread #${_currentThread.id.substring(0, 8)}', overflow: TextOverflow.ellipsis),
        backgroundColor: theme.colorScheme.primary, // Optional: Style consistency
        foregroundColor: theme.colorScheme.onPrimary, // Optional
        actions: [
          if ((_isLoadingInitialMessages && _messages.isEmpty) || _isUpdatingThreadStatus) // Show loader if initially loading OR updating status
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _isLoadingInitialMessages || _isSendingMessage ? null : _refreshConversation,
              tooltip: 'Refresh Conversation',
            ),
        ],
      ),
      body: Column(
        children: [
          Container( // Status Bar
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
                Text(
                  _currentThread.status.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' '),
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _currentThread.status.toLowerCase().contains('pending_admin')
                          ? theme.colorScheme.tertiary
                          : (_currentThread.status.toLowerCase().contains('pending_user')
                          ? theme.colorScheme.primary
                          : (_currentThread.status.toLowerCase().contains('closed') || _currentThread.status.toLowerCase().contains('resolved')
                          ? Colors.green.shade700
                          : theme.colorScheme.secondary))
                  ),
                ),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: theme.hintColor),
                    const SizedBox(height: 16),
                    Text(
                      "No messages in this thread yet.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor),
                    ),
                    if(canUserReply)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Send a message to start the conversation.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        ),
                      ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                bool showDateHeader = false;
                if (index == 0) {
                  showDateHeader = true;
                } else {
                  final prevMessage = _messages[index - 1];
                  if (!DateUtils.isSameDay(message.createdAt.toLocal(), prevMessage.createdAt.toLocal())) {
                    showDateHeader = true;
                  }
                }
                return Column(
                  children: [
                    if (showDateHeader)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          DateFormat.yMMMMd().format(message.createdAt.toLocal()),
                          style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor.withOpacity(0.8), fontWeight: FontWeight.w600),
                        ),
                      ),
                    _buildMessageBubble(message, theme),
                  ],
                );
              },
            ),
          ),
          if (canUserReply)
            _buildMessageInputField(theme)
          else
            Container(
              padding: const EdgeInsets.all(16.0),
              color: theme.cardColor,
              child: Text(
                "This thread is now ${_currentThread.status.toLowerCase().replaceAll('_',' ')}. You can no longer send messages.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.hintColor),
              ),
            ),

          if (canUserCloseOrResolve && !_isUpdatingThreadStatus)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
              child: Center( // Center the button
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark as Resolved by Me'),
                  onPressed: () => _updateThreadStatusOnServer('resolved_by_user'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
                  ),
                ),
              ),
            ),
          if (_isUpdatingThreadStatus)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
            )
        ],
      ),
    );
  }

  Widget _buildMessageInputField(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
          left: 12.0,
          right: 8.0,
          top: 8.0,
          bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 4.0 : 12.0 // Adjust bottom padding
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 2,
            color: theme.shadowColor.withOpacity(0.1),
          )
        ],
        // border: Border(top: BorderSide(color: theme.dividerColor, width: 0.7)), // Optional: keep border or use shadow
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end, // Align items to the bottom if TextField grows
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0), // Adjusted padding
                filled: true,
                fillColor: Colors.transparent, // Ensure it's transparent to show container color
              ),
              onSubmitted: (_) => _isSendingMessage ? null : _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          _isSendingMessage
              ? const Padding(
            padding: EdgeInsets.all(12.0), // Match IconButton padding
            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
              : IconButton(
            icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary, size: 28),
            onPressed: _sendMessage,
            padding: const EdgeInsets.all(12.0),
            tooltip: 'Send Message',
          ),
        ],
      ),
    );
  }
}

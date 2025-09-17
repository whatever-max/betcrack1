// lib/screens/create_new_thread_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
// Import new models if needed, though this screen primarily inserts
// import '../models/support_thread_model.dart';
// import '../models/thread_message_model.dart';

class CreateNewThreadScreen extends StatefulWidget {
  const CreateNewThreadScreen({super.key});

  @override
  State<CreateNewThreadScreen> createState() => _CreateNewThreadScreenState();
}

class _CreateNewThreadScreenState extends State<CreateNewThreadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController(); // Optional subject
  final _messageController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  void _showFeedback(String message, {bool isError = false, BuildContext? contextForSnackBar}) {
    if (!mounted) return;
    if (Platform.isAndroid || Platform.isIOS) {
      Fluttertoast.showToast(
          msg: message,
          toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: isError ? Colors.red.shade700 : null,
          textColor: Colors.white);
    } else {
      print("Feedback (${isError ? 'ERROR' : 'INFO'}): $message");
      if (contextForSnackBar != null && mounted) {
        ScaffoldMessenger.of(contextForSnackBar).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: isError ? Theme.of(contextForSnackBar).colorScheme.error : null));
      }    }
  }

  Future<void> _createNewThread() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      _showFeedback("You need to be logged in.", isError: true, contextForSnackBar: context);
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the Support Thread
      final threadResponse = await _supabase.from('support_threads').insert({
        'user_id': currentUser.id,
        'subject': _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
        'status': 'pending_admin_reply', // Initially pending admin reply as user sent first message
        'last_message_preview': _messageController.text.trim().length > 100
            ? '${_messageController.text.trim().substring(0, 97)}...'
            : _messageController.text.trim(),
        'is_read_by_user': true, // User just sent it
        'is_read_by_admin': false,
      }).select('id').single(); // Get the ID of the newly created thread

      final newThreadId = threadResponse['id'] as String?;
      if (newThreadId == null) {
        throw Exception('Failed to create support thread.');
      }

      // 2. Insert the first message into the thread
      await _supabase.from('thread_messages').insert({
        'thread_id': newThreadId,
        'sender_id': currentUser.id,
        'sender_role': 'user',
        'message_content': _messageController.text.trim(),
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _messageController.clear();
          _subjectController.clear();
        });
        _showFeedback("Support ticket created successfully!", contextForSnackBar: context);
        Navigator.pop(context, true); // Pop and indicate success to refresh list on previous screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("Error creating support thread: $e");
      String errorMessage = "Failed to create ticket. Please try again.";
      if (e is PostgrestException) errorMessage = "Failed: ${e.message}";
      _showFeedback(errorMessage, isError: true, contextForSnackBar: context);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Support Ticket'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject (Optional)',
                  hintText: 'e.g., Issue with login, Payment query',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Your Message',
                  hintText: 'Please describe your issue or question in detail...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                maxLength: 1000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter your message.';
                  if (value.trim().length < 10) return 'Message should be at least 10 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send_rounded),
                label: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Submit Ticket'),
                onPressed: _isLoading ? null : _createNewThread,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// lib/screens/send_support_sms_screen.dart
import 'dart:io' show Platform; // <<< ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SendSupportSmsScreen extends StatefulWidget {
  const SendSupportSmsScreen({super.key});

  @override
  State<SendSupportSmsScreen> createState() => _SendSupportSmsScreenState();
}

class _SendSupportSmsScreenState extends State<SendSupportSmsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Helper function for showing toast or print
  void _showFeedback(String message, {bool isError = false, BuildContext? contextForSnackBar}) {
    if (!mounted) return;

    if (Platform.isAndroid || Platform.isIOS) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: isError ? Colors.red.shade700 : null, // Ensure a good error color
        textColor: Colors.white,
      );
    } else {
      print("Feedback (${isError ? 'ERROR' : 'INFO'}): $message");
      if (contextForSnackBar != null) { // Use ScaffoldMessenger if context is available
        ScaffoldMessenger.of(contextForSnackBar).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Theme.of(contextForSnackBar).colorScheme.error : null,
          ),
        );
      }
    }
  }


  Future<void> _sendSupportMessage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      _showFeedback("You need to be logged in to send a message.", isError: true, contextForSnackBar: context);
      if (mounted) Navigator.pop(context);
      return;
    }

    String userPhone = currentUser.phone ?? ""; // Default to empty string if null

    if (userPhone.isEmpty) {
      setState(() => _isLoading = true); // Show loading while fetching profile
      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('phone')
            .eq('id', currentUser.id)
            .single();
        userPhone = profileResponse['phone'] as String? ?? 'N/A'; // N/A if still not found
      } catch (e) {
        print("Error fetching user phone from profile: $e");
        setState(() => _isLoading = false); // Stop loading on error
        _showFeedback("Could not retrieve your phone. Please update your profile or try again.", isError: true, contextForSnackBar: context);
        return; // Prevent sending if phone fetch fails and is crucial
      }
      // If still N/A after fetch, you might want to handle it (e.g., prevent sending)
      if (userPhone == 'N/A') {
        setState(() => _isLoading = false);
        _showFeedback("Your phone number is not available. Please update your profile.", isError: true, contextForSnackBar: context);
        return;
      }
    }

    setState(() => _isLoading = true); // Ensure loading is true before Supabase call

    try {
      await _supabase.from('support_messages').insert({
        'user_id': currentUser.id,
        'user_phone': userPhone,
        'message_content': _messageController.text.trim(),
        'status': 'pending',
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _messageController.clear();
        });
        _showFeedback("Message sent! Our support team will get back to you.", contextForSnackBar: context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("Error sending support message: $e");
      String errorMessage = "Failed to send message. Please try again.";
      if (e is PostgrestException) {
        errorMessage = "Failed to send message: ${e.message}";
      }
      _showFeedback(errorMessage, isError: true, contextForSnackBar: context);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Support'),
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
              Text(
                'Write your message to our support team:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Your Message',
                  hintText: 'Please describe your issue or question...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your message.';
                  }
                  if (value.trim().length < 10) {
                    return 'Message should be at least 10 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox.shrink() // Hide icon when loading
                    : const Icon(Icons.send_outlined),
                label: _isLoading
                    ? const SizedBox(
                    height: 24, // Consistent height for loader
                    width: 24,  // Consistent width for loader
                    child: CircularProgressIndicator(
                      color: Colors.white, // Or theme.colorScheme.onPrimary
                      strokeWidth: 3, // Adjust stroke
                    ))
                    : const Text('Send Message'),
                onPressed: _isLoading ? null : _sendSupportMessage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  minimumSize: const Size(double.infinity, 50), // Ensure button has good height
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// lib/admin/screens/support_message_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../../models/support_message_model.dart'; // Ensure this points to the file with "class SupportMessage"

class SupportMessageDetailScreen extends StatefulWidget {
  final String messageId;

  const SupportMessageDetailScreen({super.key, required this.messageId});

  @override
  State<SupportMessageDetailScreen> createState() =>
      _SupportMessageDetailScreenState();
}

class _SupportMessageDetailScreenState
    extends State<SupportMessageDetailScreen> {
  final _supabase = Supabase.instance.client;
  SupportMessage? _message; // <<<--- CORRECTED: Was SupportMessageAdminView?
  bool _isLoading = true;
  String? _loadingError;

  final _replyController = TextEditingController();
  // bool _isReplying = false; // Renamed to _isProcessingReply in my last version for clarity
  bool _isProcessingReply = false;
  String _selectedStatus = '';
  final _formKey = GlobalKey<FormState>(); // Added previously, ensure it's here

  @override
  void initState() {
    super.initState();
    _fetchMessageDetails();
  }

  Future<void> _fetchMessageDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingError = null;
    });
    try {
      final response = await _supabase
          .from('support_messages')
          .select('*, profiles(email, username)') // Example of joining
          .eq('id', widget.messageId)
          .single();

      String? userEmail;
      if (response['profiles'] != null) {
        userEmail = response['profiles']['email'] ?? response['profiles']['username'];
      }

      if (mounted) {
        setState(() {
          // <<<--- CORRECTED: Was SupportMessageAdminView.fromMap
          _message = SupportMessage.fromMap(response, userEmail: userEmail);
          _selectedStatus = _message?.status ?? 'pending';
          _replyController.text = _message?.adminReply ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching message details: $e");
        setState(() {
          _isLoading = false;
          _loadingError = "Failed to load message: ${e.toString()}";
        });
        Fluttertoast.showToast(msg: _loadingError!);
      }
    }
  }

  // Combined reply and status update logic (from my previous suggestion)
  Future<void> _sendOrUpdateReplyAndStatus() async {
    if (_formKey.currentState?.validate() == false) {
      if (_replyController.text.trim().isEmpty && _selectedStatus == 'replied_by_admin') {
        Fluttertoast.showToast(msg: "Reply cannot be empty if status is 'Replied'.");
        return;
      }
      // If other validations fail, they'll show in the TextFormField
    }
    if (_message == null) return;
    if (_isProcessingReply) return;

    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) {
      Fluttertoast.showToast(msg: "Admin not authenticated.");
      return;
    }

    setState(() => _isProcessingReply = true);

    Map<String, dynamic> updateData = {
      'status': _selectedStatus,
    };

    if (_replyController.text.trim().isNotEmpty) {
      updateData['admin_reply'] = _replyController.text.trim();
      updateData['admin_id_replied'] = adminId;
      updateData['replied_at'] = DateTime.now().toIso8601String();
      // If replying for the first time (status was pending), auto-change to replied_by_admin
      if (_message!.status == 'pending' && _selectedStatus == 'pending') { // Check if user intended to keep it pending
        updateData['status'] = 'replied_by_admin';
        // _selectedStatus = 'replied_by_admin'; // Update local state if needed immediately, or rely on pop & refresh
      }
    } else if (_selectedStatus == 'replied_by_admin' && _message!.status != 'replied_by_admin') {
      // If status is newly set to replied_by_admin but no reply text.
      Fluttertoast.showToast(msg: "Reply text cannot be empty if setting status to 'Replied by Admin'.");
      if (mounted) setState(() => _isProcessingReply = false);
      return;
    }


    try {
      await _supabase.from('support_messages').update(updateData).eq('id', widget.messageId);

      Fluttertoast.showToast(msg: "Message updated successfully!");
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to update message: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isProcessingReply = false);
    }
  }

  // Your original _updateStatusOnly if you still need a separate button for it.
  // Consider if the combined function _sendOrUpdateReplyAndStatus is sufficient.
  Future<void> _updateStatusOnly() async {
    if (_message == null || _selectedStatus == _message!.status) {
      Fluttertoast.showToast(msg: "Status is already $_selectedStatus or no message loaded.");
      return;
    }
    if (_replyController.text.trim().isNotEmpty && _selectedStatus != 'replied_by_admin') {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text("Confirm Status Update"),
        content: const Text("You have text in the reply field. Updating status only will discard this reply text. Continue?"),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: ()=> Navigator.pop(context, true), child: const Text("Discard & Update")),
        ],
      ));
      if (confirm != true) return;
    }


    if (_isProcessingReply) return;
    setState(() => _isProcessingReply = true);

    try {
      await _supabase.from('support_messages').update({
        'status': _selectedStatus,
        // If updating status only, explicitly clear reply fields if it was replied_by_admin but now isn't.
        // Or, ensure admin knows reply text stays if not changing from/to replied_by_admin.
        // This logic can get complex; the combined function is often simpler.
      }).eq('id', widget.messageId);

      Fluttertoast.showToast(msg: "Status updated to $_selectedStatus!");
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to update status: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isProcessingReply = false);
    }
  }


  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> statusOptions = ['pending', 'replied_by_admin', 'resolved', 'closed_by_user', 'closed_by_admin'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Loading Message...')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadingError != null || _message == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_loadingError ?? "Message not found.", style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height:10),
                  ElevatedButton(onPressed: _fetchMessageDetails, child: const Text("Retry"))
                ]
            ),
          ),
        ),
      );
    }

    // Now _message is of type SupportMessage?
    return Scaffold(
      appBar: AppBar(
        title: Text('Message Details', style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0,16,16,60),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From User:', style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Flexible(child: Text('ID: ${_message!.userId.substring(0,8)}... ${_message!.userEmail != null ? "(${_message!.userEmail})" : ""}', style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis,)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(_message!.userPhone ?? "N/A", style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Received: ${DateFormat.yMMMMEEEEd().add_jm().format(_message!.createdAt.toLocal())}', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                      const Divider(height: 24, thickness: 0.5),
                      Text('User Message Content:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8)
                        ),
                        child: SelectableText(_message!.messageContent, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),

              if (_message!.adminReply != null && _message!.adminReply!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Your Previous Reply:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  color: theme.colorScheme.primaryContainer.withOpacity(0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(_message!.adminReply!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, height: 1.4)),
                        const SizedBox(height: 10),
                        if (_message!.repliedAt != null)
                          Align(
                              alignment: Alignment.centerRight,
                              child: Text('Replied on: ${DateFormat.yMMMd().add_jm().format(_message!.repliedAt!.toLocal())}', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor))
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Text('Your Reply / Actions:', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _replyController,
                decoration: InputDecoration(
                  labelText: 'Type your response here...',
                  hintText: 'Be clear and concise.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  alignLabelWithHint: true,
                  helperText: "Leave empty if only updating status (unless new status is 'Replied').",
                ),
                maxLines: 5,
                maxLength: 1000,
                // validator: (value) { // Logic moved to button press
                //   if (_selectedStatus == 'replied_by_admin' && (value == null || value.trim().isEmpty)) {
                //     return 'Reply cannot be empty if status is "Replied".';
                //   }
                //   return null;
                // },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Set Message Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.flag_outlined),
                ),
                value: _selectedStatus,
                items: statusOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ')),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedStatus = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isProcessingReply ? const SizedBox.shrink() : const Icon(Icons.send_and_archive_outlined),
                label: _isProcessingReply
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save Changes (Reply & Status)'),
                // Use the combined function here
                onPressed: _isProcessingReply ? null : _sendOrUpdateReplyAndStatus,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(height:10),
              // If you still want the "Update Status Only" button, uncomment and ensure its logic is sound
              // Tooltip(
              //   message: "Updates status only. Current reply text will be ignored if not relevant to new status.",
              //   child: TextButton.icon(
              //     icon: Icon(Icons.published_with_changes_outlined, color: Colors.blueAccent),
              //     label: Text("Update Status Only"),
              //     onPressed: _isProcessingReply ? null : _updateStatusOnly,
              //     style: TextButton.styleFrom(minimumSize: Size(double.infinity, 40)),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

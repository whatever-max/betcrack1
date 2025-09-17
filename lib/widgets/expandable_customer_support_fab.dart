// lib/widgets/expandable_customer_support_fab.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'action_button.dart'; // Assuming this is your custom ActionButton widget
// Import new screens for threaded support
// Make sure these paths are correct for your project structure
import '../screens/create_new_thread_screen.dart';
import '../screens/my_support_threads_screen.dart';

class ExpandableCustomerSupportFab extends StatefulWidget {
  // <<< ADD THESE CALLBACKS FOR INTEGRATION >>>
  final VoidCallback? onNewTicketPressed; // Callback to navigate to create thread screen
  final VoidCallback? onViewTicketsPressed; // Callback to navigate to view threads screen

  const ExpandableCustomerSupportFab({
    super.key,
    this.onNewTicketPressed, // Initialize
    this.onViewTicketsPressed, // Initialize
  });

  @override
  State<ExpandableCustomerSupportFab> createState() =>
      _ExpandableCustomerSupportFabState();
}

class _ExpandableCustomerSupportFabState
    extends State<ExpandableCustomerSupportFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _open = false;

  // Contact numbers - ensure these are correct
  final String _supportPhoneNumber = '+255689100257'; // Example: Tanzania
  final String _whatsappNumber = '+255689100257';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _animationController,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _launchWhatsApp() async {
    final String numberForUrl = _whatsappNumber.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    // Using wa.me link is generally more reliable
    final Uri whatsappUri = Uri.parse('https://wa.me/$numberForUrl?text=${Uri.encodeComponent("Hello BetCrack Support!")}');

    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp. Is it installed?')),
        );
      }
    }
    _toggle(); // Close FAB after action
  }

  Future<void> _launchDialer() async {
    final Uri dialerUri = Uri(scheme: 'tel', path: _supportPhoneNumber);
    if (!await launchUrl(dialerUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer.')),
        );
      }
    }
    _toggle(); // Close FAB after action
  }

  // --- MODIFIED: Use the callback from widget props for New Ticket ---
  void _handleNewTicketPressed() {
    _toggle(); // Close FAB menu
    // If the callback is provided by HomeScreen, use it for navigation
    // This allows HomeScreen to handle the navigation and potential refresh logic.
    widget.onNewTicketPressed?.call();
  }

  // --- NEW: Use the callback from widget props for View Tickets ---
  void _handleViewTicketsPressed() {
    _toggle(); // Close FAB menu
    widget.onViewTicketsPressed?.call();
  }


  // Your existing _buildOption using ActionButton
  // Ensure ActionButton's onPressed makes the whole area (icon + label) tappable
  Widget _buildOption(Widget icon, String label, VoidCallback onPressed) {
    return ScaleTransition(
      scale: _expandAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: ActionButton( // Assuming ActionButton handles its own tap well
          icon: icon,
          label: label,
          onPressed: onPressed, // This is key for clickability
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Collapsed options
        if (_open) ...[
          // --- NEW: View My Tickets (if callback is provided) ---
          if (widget.onViewTicketsPressed != null)
            _buildOption(
              const Icon(Icons.history_edu_outlined), // Or Icons.list_alt, Icons.forum_outlined
              'View My Tickets',
              _handleViewTicketsPressed, // Use the new handler
            ),

          // --- MODIFIED: New Support Ticket (if callback is provided) ---
          if (widget.onNewTicketPressed != null)
            _buildOption(
              const Icon(Icons.add_comment_outlined), // Changed icon
              'New Support Ticket',
              _handleNewTicketPressed, // Use the new handler
            ),

          // Kept existing direct contact options
          _buildOption(
            const Icon(Icons.chat_bubble_outline),
            'WhatsApp',
            _launchWhatsApp,
          ),
          _buildOption(
            const Icon(Icons.call_outlined),
            'Call Us',
            _launchDialer,
          ),
        ],
        // Main FAB
        FloatingActionButton(
          heroTag: "mainSupportFab", // Ensure heroTags are unique if multiple FABs on one screen
          backgroundColor: _open ? theme.colorScheme.surfaceVariant : theme.colorScheme.primary,
          foregroundColor: _open ? theme.colorScheme.primary : theme.colorScheme.onPrimary,
          onPressed: _toggle,
          tooltip: _open ? 'Close Support Options' : 'Contact Support',
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _expandAnimation,
          ),
        ),
      ],
    );
  }
}

// lib/widgets/action_button.dart
import 'package:flutter/material.dart';

@immutable
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.onPressed, // Make onPressed required if the whole thing is a button
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed; // Changed from VoidCallback? to VoidCallback
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using Material for InkWell splash effects and proper hit testing area
    return Material(
      color: Colors.transparent, // Important so it doesn't obscure things behind it if not intended
      child: InkWell(
        onTap: onPressed, // The main onPressed for the whole widget
        borderRadius: BorderRadius.circular(25), // Optional: for splash effect shape matching overall look
        child: Padding(
          // Add some padding around the tappable area if needed, or keep it tight
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end, // Align items to the right
            crossAxisAlignment: CrossAxisAlignment.center, // Vertically align items
            children: [
              // Label part
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Adjusted padding
                decoration: BoxDecoration(
                    color: theme.cardColor.withOpacity(0.90), // Slightly less opacity perhaps
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )
                    ]
                ),
                child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith( // Consider labelSmall or bodyMedium
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500
                    )
                ),
              ),
              const SizedBox(width: 10), // Slightly reduced SizedBox

              // Icon part (now just for display, not handling its own tap for action)
              // We make this smaller or style it to look like part of the larger button.
              // Option 1: Using a simple Container with Icon (more customizable)
              Container(
                padding: const EdgeInsets.all(8), // Padding around the icon
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle, // Make it circular
                  // No separate shadow if the InkWell handles visual feedback, or add a subtle one
                ),
                child: IconTheme( // Ensure icon color is consistent
                  data: IconThemeData(
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 20, // Adjust size as needed
                  ),
                  child: icon,
                ),
              ),

              // Option 2: Keep FloatingActionButton.small but ensure its onPressed is null or calls main onPressed
              // FloatingActionButton.small(
              //   heroTag: null, // No heroTag needed if it's not a standalone FAB for page transitions
              //   onPressed: onPressed, // Or make this null and let InkWell handle it. If not null, it makes two tap targets.
              //   backgroundColor: theme.colorScheme.secondaryContainer,
              //   foregroundColor: theme.colorScheme.onSecondaryContainer,
              //   elevation: 0, // Remove elevation if InkWell provides visual feedback
              //   mini: true, // ensure it's small
              //   child: icon,
              // ),
            ],
          ),
        ),
      ),
    );
  }
}


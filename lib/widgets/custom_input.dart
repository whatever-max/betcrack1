// lib/widgets/custom_input.dart
import 'package:flutter/material.dart';

class CustomInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText; // Optional label
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final String? errorText; // For displaying validation errors
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator; // CORRECTED TYPE
  final int? maxLines;

  // REMOVED 'const' because onChanged and validator are not final
  CustomInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.errorText,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    // The InputDecorationTheme from main.dart will apply its styles automatically.
    // We only need to provide the specifics for this instance.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Consistent vertical padding
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)) : null,
          errorText: errorText,
          // Other properties like filled, fillColor, border, focusedBorder, etc.,
          // will be inherited from the InputDecorationTheme in main.dart.
        ),
        onChanged: onChanged,
        validator: validator,
        maxLines: obscureText ? 1 : maxLines,
        style: Theme.of(context).textTheme.bodyLarge, // Ensure input text also uses themed style
      ),
    );
  }
}

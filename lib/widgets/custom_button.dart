// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';

enum CustomButtonType { elevated, text, outlined }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed; // Allow null onPressed to natively disable button
  final bool isLoading;
  final CustomButtonType type;
  final IconData? icon; // Optional icon
  final double? width; // Optional width: null for intrinsic, double.infinity for full, or specific value
  final Color? backgroundColor; // Optional override for button's own background
  final Color? foregroundColor; // Optional override for text/icon color
  final ButtonStyle? style; // Allow full style override if needed

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.type = CustomButtonType.elevated,
    this.icon,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Determine the base style from the theme
    ButtonStyle? baseStyle;
    Color? defaultForegroundColor;
    Color? defaultLoadingIndicatorColor;

    switch (type) {
      case CustomButtonType.elevated:
        baseStyle = theme.elevatedButtonTheme.style;
        defaultForegroundColor = baseStyle?.foregroundColor?.resolve({}) ?? theme.colorScheme.onPrimary;
        defaultLoadingIndicatorColor = defaultForegroundColor;
        break;
      case CustomButtonType.text:
        baseStyle = theme.textButtonTheme.style;
        defaultForegroundColor = baseStyle?.foregroundColor?.resolve({}) ?? theme.colorScheme.primary;
        defaultLoadingIndicatorColor = defaultForegroundColor;
        break;
      case CustomButtonType.outlined:
        baseStyle = theme.outlinedButtonTheme.style;
        defaultForegroundColor = baseStyle?.foregroundColor?.resolve({}) ?? theme.colorScheme.primary;
        defaultLoadingIndicatorColor = defaultForegroundColor;
        break;
    }

    // Prepare button content
    Widget buttonContent = isLoading
        ? SizedBox(
      width: (textTheme.labelLarge?.fontSize ?? 16) * 1.2, // Size relative to text
      height: (textTheme.labelLarge?.fontSize ?? 16) * 1.2,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        color: foregroundColor ?? defaultLoadingIndicatorColor,
      ),
    )
        : Row(
      mainAxisSize: MainAxisSize.min, // Important for Row to fit content
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: textTheme.labelLarge?.fontSize ?? 16, // Icon size matches button text
            color: foregroundColor ?? defaultForegroundColor, // Apply foreground color override
          ),
          const SizedBox(width: 8),
        ],
        Text(label), // Text will inherit style from button's textStyle
      ],
    );

    // Build the specific button type
    Widget button;
    switch (type) {
      case CustomButtonType.text:
        button = TextButton(
          onPressed: effectiveOnPressed,
          style: style ?? baseStyle?.copyWith( // Prioritize explicit style, then theme, then overrides
            backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (backgroundColor != null) return backgroundColor;
              return baseStyle?.backgroundColor?.resolve(states);
            }),
            foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (foregroundColor != null) return foregroundColor;
              return baseStyle?.foregroundColor?.resolve(states);
            }),
            padding: baseStyle?.padding ?? MaterialStateProperty.all<EdgeInsetsGeometry>(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10) // Specific default for text
            ),
            textStyle: baseStyle?.textStyle ?? MaterialStateProperty.all(textTheme.labelLarge),
          ),
          child: buttonContent,
        );
        // For TextButtons, allow intrinsic width by default if `width` is not specified
        return width != null ? SizedBox(width: width, child: button) : button;

      case CustomButtonType.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: style ?? baseStyle?.copyWith(
            backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (backgroundColor != null) return backgroundColor;
              return baseStyle?.backgroundColor?.resolve(states);
            }),
            foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (foregroundColor != null) return foregroundColor;
              return baseStyle?.foregroundColor?.resolve(states);
            }),
            side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
              if (states.contains(MaterialState.disabled)) {
                return baseStyle?.side?.resolve(states); // Keep theme's disabled border
              }
              // You might want to theme the border color based on foregroundColor or a specific theme color
              return BorderSide(color: foregroundColor ?? theme.colorScheme.primary, width: 1.5);
            }),
            padding: baseStyle?.padding ?? MaterialStateProperty.all<EdgeInsetsGeometry>(
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            textStyle: baseStyle?.textStyle ?? MaterialStateProperty.all(textTheme.labelLarge),
          ),
          child: buttonContent,
        );
        break; // break for outlined

      case CustomButtonType.elevated:
      default:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: style ?? baseStyle?.copyWith(
            backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (backgroundColor != null) return backgroundColor;
              return baseStyle?.backgroundColor?.resolve(states); // Usually from colorScheme.primary via theme
            }),
            foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (foregroundColor != null) return foregroundColor;
              return baseStyle?.foregroundColor?.resolve(states); // Usually from colorScheme.onPrimary via theme
            }),
            padding: baseStyle?.padding ?? MaterialStateProperty.all<EdgeInsetsGeometry>(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            textStyle: baseStyle?.textStyle ?? MaterialStateProperty.all(textTheme.labelLarge),
          ),
          child: buttonContent,
        );
        break; // break for elevated
    }

    // Apply width wrapper if width is specified and it's not a TextButton handled above
    if (width != null && type != CustomButtonType.text) {
      return SizedBox(width: width, child: button);
    } else if (width == double.infinity && type != CustomButtonType.text) { // Ensure full width for elevated/outlined if desired
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

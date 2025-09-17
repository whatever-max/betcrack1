import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Or your preferred toast/snackbar

// Define an enum for the different stages of the password reset process
enum ResetPasswordPhoneStage {
  enterPhone,
  enterOtp,
  setNewPassword,
}

class ForgotPasswordPhoneScreen extends StatefulWidget {
  static const String routeName = '/forgot-password-phone';

  const ForgotPasswordPhoneScreen({super.key});

  @override
  State<ForgotPasswordPhoneScreen> createState() =>
      _ForgotPasswordPhoneScreenState();
}

class _ForgotPasswordPhoneScreenState extends State<ForgotPasswordPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  ResetPasswordPhoneStage _currentStage = ResetPasswordPhoneStage.enterPhone;
  String _fullPhoneNumber = ''; // To store the E.164 formatted number

  // Example country code - you might want to make this selectable
  // Or infer from user's locale if possible and reliable for your target audience.
  // For Tanzania, the country code is +255.
  // We'll prepend this. Users should enter numbers like 07... or 7...
  final String _countryCode = '+255';

  // --- Helper to format phone number to E.164 ---
  String _formatPhoneNumber(String phone) {
    String cleanedPhone = phone.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = cleanedPhone.substring(1); // Remove leading 0
    }
    if (cleanedPhone.length == 9) { // Common length for TZ numbers after 0
      return _countryCode + cleanedPhone;
    }
    // Add more specific validation for your target region if needed
    return _countryCode + cleanedPhone; // Fallback, might be incorrect
  }


  // --- Stage 1: Send OTP ---
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    _fullPhoneNumber = _formatPhoneNumber(_phoneController.text.trim());

    try {
      // For password reset via phone, Supabase typically sends an OTP when you
      // call auth.signInWithOtp() or auth.signUp() with a phone number.
      // Or, if using a dedicated password reset OTP flow, it would be resetPasswordForEmail with phone
      // However, the standard `resetPasswordForEmail` does not directly take a phone number.
      // The common flow is:
      // 1. User provides phone number.
      // 2. Send an OTP to that phone for verification (e.g., using `signInWithOtp` with type `sms` or `phone_change`)
      //    (This step implicitly verifies the user owns the phone).
      // 3. After OTP verification, allow the user to update their password.

      // We'll use signInWithOtp to send the OTP. This is also used for phone login/signup.
      // The `type` can be 'sms'.
      // If the user already exists, it will send an OTP.
      // Supabase's `updateUser` requires the user to be authenticated to change password.
      // So, the OTP verification step effectively authenticates them for this session.

      // IMPORTANT: Ensure your Supabase project has an SMS provider configured!
      await _supabase.auth.signInWithOtp(
        phone: _fullPhoneNumber,
        // smsTemplate: 'your-custom-sms-template-id', // Optional: if you have a custom SMS template
      );

      setState(() {
        _isLoading = false;
        _successMessage = 'OTP sent to $_fullPhoneNumber. Please enter it below.';
        _currentStage = ResetPasswordPhoneStage.enterOtp;
      });
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to send OTP: ${e.message}";
      });
      _showErrorToast(_errorMessage!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred: ${e.toString()}";
      });
      _showErrorToast(_errorMessage!);
    }
  }

  // --- Stage 2: Verify OTP ---
  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final AuthResponse response = await _supabase.auth.verifyOTP(
        type: OtpType.sms, // Or OtpType.phoneChange if that was used to send
        token: _otpController.text.trim(),
        phone: _fullPhoneNumber,
      );

      if (response.session != null && response.user != null) {
        // OTP Verified! User is now "authenticated" for this session.
        setState(() {
          _isLoading = false;
          _successMessage = 'OTP verified successfully! Set your new password.';
          _currentStage = ResetPasswordPhoneStage.setNewPassword;
          _otpController.clear();
        });
      } else {
        // This case should ideally be caught by AuthException if OTP is invalid
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid OTP or an unexpected error occurred.';
        });
        _showErrorToast(_errorMessage!);
      }
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "OTP verification failed: ${e.message}";
      });
      _showErrorToast(_errorMessage!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred: ${e.toString()}";
      });
      _showErrorToast(_errorMessage!);
    }
  }

  // --- Stage 3: Set New Password ---
  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // The user should be authenticated at this point from the OTP verification
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Session expired or user not authenticated. Please start over.";
          _currentStage = ResetPasswordPhoneStage.enterPhone; // Reset flow
        });
        _showErrorToast(_errorMessage!);
        return;
      }

      await _supabase.auth.updateUser(
        UserAttributes(
          password: _newPasswordController.text.trim(),
        ),
      );

      setState(() {
        _isLoading = false;
        // Password updated successfully. Clear controllers.
        _phoneController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _successMessage = 'Password reset successfully! You can now log in with your new password.';
        // Optionally navigate back to login after a delay or on user action
      });
      _showSuccessToast(_successMessage!);

      // Sign out the user after password update to force login with new password
      await _supabase.auth.signOut();


      // Navigate to login after a short delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst); // Go back to the very first screen (usually login or home)
          // Or specifically: Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (route) => false);
        }
      });

    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to update password: ${e.message}";
      });
      _showErrorToast(_errorMessage!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred: ${e.toString()}";
      });
      _showErrorToast(_errorMessage!);
    }
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }


  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- UI Builder Methods for Each Stage ---
  Widget _buildEnterPhoneStage(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset Password',
          style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your phone number (e.g., 0712345678). An OTP will be sent to verify.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '0712345678',
            prefixIcon: Icon(Icons.phone_outlined, color: theme.colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10), // For numbers like 07... (10 digits)
            // Or 9 if you expect them to omit the leading 0
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            if (!value.startsWith('0')) {
              return 'Phone number must start with 0';
            }
            if (value.length != 10) { // e.g. 0712345678
              return 'Please enter a valid 10-digit phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendOtp,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Send OTP'),
        ),
      ],
    );
  }

  Widget _buildEnterOtpStage(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify OTP',
          style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _successMessage ?? 'Enter the OTP sent to $_fullPhoneNumber.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: _successMessage != null ? Colors.green.shade700 : null
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _otpController,
          decoration: InputDecoration(
            labelText: 'OTP Code',
            hintText: '123456',
            prefixIcon: Icon(Icons.password_outlined, color: theme.colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6), // Standard OTP length
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the OTP';
            }
            if (value.length != 6) {
              return 'OTP must be 6 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Verify OTP'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : () => setState(() => _currentStage = ResetPasswordPhoneStage.enterPhone),
          child: Text('Change Phone Number?', style: TextStyle(color: theme.colorScheme.secondary)),
        ),
      ],
    );
  }

  Widget _buildSetNewPasswordStage(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set New Password',
          style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _successMessage ?? 'Enter your new password below.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: _successMessage != null && !_successMessage!.contains("Password reset successfully") ? Colors.green.shade700 : null // Only green if it's the OTP success message
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _newPasswordController,
          decoration: InputDecoration(
            labelText: 'New Password',
            hintText: 'Enter new password',
            prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a new password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            hintText: 'Confirm new password',
            prefixIcon: Icon(Icons.lock_reset_outlined, color: theme.colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your new password';
            }
            if (value != _newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _setNewPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Reset Password'),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget currentStageWidget;
    String appBarTitle = 'Forgot Password';

    switch (_currentStage) {
      case ResetPasswordPhoneStage.enterPhone:
        currentStageWidget = _buildEnterPhoneStage(context);
        appBarTitle = 'Enter Phone Number';
        break;
      case ResetPasswordPhoneStage.enterOtp:
        currentStageWidget = _buildEnterOtpStage(context);
        appBarTitle = 'Verify OTP';
        break;
      case ResetPasswordPhoneStage.setNewPassword:
        currentStageWidget = _buildSetNewPasswordStage(context);
        appBarTitle = 'Set New Password';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        titleTextStyle: TextStyle(
            color: theme.colorScheme.primary, fontSize: 20),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: AnimatedSwitcher( // For smooth transition between stages
              duration: const Duration(milliseconds: 300),
              child: Column( // Wrap the stage widget in a Column for consistent key
                key: ValueKey<ResetPasswordPhoneStage>(_currentStage),
                children: [
                  currentStageWidget,
                  const SizedBox(height: 16),
                  if (_errorMessage != null && _successMessage == null || (_successMessage !=null && _successMessage!.contains("Password reset successfully"))) // Show error or final success
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage ?? _successMessage ?? '',
                        style: TextStyle(
                            color: _errorMessage != null
                                ? theme.colorScheme.error
                                : Colors.green.shade700,
                            fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_currentStage != ResetPasswordPhoneStage.setNewPassword || (_successMessage !=null && _successMessage!.contains("Password reset successfully")))
                    Padding( // Show back to login only if not on final success message
                      padding: const EdgeInsets.only(top: 24.0),
                      child: TextButton(
                        child: Text(
                          'Back to Login',
                          style: TextStyle(color: theme.colorScheme.secondary),
                        ),
                        onPressed: _isLoading ? null : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context); // Go back one screen
                          }
                          // Or navigate to login screen by route name if always needed
                          // Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (route) => false);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For AuthException
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // For form validation

  bool _isLoading = false;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) { // Validate the form
      return;
    }
    if (_isLoading) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(msg: "Passwords do not match");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final res = await _auth.signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = res.user;
      if (user != null) {
        // Insert profile data
        await _auth.supabase.from('profiles').insert({
          'id': user.id,
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': 'user', // Default role
        });
        if (!mounted) return;
        Fluttertoast.showToast(msg: "Signup successful!");
        Navigator.pushAndRemoveUntil( // Use pushAndRemoveUntil to clear stack
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
      } else {
        if (!mounted) return;
        Fluttertoast.showToast(msg: "Signup failed. Please try again.");
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: "Signup error: ${e.message}");
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: "An unexpected error occurred: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form( // Added Form widget
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "Join BetCrack today!",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                CustomInput(
                  controller: _usernameController,
                  hintText: "Choose a username", // UPDATED
                  labelText: "Username",
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _emailController,
                  hintText: "Enter your email", // UPDATED
                  labelText: "Email",
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _phoneController,
                  hintText: "Enter your phone number", // UPDATED
                  labelText: "Phone Number",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    // Add more specific phone validation if needed
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _passwordController,
                  hintText: "Create a password", // UPDATED
                  labelText: "Password",
                  obscureText: true, // UPDATED
                  prefixIcon: Icons.lock_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please create a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _confirmPasswordController,
                  hintText: "Confirm your password", // UPDATED
                  labelText: "Confirm Password",
                  obscureText: true, // UPDATED
                  prefixIcon: Icons.lock_person_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: "Create Account",
                  onPressed: _signup,
                  isLoading: _isLoading, // UPDATED
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account?", style: theme.textTheme.bodyMedium),
                    CustomButton(
                      label: "Log In",
                      onPressed: _isLoading ? null : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      type: CustomButtonType.text,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


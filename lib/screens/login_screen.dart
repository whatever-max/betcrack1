// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>(); // For form validation

  bool _isLoading = false;

  Future<String?> _fetchUserRoleFromProfile(String userId) async {
    // ... (no changes here) ...
    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      return response['role'] as String?;
    } catch (e) {
      print("Error fetching role from profile: $e");
      if (mounted) {
        Fluttertoast.showToast(msg: "Could not verify user role.");
      }
      return null;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) { // Validate the form
      return;
    }
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _auth.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      final User? user = res.user;

      if (user != null) {
        final String? userRole = await _fetchUserRoleFromProfile(user.id);
        if (!mounted) return;

        if (userRole == 'super_admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
          );
        } else if (userRole != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          Fluttertoast.showToast(msg: "Role not found. Defaulting to Home.");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        if (mounted) {
          Fluttertoast.showToast(msg: "Login failed: User not found or invalid credentials.");
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: "Login error: ${e.message}");
      }
    } catch (e, s) {
      print("Unexpected error during login: $e\n$s");
      if (mounted) {
        Fluttertoast.showToast(msg: "An unexpected error occurred.");
      }
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
                  "Welcome Back!",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "Log in to your BetCrack account",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                CustomInput(
                  controller: _emailController,
                  hintText: "Enter your email", // UPDATED: hint -> hintText
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
                  controller: _passwordController,
                  hintText: "Enter your password", // UPDATED: hint -> hintText
                  labelText: "Password",
                  obscureText: true, // UPDATED: isPassword -> obscureText
                  prefixIcon: Icons.lock_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: "Log In",
                  onPressed: _login,
                  isLoading: _isLoading, // UPDATED: loading -> isLoading
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: theme.textTheme.bodyMedium),
                    CustomButton( // Using CustomButton for text button style
                      label: "Sign Up",
                      onPressed: _isLoading ? null : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                      type: CustomButtonType.text, // Specify type
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


import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import '../admin/app_management_screen.dart'; // Ensure this path is correct
import '../widgets/custom_input.dart';
import '../widgets/custom_button.dart';
import 'forgot_password_phone_screen.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login'; // This one is fine for LoginScreen itself

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  Future<String?> _fetchUserRoleFromProfile(String userId) async {
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _authService.signIn(
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
            MaterialPageRoute(
              builder: (_) => const AppManagementScreen(),
              // Removed RouteSettings or ensure AppManagementScreen has routeName if you need it
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeScreen(),
              // Removed RouteSettings or ensure HomeScreen has routeName if you need it
            ),
          );
          if (userRole == null) {
            Fluttertoast.showToast(msg: "Role not found. Defaulting to Home.");
          }
        }
      } else {
        if (mounted) {
          Fluttertoast.showToast(
              msg: "Login failed: User not found or invalid credentials.");
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: "Login error: ${e.message}");
      }
    } catch (e, s) {
      print("Unexpected error during login: $e\n$s");
      if (mounted) {
        Fluttertoast.showToast(
            msg: "An unexpected error occurred. Please try again.");
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
          child: Form(
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
                  hintText: "Enter your email",
                  labelText: "Email",
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    // Using a more common regex for basic email validation
                    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  controller: _passwordController,
                  hintText: "Enter your password",
                  labelText: "Password",
                  obscureText: true,
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
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: theme.textTheme.bodyMedium),
                    CustomButton(
                      label: "Sign Up",
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignupScreen(),
                          // Removed RouteSettings or ensure SignupScreen has routeName if you need it
                        ),
                      ),
                      type: CustomButtonType.text,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    Navigator.push( // Using push for ForgotPassword, as it's not a replacement
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordPhoneScreen(),
                        // No RouteSettings here unless ForgotPasswordPhoneScreen explicitly defines and uses its routeName for specific purposes
                      ),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: theme.colorScheme.secondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


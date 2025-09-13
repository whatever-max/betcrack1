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
  final _supabase = Supabase.instance.client; // Supabase client for querying profiles

  bool _isLoading = false;

  Future<String?> _fetchUserRoleFromProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single(); // Assuming 'id' in profiles is the user_id and is unique

      return response['role'] as String?;
    } catch (e) {
      print("Error fetching role from profile: $e");
      Fluttertoast.showToast(msg: "Could not verify user role. Please try again.");
      return null; // Return null on error
    }
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _auth.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      final User? user = res.user;

      if (user != null) {
        print("User login successful. User ID: ${user.id}");

        // Fetch role from profiles table
        final String? userRole = await _fetchUserRoleFromProfile(user.id);
        print("Role from profiles table: $userRole");

        if (!mounted) {
          if (_isLoading) setState(() => _isLoading = false);
          return;
        }

        setState(() => _isLoading = false); // Reset loading state AFTER role fetch

        if (userRole == 'super_admin') {
          print("Redirecting to AdminPanelScreen because role is '$userRole'");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
          );
        } else if (userRole != null) { // User has a role, but not super_admin
          print("Redirecting to HomeScreen because role is '$userRole'");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          // Role could not be fetched or is null in profiles table
          print("Role not found or error fetching role. Redirecting to HomeScreen by default.");
          Fluttertoast.showToast(msg: "Could not determine user role. Please contact support if this persists.");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }

      } else {
        // user is null from _auth.signIn
        if (mounted) setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Login failed: User not found or invalid credentials.");
      }
    } on AuthException catch (e) {
      print("AuthException during login: ${e.message}");
      if (mounted) setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Login error: ${e.message}");
    } catch (e, s) {
      print("Unexpected error during login: $e");
      print("Stack trace: $s");
      if (mounted) setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "An unexpected error occurred: ${e.toString()}");
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Log In", style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              CustomInput(controller: _emailController, hint: "Email"),
              CustomInput(
                  controller: _passwordController,
                  hint: "Password",
                  isPassword: true),
              const SizedBox(height: 16),
              CustomButton(
                  label: "Log In", loading: _isLoading, onPressed: _login),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignupScreen())),
                child: const Text("Don't have an account? Sign up"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

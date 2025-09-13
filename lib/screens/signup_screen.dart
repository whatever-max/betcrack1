import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  bool _isLoading = false;

  Future<void> _signup() async {
    setState(() => _isLoading = true);

    if (_passwordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(msg: "Passwords do not match");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await _auth.signUp(
        _emailController.text,
        _passwordController.text,
      );

      final user = res.user;
      if (user != null) {
        await _auth.supabase.from('profiles').insert({
          'id': user.id,
          'username': _usernameController.text,
          'phone': _phoneController.text,
          'role': 'user',
        });

        Fluttertoast.showToast(msg: "Signup successful!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }

    setState(() => _isLoading = false);
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
              Text("Sign Up", style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              CustomInput(controller: _usernameController, hint: "Username"),
              CustomInput(controller: _emailController, hint: "Email"),
              CustomInput(controller: _phoneController, hint: "Phone Number"),
              CustomInput(controller: _passwordController, hint: "Password", isPassword: true),
              CustomInput(controller: _confirmPasswordController, hint: "Confirm Password", isPassword: true),
              const SizedBox(height: 16),
              CustomButton(
                label: "Create Account",
                loading: _isLoading,
                onPressed: _signup,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text("Already have an account? Log in"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

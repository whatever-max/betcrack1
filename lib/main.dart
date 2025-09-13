import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
// Import your constants file. Adjust the path if you placed it elsewhere.
import 'constants.dart'; // Or 'core/constants.dart' etc.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    // Use the constants here
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const BetCrackApp());
}

class BetCrackApp extends StatelessWidget {
  const BetCrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BetCrack',debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorSchemeSeed: Colors.greenAccent,
      ),
      home: const LoginScreen(),
    );
  }
}

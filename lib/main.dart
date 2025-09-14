// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; // For checking initial session
// import 'admin/admin_panel_screen.dart'; // Not needed for _getInitialScreen logic here
import 'constants.dart'; // Your Supabase URL and Anon Key

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const BetCrackApp());
}

// Helper function to determine initial route based on session
Widget _getInitialScreen() {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    print("No active session, navigating to LoginScreen.");
    return const LoginScreen();
  }

  // If session exists, navigate to HomeScreen.
  // HomeScreen or a dedicated SplashScreen should then handle fetching
  // the user's profile/role from the 'profiles' table and navigate
  // to AdminPanelScreen if the role is 'super_admin'.
  print("Active session found, navigating to HomeScreen initially.");
  return const HomeScreen();
}


class BetCrackApp extends StatelessWidget {
  const BetCrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seedColor = Color(0xFF00695C); // Deep Teal

    // --- Light Theme ---
    final ThemeData lightTheme = ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          // You can fine-tune generated colors if needed:
          // primary: seedColor,
          // secondary: Colors.amber, // Example
        ),
        scaffoldBackgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).background,
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).primary,
          foregroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).onPrimary,
          elevation: 0.5,
          titleTextStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).onPrimary,
          ),
          iconTheme: IconThemeData(
            color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).onPrimary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).primary,
            foregroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 2,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).primary,
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).surfaceVariant.withOpacity(0.5),
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).error, width: 2),
          ),
        ),
        // CORRECTED CardThemeData
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            // side: BorderSide(color: Colors.grey.shade300, width: 0.5) // Optional subtle border
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), // Added some horizontal margin
          clipBehavior: Clip.antiAlias, // Ensures content respects rounded corners
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          iconColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).primary,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).surface,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData(brightness: Brightness.light).textTheme,
        ).copyWith(
          // General text styles
          bodyLarge: GoogleFonts.poppins(fontSize: 16.0),
          bodyMedium: GoogleFonts.poppins(fontSize: 14.0, color: Colors.grey.shade700), // Default text
          labelLarge: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.w600), // For button text

          // Headlines and Titles
          displayLarge: GoogleFonts.poppins(fontSize: 57.0, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.poppins(fontSize: 45.0, fontWeight: FontWeight.bold),
          displaySmall: GoogleFonts.poppins(fontSize: 36.0, fontWeight: FontWeight.bold),
          headlineLarge: GoogleFonts.poppins(fontSize: 32.0, fontWeight: FontWeight.bold),
          headlineMedium: GoogleFonts.poppins(fontSize: 28.0, fontWeight: FontWeight.w600), // Good for Login/Signup title
          headlineSmall: GoogleFonts.poppins(fontSize: 24.0, fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.poppins(fontSize: 22.0, fontWeight: FontWeight.w600), // Good for card titles / AppBar
          titleMedium: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.w500),
          titleSmall: GoogleFonts.poppins(fontSize: 14.0, fontWeight: FontWeight.w500),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).primary,
          unselectedItemColor: Colors.grey.shade600,
        ),
        chipTheme: ChipThemeData(
            backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).primaryContainer,
            labelStyle: GoogleFonts.poppins(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).onPrimaryContainer)
        )
    );

    // --- Dark Theme ---
    final ThemeData darkTheme = ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          // You can fine-tune generated colors if needed:
          // primary: seedColor, // Or a slightly desaturated version for dark mode
          // surface: Colors.grey[850], // Example custom surface
        ),
        scaffoldBackgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).background,
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).surfaceVariant,
          foregroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).onSurfaceVariant,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).onSurfaceVariant,
          ),
          iconTheme: IconThemeData(
            color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).onSurfaceVariant,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).primary,
            foregroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 2,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).primary,
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            )
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.08), // Slightly more visible fill for dark theme
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).error, width: 2),
          ),
        ),
        // CORRECTED CardThemeData
        cardTheme: CardThemeData(
          elevation: 1,
          color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            // side: BorderSide(color: Colors.grey.shade700, width: 0.5) // Optional subtle border
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          clipBehavior: Clip.antiAlias,
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          iconColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).primary,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).surface,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ).copyWith(
          // General text styles
          bodyLarge: GoogleFonts.poppins(fontSize: 16.0),
          bodyMedium: GoogleFonts.poppins(fontSize: 14.0, color: Colors.grey.shade400),
          labelLarge: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.w600),

          // Headlines and Titles
          displayLarge: GoogleFonts.poppins(fontSize: 57.0, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.poppins(fontSize: 45.0, fontWeight: FontWeight.bold),
          displaySmall: GoogleFonts.poppins(fontSize: 36.0, fontWeight: FontWeight.bold),
          headlineLarge: GoogleFonts.poppins(fontSize: 32.0, fontWeight: FontWeight.bold),
          headlineMedium: GoogleFonts.poppins(fontSize: 28.0, fontWeight: FontWeight.w600),
          headlineSmall: GoogleFonts.poppins(fontSize: 24.0, fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.poppins(fontSize: 22.0, fontWeight: FontWeight.w600),
          titleMedium: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.w500),
          titleSmall: GoogleFonts.poppins(fontSize: 14.0, fontWeight: FontWeight.w500),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).primary,
          unselectedItemColor: Colors.grey.shade500,
          // backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).surfaceVariant,
        ),
        chipTheme: ChipThemeData(
            backgroundColor: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).primaryContainer,
            labelStyle: GoogleFonts.poppins(color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).onPrimaryContainer)
        )
    );

    return MaterialApp(
      title: 'BetCrack',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: _getInitialScreen(),
    );
  }
}

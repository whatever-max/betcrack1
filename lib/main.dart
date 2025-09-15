// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'admin/app_management_screen.dart';
import 'constants.dart'; // Ensure supabaseUrl and supabaseAnonKey are defined here

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const BetCrackApp());
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
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          clipBehavior: Clip.antiAlias,
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
          bodyLarge: GoogleFonts.poppins(fontSize: 16.0),
          bodyMedium: GoogleFonts.poppins(fontSize: 14.0, color: Colors.grey.shade700),
          labelLarge: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.w600),
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
          fillColor: Colors.white.withOpacity(0.08),
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
        cardTheme: CardThemeData(
          elevation: 1,
          color: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark).surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
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
          bodyLarge: GoogleFonts.poppins(fontSize: 16.0),
          bodyMedium: GoogleFonts.poppins(fontSize: 14.0, color: Colors.grey.shade400),
          labelLarge: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.w600),
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
      home: const InitialAuthCheckScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(), // Users (and admin in user mode)
        '/app_management': (context) => const AppManagementScreen(), // Admin's primary screen
      },
    );
  }
}

class InitialAuthCheckScreen extends StatefulWidget {
  const InitialAuthCheckScreen({super.key});

  @override
  State<InitialAuthCheckScreen> createState() => _InitialAuthCheckScreenState();
}

class _InitialAuthCheckScreenState extends State<InitialAuthCheckScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Perform check after the first frame to ensure context is valid for navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialCheckAndNavigate();
    });
  }

  Future<void> _performInitialCheckAndNavigate() async {
    // Ensure the widget is still mounted before attempting navigation, especially after async operations.
    if (!mounted) return;

    final session = supabase.auth.currentSession;

    if (session == null) {
      print("[InitialAuthCheck] No active session, navigating to LoginScreen.");
      // Use pushReplacementNamed to ensure this screen is removed from the stack.
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Session exists, fetch the user's role from the 'profiles' table.
    try {
      print("[InitialAuthCheck] Active session for user ${session.user.id}, fetching role...");
      final profileResponse = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .single(); // .single() will throw if 0 or >1 rows, good for this.

      final userRole = profileResponse['role'] as String?;
      print("[InitialAuthCheck] User role: $userRole");

      if (!mounted) return; // Check mounted again after await

      if (userRole == 'super_admin') {
        print("[InitialAuthCheck] Role is super_admin, navigating to AppManagementScreen.");
        Navigator.pushReplacementNamed(context, '/app_management');
      } else {
        // Includes 'user' role or any other non-admin role, or if role is null (fallback)
        print("[InitialAuthCheck] Role is '$userRole' (or null), navigating to HomeScreen.");
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e, stacktrace) {
      print("[InitialAuthCheck] Error fetching profile/role: $e");
      print(stacktrace); // Print stacktrace for better debugging
      if (mounted) {
        // If profile fetch fails (e.g., user deleted from profiles but not auth, or network error),
        // sign out to clear potentially inconsistent state and go to login.
        await supabase.auth.signOut().catchError((signOutError) {
          print("[InitialAuthCheck] Error during sign out after profile fetch failure: $signOutError");
        });
        print("[InitialAuthCheck] Signed out due to profile/role fetch error. Navigating to LoginScreen.");
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This screen acts as a splash/loading screen while checks are performed.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Initializing BetCrack..."),
          ],
        ),
      ),
    );
  }
}

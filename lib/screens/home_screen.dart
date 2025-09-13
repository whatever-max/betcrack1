// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/betslip.dart';
import '../widgets/betslip_card.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  final AuthService _auth = AuthService();

  String? _username; // Allow null initially
  String? _phone;    // Allow null initially
  String? _role;     // Allow null initially
  List<Betslip>? _betslips; // Allow null initially to distinguish from empty list

  bool _isLoadingProfile = true;
  bool _isLoadingBetslips = true;

  @override
  void initState() {
    super.initState();
    print("HomeScreen: initState called");
    _fetchProfile();
    _fetchBetslips();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("HomeScreen: User not found for profile fetch.");
        // Optionally handle this, e.g., navigate to login
        if (mounted) setState(() => _isLoadingProfile = false);
        return;
      }

      final res = await supabase
          .from('profiles')
          .select('username, phone, role') // Select specific fields
          .eq('id', user.id)
          .single(); // Use single() for one expected row

      if (mounted) {
        setState(() {
          _username = res['username'] as String? ?? 'N/A';
          _phone = res['phone'] as String? ?? 'N/A';
          _role = res['role'] as String? ?? 'user'; // Default role if null
          _isLoadingProfile = false;
          print("HomeScreen: Profile fetched - Username: $_username");
        });
      }
    } catch (e, s) {
      print("HomeScreen: Error fetching profile: $e");
      print("HomeScreen: Stacktrace: $s");
      if (mounted) {
        setState(() {
          _username = 'Error';
          _phone = 'Error';
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchBetslips() async {
    setState(() => _isLoadingBetslips = true);
    try {
      final data = await supabase
          .from('betslips')
          .select()
          .order('created_at', ascending: false);

      // final slips = data.map<Betslip>((json) => Betslip.fromJson(json)).toList();
      // More robust parsing:
      final List<Betslip> slips = [];
      for (var jsonItem in data) {
        try {
          slips.add(Betslip.fromJson(jsonItem as Map<String, dynamic>));
        } catch (e) {
          print("HomeScreen: Error parsing betslip item: $jsonItem. Error: $e");
          // Optionally skip this item or handle it
        }
      }


      if (mounted) {
        setState(() {
          _betslips = slips;
          _isLoadingBetslips = false;
          print("HomeScreen: Betslips fetched - Count: ${_betslips?.length}");
        });
      }
    } catch (e, s) {
      print("HomeScreen: Error fetching betslips: $e");
      print("HomeScreen: Stacktrace: $s");
      if (mounted) {
        setState(() {
          _isLoadingBetslips = false;
          _betslips = []; // Set to empty list on error to avoid null issues
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching betslips: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    print("HomeScreen: Refreshing data...");
    await _fetchProfile();
    await _fetchBetslips();
  }

  void _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch(e) {
      print("HomeScreen: Error during logout: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: ${e.toString()}')),
        );
      }
    }
  }

  void _handleLockedClick(Betslip slip) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("This slip is locked. Pay ${slip.price ?? 0} TZS to view.")), // Handle null price
    );
  }

  @override
  Widget build(BuildContext context) {
    print("HomeScreen: build called. Profile Loading: $_isLoadingProfile, Betslips Loading: $_isLoadingBetslips");
    final bool stillLoading = _isLoadingProfile || _isLoadingBetslips;

    return Scaffold(
      appBar: AppBar(
        title: const Text("BetCrack"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              if (_isLoadingProfile)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                UserAccountsDrawerHeader(
                  accountName: Text(_username ?? 'Loading...'), // Provide default
                  accountEmail: Text(_phone ?? 'Loading...'),   // Provide default
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.green),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("My History"),
                onTap: () { /* TODO */ },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Settings"),
                onTap: () { /* TODO */ },
              ),
              const Spacer(), // Pushes logout to the bottom
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Log Out"),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: stillLoading
          ? const Center(child: CircularProgressIndicator(key: ValueKey("home_loading")))
          : _betslips == null // Distinguish initial null from empty
          ? const Center(child: Text("Error loading betslips or none available yet."))
          : _betslips!.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("No betslips posted yet."),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _refreshData, child: const Text("Refresh"))
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView.builder(
          itemCount: _betslips!.length,
          itemBuilder: (context, index) {
            final slip = _betslips![index];
            return BetslipCard(
              betslip: slip,
              isPurchased: false, // TODO: replace with real check later
              onTapLocked: () => _handleLockedClick(slip),
            );
          },
        ),
      ),
    );
  }
}

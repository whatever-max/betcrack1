// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/betslip.dart';
import '../widgets/betslip_card.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../admin/admin_panel_screen.dart';
import 'payment_methods_screen.dart';
import 'betslip_detail_screen.dart'; // <<<--- IMPORTED DETAIL SCREEN
import '../widgets/app_drawer.dart';   // <<<--- IMPORTED APP DRAWER
import 'payment_history_screen.dart'; // For drawer navigation
// TODO: Import SettingsScreen when created

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  final AuthService _auth = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _username;
  String? _phone;
  String? _userRole;
  List<Betslip>? _allBetslips;
  List<Betslip>? _filteredBetslips;
  Map<String, bool> _purchaseStatus = {}; // Stores betslip_id: isPurchased

  bool _isLoadingProfile = true;
  bool _isLoadingBetslips = true;
  bool _isLoadingPurchases = true; // For loading purchase status

  DateTime _selectedFilterDate = DateTime.now();
  final List<DateTime> _filterDates = [];
  static const int _numberOfFutureDaysToShow = 4;

  @override
  void initState() {
    super.initState();
    _generateFilterDates();
    _fetchInitialData();
  }

  void _generateFilterDates() {
    _filterDates.clear();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _filterDates.add(today.subtract(const Duration(days: 1))); // Yesterday
    _filterDates.add(today); // Today
    _filterDates.add(today.add(const Duration(days: 1))); // Tomorrow
    for (int i = 2; i < 2 + _numberOfFutureDaysToShow; i++) {
      _filterDates.add(today.add(Duration(days: i)));
    }
    _selectedFilterDate = today;
  }

  Future<void> _fetchInitialData() async {
    // Fetch profile first to get user_id if needed
    await _fetchProfile();
    // Then fetch purchases for that user
    await _fetchUserPurchases();
    // Then fetch all betslips
    await _fetchBetslips();
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        }
        return;
      }
      final res = await supabase
          .from('profiles')
          .select('username, phone, role')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _username = res['username'] as String? ?? 'User';
          _phone = res['phone'] as String? ?? 'No phone';
          _userRole = res['role'] as String? ?? 'user';
          _isLoadingProfile = false;
        });
        if (_userRole == 'super_admin' && ModalRoute.of(context)?.settings.name != '/admin_panel') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanelScreen(), settings: const RouteSettings(name: '/admin_panel')),
          );
        }
      }
    } catch (e, s) {
      print("HomeScreen: Error fetching profile: $e\n$s");
      if (mounted) {
        setState(() {
          _username = 'Error';
          _phone = 'Error';
          _userRole = 'user';
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _fetchUserPurchases() async {
    if (!mounted) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoadingPurchases = false);
      return; // No user, no purchases
    }

    setState(() => _isLoadingPurchases = true);
    try {
      final data = await supabase
          .from('purchases') // MAKE SURE YOU HAVE THIS TABLE
          .select('betslip_id')
          .eq('user_id', userId)
          .eq('status', 'completed'); // Only count completed purchases

      final Map<String, bool> status = {};
      for (var item in data) {
        if (item['betslip_id'] != null) {
          status[item['betslip_id'] as String] = true;
        }
      }
      if (mounted) {
        setState(() {
          _purchaseStatus = status;
          _isLoadingPurchases = false;
        });
      }
    } catch (e) {
      print("HomeScreen: Error fetching user purchases: $e");
      if (mounted) {
        setState(() => _isLoadingPurchases = false);
        // Optionally show a less intrusive error for purchase fetching
      }
    }
  }

  Future<void> _fetchBetslips() async {
    if (!mounted) return;
    setState(() => _isLoadingBetslips = true);
    try {
      final data = await supabase.from('betslips').select().order('created_at', ascending: false);
      final List<Betslip> slips = [];
      for (var jsonItem in data) {
        try {
          slips.add(Betslip.fromJson(jsonItem as Map<String, dynamic>));
        } catch (e) {
          print("HomeScreen: Error parsing betslip item: $jsonItem. Error: $e");
        }
      }
      if (mounted) {
        setState(() {
          _allBetslips = slips;
          _isLoadingBetslips = false;
          _applyDateFilter();
        });
      }
    } catch (e, s) {
      print("HomeScreen: Error fetching betslips: $e\n$s");
      if (mounted) {
        setState(() {
          _isLoadingBetslips = false;
          _allBetslips = [];
          _filteredBetslips = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching betslips: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _applyDateFilter() {
    if (_allBetslips == null) {
      if (mounted) setState(() => _filteredBetslips = []);
      return;
    }
    _filteredBetslips = _allBetslips!.where((slip) {
      if (slip.createdAt == null) return false;
      final createdAtDate = DateTime(slip.createdAt!.year, slip.createdAt!.month, slip.createdAt!.day);
      return createdAtDate.isAtSameMomentAs(_selectedFilterDate);
    }).toList();

    _filteredBetslips?.sort((a, b) {
      bool aIsValid = a.validUntil != null && a.validUntil!.isAfter(DateTime.now());
      bool bIsValid = b.validUntil != null && b.validUntil!.isAfter(DateTime.now());
      if (aIsValid && !bIsValid) return -1;
      if (!aIsValid && bIsValid) return 1;
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    if (mounted) setState(() {});
  }

  Future<void> _refreshData() async {
    _generateFilterDates();
    await _fetchProfile();
    await _fetchUserPurchases(); // Refresh purchases
    await _fetchBetslips();
  }

  void _onDateFilterChanged(DateTime newDate) {
    if (mounted) {
      setState(() {
        _selectedFilterDate = DateTime(newDate.year, newDate.month, newDate.day);
        _applyDateFilter();
      });
    }
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
    } catch (e) {
      print("HomeScreen: Error during logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _handleLockedClick(Betslip slip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodsScreen(betslipToPurchase: slip),
      ),
    ).then((paymentResult) {
      // After returning from PaymentMethodsScreen, check if payment might have succeeded
      // This is a basic way; a more robust solution would use a proper state management or event bus
      if (paymentResult == true) { // Assume PaymentMethodsScreen pops with true on (simulated) success
        _refreshData(); // Refresh data to get new purchase status and potentially unlock slip
      }
    });
  }

  void _navigateToPaymentHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()));
  }

  void _navigateToSettings() {
    // TODO: Implement Settings Screen
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings: Coming soon!")));
  }
  void _navigateToAdminPanel() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
  }


  String _getFilterDateLabel(DateTime date, DateTime today) {
    if (date.year == today.year && date.month == today.month && date.day == today.day) return "Today";
    if (date.year == today.year && date.month == today.month && date.day == today.day - 1) return "Yesterday";
    if (date.year == today.year && date.month == today.month && date.day == today.day + 1) return "Tomorrow";
    return DateFormat('EEE, d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool stillLoadingCoreData = _isLoadingProfile || _isLoadingBetslips || _isLoadingPurchases;
    final todayForLabel = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("BetCrack Feed"),
      ),
      drawer: AppDrawer( // <<<--- USE THE STANDALONE DRAWER
        username: _username,
        phone: _phone,
        userRole: _userRole,
        isLoadingProfile: _isLoadingProfile,
        onLogout: () {
          Navigator.pop(context); // Close drawer
          _logout();
        },
        onNavigateToAdminPanel: () {
          Navigator.pop(context); // Close drawer
          _navigateToAdminPanel();
        },
        onNavigateToPaymentHistory: () {
          Navigator.pop(context); // Close drawer
          _navigateToPaymentHistory();
        },
        onNavigateToSettings: () {
          Navigator.pop(context); // Close drawer
          _navigateToSettings();
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- Date Filter Chips ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: ElevationOverlay.applySurfaceTint(theme.colorScheme.surface, theme.colorScheme.surfaceTint, 1.5),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterDates.length,
                  itemBuilder: (context, index) {
                    final date = _filterDates[index];
                    final isSelected = date.isAtSameMomentAs(_selectedFilterDate);
                    return ChoiceChip(
                      label: Text(_getFilterDateLabel(date, todayForLabel)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) _onDateFilterChanged(date);
                      },
                      backgroundColor: isSelected ? theme.colorScheme.primary.withOpacity(0.12) : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3), width: 1.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      visualDensity: VisualDensity.compact,
                      elevation: isSelected ? 1 : 0,
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // --- Betslips List ---
            Expanded(
              child: stillLoadingCoreData
                  ? const Center(child: CircularProgressIndicator())
                  : _allBetslips == null
                  ? Center( /* Error loading betslips */
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                      const SizedBox(height: 16),
                      Text("Could not load betslips.", style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      Text("Please check your internet connection.", style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(icon: const Icon(Icons.refresh_rounded), label: const Text("Retry"), onPressed: _refreshData)
                    ],
                  ),
                ),
              )
                  : _filteredBetslips == null || _filteredBetslips!.isEmpty
                  ? Center( /* No slips for filter or no slips at all */
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_outlined, color: theme.colorScheme.secondary, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        _allBetslips!.isEmpty ? "No Tips Posted Yet!" : "No Tips for ${_getFilterDateLabel(_selectedFilterDate, todayForLabel)}",
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _allBetslips!.isEmpty ? "Check back soon for the latest tips." : "Check other dates or refresh the feed.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_allBetslips!.isEmpty ? "Refresh Feed" : "Refresh All"),
                        onPressed: _refreshData,
                        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: theme.colorScheme.onSecondary),
                      )
                    ],
                  ),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _refreshData,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  itemCount: _filteredBetslips!.length,
                  itemBuilder: (context, index) {
                    final slip = _filteredBetslips![index];
                    final isUserPurchasedThisSlip = _purchaseStatus[slip.id] ?? false;

                    return BetslipCard(
                      betslip: slip,
                      isPurchased: isUserPurchasedThisSlip,
                      onTapCard: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BetslipDetailScreen(
                              betslip: slip,
                              isPurchased: isUserPurchasedThisSlip,
                            ),
                          ),
                        ).then((_){
                          // Potentially refresh purchase status if detail screen could change it
                          // (e.g. if detail screen also has an unlock button)
                          _fetchUserPurchases();
                        });
                      },
                      onTapLocked: () => _handleLockedClick(slip),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


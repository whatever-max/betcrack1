// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/betslip.dart';
import '../widgets/betslip_card.dart';
import '../services/auth_service.dart';
// import 'login_screen.dart'; // Handled by main.dart or auth state listeners
// import '../admin/app_management_screen.dart'; // Handled by main.dart or drawer
import 'payment_methods_screen.dart';
import 'betslip_detail_screen.dart';
import '../widgets/app_drawer.dart';
import 'payment_history_screen.dart';
import 'premium_slips_screen.dart'; // For navigating to premium packages

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

  List<Betslip>? _allBetslips; // Contains ALL slips initially
  List<Betslip>? _filteredRegularSlips; // For the main feed (non-premium only)
  Map<String, bool> _purchaseStatus = {};

  bool _isLoadingProfile = true;
  bool _isLoadingBetslips = true;
  bool _isLoadingPurchases = true;

  DateTime _selectedFilterDate = DateTime.now();
  final List<DateTime> _filterDates = [];
  static const int _numberOfPastDaysToShow = 7;
  static const int _numberOfFutureDaysToShow = 4;
  final ScrollController _dateFilterScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    print("[HomeScreen initState] Initializing HomeScreen.");
    _generateFilterDates();
    _fetchInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelectedDate(isInitialLoad: true);
    });
  }

  @override
  void dispose() {
    _dateFilterScrollController.dispose();
    super.dispose();
  }

  void _generateFilterDates() {
    _filterDates.clear();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int i = _numberOfPastDaysToShow - 1; i >= 1; i--) {
      _filterDates.add(today.subtract(Duration(days: i)));
    }
    _filterDates.add(today);
    for (int i = 1; i <= _numberOfFutureDaysToShow; i++) {
      _filterDates.add(today.add(Duration(days: i)));
    }
    _selectedFilterDate = DateTime(today.year, today.month, today.day);
  }

  void _scrollToSelectedDate({bool isInitialLoad = false}) {
    if (_filterDates.isEmpty || !_dateFilterScrollController.hasClients) return;
    int selectedIndex = _filterDates.indexWhere((date) => date.isAtSameMomentAs(_selectedFilterDate));
    if (selectedIndex != -1) {
      const double chipWidth = 110.0;
      const double spacing = 8.0;
      double scrollOffset = (selectedIndex * (chipWidth + spacing)) - (MediaQuery.of(context).size.width / 2) + (chipWidth / 2);
      scrollOffset = scrollOffset.clamp(
          _dateFilterScrollController.position.minScrollExtent,
          _dateFilterScrollController.position.maxScrollExtent);
      _dateFilterScrollController.animateTo(
        scrollOffset,
        duration: Duration(milliseconds: isInitialLoad ? 500 : 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _fetchInitialData() async {
    await _fetchProfile();
    if (!mounted) return;

    if (_userRole == 'super_admin' && ModalRoute.of(context)?.settings.name != '/home') {
      print("[HomeScreen _fetchInitialData] Admin detected, but current route is not /home ('${ModalRoute.of(context)?.settings.name}'). Skipping further data load for this instance.");
      if (mounted) setState(() { _isLoadingBetslips = false; _isLoadingPurchases = false; });
      return;
    }
    print("[HomeScreen _fetchInitialData] Proceeding to load user purchases and betslips. Role: $_userRole, Route: ${ModalRoute.of(context)?.settings.name}");
    await _fetchUserPurchases();
    await _fetchBetslips(); // Fetches all types of betslips
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final res = await supabase.from('profiles').select('username, phone, role').eq('id', user.id).single();
      if (mounted) {
        final String fetchedRole = res['role'] as String? ?? 'user';
        setState(() {
          _username = res['username'] as String? ?? 'User';
          _phone = res['phone'] as String? ?? 'No phone';
          _userRole = fetchedRole;
          _isLoadingProfile = false;
        });
        print("[HomeScreen _fetchProfile] Profile fetched. Role: $_userRole. Current Route: ${ModalRoute.of(context)?.settings.name}");
      }
    } catch (e, s) {
      print("HomeScreen: Error fetching profile: $e\n$s");
      if (mounted) {
        setState(() { _username = 'Error'; _phone = 'Error'; _userRole = 'user'; _isLoadingProfile = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching profile: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  Future<void> _fetchUserPurchases() async {
    if (!mounted) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoadingPurchases = false);
      return;
    }
    if (mounted) setState(() => _isLoadingPurchases = true);
    try {
      final data = await supabase.from('purchases').select('betslip_id').eq('user_id', userId).eq('status', 'completed');
      final Map<String, bool> status = {};
      for (var item in data) {
        if (item['betslip_id'] != null) status[item['betslip_id'] as String] = true;
      }
      if (mounted) setState(() { _purchaseStatus = status; _isLoadingPurchases = false; });
    } catch (e) {
      print("HomeScreen: Error fetching user purchases: $e");
      if (mounted) setState(() => _isLoadingPurchases = false);
    }
  }

  Future<void> _fetchBetslips() async { // Fetches ALL betslips
    if (!mounted) return;
    setState(() => _isLoadingBetslips = true);
    try {
      final data = await supabase.from('betslips').select().order('created_at', ascending: false);
      final List<Betslip> slips = data.map((item) {
        if (item is Map<String, dynamic>) return Betslip.fromJson(item);
        return null;
      }).whereType<Betslip>().toList();
      if (mounted) {
        setState(() {
          _allBetslips = slips; // Store all slips
          _isLoadingBetslips = false;
          _applyDateFilter(); // This will filter for REGULAR slips to display in main feed
        });
      }
    } catch (e, s) {
      print("HomeScreen: Error fetching betslips: $e\n$s");
      if (mounted) {
        setState(() { _isLoadingBetslips = false; _allBetslips = []; _filteredRegularSlips = []; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching betslips: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  void _applyDateFilter() { // Filters for REGULAR (non-premium) slips for the main feed
    if (_allBetslips == null) {
      if (mounted) setState(() => _filteredRegularSlips = []);
      return;
    }
    // Filter for non-premium slips based on the selected date
    _filteredRegularSlips = _allBetslips!.where((slip) {
      if (slip.isPremium) return false; // Exclude premium slips from this list
      if (slip.createdAt == null) return false;
      final createdAtDate = DateTime(slip.createdAt!.year, slip.createdAt!.month, slip.createdAt!.day);
      return createdAtDate.isAtSameMomentAs(_selectedFilterDate);
    }).toList();

    // Sort the filtered regular slips
    _filteredRegularSlips?.sort((a, b) {
      bool aIsValid = a.validUntil != null && a.validUntil!.isAfter(DateTime.now());
      bool bIsValid = b.validUntil != null && b.validUntil!.isAfter(DateTime.now());
      if (aIsValid && !bIsValid) return -1;
      if (!aIsValid && bIsValid) return 1;
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    });
    if (mounted) setState(() {});
  }

  Future<void> _refreshData() async {
    await _fetchProfile();
    if (!mounted) return;
    if (_userRole == 'super_admin' && ModalRoute.of(context)?.settings.name != '/home') {
      return;
    }
    await _fetchUserPurchases();
    await _fetchBetslips(); // Re-fetches all, then _applyDateFilter separates them
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSelectedDate();
      });
    }
  }

  void _onDateFilterChanged(DateTime newDate) {
    if (mounted) {
      setState(() {
        _selectedFilterDate = DateTime(newDate.year, newDate.month, newDate.day);
        _applyDateFilter();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSelectedDate();
      });
    }
  }

  void _logout() async {
    try {
      await _auth.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print("HomeScreen: Error during logout: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error logging out: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  void _handleLockedClick(Betslip slip) {
    Navigator.push(
      context, MaterialPageRoute(builder: (_) => PaymentMethodsScreen(betslipToPurchase: slip)),
    ).then((paymentResult) {
      if (paymentResult == true) _refreshData();
    });
  }

  void _navigateToPaymentHistory() {
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()));
  }

  void _navigateToSettings() {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings: Coming soon!")));
  }

  String _getFilterDateLabel(DateTime date, DateTime today) {
    if (date.isAtSameMomentAs(today)) return "Today";
    if (date.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) return "Yesterday";
    if (date.isAtSameMomentAs(today.add(const Duration(days: 1)))) return "Tomorrow";
    return DateFormat('EEE, d MMM').format(date);
  }

  void _navigateToPremiumPackages() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumSlipsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayForLabel = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final currentRouteName = ModalRoute.of(context)?.settings.name;

    print("[HomeScreen Build] Building UI. Role: $_userRole, Current Route: $currentRouteName");

    if (_isLoadingProfile || (_userRole == null && supabase.auth.currentSession != null)) {
      print("[HomeScreen Build] Initial Profile Loading State in build.");
      return const Scaffold(body: Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenProfileLoadingBuild"))));
    }

    if (_userRole == 'super_admin' && currentRouteName != '/home') {
      print("[HomeScreen Build] Admin detected and current route is NOT /home ('$currentRouteName'). Showing loading; expecting navigation handled by InitialAuthCheck or drawer.");
      return const Scaffold(body: Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenAdminNotHomeRouteLoadingBuild"))));
    }

    final bool stillLoadingBetslipData = _isLoadingBetslips || _isLoadingPurchases; // Check if betslip specific data is loading

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("BetCrack Feed"),
        actions: [
          TextButton.icon(
            onPressed: _navigateToPremiumPackages,
            icon: Icon(Icons.star_purple500_outlined, color: theme.colorScheme.onPrimary),
            label: Text("Premium", style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(
        username: _username,
        phone: _phone,
        userRole: _userRole,
        isLoadingProfile: _isLoadingProfile,
        onLogout: () { Navigator.pop(context); _logout(); },
        onNavigateToUserModeHome: () {
          Navigator.pop(context);
          if (ModalRoute.of(context)?.settings.name != '/home' && _userRole == 'super_admin') {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
        onNavigateToAppManagement: () {
          Navigator.pop(context);
          if (_userRole == 'super_admin') {
            Navigator.pushReplacementNamed(context, '/app_management');
          }
        },
        onNavigateToPaymentHistory: () { Navigator.pop(context); _navigateToPaymentHistory(); },
        onNavigateToSettings: () { Navigator.pop(context); _navigateToSettings(); },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Filter Chips for Regular Slips
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: ElevationOverlay.applySurfaceTint(theme.colorScheme.surface, theme.colorScheme.surfaceTint, 1.5),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  controller: _dateFilterScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterDates.length,
                  itemBuilder: (context, index) {
                    final date = _filterDates[index];
                    final isSelected = date.isAtSameMomentAs(_selectedFilterDate);
                    return ChoiceChip(
                      label: Text(_getFilterDateLabel(date, todayForLabel)),
                      selected: isSelected,
                      onSelected: (selected) { if (selected) _onDateFilterChanged(date); },
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

            // List of REGULAR Betslips
            Expanded(
              child: stillLoadingBetslipData
                  ? const Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenRegularSlipsLoading")))
                  : _allBetslips == null // This implies an error fetching any slips
                  ? _buildErrorState(theme, "Could not load betslips.", "Please check your internet connection.")
                  : (_filteredRegularSlips == null || _filteredRegularSlips!.isEmpty)
                  ? _buildEmptyState(theme, todayForLabel) // Empty state specifically for regular slips
                  : RefreshIndicator(
                onRefresh: _refreshData,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 80.0), // Padding for FAB if any, or general spacing
                  itemCount: _filteredRegularSlips!.length,
                  itemBuilder: (context, index) {
                    final slip = _filteredRegularSlips![index];
                    // Ensure we are not accidentally showing a premium slip here
                    if (slip.isPremium) return const SizedBox.shrink(); // Should not happen due to filter

                    final isUserPurchasedThisSlip = _purchaseStatus[slip.id] ?? false;
                    return BetslipCard(
                      betslip: slip,
                      isPurchased: isUserPurchasedThisSlip,
                      isAdminView: _userRole == 'super_admin',
                      onTapCard: () {
                        Navigator.push(
                          context, MaterialPageRoute(builder: (_) => BetslipDetailScreen(betslip: slip, isPurchased: isUserPurchasedThisSlip)),
                        ).then((_) => _fetchUserPurchases());
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

  Widget _buildErrorState(ThemeData theme, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(icon: const Icon(Icons.refresh_rounded), label: const Text("Retry"), onPressed: _refreshData)
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, DateTime todayForLabel) {
    String message = "No regular tips for ${_getFilterDateLabel(_selectedFilterDate, todayForLabel)}.";
    if (_allBetslips?.where((s) => !s.isPremium).isEmpty ?? true) {
      message = "No regular tips posted yet.";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined, color: theme.colorScheme.secondary, size: 60), // Changed icon
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _allBetslips?.where((s) => !s.isPremium).isEmpty ?? true
                  ? "Check back soon or explore Premium Packages!"
                  : "Try other dates or check out Premium Packages.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Refresh Feed"),
                  onPressed: _refreshData,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.star_purple500_outlined, color: theme.colorScheme.onPrimaryContainer),
                  label: Text("Premium Tips", style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
                  onPressed: _navigateToPremiumPackages,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}


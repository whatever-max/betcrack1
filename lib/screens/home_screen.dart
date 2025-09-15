// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/betslip.dart';
import '../widgets/betslip_card.dart';
import '../services/auth_service.dart';
// import 'login_screen.dart'; // Not directly needed for navigation from here
// import '../admin/app_management_screen.dart'; // Not directly needed
import 'payment_methods_screen.dart';
import 'betslip_detail_screen.dart';
import '../widgets/app_drawer.dart';
import 'payment_history_screen.dart';
// TODO: Import SettingsScreen if you create it

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
    // print("[HomeScreen initState] Initializing HomeScreen. Current route: ${ModalRoute.of(context)?.settings.name}"); // <<<--- REMOVED/COMMENTED THIS LINE
    print("[HomeScreen initState] Initializing HomeScreen."); // Safe print
    _generateFilterDates();
    _fetchInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Access ModalRoute here if needed for the first frame actions, though _scrollToSelectedDate doesn't use it.
      // print("[HomeScreen initState - postFrame] Current route: ${ModalRoute.of(context)?.settings.name}");
      if (mounted) _scrollToSelectedDate(isInitialLoad: true);
    });
  }

  // If you need to react to route changes or access ModalRoute early after initState:
  // bool _isFirstDidChangeDependencies = true;
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   if (_isFirstDidChangeDependencies) {
  //     _isFirstDidChangeDependencies = false;
  //     // It's safe to use ModalRoute.of(context) here.
  //     print("[HomeScreen didChangeDependencies] Initial call. Current route: ${ModalRoute.of(context)?.settings.name}");
  //   }
  // }

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
    // You can access ModalRoute here if needed for logic within this method
    // print("[HomeScreen _fetchInitialData] START. Current route: ${ModalRoute.of(context)?.settings.name}");
    await _fetchProfile();
    if (!mounted) return;

    if (_userRole == 'super_admin' && ModalRoute.of(context)?.settings.name != '/home') {
      print("[HomeScreen _fetchInitialData] Admin detected, but current route is not /home ('${ModalRoute.of(context)?.settings.name}'). Skipping further data load for this instance.");
      if (mounted) {
        setState(() { _isLoadingBetslips = false; _isLoadingPurchases = false; });
      }
      return;
    }
    print("[HomeScreen _fetchInitialData] Proceeding. Role: $_userRole, Route: ${ModalRoute.of(context)?.settings.name}");
    await _fetchUserPurchases();
    await _fetchBetslips();
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    // You can access ModalRoute.of(context).settings.name here too
    // print("[HomeScreen _fetchProfile] START. Current route: ${ModalRoute.of(context)?.settings.name}");
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
        // This print is safe here because it's after `await` and within the async method, not directly in initState's sync part.
        print("[HomeScreen _fetchProfile] Profile fetched. Role: $_userRole. Current Route from _fetchProfile: ${ModalRoute.of(context)?.settings.name}");
        // NO automatic redirect to /app_management from here.
        // InitialAuthCheckScreen handles primary routing for app start.
        // If an admin is on /home, it's because they chose to be (User Mode).
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

  Future<void> _fetchBetslips() async {
    if (!mounted) return;
    if (mounted) setState(() => _isLoadingBetslips = true);
    try {
      final data = await supabase.from('betslips').select().order('created_at', ascending: false);
      final List<Betslip> slips = data.map((item) {
        if (item is Map<String, dynamic>) return Betslip.fromJson(item);
        return null;
      }).whereType<Betslip>().toList();
      if (mounted) setState(() { _allBetslips = slips; _isLoadingBetslips = false; _applyDateFilter(); });
    } catch (e, s) {
      print("HomeScreen: Error fetching betslips: $e\n$s");
      if (mounted) {
        setState(() { _isLoadingBetslips = false; _allBetslips = []; _filteredBetslips = []; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching betslips: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
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
    await _fetchBetslips();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayForLabel = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // This print is safe as it's in the build method.
    final currentRouteName = ModalRoute.of(context)?.settings.name;
    print("[HomeScreen Build] Building UI. Role: $_userRole, Current Route from Build: $currentRouteName");

    if (_isLoadingProfile || (_userRole == null && supabase.auth.currentSession != null)) {
      print("[HomeScreen Build] Initial Profile Loading State in build.");
      return const Scaffold(body: Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenProfileLoadingBuild"))));
    }

    if (_userRole == 'super_admin' && currentRouteName != '/home') {
      print("[HomeScreen Build] Admin detected and current route is NOT /home ('$currentRouteName'). Showing loading; expecting navigation handled by InitialAuthCheck or drawer.");
      return const Scaffold(body: Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenAdminNotHomeRouteLoadingBuild"))));
    }

    final bool stillLoadingBetslipData = _isLoadingBetslips || _isLoadingPurchases;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text("BetCrack Feed")),
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
            Expanded(
              child: stillLoadingBetslipData
                  ? const Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenBetslipDataLoadingBuild")))
                  : _allBetslips == null
                  ? _buildErrorState(theme, "Could not load betslips.", "Please check your internet connection.")
                  : (_filteredBetslips == null || _filteredBetslips!.isEmpty)
                  ? _buildEmptyState(theme, todayForLabel)
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, color: theme.colorScheme.secondary, size: 60),
            const SizedBox(height: 16),
            Text(
              _allBetslips?.isEmpty ?? true ? "No Tips Posted Yet!" : "No Tips for ${_getFilterDateLabel(_selectedFilterDate, todayForLabel)}",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _allBetslips?.isEmpty ?? true ? "Check back soon for the latest tips." : "Check other dates or refresh the feed.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_allBetslips?.isEmpty ?? true ? "Refresh Feed" : "Refresh All"),
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: theme.colorScheme.onSecondary),
            )
          ],
        ),
      ),
    );
  }
}


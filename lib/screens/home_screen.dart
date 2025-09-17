// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Models
import '../models/betslip.dart';
import '../models/banner_item_model.dart';

// Widgets
import '../widgets/betslip_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/home_banner_carousel.dart';
import '../widgets/expandable_customer_support_fab.dart';

// Screens
import 'my_support_threads_screen.dart';
import 'create_new_thread_screen.dart';
import 'payment_methods_screen.dart';
import 'betslip_detail_screen.dart';
import 'payment_history_screen.dart';
import 'premium_slips_screen.dart';
import 'banner_detail_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

// Services
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';
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
  bool _isLoadingProfile = true;

  List<Betslip>? _allBetslips;
  List<Betslip>? _filteredRegularSlips;
  Map<String, bool> _purchaseStatus = {};
  bool _isLoadingBetslips = true;
  bool _isLoadingPurchases = true;

  List<BannerItem> _activeBanners = [];
  bool _isLoadingBanners = true;
  String? _bannerLoadingError;

  DateTime _selectedFilterDate = DateTime.now();
  final List<DateTime> _filterDates = [];
  static const int _numberOfPastDaysToShow = 7;
  static const int _numberOfFutureDaysToShow = 4;
  final ScrollController _dateFilterScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();

  bool _userHasUnreadSupportThreads = false;
  bool _isLoadingSupportThreadStatus = true;

  @override
  void initState() {
    super.initState();
    _generateFilterDates();
    _fetchInitialScreenData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelectedDate(isInitialLoad: true);
    });
  }

  @override
  void dispose() {
    _dateFilterScrollController.dispose();
    _mainScrollController.dispose();
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
    if (_filterDates.isEmpty || !_dateFilterScrollController.hasClients || !mounted) return;
    int selectedIndex = _filterDates.indexWhere((date) => DateUtils.isSameDay(_selectedFilterDate, date));

    if (selectedIndex != -1) {
      const double chipWidthEstimate = 105.0;
      const double spacing = 8.0;
      double screenWidth = MediaQuery.of(context).size.width;
      double scrollOffset = (selectedIndex * (chipWidthEstimate + spacing)) - (screenWidth / 2) + (chipWidthEstimate / 2);
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

  Future<void> _fetchInitialScreenData() async {
    await _fetchProfile();
    if (!mounted) return;
    await _checkUserSupportThreadsStatus();
    if (!mounted) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (_userRole == 'super_admin' && currentRoute != HomeScreen.routeName) {
      if (mounted) {
        setState(() {
          _isLoadingBetslips = false; _isLoadingPurchases = false; _isLoadingBanners = false;
        });
      }
      return;
    }
    await Future.wait([_fetchUserPurchases(), _fetchBetslips(), _fetchActiveBanners()]);
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _scrollToSelectedDate(isInitialLoad: true); });
  }

  Future<void> _fetchActiveBanners() async {
    if (!mounted) return;
    setState(() { _isLoadingBanners = true; _bannerLoadingError = null; });
    try {
      final response = await supabase.from('banners').select().eq('is_active', true).order('created_at', ascending: false);
      if (mounted) {
        final List<BannerItem> fetchedBanners = response.map((data) => BannerItem.fromMap(data as Map<String, dynamic>)).toList();
        setState(() { _activeBanners = fetchedBanners; _isLoadingBanners = false; });
      }
    } catch (e) {
      if (mounted) {
        print("HomeScreen: Error fetching active banners: $e");
        setState(() { _isLoadingBanners = false; _bannerLoadingError = "Failed to load promotional content."; });
      }
    }
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
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
      }
    } catch (e, s) {
      print("HomeScreen: Error fetching profile: $e\n$s");
      if (mounted) {
        setState(() { _username = 'Error'; _phone = 'Error'; _userRole = 'user'; _isLoadingProfile = false; });
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching profile: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
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
    setState(() => _isLoadingBetslips = true);
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
        setState(() { _isLoadingBetslips = false; _allBetslips = []; _filteredRegularSlips = []; });
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching betslips: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  // --- DEFINITIVELY CORRECTED Method to check if user has any UNREAD support threads ---
  Future<void> _checkUserSupportThreadsStatus() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _userHasUnreadSupportThreads = false;
          _isLoadingSupportThreadStatus = false;
        });
      }
      return;
    }

    if (mounted && !_isLoadingSupportThreadStatus) {
      setState(() => _isLoadingSupportThreadStatus = true);
    }

    try {
      // Chain filters and then call .count()
      final countResponse = await supabase
          .from('support_threads')
          .select() // Select is needed before count() in some versions, or just use .count() directly on PostgrestFilterBuilder
          .eq('user_id', userId)
          .eq('is_read_by_user', false)
          .eq('status', 'pending_user_reply')
          .count(CountOption.exact); // <<< Use .count() method with CountOption

      if (mounted) {
        // The .count() method directly returns an object from which .count can be extracted,
        // or for some client versions it might directly be the int.
        // Supabase an object of type PostgrestResponse with a count field.
        final int count = countResponse.count;

        setState(() {
          _userHasUnreadSupportThreads = count > 0;
          _isLoadingSupportThreadStatus = false;
        });
      }
    } catch (e, stackTrace) {
      print("Error checking user support thread status: $e");
      print("Stack trace for support thread status error: $stackTrace");
      if (mounted) {
        setState(() {
          _userHasUnreadSupportThreads = false;
          _isLoadingSupportThreadStatus = false;
        });
      }
    }
  }
  // --- END DEFINITIVELY CORRECTED Method ---

  void _applyDateFilter() {
    if (_allBetslips == null) {
      if (mounted) setState(() => _filteredRegularSlips = []);
      return;
    }
    _filteredRegularSlips = _allBetslips!.where((slip) {
      if (slip.isPremium) return false;
      if (slip.createdAt == null) return false;
      final createdAtDate = DateTime(slip.createdAt!.year, slip.createdAt!.month, slip.createdAt!.day);
      final filterDateNormalized = DateTime(_selectedFilterDate.year, _selectedFilterDate.month, _selectedFilterDate.day);
      return createdAtDate.isAtSameMomentAs(filterDateNormalized);
    }).toList();
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
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true; _isLoadingSupportThreadStatus = true; _isLoadingBetslips = true;
      _isLoadingPurchases = true; _isLoadingBanners = true; _bannerLoadingError = null;
    });
    await _fetchProfile();
    if (!mounted) return;
    await _checkUserSupportThreadsStatus();
    if (!mounted) return;
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (_userRole == 'super_admin' && currentRoute != HomeScreen.routeName) {
      setState(() { _isLoadingBetslips = false; _isLoadingPurchases = false; _isLoadingBanners = false; });
      return;
    }
    await Future.wait([_fetchUserPurchases(), _fetchBetslips(), _fetchActiveBanners()]);
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _scrollToSelectedDate(); });
  }

  void _onDateFilterChanged(DateTime newDate) {
    if (mounted) {
      setState(() { _selectedFilterDate = DateTime(newDate.year, newDate.month, newDate.day); _applyDateFilter(); });
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _scrollToSelectedDate(); });
    }
  }

  void _logout() async {
    try {
      await _auth.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error logging out: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  void _handleLockedClick(Betslip slip) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentMethodsScreen(betslipToPurchase: slip)))
        .then((paymentResult) { if (paymentResult == true) _refreshData(); });
  }

  void _navigateToPaymentHistory() {
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()));
  }

  void _navigateToGeneralSettings() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _navigateToMySupportThreads() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MySupportThreadsScreen()))
        .then((_) => _checkUserSupportThreadsStatus());
  }

  String _getFilterDateLabel(DateTime date, DateTime today) {
    if (DateUtils.isSameDay(date, today)) return "Today";
    if (DateUtils.isSameDay(date, today.subtract(const Duration(days: 1)))) return "Yesterday";
    if (DateUtils.isSameDay(date, today.add(const Duration(days: 1)))) return "Tomorrow";
    return DateFormat('EEE, d MMM').format(date);
  }

  void _navigateToPremiumPackages() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumSlipsScreen()));
  }

  void _onBannerTap(BannerItem banner) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BannerDetailScreen(banner: banner)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayForLabel = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    bool showFullScreenLoader = (_isLoadingProfile || _isLoadingSupportThreadStatus) && supabase.auth.currentUser != null;

    if (showFullScreenLoader) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenEssentialLoadingBuild"))));
    }

    final bool stillLoadingMainBetslipData = _isLoadingBetslips || _isLoadingPurchases;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("BetCrack Feed"),
        elevation: 1,
        actions: [
          TextButton.icon(
            onPressed: _navigateToPremiumPackages,
            icon: Icon(Icons.star_purple500_outlined, color: theme.colorScheme.onPrimary),
            label: Text("Premium", style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(
        username: _username, phone: _phone, userRole: _userRole, isLoadingProfile: _isLoadingProfile,
        onLogout: _logout,
        onNavigateToUserModeHome: _userRole == 'super_admin' ? () {
          Navigator.pop(context);
          if (ModalRoute.of(context)?.settings.name != HomeScreen.routeName) Navigator.pushReplacementNamed(context, HomeScreen.routeName);
        } : null,
        onNavigateToAppManagement: _userRole == 'super_admin' ? () {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, '/app_management');
        } : null,
        onNavigateToPaymentHistory: () { Navigator.pop(context); _navigateToPaymentHistory(); },
        onNavigateToSettings: _navigateToGeneralSettings,
        hasUnreadSupportThreads: _userHasUnreadSupportThreads,
        onNavigateToMySupportThreads: _navigateToMySupportThreads,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surface,
          child: CustomScrollView(
            controller: _mainScrollController,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  color: ElevationOverlay.applySurfaceTint(theme.colorScheme.surface, theme.colorScheme.surfaceTint, 1.0),
                  child: SizedBox(
                    height: 45,
                    child: ListView.separated(
                      controller: _dateFilterScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: _filterDates.length,
                      itemBuilder: (context, index) {
                        final date = _filterDates[index];
                        final isSelected = DateUtils.isSameDay(_selectedFilterDate, date);
                        return ChoiceChip(
                          label: Text(_getFilterDateLabel(date, todayForLabel)),
                          selected: isSelected,
                          onSelected: (selected) { if (selected) _onDateFilterChanged(date); },
                          backgroundColor: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : theme.colorScheme.surfaceVariant.withOpacity(0.6),
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.4), width: 1.2),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
                          visualDensity: VisualDensity.comfortable, elevation: isSelected ? 2 : 0,
                        );
                      },
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1, thickness: 0.5)),
              if (_isLoadingBanners)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenBannerLoading")))))
              else if (_bannerLoadingError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 30),
                      const SizedBox(height: 8),
                      Text(_bannerLoadingError!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _fetchActiveBanners, child: const Text("Retry"))
                    ]),
                  ),
                )
              else if (_activeBanners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: HomeBannerCarousel(key: ValueKey(_activeBanners.map((b) => b.id).join(',')), banners: _activeBanners, onBannerTap: _onBannerTap),
                    ),
                  ),
              stillLoadingMainBetslipData
                  ? const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenRegularSlipsLoading"))))
                  : _allBetslips == null
                  ? SliverFillRemaining(hasScrollBody: false, child: _buildErrorState(theme, "Could Not Load Tips", "Failed to fetch tips data. Please try again."))
                  : (_filteredRegularSlips == null || _filteredRegularSlips!.isEmpty)
                  ? SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(theme, todayForLabel))
                  : SliverPadding(
                padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 80.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final slip = _filteredRegularSlips![index];
                      final isUserPurchasedThisSlip = _purchaseStatus[slip.id] ?? false;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: BetslipCard(
                          betslip: slip, isPurchased: isUserPurchasedThisSlip, isAdminView: false,
                          onTapCard: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BetslipDetailScreen(betslip: slip, isPurchased: isUserPurchasedThisSlip))).then((_) => _fetchUserPurchases()),
                          onTapLocked: () => _handleLockedClick(slip),
                        ),
                      );
                    },
                    childCount: _filteredRegularSlips!.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ExpandableCustomerSupportFab(
        onNewTicketPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateNewThreadScreen()))
              .then((success) { if (success == true) _checkUserSupportThreadsStatus(); });
        },
        onViewTicketsPressed: _navigateToMySupportThreads,
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String title, String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5, alignment: Alignment.center,
        padding: const EdgeInsets.all(20.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 50),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(icon: const Icon(Icons.refresh_rounded), label: const Text("Retry Load"), onPressed: _refreshData, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)))
        ]),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, DateTime todayForLabel) {
    String message = "No regular tips for ${_getFilterDateLabel(_selectedFilterDate, todayForLabel)} yet.";
    if (_allBetslips != null && _allBetslips!.where((s) => !s.isPremium).isEmpty) {
      message = "No regular tips currently posted by Admin.";
    } else if (_allBetslips == null) {
      message = "Tips are currently unavailable. Please try again.";
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5, alignment: Alignment.center,
        padding: const EdgeInsets.all(20.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(Icons.event_busy_outlined, color: theme.colorScheme.secondary, size: 60),
          const SizedBox(height: 20),
          Text(message, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text("Try other dates or explore our Premium Packages for exclusive tips!", textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(icon: const Icon(Icons.refresh_rounded), label: const Text("Refresh Feed"), onPressed: _refreshData, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10))),
            const SizedBox(width: 12),
            ElevatedButton.icon(icon: Icon(Icons.star_purple500_outlined, color: theme.colorScheme.onPrimary), label: Text("Premium Tips", style: TextStyle(color: theme.colorScheme.onPrimary)), onPressed: _navigateToPremiumPackages, style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)))
          ])
        ]),
      ),
    );
  }
}


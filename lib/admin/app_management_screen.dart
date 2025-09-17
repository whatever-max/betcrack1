// lib/admin/app_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your existing admin screens
import 'upload_betslip_screen.dart';
import 'user_management_screen.dart';
import 'admin_view_posted_slips.dart';
import 'admin_view_purchases_screen.dart';
import 'screens/manage_banners_screen.dart'; // Ensure this path is correct if in 'admin/screens/'

// Import the AdminSupportThreadsListScreen
import 'admin_support_threads_list_screen.dart'; // <<< MAKE SURE THIS PATH IS CORRECT

// Shared widgets and screens
import '../widgets/app_drawer.dart';
import '../screens/home_screen.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/payment_history_screen.dart';
import '../screens/settings_screen.dart';

class AppManagementScreen extends StatefulWidget {
  static const String routeName = '/app_management';
  const AppManagementScreen({super.key});

  @override
  State<AppManagementScreen> createState() => _AppManagementScreenState();
}

class _AppManagementScreenState extends State<AppManagementScreen> {
  final supabase = Supabase.instance.client;
  final AuthService _auth = AuthService();

  String? _username;
  String? _phone;
  String? _userRole;
  bool _isLoadingProfile = true;

  double _dailyIncome = 0.0;
  double _monthlyIncome = 0.0;
  double _totalIncome = 0.0;
  bool _isLoadingIncome = true;
  String _incomeError = '';

  @override
  void initState() {
    super.initState();
    _fetchAdminProfile();
    _fetchIncomeAnalytics();
  }

  Future<void> _fetchAdminProfile() async {
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
          _username = res['username'] as String? ?? 'Admin';
          _phone = res['phone'] as String? ?? 'No phone';
          _userRole = res['role'] as String? ?? 'user';
          _isLoadingProfile = false;
        });
        if (_userRole != 'super_admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      print("AppManagementScreen: Error fetching profile: $e");
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error loading admin profile: ${e.toString()}")));
        await _auth.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  Future<void> _fetchIncomeAnalytics() async {
    if (!mounted) return;
    setState(() {
      _isLoadingIncome = true;
      _incomeError = '';
    });
    try {
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dailyResult = await supabase
          .rpc('calculate_daily_income', params: {'p_date': todayDate});
      if (mounted) _dailyIncome = (dailyResult as num?)?.toDouble() ?? 0.0;

      final now = DateTime.now();
      final monthlyResult = await supabase.rpc('calculate_monthly_income',
          params: {'p_year': now.year, 'p_month': now.month});
      if (mounted) _monthlyIncome = (monthlyResult as num?)?.toDouble() ?? 0.0;

      final totalResult = await supabase.rpc('calculate_total_income');
      if (mounted) _totalIncome = (totalResult as num?)?.toDouble() ?? 0.0;
    } on PostgrestException catch (e) {
      print('Supabase RPC Error fetching income: ${e.message}');
      if (mounted) {
        _incomeError =
        'Failed to load income: RPC error. Ensure functions are set up and permissions are correct.';
      }
    } catch (e) {
      print('Generic Error fetching income: $e');
      if (mounted) {
        _incomeError = 'An unexpected error occurred loading income.';
      }
    } finally {
      if (mounted) setState(() => _isLoadingIncome = false);
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
      print("Logout error from AppManagementScreen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error logging out: ${e.toString()}")));
      }
    }
  }

  void _copyIncomeToClipboard() {
    final currencyFormat =
    NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);
    String incomeText = "Income Summary (BetCrack):\n"
        "Today: ${currencyFormat.format(_dailyIncome)}\n"
        "This Month: ${currencyFormat.format(_monthlyIncome)}\n"
        "All Time: ${currencyFormat.format(_totalIncome)}";
    Clipboard.setData(ClipboardData(text: incomeText)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Income summary copied to clipboard!')),
      );
    });
  }

  Widget _buildManagementCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: backgroundColor ?? theme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor:
                (iconColor ?? theme.colorScheme.primary).withOpacity(0.15),
                child: Icon(icon,
                    size: 28.0, color: iconColor ?? theme.colorScheme.primary),
              ),
              const SizedBox(height: 12.0),
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4.0),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeInfoCard(BuildContext context, String title, double amount,
      {bool isLoading = false}) {
    final theme = Theme.of(context);
    final currencyFormat =
    NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor.withOpacity(0.5))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            isLoading
                ? const SizedBox(
                height: 22,
                child: LinearProgressIndicator(
                    minHeight: 3,
                    valueColor:
                    AlwaysStoppedAnimation(Colors.blueAccent)))
                : Text(
              currencyFormat.format(amount),
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToUserMode() {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => const HomeScreen(),
            settings: const RouteSettings(name: HomeScreen.routeName)),
            (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_userRole != 'super_admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
          );
        }
      });
      return const Scaffold(
          body: Center(child: Text("Redirecting... Not Admin.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 1,
      ),
      drawer: AppDrawer(
        username: _username,
        phone: _phone,
        userRole: _userRole,
        isLoadingProfile: _isLoadingProfile,
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
        onNavigateToUserModeHome: () {
          Navigator.pop(context);
          _navigateToUserMode();
        },
        onNavigateToAppManagement: () {
          Navigator.pop(context);
        },
        onNavigateToPaymentHistory: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()));
        },
        onNavigateToSettings: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()));
        },
        hasUnreadSupportThreads: false,
        onNavigateToMySupportThreads: null,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchIncomeAnalytics,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 70.0),
          children: <Widget>[
            Text("Financial Overview",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Revenue Snapshot",
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w500)),
                        if (!_isLoadingIncome && _incomeError.isEmpty)
                          IconButton(
                            icon: Icon(Icons.copy_all_outlined,
                                size: 22, color: theme.colorScheme.primary),
                            tooltip: "Copy Income Summary",
                            onPressed: _copyIncomeToClipboard,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                      ],
                    ),
                    const Divider(height: 20, thickness: 0.8),
                    if (_incomeError.isNotEmpty && !_isLoadingIncome)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(children: [
                          Icon(Icons.warning_amber_rounded,
                              color: theme.colorScheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_incomeError,
                                  style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 13))),
                        ]),
                      ),
                    Row(
                      children: [
                        _buildIncomeInfoCard(
                            context, "Today's Income", _dailyIncome,
                            isLoading: _isLoadingIncome),
                        const SizedBox(width: 12),
                        _buildIncomeInfoCard(
                            context, "This Month", _monthlyIncome,
                            isLoading: _isLoadingIncome),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildIncomeInfoCard(
                            context, "All Time Income", _totalIncome,
                            isLoading: _isLoadingIncome),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text("Content & User Management",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 12.0,
              childAspectRatio: 0.95,
              children: <Widget>[
                _buildManagementCard(
                  context: context,
                  icon: Icons.cloud_upload_outlined,
                  title: 'Upload Betslip',
                  subtitle: 'Create & publish new betting tips for users.',
                  iconColor: Colors.blueAccent[700],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UploadBetslipScreen())),
                ),
                _buildManagementCard(
                  context: context,
                  icon: Icons.article_outlined,
                  title: 'View Posted Slips',
                  subtitle: 'Review, filter, and manage all posted slips.',
                  iconColor: Colors.orangeAccent[700],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminViewPostedSlipsScreen())),
                ),
                _buildManagementCard(
                  context: context,
                  icon: Icons.photo_library_outlined,
                  title: 'Manage Banners',
                  subtitle: 'Add, update, or remove promotional banners.',
                  iconColor: Colors.teal[600],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageBannersScreen())),
                ),
                _buildManagementCard(
                  context: context,
                  icon: Icons.support_agent_outlined,
                  title: 'Support Inbox',
                  subtitle: 'View and reply to user support messages.',
                  iconColor: Colors.purple[600],
                  // MODIFIED: Navigate to AdminSupportThreadsListScreen
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminSupportThreadsListScreen())),
                ),
                _buildManagementCard(
                  context: context,
                  icon: Icons.group_outlined,
                  title: 'User Management',
                  subtitle: 'View analytics & manage platform users.',
                  iconColor: Colors.green[700],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserManagementScreen())),
                ),
                _buildManagementCard(
                  context: context,
                  icon: Icons.receipt_long_outlined,
                  title: 'View Purchases',
                  subtitle: 'Monitor all payment transactions and history.',
                  iconColor: Colors.redAccent[400],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminViewPurchasesScreen())),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

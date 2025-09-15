// lib/screens/premium_slips_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For NumberFormat
import 'package:fluttertoast/fluttertoast.dart'; // <<<--- ADDED THIS IMPORT
import '../models/betslip.dart';
import '../widgets/betslip_card.dart';
import 'payment_methods_screen.dart';
import 'betslip_detail_screen.dart';

class PremiumSlipsScreen extends StatefulWidget {
  const PremiumSlipsScreen({super.key});

  @override
  State<PremiumSlipsScreen> createState() => _PremiumSlipsScreenState();
}

class _PremiumSlipsScreenState extends State<PremiumSlipsScreen> {
  final supabase = Supabase.instance.client;
  List<Betslip> _premiumSlips = [];
  bool _isLoading = true;
  String? _userId;
  Map<String, bool> _purchaseStatus = {};

  @override
  void initState() {
    super.initState();
    _userId = supabase.auth.currentUser?.id;
    _refreshAllData(); // Initial fetch
  }

  Future<void> _fetchUserPurchases() async {
    if (_userId == null || !mounted) return;
    try {
      final data = await supabase
          .from('purchases')
          .select('betslip_id')
          .eq('user_id', _userId!)
          .eq('status', 'completed');

      final Map<String, bool> status = {};
      for (var item in data) {
        if (item['betslip_id'] != null) {
          status[item['betslip_id'] as String] = true;
        }
      }
      if (mounted) {
        setState(() {
          _purchaseStatus = status;
        });
      }
    } catch (e) {
      print("Error fetching user purchases for premium screen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load your purchase status: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchPremiumSlips() async {
    if (!mounted) return;
    try {
      final data = await supabase
          .from('betslips')
          .select()
          .eq('is_premium', true)
          .order('created_at', ascending: false);

      final List<Betslip> slips = data.map((item) {
        if (item is Map<String, dynamic>) return Betslip.fromJson(item);
        return null;
      }).whereType<Betslip>().toList();

      if (mounted) {
        setState(() {
          _premiumSlips = slips;
        });
      }
    } catch (e, s) {
      print("Error fetching premium betslips: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading premium slips: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _fetchPremiumSlips();
    if (_userId != null && mounted) {
      await _fetchUserPurchases();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handlePremiumLockedClick(Betslip slip) {
    if (slip.isExpired) {
      Fluttertoast.showToast(msg: "This premium package has expired and cannot be purchased.");
      return;
    }
    Navigator.push(
      context, MaterialPageRoute(builder: (_) => PaymentMethodsScreen(betslipToPurchase: slip)),
    ).then((paymentResult) {
      if (paymentResult == true && mounted) {
        setState(() {
          _purchaseStatus[slip.id] = true; // Optimistic update
        });
        _fetchUserPurchases(); // Re-verify
      }
    });
  }

  void _showRefundInfoPopup() {
    final theme = Theme.of(context);
    // Basic check for Swahili. For a real app, use Flutter's localization system.
    bool isSwahili = Localizations.localeOf(context).languageCode == 'sw';

    String titleText = isSwahili ? "Dhamana ya Kurejeshewa Pesa" : "Refund Guarantee";
    String contentText = isSwahili
        ? "Kwa ununuzi wowote utakaofanywa kwenye Kifurushi cha Premium, ikiwa bahati mbaya tiketi haitashinda, kiasi ulicholipa kwa kifurushi hicho, pamoja na asilimia yoyote ya bonasi iliyoainishwa, kitarejeshwa kwako. Iwapo mchezo utawekwa kama batili (void), hautakuwa na matokeo, au hautachezwa, marejesho yatatolewa lakini yanaweza kupungua kutokana na mabadiliko ya odds. Vigezo na masharti kuzingatiwa."
        : "For any purchase made on a Premium Package, if the betslip unfortunately does not win, the amount you paid for the package, plus any specified bonus percentage, will be refunded to you. If the game has been placed as void, has no results, or has not been played, the refund will be made but it may decrease due to odds changes. Terms and conditions may apply.";
    String okButtonText = isSwahili ? "SAWA, NIMEKIPATA!" : "OK, GOT IT!";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 10),
            Text(titleText, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            contentText,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        actions: [
          TextButton(
            child: Text(okButtonText),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Premium Packages"),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: theme.colorScheme.onPrimary),
            tooltip: "Refund Information",
            onPressed: _showRefundInfoPopup,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _premiumSlips.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_outline_rounded, size: 60, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              Text("No Premium Packages Available Yet", style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("Check back soon for exclusive premium tips with refund guarantees!", textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Refresh"),
                onPressed: _refreshAllData,
              )
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshAllData,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
          itemCount: _premiumSlips.length,
          itemBuilder: (context, index) {
            final slip = _premiumSlips[index];
            final isPurchased = _purchaseStatus[slip.id] ?? false;
            return BetslipCard(
              betslip: slip,
              isPurchased: isPurchased,
              isAdminView: false, // This screen is user-facing
              onTapCard: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BetslipDetailScreen(
                      betslip: slip,
                      isPurchased: isPurchased,
                    ),
                  ),
                ).then((_){
                  if (mounted) _fetchUserPurchases(); // Refresh purchase status on return
                });
              },
              onTapLocked: () => _handlePremiumLockedClick(slip),
            );
          },
        ),
      ),
    );
  }
}


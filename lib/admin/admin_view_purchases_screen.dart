// lib/admin/admin_view_purchases_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminViewPurchasesScreen extends StatefulWidget {
  const AdminViewPurchasesScreen({super.key});

  @override
  State<AdminViewPurchasesScreen> createState() =>
      _AdminViewPurchasesScreenState();
}

class _AdminViewPurchasesScreenState extends State<AdminViewPurchasesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;
  String _searchTerm = '';
  String _filterStatus = 'completed'; // Default filter
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_searchTerm != _searchController.text) {
        setState(() {
          _searchTerm = _searchController.text;
        });
        _fetchPurchases();
      }
    });
  }

  Future<void> _fetchPurchases({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      // Start with the base query
      var query = supabase.from('purchases');

      // Construct the select string
      // Always select core purchase fields. Conditionally join others if needed for display or search.
      String selectString = '''
        id, 
        created_at, 
        status, 
        phone, 
        payment_method,
        user_id,
        betslip_id,
        profiles ( username ), 
        betslips ( title, price ) 
      ''';

      // Apply filters first on a PostgrestQueryBuilder (from .from())
      // or PostgrestFilterBuilder (from .select().<filters>)
      // For .or(), it's typically easier to apply it after .select() and before .order()

      PostgrestFilterBuilder filterBuilder = query.select(selectString);

      if (_filterStatus.isNotEmpty) {
        filterBuilder = filterBuilder.eq('status', _filterStatus);
      }

      if (_searchTerm.isNotEmpty) {
        final searchPattern = '%$_searchTerm%';
        // Apply OR conditions for searching across multiple fields
        // Note: For searching related table fields (profiles.username, betslips.title),
        // Supabase handles this by knowing the relationship from the select string.
        filterBuilder = filterBuilder.or(
            'phone.ilike.$searchPattern,'
                'profiles.username.ilike.$searchPattern,' // This targets the joined profiles table
                'betslips.title.ilike.$searchPattern,'   // This targets the joined betslips table
                'id::text.ilike.$searchPattern'          // Search by purchase ID (cast UUID to text)
        );
      }

      // Finally, apply ordering and execute.
      final data = await filterBuilder.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _purchases = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e, s) {
      print("Error fetching purchases for admin: $e\n$s");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error fetching purchases: ${e.toString()}")));
      }
    }
  }

  void _showPurchaseDetailsDialog(Map<String, dynamic> purchase) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d, yyyy HH:mm:ss');
    final currencyFormat = NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);

    final profileData = purchase['profiles'] as Map<String,dynamic>?;
    final betslipData = purchase['betslips'] as Map<String,dynamic>?;

    String detailsText = "Purchase ID: ${purchase['id']}\n"
        "Timestamp: ${dateFormat.format(DateTime.parse(purchase['created_at']))}\n"
        "Status: ${(purchase['status'] as String?)?.toUpperCase() ?? 'N/A'}\n"
        "Payment Method: ${purchase['payment_method'] ?? 'N/A'}\n"
        "User Provided Phone: ${purchase['phone'] ?? 'N/A'}\n"
        "------------------------------------\n"
        "User ID: ${purchase['user_id'] ?? 'N/A'}\n"
        "Username: ${profileData?['username'] ?? 'N/A'}\n"
        "------------------------------------\n"
        "Betslip ID: ${purchase['betslip_id'] ?? 'N/A'}\n"
        "Betslip Title: ${betslipData?['title'] ?? 'N/A'}\n"
        "Amount Paid: ${betslipData?['price'] != null ? currencyFormat.format(betslipData!['price']) : 'N/A'}";

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text("Purchase Details", style: theme.textTheme.titleLarge),
            content: SingleChildScrollView(
              child: SelectableText(detailsText, style: theme.textTheme.bodyMedium),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Copy Details'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: detailsText));
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Purchase details copied!'))
                  );
                },
              ),
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM, HH:mm');
    final currencyFormat = NumberFormat.compactCurrency(locale: 'en_TZ', symbol: 'TZS');

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Purchases"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search user, phone, slip...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      icon: const Icon(Icons.filter_list_alt, size: 20),
                      items: ['all', 'completed', 'pending', 'failed']
                          .map((status) => DropdownMenuItem(
                        value: status == 'all' ? '' : status,
                        child: Text(status.toUpperCase(), style: theme.textTheme.bodyMedium),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() { _filterStatus = value; });
                        _fetchPurchases();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
          ? Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          "No purchases found for status '${_filterStatus.isEmpty ? "ALL" : _filterStatus.toUpperCase()}'${_searchTerm.isNotEmpty ? ' matching "$_searchTerm"' : ''}.",
          textAlign: TextAlign.center, style: theme.textTheme.titleMedium,
        ),
      ))
          : RefreshIndicator(
        onRefresh: () => _fetchPurchases(showLoading: false),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
          itemCount: _purchases.length,
          itemBuilder: (context, index) {
            final purchase = _purchases[index];
            final profileData = purchase['profiles'] as Map<String,dynamic>?;
            final betslipData = purchase['betslips'] as Map<String,dynamic>?;
            final purchaseDate = DateTime.parse(purchase['created_at']);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: purchase['status'] == 'completed'
                      ? Colors.green.withOpacity(0.15)
                      : (purchase['status'] == 'pending'
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15)),
                  child: Icon(
                    purchase['status'] == 'completed'
                        ? Icons.check_circle
                        : (purchase['status'] == 'pending'
                        ? Icons.hourglass_top_rounded
                        : Icons.error_rounded),
                    color: purchase['status'] == 'completed'
                        ? Colors.green[700]
                        : (purchase['status'] == 'pending'
                        ? Colors.orange[700]
                        : Colors.red[700]),
                    size: 22,
                  ),
                ),
                title: Text(
                  "User: ${profileData?['username'] ?? 'ID: ...${(purchase['user_id'] as String?)?.substring((purchase['user_id'] as String?)?.length ?? 5 - 5) ?? 'N/A'}'}",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "Slip: ${betslipData?['title'] ?? 'ID: ...${(purchase['betslip_id'] as String?)?.substring((purchase['betslip_id'] as String?)?.length ?? 5 - 5) ?? 'N/A'}'}\n"
                      "${purchase['payment_method']?.toUpperCase() ?? ''} on ${dateFormat.format(purchaseDate.toLocal())}",
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        betslipData?['price'] != null ? currencyFormat.format(betslipData!['price']) : "N/A",
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13)
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (purchase['status'] as String?)?.toUpperCase() ?? 'N/A',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: purchase['status'] == 'completed' ? Colors.green[700] : (purchase['status'] == 'pending' ? Colors.orange[700] : Colors.red[700]),
                          fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () => _showPurchaseDetailsDialog(purchase),
              ),
            );
          },
        ),
      ),
    );
  }
}


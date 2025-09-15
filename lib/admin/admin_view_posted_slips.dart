// lib/admin/admin_view_posted_slips.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/betslip.dart';
import '../widgets/betslip_card.dart'; // Ensure this is the updated BetslipCard
import 'upload_betslip_screen.dart';

class AdminViewPostedSlipsScreen extends StatefulWidget {
  const AdminViewPostedSlipsScreen({super.key});

  @override
  State<AdminViewPostedSlipsScreen> createState() =>
      _AdminViewPostedSlipsScreenState();
}

class _AdminViewPostedSlipsScreenState
    extends State<AdminViewPostedSlipsScreen> {
  final supabase = Supabase.instance.client;
  List<Betslip> _allBetslips = [];
  List<Betslip> _filteredBetslips = [];
  bool _isLoading = true;

  DateTime? _selectedFilterDate; // Nullable, if null show all
  final ScrollController _dateFilterScrollController = ScrollController();
  List<DateTime?> _filterDates = [];

  @override
  void initState() {
    super.initState();
    _generateFilterDates();
    _fetchBetslips();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDateChip();
    });
  }

  @override
  void dispose() {
    _dateFilterScrollController.dispose();
    super.dispose();
  }

  void _generateFilterDates() {
    _filterDates.clear();
    _filterDates.add(null); // Option for "Show All"

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Add past 14 days (including today)
    for (int i = 0; i < 14; i++) {
      _filterDates.add(today.subtract(Duration(days: i)));
    }
    // Add next 7 days
    for (int i = 1; i <= 7; i++) {
      _filterDates.add(today.add(Duration(days: i)));
    }
    // Remove duplicates that might occur if today is added twice, then sort
    _filterDates = _filterDates.toSet().toList();


    _filterDates.sort((a, b) {
      if (a == null) return -1; // "Show All" always first
      if (b == null) return 1;
      return b.compareTo(a); // Newest non-null first
    });
    _selectedFilterDate = null; // Default to "Show All"
  }


  void _scrollToSelectedDateChip() {
    if (_filterDates.isEmpty || !_dateFilterScrollController.hasClients) return;
    int selectedIndex = _filterDates.indexWhere((date) =>
    (_selectedFilterDate == null && date == null) ||
        (_selectedFilterDate != null && date != null && date.isAtSameMomentAs(_selectedFilterDate!)));

    if (selectedIndex != -1) {
      const double chipWidth = 110.0; // Approximate width of a ChoiceChip
      const double spacing = 8.0;    // Approximate spacing between chips
      double scrollOffset = (selectedIndex * (chipWidth + spacing)) - (MediaQuery.of(context).size.width / 3); // Try to center it a bit

      scrollOffset = scrollOffset.clamp(
          _dateFilterScrollController.position.minScrollExtent,
          _dateFilterScrollController.position.maxScrollExtent);

      _dateFilterScrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }


  Future<void> _fetchBetslips() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('betslips')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        _allBetslips = data.map((item) {
          if (item is Map<String, dynamic>) { // Ensure correct type
            return Betslip.fromJson(item);
          }
          print("Warning: Unexpected item type in betslips data: $item");
          return null;
        }).whereType<Betslip>().toList(); // Filter out any nulls

        _applyDateFilter(); // This will set _filteredBetslips
        setState(() => _isLoading = false);
      }
    } catch (e,s) {
      print("Error fetching betslips for admin: $e\n$s");
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching slips: ${e.toString()}")));
    }
  }

  void _applyDateFilter() {
    if (_selectedFilterDate == null) {
      _filteredBetslips = List.from(_allBetslips);
    } else {
      _filteredBetslips = _allBetslips.where((slip) {
        if (slip.createdAt == null) return false;
        final createdAtDate = DateTime(slip.createdAt!.year, slip.createdAt!.month, slip.createdAt!.day);
        return createdAtDate.isAtSameMomentAs(_selectedFilterDate!);
      }).toList();
    }
    if (mounted) setState(() {});
  }

  void _onDateFilterChanged(DateTime? newDate) {
    if (mounted) {
      setState(() {
        _selectedFilterDate = newDate;
        _applyDateFilter();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDateChip());
    }
  }


  Future<void> _deleteSlip(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Slip"),
        content: Text("Are you sure you want to delete the slip \"$title\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('betslips').delete().eq('id', id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Slip \"$title\" deleted.")));
        _fetchBetslips(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete slip: ${e.toString()}")));
      }
    }
  }

  String _getFilterDateChipLabel(DateTime? date) {
    if (date == null) return "All Dates";
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (date.isAtSameMomentAs(today)) return "Today";
    if (date.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) return "Yesterday";
    return DateFormat('EEE, d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Posted Slips"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text("Post Slip"),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadBetslipScreen()))
              .then((value) {
            if (value == true) _fetchBetslips(); // Refresh if pop indicates success
          });
        },
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            color: ElevationOverlay.applySurfaceTint(theme.colorScheme.surface, theme.colorScheme.surfaceTint, 1.0),
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                controller: _dateFilterScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                scrollDirection: Axis.horizontal,
                itemCount: _filterDates.length,
                itemBuilder: (context, index) {
                  final date = _filterDates[index];
                  final bool isSelected = (_selectedFilterDate == null && date == null) ||
                      (_selectedFilterDate != null && date != null && date.isAtSameMomentAs(_selectedFilterDate!));
                  return ChoiceChip(
                    label: Text(_getFilterDateChipLabel(date)),
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
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allBetslips.isEmpty
                ? Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("No betslips posted yet. Click '+' to add one.", textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            ))
                : _filteredBetslips.isEmpty
                ? Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("No betslips found for ${_getFilterDateChipLabel(_selectedFilterDate)}.", textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            ))
                : RefreshIndicator(
              onRefresh: _fetchBetslips,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0), // Padding for FAB
                itemCount: _filteredBetslips.length,
                itemBuilder: (context, index) {
                  final slip = _filteredBetslips[index];
                  return BetslipCard(
                    betslip: slip,
                    isPurchased: true, // Admin always sees details
                    isAdminView: true, // <<<--- This is used here
                    onDelete: () => _deleteSlip(slip.id, slip.title), // <<<--- And here
                    onTapCard: () {
                      // Optionally, navigate to an edit screen or detail view
                      // For now, admin card might not need a specific onTapCard
                      // if delete is the primary action from the list.
                      print("Admin tapped on card: ${slip.title}");
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


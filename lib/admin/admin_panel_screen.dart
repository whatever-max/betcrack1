/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/betslip.dart';
import '../widgets/betslip_card.dart';
import 'upload_betslip_screen.dart';
import 'user_management_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final supabase = Supabase.instance.client;

  List<Betslip> betslips = [];
  int totalUsers = 0;

  Future<void> fetchAllData() async {
    final betslipRes = await supabase
        .from('betslips')
        .select()
        .order('created_at', ascending: false);

    final usersRes = await supabase.from('profiles').select('id');

    setState(() {
      betslips = betslipRes.map<Betslip>((json) => Betslip.fromJson(json)).toList();
      totalUsers = usersRes.length;
    });
  }

  Future<void> deleteSlip(String id) async {
    await supabase.from('betslips').delete().eq('id', id);
    fetchAllData();
  }

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel - BetCrack"),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Post Slip"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UploadBetslipScreen()),
          ).then((_) => fetchAllData());
        },
      ),
      body: RefreshIndicator(
        onRefresh: fetchAllData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: const Text("Total Users"),
                trailing: Text("$totalUsers"),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "All Betslips",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (betslips.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text("No betslips posted yet."),
              )),
            ...betslips.map((slip) => Dismissible(
              key: Key(slip.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Slip"),
                    content: const Text("Are you sure you want to delete this betslip?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
                    ],
                  ),
                );
              },
              onDismissed: (_) => deleteSlip(slip.id),
              child: BetslipCard(
                betslip: slip,
                isPurchased: true, // Admin sees everything
              ),
            )),
          ],
        ),
      ),
    );
  }
}*/

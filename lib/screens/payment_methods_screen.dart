// lib/screens/payment_methods_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import '../models/betslip.dart'; // To receive betslip data
// You might want to add actual logos for payment methods later
// import 'package:flutter_svg/flutter_svg.dart'; or Image.asset

class PaymentMethodsScreen extends StatefulWidget {
  final Betslip betslipToPurchase;

  const PaymentMethodsScreen({
    super.key,
    required this.betslipToPurchase,
  });

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _phoneNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // In a real app, these would come from a config or backend
  final List<Map<String, dynamic>> _paymentMethods = [
    {'name': 'M-Pesa', 'icon': Icons.phone_android_rounded, 'color': Colors.red[700]},
    {'name': 'Airtel Money', 'icon': Icons.phone_android_rounded, 'color': Colors.pink[700]},
    {'name': 'Tigo Pesa', 'icon': Icons.phone_android_rounded, 'color': Colors.blue[700]}, // Common operator
    {'name': 'HaloPesa', 'icon': Icons.phone_android_rounded, 'color': Colors.orange[700]},
    // Add "MIXX by Yas" here if it's a mobile money like system or different type
    // {'name': 'MIXX by Yas', 'icon': Icons.payment_rounded, 'color': Colors.purple},
  ];

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _showEnterPhoneNumberDialog(String paymentMethodName) async {
    _phoneNumberController.clear(); // Clear previous input

    return showDialog<void>(
      context: context,
      barrierDismissible: true, // User can dismiss by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Pay with $paymentMethodName'),
          content: SingleChildScrollView( // In case of small screens
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Enter your $paymentMethodName phone number to pay TZS ${widget.betslipToPurchase.price.toStringAsFixed(0)}.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneNumberController,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (e.g., 07XXXXXXXX)',
                      hintText: 'Enter 10 digits',
                      prefixIcon: Icon(Icons.phone_iphone_rounded, color: Theme.of(dialogContext).colorScheme.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Allow only numbers
                      LengthLimitingTextInputFormatter(10),   // Limit to 10 digits
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length != 10) {
                        return 'Phone number must be 10 digits';
                      }
                      // You might want to add regex for specific prefixes (06, 07)
                      if (!value.startsWith('0')) {
                        return 'Number should start with 0';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
              ),
              child: const Text('Proceed to Pay'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // --- SIMULATED PAYMENT INITIATION ---
                  final phoneNumber = _phoneNumberController.text;
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  _initiatePayment(paymentMethodName, phoneNumber, widget.betslipToPurchase);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _initiatePayment(String paymentMethod, String phoneNumber, Betslip slip) {
    // **IMPORTANT:** This is where you would integrate with the actual payment gateway SDK/API.
    // For now, we'll simulate it and show a confirmation/info message.
    print('Initiating payment for slip "${slip.title}" (ID: ${slip.id})');
    print('Amount: TZS ${slip.price}');
    print('Method: $paymentMethod');
    print('Phone: $phoneNumber');

    // Simulate a delay and then a "success" or "pending" message
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Payment Initiated (Simulation)"),
          content: Text("A USSD prompt or SMS should be sent to $phoneNumber to complete the payment of TZS ${slip.price} for \"${slip.title}\" via $paymentMethod.\n\n"
              "In a real app, we would wait for payment confirmation before unlocking the slip."),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Potentially navigate back to home screen or a "pending payment" screen
                  Navigator.of(context).pop(); // Pop PaymentMethodsScreen
                },
                child: const Text("OK"))
          ],
        ));

    // **NEXT STEPS IN A REAL APP (after payment confirmation from gateway):**
    // 1. Verify payment on your backend.
    // 2. Record the purchase in your 'purchases' table in Supabase:
    //    await supabase.from('purchases').insert({
    //      'user_id': supabase.auth.currentUser.id,
    //      'betslip_id': slip.id,
    //      'amount_paid': slip.price,
    //      'payment_method': paymentMethod,
    //      'transaction_id': 'some_gateway_transaction_id', // from payment gateway
    //      'status': 'completed'
    //    });
    // 3. Navigate the user to a success screen or back to the HomeScreen (which should then reflect the purchase).
    // 4. Potentially trigger a refresh of betslips or user data on HomeScreen.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Pay for: ${widget.betslipToPurchase.title}"),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Complete Your Purchase",
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              "You are about to purchase the betslip \"${widget.betslipToPurchase.title}\" for TZS ${widget.betslipToPurchase.price.toStringAsFixed(0)}.",
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              "Select a Payment Method:",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _paymentMethods.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final method = _paymentMethods[index];
                  return Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 0.5)
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (method['color'] as Color? ?? theme.colorScheme.primary).withOpacity(0.15),
                        child: Icon(
                          method['icon'] as IconData? ?? Icons.payment_rounded,
                          color: method['color'] as Color? ?? theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      title: Text(method['name'] as String, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
                      // subtitle: Text("Pay with ${method['name']}"), // Optional
                      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
                      onTap: () {
                        _showEnterPhoneNumberDialog(method['name'] as String);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

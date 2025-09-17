// lib/screens/payment_methods_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:http/http.dart' as http; // For calling Edge Function
import 'dart:convert'; // For jsonEncode/Decode
import 'package:supabase_flutter/supabase_flutter.dart'; // To get current user token
import 'package:fluttertoast/fluttertoast.dart';

import '../models/betslip.dart'; // To receive betslip data

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
  bool _isProcessingPayment = false;

  // Your provided payment methods list
  final List<Map<String, dynamic>> _paymentMethods = [
    {'name': 'M-Pesa', 'icon': Icons.phone_android_rounded, 'color': Colors.red[700], 'provider_code': 'Mpesa'},
    {'name': 'Airtel Money', 'icon': Icons.phone_android_rounded, 'color': Colors.pink[700], 'provider_code': 'Airtel'},
    {'name': 'Tigo Pesa', 'icon': Icons.phone_android_rounded, 'color': Colors.blue[700], 'provider_code': 'Tigo'},
    {'name': 'HaloPesa', 'icon': Icons.phone_android_rounded, 'color': Colors.orange[700], 'provider_code': 'Halopesa'},
    {'name': 'AzamPesa', 'icon': Icons.account_balance_wallet_outlined, 'color': Colors.green[700], 'provider_code': 'Azampesa'},
  ];

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  String _getAzamProviderCode(String paymentMethodName) {
    final method = _paymentMethods.firstWhere(
            (m) => m['name'] == paymentMethodName,
        orElse: () => {'provider_code': 'Mpesa'} // Default or throw error if not found
    );
    return method['provider_code'];
  }

  Future<void> _initiatePayment(String paymentMethodName, String phoneNumber, Betslip slip) async {
    if (_isProcessingPayment) return;
    if (mounted) {
      setState(() => _isProcessingPayment = true);
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _showErrorDialog("Authentication error. Please log in again.");
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
      return;
    }
    final accessToken = session.accessToken;

    // Using your provided Supabase project URL for the function
    const String functionUrl = "https://ptkdfuxoiupkmprpafcp.supabase.co/functions/v1/pay_via_azampay";

    final providerCode = _getAzamProviderCode(paymentMethodName);
    final amountToPay = slip.isPremium ? slip.packagePrice : slip.price;

    // Basic phone number validation for AzamPay (might need 255 prefix)
    // AzamPay often requires the international format (e.g., 2557XXXXXXXX)
    String formattedPhoneNumber = phoneNumber;
    if (phoneNumber.startsWith('0') && phoneNumber.length == 10) {
      formattedPhoneNumber = '255${phoneNumber.substring(1)}';
    } else if (phoneNumber.length == 9 && !phoneNumber.startsWith('0')) { // e.g. 7XXXXXXXX
      formattedPhoneNumber = '255$phoneNumber';
    }
    // Add more specific validation/formatting if AzamPay requires it

    try {
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'phone': formattedPhoneNumber,
          'provider': providerCode,
          'betslip_id': slip.id,
          'amount': amountToPay,
        }),
      );

      if (!mounted) return;

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 202) {
        final String message = responseBody['message'] ?? "Payment initiated. Check your phone.";
        final String? transactionId = responseBody['transactionId']; // Get transactionId if returned

        print("Payment initiation successful. Transaction ID (from AzamPay via function): $transactionId");
        _showSuccessDialog(message, paymentMethodName, slip, formattedPhoneNumber);
      } else {
        final String errorMessage = responseBody['error'] ?? "Payment initiation failed. Please try again later.";
        print("Payment initiation error: ${response.statusCode} - $errorMessage");
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      print("Error calling Edge Function or processing response: $e");
      if (mounted) {
        _showErrorDialog("An unexpected error occurred: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  void _showSuccessDialog(String message, String method, Betslip slip, String phone) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Payment Initiated"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close this dialog
              // Pop PaymentMethodsScreen, return true to indicate initiation was successful
              // The calling screen (e.g., PremiumSlipsScreen or BetslipDetailScreen) can then act accordingly.
              Navigator.of(context).pop(true);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Payment Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  Future<void> _showEnterPhoneNumberDialog(String paymentMethodName) async {
    _phoneNumberController.clear();

    return showDialog<void>(
      context: context,
      barrierDismissible: !_isProcessingPayment,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('Pay with $paymentMethodName'),
                content: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                            'Enter your $paymentMethodName phone number to pay TZS ${widget.betslipToPurchase.isPremium ? widget.betslipToPurchase.formattedPackagePrice : widget.betslipToPurchase.formattedPrice}.'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneNumberController,
                          autofocus: true,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number (e.g., 07XXXXXXXX)',
                            hintText: 'Enter 10 digits starting with 0',
                            prefixIcon: Icon(Icons.phone_iphone_rounded,
                                color: Theme.of(dialogContext).colorScheme.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (value.length != 10) {
                              return 'Phone number must be 10 digits';
                            }
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
                    onPressed: _isProcessingPayment ? null : () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      Theme.of(dialogContext).colorScheme.primary,
                      foregroundColor:
                      Theme.of(dialogContext).colorScheme.onPrimary,
                    ),
                    onPressed: _isProcessingPayment ? null : () async {
                      if (_formKey.currentState!.validate()) {
                        final phoneNumber = _phoneNumberController.text;
                        // Close the phone number dialog *before* calling _initiatePayment,
                        // as _initiatePayment will show its own success/error dialog.
                        Navigator.of(dialogContext).pop();
                        await _initiatePayment(paymentMethodName, phoneNumber, widget.betslipToPurchase);
                      }
                    },
                    child: _isProcessingPayment
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Proceed to Pay'),
                  ),
                ],
              );
            }
        );
      },
    ).then((_) {
      if (_isProcessingPayment && mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final betslip = widget.betslipToPurchase;
    final amountString = betslip.isPremium ? betslip.formattedPackagePrice : betslip.formattedPrice;

    return Scaffold(
      appBar: AppBar(
        title: Text("Pay for: ${betslip.title}"),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Complete Your Purchase",
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              "You are about to purchase \"${betslip.title}\" for TZS $amountString.",
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              "Select a Payment Method:",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _paymentMethods.length,
                separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final method = _paymentMethods[index];
                  return Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: theme.dividerColor.withOpacity(0.5),
                            width: 0.5)),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (method['color'] as Color? ??
                            theme.colorScheme.primary)
                            .withOpacity(0.15),
                        child: Icon(
                          method['icon'] as IconData? ??
                              Icons.payment_rounded,
                          color: method['color'] as Color? ??
                              theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      title: Text(method['name'] as String,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: theme.colorScheme.outline),
                      onTap: () {
                        if (betslip.isExpired) {
                          Fluttertoast.showToast(msg: "This betslip has expired and cannot be purchased.");
                          return;
                        }
                        _showEnterPhoneNumberDialog(method['name'] as String);
                      },
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

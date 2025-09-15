// lib/admin/upload_betslip_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';

class UploadBetslipScreen extends StatefulWidget {
  const UploadBetslipScreen({super.key});

  @override
  State<UploadBetslipScreen> createState() => _UploadBetslipScreenState();
}

class _UploadBetslipScreenState extends State<UploadBetslipScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();
  final uuid = const Uuid();

  ImageProvider? _imageProvider;
  Uint8List? _imageBytes;
  String? _imageName;

  final _titleController = TextEditingController();
  final _bookingCodeController = TextEditingController();
  final _oddsController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _regularPriceController = TextEditingController();
  bool _isRegularPaid = false;

  bool _isPremium = false;
  final _packagePriceController = TextEditingController();
  final _refundAmountController = TextEditingController();
  final _refundPercentageController = TextEditingController(text: '0');
  double _calculatedTotalRefund = 0.0;

  bool _isUploading = false;
  bool _formSubmittedAttempted = false;

  DateTime? _selectedValidUntilDate;
  TimeOfDay? _selectedValidUntilTime;

  @override
  void initState() {
    super.initState();
    _refundAmountController.addListener(_calculateRefund);
    _refundPercentageController.addListener(_calculateRefund);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _regularPriceController.dispose();
    _bookingCodeController.dispose();
    _oddsController.dispose();
    _companyNameController.dispose();
    _packagePriceController.dispose();
    _refundAmountController.removeListener(_calculateRefund);
    _refundAmountController.dispose();
    _refundPercentageController.removeListener(_calculateRefund);
    _refundPercentageController.dispose();
    super.dispose();
  }

  void _calculateRefund() {
    final double amount = double.tryParse(_refundAmountController.text) ?? 0.0;
    final double percentage = double.tryParse(_refundPercentageController.text) ?? 0.0;
    setState(() {
      _calculatedTotalRefund = amount + (amount * (percentage / 100.0));
    });
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
        _imageProvider = MemoryImage(bytes);
      });
    }
  }

  Future<String?> _uploadImageBytes(Uint8List bytes, String fileName) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final filePath = 'betslips/${uuid.v4()}.$ext';
    try {
      await supabase.storage.from('betslips').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return supabase.storage.from('betslips').getPublicUrl(filePath);
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: ${e.toString()}')));
      return null;
    }
  }

  Future<void> _selectValidUntilDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedValidUntilDate ?? DateTime.now().add(const Duration(hours:1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedValidUntilDate) {
      setState(() => _selectedValidUntilDate = picked);
    }
  }

  Future<void> _selectValidUntilTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedValidUntilTime ?? TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours:1))),
    );
    if (picked != null && picked != _selectedValidUntilTime) {
      setState(() => _selectedValidUntilTime = picked);
    }
  }

  Future<void> _postSlip() async {
    setState(() => _formSubmittedAttempted = true);
    bool isFormValid = _formKey.currentState!.validate();
    bool isImageSelected = _imageBytes != null;
    bool isValidityDateTimeSet = _selectedValidUntilDate != null && _selectedValidUntilTime != null;

    if (!isFormValid || !isImageSelected || !isValidityDateTimeSet) {
      if (!isImageSelected && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an image.")));
      return;
    }

    setState(() => _isUploading = true);
    DateTime? finalValidUntil;
    DateTime? finalAutoUnlockAt;

    finalValidUntil = DateTime(
      _selectedValidUntilDate!.year, _selectedValidUntilDate!.month, _selectedValidUntilDate!.day,
      _selectedValidUntilTime!.hour, _selectedValidUntilTime!.minute,
    );

    if (finalValidUntil.isBefore(DateTime.now().add(const Duration(minutes: -1)))) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("'Valid Until' must be in the future.")));
      setState(() => _isUploading = false);
      return;
    }

    // Set autoUnlockAt for both regular paid and premium slips
    // 2 hours after validUntil
    finalAutoUnlockAt = finalValidUntil.add(const Duration(hours: 2));

    try {
      final imageUrl = await _uploadImageBytes(_imageBytes!, _imageName!);
      if (imageUrl == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }
      final user = supabase.auth.currentUser;
      if (user == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not authenticated.")));
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final Map<String, dynamic> betslipData = {
        'title': _titleController.text.trim(),
        'image_url': imageUrl,
        'posted_by': user.id,
        'booking_code': _bookingCodeController.text.trim().isEmpty ? null : _bookingCodeController.text.trim(),
        'odds': _oddsController.text.trim().isEmpty ? null : _oddsController.text.trim(),
        'company_name': _companyNameController.text.trim().isEmpty ? null : _companyNameController.text.trim(),
        'valid_until': finalValidUntil.toIso8601String(),
        'is_premium': _isPremium,
        'auto_unlock_at': finalAutoUnlockAt.toIso8601String(), // Always set auto_unlock_at
      };

      if (_isPremium) {
        betslipData['package_price'] = int.tryParse(_packagePriceController.text.trim()) ?? 0;
        betslipData['refund_amount_if_lost'] = int.tryParse(_refundAmountController.text.trim()) ?? 0;
        betslipData['refund_percentage_bonus'] = int.tryParse(_refundPercentageController.text.trim()) ?? 0;
        betslipData['is_paid'] = true; // Premium slips are inherently "paid"
        betslipData['price'] = betslipData['package_price']; // Main price is package price
      } else {
        betslipData['is_paid'] = _isRegularPaid;
        betslipData['price'] = _isRegularPaid ? (int.tryParse(_regularPriceController.text.trim()) ?? 0) : 0;
        // auto_unlock_at is already set above for both cases if applicable
      }

      await supabase.from('betslips').insert(betslipData);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Betslip uploaded successfully!")));
      }
    } catch (e, s) {
      print("Post slip error: $e\n$s");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ... (build method - no major changes needed other than what was done for premium fields already)
  // Ensure the existing premium fields section from your previous version is there.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Post New Betslip")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: _formSubmittedAttempted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Create & Post Betslip", style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 8),
              Text("Fields marked with * are required.", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),

              Text("Betslip Image*", style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _imageProvider == null ? theme.colorScheme.surfaceVariant.withOpacity(0.7) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _formSubmittedAttempted && _imageBytes == null
                            ? theme.colorScheme.error
                            : theme.colorScheme.outline.withOpacity(_imageProvider == null ? 0.9 : 0.3)
                    ),
                  ),
                  child: _imageProvider != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image(image: _imageProvider!, fit: BoxFit.contain),
                  )
                      : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text("Tap to select image", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                        ],
                      )),
                ),
              ),
              if (_formSubmittedAttempted && _imageBytes == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text('Please select an image.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title*", hintText: "e.g., Weekend Special Accumulator"),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Title is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Card(
                  elevation: 0,
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          title: Text("Premium Package Slip?", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
                          subtitle: Text(_isPremium ? "Offer refund guarantees." : "Set as a premium offering.", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7))),
                          value: _isPremium,
                          onChanged: (val) {
                            setState(() {
                              _isPremium = val;
                              if (_isPremium) {
                                _isRegularPaid = false;
                              }
                            });
                          },
                          activeColor: theme.colorScheme.primary,
                          tileColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          dense: true,
                        ),

                        if (!_isPremium) ...[
                          const Divider(height: 16, indent: 16, endIndent: 16),
                          SwitchListTile.adaptive(
                            title: Text("Regular Paid Slip?", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
                            subtitle: Text(_isRegularPaid ? "Users will purchase to view." : "This slip will be free.", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7))),
                            value: _isRegularPaid,
                            onChanged: (val) => setState(() => _isRegularPaid = val),
                            activeColor: theme.colorScheme.secondary,
                            tileColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                  )
              ),
              const SizedBox(height: 16),

              if (_isPremium) ...[
                Text("Premium Package Details", style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _packagePriceController,
                  decoration: const InputDecoration(labelText: "Package Price (TZS)*", hintText: "e.g., 5000", prefixText: "TZS "),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isPremium) return null;
                    if (value == null || value.isEmpty) return 'Package Price is required.';
                    final price = int.tryParse(value);
                    if (price == null || price <= 0) return 'Enter a valid positive price.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refundAmountController,
                  decoration: const InputDecoration(labelText: "Amount Refunded if Lost (TZS)*", hintText: "e.g., 5000 (stake amount)", prefixText: "TZS "),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isPremium) return null;
                    if (value == null || value.isEmpty) return 'Refund amount is required.';
                    final amount = int.tryParse(value);
                    if (amount == null || amount < 0) return 'Enter a valid refund amount (can be 0).';
                    // Allow refund to be equal to package price (full stake back)
                    // if (amount > (int.tryParse(_packagePriceController.text) ?? 0)) {
                    //   return 'Refund cannot exceed package price.';
                    // }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refundPercentageController,
                  decoration: const InputDecoration(labelText: "Additional Refund Bonus (%)*", hintText: "e.g., 10 for 10% (can be 0)", suffixText: "%"),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isPremium) return null;
                    if (value == null || value.isEmpty) return 'Refund percentage is required (enter 0 if no bonus).';
                    final percent = int.tryParse(value);
                    if (percent == null || percent < 0 || percent > 100) return 'Enter a valid percentage (0-100).';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Potential Refund:", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer)),
                      Text(currencyFormat.format(_calculatedTotalRefund), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.tertiary)),
                    ],
                  ),
                ),
              ] else if (_isRegularPaid) ...[
                TextFormField(
                  controller: _regularPriceController,
                  decoration: const InputDecoration(labelText: "Price (TZS)*", hintText: "e.g., 1000", prefixText: "TZS "),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!(_isRegularPaid && !_isPremium) ) return null;
                    if (value == null || value.isEmpty) return 'Price is required for paid slips.';
                    final price = int.tryParse(value);
                    if (price == null || price <= 0) return 'Enter a valid positive price.';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              Text("Optional Details", style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bookingCodeController,
                decoration: const InputDecoration(labelText: "Booking Code", hintText: "e.g., AB12CD (Optional)"),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _oddsController,
                decoration: const InputDecoration(labelText: "Total Odds", hintText: "e.g., 2.35 or 10/1 (Optional)"),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(labelText: "Betting Company", hintText: "e.g., BetCompany (Optional)"),
              ),
              const SizedBox(height: 20),

              Text("Valid Until*", style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectValidUntilDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Date*",
                          prefixIcon: Icon(Icons.calendar_today_outlined, color: theme.colorScheme.primary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: _formSubmittedAttempted && _selectedValidUntilDate == null
                                ? BorderSide(color: theme.colorScheme.error)
                                : BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: _formSubmittedAttempted && _selectedValidUntilDate == null
                                ? BorderSide(color: theme.colorScheme.error)
                                : BorderSide.none,
                          ),
                        ),
                        child: Text(
                          _selectedValidUntilDate != null ? DateFormat('EEE, MMM d, yyyy').format(_selectedValidUntilDate!) : 'Select Date',
                          style: theme.textTheme.bodyLarge?.copyWith(color: _selectedValidUntilDate == null ? theme.hintColor : theme.colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectValidUntilTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Time*",
                          prefixIcon: Icon(Icons.access_time_outlined, color: theme.colorScheme.primary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: _formSubmittedAttempted && _selectedValidUntilTime == null
                                ? BorderSide(color: theme.colorScheme.error)
                                : BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: _formSubmittedAttempted && _selectedValidUntilTime == null
                                ? BorderSide(color: theme.colorScheme.error)
                                : BorderSide.none,
                          ),
                        ),
                        child: Text(
                          _selectedValidUntilTime != null ? _selectedValidUntilTime!.format(context) : 'Select Time',
                          style: theme.textTheme.bodyLarge?.copyWith(color: _selectedValidUntilTime == null ? theme.hintColor : theme.colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_formSubmittedAttempted && (_selectedValidUntilDate == null || _selectedValidUntilTime == null))
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text('Validity date and time are required.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 32),
              CustomButton(
                label: _isUploading ? "UPLOADING..." : "POST BETSLIP",
                onPressed: _isUploading ? null : _postSlip,
                isLoading: _isUploading,
                icon: Icons.cloud_upload_outlined,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

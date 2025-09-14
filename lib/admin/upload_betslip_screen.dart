// lib/admin/upload_betslip_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // For date formatting display
import '../widgets/custom_button.dart'; // Ensure this import is correct

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
  final _priceController = TextEditingController();
  final _bookingCodeController = TextEditingController();
  final _oddsController = TextEditingController();
  final _companyNameController = TextEditingController();

  bool _isPaid = false;
  bool _isUploading = false;
  bool _formSubmittedAttempted = false; // To control custom validation message visibility

  DateTime? _selectedValidUntilDate;
  TimeOfDay? _selectedValidUntilTime;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _bookingCodeController.dispose();
    _oddsController.dispose();
    _companyNameController.dispose();
    super.dispose();
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
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: 'image/$ext',
        ),
      );
      return supabase.storage.from('betslips').getPublicUrl(filePath);
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: ${e.toString()}')));
      }
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
      setState(() {
        _selectedValidUntilDate = picked;
      });
    }
  }

  Future<void> _selectValidUntilTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedValidUntilTime ?? TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours:1))),
    );
    if (picked != null && picked != _selectedValidUntilTime) {
      setState(() {
        _selectedValidUntilTime = picked;
      });
    }
  }

  Future<void> _postSlip() async {
    setState(() { // Set attempt flag first
      _formSubmittedAttempted = true;
    });

    bool isFormValid = _formKey.currentState!.validate(); // Validate form fields

    // Now check custom validations (image and date/time)
    bool isImageSelected = _imageBytes != null;
    bool isValidityDateTimeSet = _selectedValidUntilDate != null && _selectedValidUntilTime != null;

    if (!isFormValid || !isImageSelected || !isValidityDateTimeSet) {
      // If any validation fails, show appropriate SnackBars if not handled by TextFormField validators
      if (!isImageSelected) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an image.")));
      }
      // The TextFormField validators will show their own messages.
      // The custom error text for date/time will become visible due to _formSubmittedAttempted.
      return;
    }

    setState(() => _isUploading = true);

    DateTime? finalValidUntil;
    DateTime? finalAutoUnlockAt;

    // This check is now safe because we ensured they are not null above
    finalValidUntil = DateTime(
      _selectedValidUntilDate!.year,
      _selectedValidUntilDate!.month,
      _selectedValidUntilDate!.day,
      _selectedValidUntilTime!.hour,
      _selectedValidUntilTime!.minute,
    );

    if (finalValidUntil.isBefore(DateTime.now().add(const Duration(minutes: -1)))) { // Allow for slight clock differences
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("'Valid Until' must be in the future.")));
      setState(() => _isUploading = false);
      return;
    }
    if (_isPaid) {
      finalAutoUnlockAt = finalValidUntil.add(const Duration(hours: 3));
    }

    try {
      final imageUrl = await _uploadImageBytes(_imageBytes!, _imageName!);
      if (imageUrl == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not authenticated.")));
          setState(() => _isUploading = false);
        }
        return;
      }

      await supabase.from('betslips').insert({
        'title': _titleController.text.trim(),
        'image_url': imageUrl,
        'is_paid': _isPaid,
        'price': _isPaid ? (int.tryParse(_priceController.text.trim()) ?? 0) : 0,
        'posted_by': user.id,
        'booking_code': _bookingCodeController.text.trim().isEmpty ? null : _bookingCodeController.text.trim(),
        'odds': _oddsController.text.trim().isEmpty ? null : _oddsController.text.trim(),
        'company_name': _companyNameController.text.trim().isEmpty ? null : _companyNameController.text.trim(),
        'valid_until': finalValidUntil.toIso8601String(),
        'auto_unlock_at': finalAutoUnlockAt?.toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context, true); // Pop with true to indicate success for refresh
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Betslip uploaded successfully!")));
      }
    } catch (e) {
      print("Post slip error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

              // --- Image Picker ---
              Text("Betslip Image*", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
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
                  child: Text(
                    'Please select an image.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),

              // --- Title ---
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title*", hintText: "e.g., Weekend Special Accumulator"),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Title is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Paid Switch & Price ---
              SwitchListTile.adaptive(
                title: Text("Is this a Paid Slip?", style: theme.textTheme.titleMedium),
                subtitle: Text(_isPaid ? "Users will need to purchase to view details." : "This slip will be free for all users."),
                value: _isPaid,
                onChanged: (val) => setState(() => _isPaid = val),
                tileColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                dense: true,
              ),
              if (_isPaid) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: "Price (TZS)*", hintText: "e.g., 1000", prefixText: "TZS "),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isPaid) return null; // Only validate if it's a paid slip
                    if (value == null || value.isEmpty) return 'Price is required for paid slips';
                    final price = int.tryParse(value);
                    if (price == null || price <= 0) return 'Enter a valid positive price';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),

              // --- Booking Code ---
              TextFormField(
                controller: _bookingCodeController,
                decoration: const InputDecoration(labelText: "Booking Code", hintText: "e.g., AB12CD (Optional)"),
              ),
              const SizedBox(height: 16),

              // --- Odds ---
              TextFormField(
                controller: _oddsController,
                decoration: const InputDecoration(labelText: "Total Odds", hintText: "e.g., 2.35 or 10/1 (Optional)"),
              ),
              const SizedBox(height: 16),

              // --- Company Name ---
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(labelText: "Betting Company", hintText: "e.g., BetCompany (Optional)"),
              ),
              const SizedBox(height: 20),

              // --- Valid Until Date & Time ---
              Text("Valid Until*", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectValidUntilDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Date*",
                          prefixIcon: Icon(Icons.calendar_today_outlined, color: theme.colorScheme.primary, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15), // Adjust padding
                          border: OutlineInputBorder( // Consistent border style
                            borderRadius: BorderRadius.circular(10),
                            borderSide: _formSubmittedAttempted && _selectedValidUntilDate == null
                                ? BorderSide(color: theme.colorScheme.error)
                                : BorderSide.none, // Use none if surface is colored by fillColor
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: _formSubmittedAttempted && _selectedValidUntilDate == null
                                ? BorderSide(color: theme.colorScheme.error)
                                : BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          // filled: true, // Already true from theme
                          // fillColor: theme.inputDecorationTheme.fillColor, // from theme
                        ),
                        child: Text(
                          _selectedValidUntilDate != null ? DateFormat('EEE, MMM d, yyyy').format(_selectedValidUntilDate!) : 'Select Date',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _selectedValidUntilDate == null ? theme.hintColor : theme.colorScheme.onSurface,
                          ),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                        ),
                        child: Text(
                          _selectedValidUntilTime != null ? _selectedValidUntilTime!.format(context) : 'Select Time',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _selectedValidUntilTime == null ? theme.hintColor : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_formSubmittedAttempted && (_selectedValidUntilDate == null || _selectedValidUntilTime == null))
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text(
                    'Validity date and time are required.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 32),

              // --- Submit Button ---
              CustomButton(
                label: _isUploading ? "UPLOADING..." : "POST BETSLIP",
                onPressed: _isUploading ? null : _postSlip,
                isLoading: _isUploading,
                icon: Icons.cloud_upload_outlined,
                type: CustomButtonType.elevated,
              ),
              const SizedBox(height: 40), // More space at the bottom for scrollability
            ],
          ),
        ),
      ),
    );
  }
}

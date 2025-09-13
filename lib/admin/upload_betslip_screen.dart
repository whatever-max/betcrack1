import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart' show kIsWeb; // To check if running on web
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
// Conditionally import dart:io for File type if not on web
import 'dart:io' if (kIsWeb) 'dart:html' show File; // This line is tricky, usually avoid direct dart:html

class UploadBetslipScreen extends StatefulWidget {
  const UploadBetslipScreen({super.key});

  @override
  State<UploadBetslipScreen> createState() => _UploadBetslipScreenState();
}

class _UploadBetslipScreenState extends State<UploadBetslipScreen> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();
  final uuid = const Uuid();

  // For displaying the image
  ImageProvider? _imageProvider; // Use ImageProvider for flexibility
  // For uploading
  Uint8List? _imageBytes;
  String? _imageName; // To get the extension

  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _bookingCodeController = TextEditingController();
  bool _isPaid = false;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name; // Store the name for extension
        if (kIsWeb) {
          _imageProvider = NetworkImage(pickedFile.path); // pickedFile.path is a blob URL on web
        } else {
          // For mobile, you can use MemoryImage directly or create a File object if needed elsewhere
          _imageProvider = MemoryImage(bytes);
          // If you absolutely need a File object for other non-UI logic on mobile:
          // _imageFileForMobile = File(pickedFile.path);
        }
      });
    } else {
      print('No image selected.');
    }
  }

  Future<String?> _uploadImageBytes(Uint8List bytes, String fileName) async {
    // Attempt to get the extension from the file name
    final ext = fileName.contains('.') ? fileName.split('.').last : 'png'; // Default to png if no extension
    final filePath = 'betslips/${uuid.v4()}.$ext';

    try {
      // Use uploadBinary for Uint8List
      await supabase.storage
          .from('betslips') // Make sure this is your bucket name
          .uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600', // Optional: Caching strategy
          upsert: true,         // Optional: Overwrite if file exists
          // contentType: 'image/$ext' // Optional: Manually set content type if needed
        ),
      );

      final String publicUrl = supabase.storage
          .from('betslips')
          .getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('Error uploading image to Supabase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: ${e.toString()}')),
      );
      return null;
    }
  }

  Future<void> _postSlip() async {
    if (_imageBytes == null || _imageName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }
    if (_titleController.text.trim().isEmpty ||
        _bookingCodeController.text.trim().isEmpty ||
        (_isPaid && _priceController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final imageUrl = await _uploadImageBytes(_imageBytes!, _imageName!);
      if (imageUrl == null) {
        // Error already shown in _uploadImageBytes
        setState(() => _isUploading = false);
        return;
      }

      final user = supabase.auth.currentUser;

      await supabase.from('betslips').insert({
        'title': _titleController.text.trim(),
        'image_url': imageUrl,
        'is_paid': _isPaid,
        'price': _isPaid ? int.tryParse(_priceController.text.trim()) ?? 0 : 0, // Use tryParse
        'posted_by': user?.id,
        'booking_code': _bookingCodeController.text.trim(),
      });

      if (mounted) {
        // Return true to indicate success for the AdminPanelScreen to refresh
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Betslip uploaded successfully!")),
        );
      }
    } catch (e) {
      print("Post slip error: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: ${e.toString()}")),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Betslip")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey.shade300,
                child: _imageProvider != null
                    ? Image(image: _imageProvider!, fit: BoxFit.cover)
                    : const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Tap to select image"),
                  ],
                )),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isPaid,
              onChanged: (val) => setState(() => _isPaid = val),
              title: const Text("Is this a paid slip?"),
              tileColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 12),
            if (_isPaid)
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: "Price (TZS)", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            if (_isPaid) const SizedBox(height: 12),
            TextField(
              controller: _bookingCodeController,
              decoration: const InputDecoration(
                  labelText: "Booking Code",
                  hintText: "Required to post",
                  border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload),
              label: Text(_isUploading ? "Uploading..." : "Post Slip"),
              onPressed: _isUploading ? null : _postSlip,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16)
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/admin/screens/manage_banners_screen.dart
import 'dart:io'; // Import the full dart:io library to get File and Platform
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../models/banner_item_model.dart';
import '../widgets/banner_list_item.dart';
import '../../constants.dart'; // Assuming supabaseUrl is defined here

class ManageBannersScreen extends StatefulWidget {
  static const String routeName = '/admin/manage-banners';
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _imageUrlController = TextEditingController();
  final _titleController = TextEditingController();
  final _actionUrlController = TextEditingController();

  XFile? _selectedImageFile;
  bool _isProcessing = false;
  bool _isLoadingBanners = true;
  List<BannerItem> _banners = [];
  String? _loadingError;

  String? _deletingBannerId;
  String? _togglingBannerId;

  // Helper for showing toast or printing
  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    if (Platform.isAndroid || Platform.isIOS) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: isError ? Colors.red.shade800 : null,
        textColor: Colors.white,
      );
    } else {
      print("Feedback (${isError ? 'ERROR' : 'INFO'}): $message");
      // Optionally show a SnackBar if context is readily available and appropriate
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text(message),
      //       backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      //     ),
      //   );
      // }
    }
  }


  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBanners = true;
      _loadingError = null;
    });
    try {
      final response = await _supabase
          .from('banners')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _banners = response.map((data) => BannerItem.fromMap(data)).toList();
          _isLoadingBanners = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching banners: $e");
        _loadingError = "Failed to load banners: ${e.toString()}";
        setState(() {
          _isLoadingBanners = false;
        });
        _showFeedback(_loadingError!, isError: true);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _selectedImageFile = image;
          _imageUrlController.text = image.name;
        });
      }
    } catch (e) {
      _showFeedback("Failed to pick image: $e", isError: true);
    }
  }

  Future<String?> _uploadBannerImage() async {
    if (_selectedImageFile == null) return _imageUrlController.text.trim();

    // setState(() => _isProcessing = true); // _isProcessing is handled by _addBanner for the whole operation
    String? publicUrl;

    try {
      final imageFile = File(_selectedImageFile!.path); // Now File() is recognized
      final fileExt = _selectedImageFile!.path.split('.').lastOrNull ?? 'png';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_banner.$fileExt';
      final String storagePath = 'public/banner_images/$fileName';

      await _supabase.storage
          .from('banner_images')
          .upload(storagePath, imageFile, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));

      publicUrl = _supabase.storage
          .from('banner_images')
          .getPublicUrl(storagePath);

    } on StorageException catch (e) {
      print("Storage Error uploading banner image: ${e.message}");
      _showFeedback("Image upload failed: ${e.message}", isError: true);
      publicUrl = null;
    } catch (e) {
      print("General Error uploading banner image: $e");
      _showFeedback("Image upload error: ${e.toString()}", isError: true);
      publicUrl = null;
    }
    return publicUrl;
  }

  Future<void> _addBanner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isProcessing) return;

    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) {
      _showFeedback("Admin not authenticated.", isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    String? finalImageUrl;

    if (_selectedImageFile != null) {
      finalImageUrl = await _uploadBannerImage();
      if (finalImageUrl == null) {
        _showFeedback("Banner image selected but upload failed. Cannot add banner.", isError: true);
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
    } else {
      finalImageUrl = _imageUrlController.text.trim();
      if (finalImageUrl.isEmpty) {
        _showFeedback("Please provide an image URL or select an image file.", isError: true);
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
    }

    try {
      await _supabase.from('banners').insert({
        'image_url': finalImageUrl,
        'title': _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        'action_url': _actionUrlController.text.trim().isEmpty ? null : _actionUrlController.text.trim(),
        'admin_id': adminId,
        'is_active': true,
      });

      _showFeedback("Banner added successfully!");
      _formKey.currentState?.reset();
      _imageUrlController.clear();
      _titleController.clear();
      _actionUrlController.clear();
      if (mounted) {
        setState(() {
          _selectedImageFile = null;
        });
      }
      _fetchBanners();
    } catch (e) {
      _showFeedback("Failed to add banner: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteBanner(String bannerId) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this banner? This will also attempt to delete the image from storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) setState(() => _deletingBannerId = bannerId);

    try {
      final bannerToDelete = _banners.firstWhere((b) => b.id == bannerId);
      final imageUrl = bannerToDelete.imageUrl;
      final bucketName = 'banner_images';

      // Construct the base storage URL from your Supabase project URL
      // Ensure supabaseUrl is accessible here (e.g. from constants.dart)
      final projectBaseUrl = supabaseUrl; // Use the main Supabase URL from your constants
      final String supabaseStorageBaseUrl = '$projectBaseUrl/storage/v1/object/public/$bucketName/';


      if (imageUrl.startsWith(supabaseStorageBaseUrl)) {
        final String pathInStorage = imageUrl.replaceFirst(supabaseStorageBaseUrl, '');
        if (pathInStorage.isNotEmpty && pathInStorage != imageUrl) {
          print("Attempting to delete from storage: '$pathInStorage' from bucket '$bucketName'");
          await _supabase.storage.from(bucketName).remove([pathInStorage]);
          _showFeedback("Image removed from storage.");
        } else {
          print("Could not reliably parse storage path from URL for deletion, or it's not a storage URL: $imageUrl");
          _showFeedback("Could not parse storage path for deletion from: $imageUrl", isError: true);
        }
      } else {
        print("Image URL does not appear to be a Supabase storage URL from '$bucketName' bucket: $imageUrl. URL starts with: ${imageUrl.substring(0, imageUrl.length > 50 ? 50 : imageUrl.length)}. Expected start: $supabaseStorageBaseUrl");
        // Don't show an error toast here if it's just an external URL, only if parsing failed for an expected Supabase URL.
      }

      await _supabase.from('banners').delete().eq('id', bannerId);
      _showFeedback("Banner record deleted!");
      _fetchBanners();
    } catch (e) {
      print("Error deleting banner or storage image: $e");
      _showFeedback("Failed to delete banner: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _deletingBannerId = null);
    }
  }


  Future<void> _toggleBannerActive(String bannerId) async {
    if (!mounted) return;
    BannerItem? banner;
    try {
      banner = _banners.firstWhere((b) => b.id == bannerId);
    } catch (e) {
      _showFeedback("Error finding banner to toggle.", isError: true);
      return;
    }
    final newStatus = !banner.isActive;

    if (mounted) setState(() => _togglingBannerId = bannerId);

    try {
      await _supabase
          .from('banners')
          .update({'is_active': newStatus})
          .eq('id', bannerId);
      _showFeedback("Banner status updated!");
      _fetchBanners();
    } catch (e) {
      _showFeedback("Failed to update banner status: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _togglingBannerId = null);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Banners'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBanners,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Add New Banner', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _imageUrlController,
                          decoration: InputDecoration(
                            labelText: 'Image URL',
                            hintText: _selectedImageFile == null ? 'https://example.com/banner.jpg' : 'Using picked image below',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: _selectedImageFile != null,
                            fillColor: _selectedImageFile != null ? Colors.grey.shade200 : null,
                            suffixIcon: _imageUrlController.text.isNotEmpty || _selectedImageFile != null
                                ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: (){
                                  _imageUrlController.clear();
                                  setState(() => _selectedImageFile = null);
                                }
                            )
                                : null,
                          ),
                          readOnly: _selectedImageFile != null,
                          validator: (value) {
                            if (_selectedImageFile == null && (value == null || value.isEmpty)) {
                              return 'Provide an image URL or pick an image.';
                            }
                            if (_selectedImageFile == null && value != null && value.isNotEmpty && !Uri.tryParse(value)!.isAbsolute) {
                              return 'Please enter a valid URL.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.image_search_outlined),
                          label: Text(_selectedImageFile == null ? 'Pick Image from Gallery' : 'Change Picked Image'),
                          onPressed: _pickImage,
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 15)
                          ),
                        ),
                        if (_selectedImageFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text("Picked: ${_selectedImageFile!.name}", style: theme.textTheme.labelMedium, overflow: TextOverflow.ellipsis,),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(labelText: 'Title (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actionUrlController,
                          decoration: InputDecoration(labelText: 'Action URL (Optional)', hintText:'https://your-target-link.com', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          validator: (value) {
                            if (value != null && value.isNotEmpty && !Uri.tryParse(value)!.isAbsolute) {
                              return 'Please enter a valid URL or leave empty.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: _isProcessing ? const SizedBox.shrink() : const Icon(Icons.add_photo_alternate_outlined),
                          label: _isProcessing
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5,))
                              : const Text('Add Banner'),
                          onPressed: _isProcessing ? null : _addBanner,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 20, thickness: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Current Banners", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (!_isLoadingBanners && _banners.isNotEmpty) Text("${_banners.length} total", style: theme.textTheme.labelMedium)
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoadingBanners
                  ? const Center(child: CircularProgressIndicator())
                  : _loadingError != null
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
                    const SizedBox(height: 8),
                    Text(_loadingError!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _fetchBanners, child: const Text("Retry"))
                  ],
                ),
              ))
                  : _banners.isEmpty
                  ? const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No banners found. Add one using the form above!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              ))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                itemCount: _banners.length,
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  return BannerListItem(
                    banner: banner,
                    onDelete: _deleteBanner,
                    onToggleActive: _toggleBannerActive,
                    isDeleting: _deletingBannerId == banner.id,
                    isToggling: _togglingBannerId == banner.id,
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


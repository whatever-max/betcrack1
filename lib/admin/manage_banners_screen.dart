import 'dart:io'; // For File type if using image_picker
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/banner_item_model.dart';
import '../widgets/banner_list_item.dart';

class ManageBannersScreen extends StatefulWidget {
  static const String routeName = '/admin/manage-banners';
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _imageUrlController = TextEditingController(); // For direct URL input
  final _titleController = TextEditingController();
  final _actionUrlController = TextEditingController();

  XFile? _selectedImageFile;
  bool _isUploading = false;
  bool _isLoadingBanners = true;
  List<BannerItem> _banners = [];
  String? _loadingError;

  // For tracking individual item loading states
  String? _deletingBannerId;
  String? _togglingBannerId;


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
        setState(() {
          _isLoadingBanners = false;
          _loadingError = "Failed to load banners: ${e.toString()}";
        });
        Fluttertoast.showToast(msg: _loadingError!);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImageFile = image;
          _imageUrlController.text = image.name; // Show file name in text field
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to pick image: $e");
    }
  }

  Future<String?> _uploadBannerImage() async {
    if (_selectedImageFile == null) return null;

    setState(() => _isUploading = true);
    String? publicUrl;

    try {
      final imageFile = File(_selectedImageFile!.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImageFile!.name}';
      final String storagePath = 'public/banner_images/$fileName'; // Ensure 'public' if bucket is public

      await _supabase.storage
          .from('banner_images') // Your bucket name
          .upload(storagePath, imageFile, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));

      publicUrl = _supabase.storage
          .from('banner_images')
          .getPublicUrl(storagePath);

      Fluttertoast.showToast(msg: "Image uploaded successfully!");
    } on StorageException catch (e) {
      print("Storage Error: ${e.message}");
      Fluttertoast.showToast(msg: "Image upload failed: ${e.message}");
      publicUrl = null; // Ensure url is null on error
    } catch (e) {
      print("General Upload Error: $e");
      Fluttertoast.showToast(msg: "Image upload error: ${e.toString()}");
      publicUrl = null;
    } finally {
      if(mounted) setState(() => _isUploading = false);
    }
    return publicUrl;
  }

  Future<void> _addBanner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploading) return; // Prevent adding while another upload is in progress

    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) {
      Fluttertoast.showToast(msg: "Admin not authenticated.");
      return;
    }

    String? finalImageUrl = _imageUrlController.text.trim();

    // If an image file was selected, upload it and override direct URL
    if (_selectedImageFile != null) {
      finalImageUrl = await _uploadBannerImage();
      if (finalImageUrl == null) { // Upload failed
        Fluttertoast.showToast(msg: "Banner image upload failed. Cannot add banner.");
        return;
      }
    } else if (finalImageUrl.isEmpty) {
      Fluttertoast.showToast(msg: "Please provide an image URL or select an image file.");
      return;
    }


    setState(() => _isUploading = true); // General loading state for the add operation

    try {
      await _supabase.from('banners').insert({
        'image_url': finalImageUrl,
        'title': _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        'action_url': _actionUrlController.text.trim().isEmpty ? null : _actionUrlController.text.trim(),
        'admin_id': adminId,
        'is_active': true, // Default new banners to active
      });

      Fluttertoast.showToast(msg: "Banner added successfully!");
      _formKey.currentState?.reset();
      _imageUrlController.clear();
      _titleController.clear();
      _actionUrlController.clear();
      setState(() {
        _selectedImageFile = null;
      });
      _fetchBanners(); // Refresh list
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to add banner: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteBanner(String bannerId) async {
    if(!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this banner? This may also involve deleting the image from storage if you manage that separately.'),
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
      // Optional: Delete from storage if you store the storage path
      // final bannerData = _banners.firstWhere((b) => b.id == bannerId);
      // if (bannerData.imageUrl.contains('supabase.co/storage/v1/object/public/banner_images')) {
      //   final path = bannerData.imageUrl.split('/banner_images/').last;
      //   await _supabase.storage.from('banner_images').remove(['public/banner_images/$path']);
      // }

      await _supabase.from('banners').delete().eq('id', bannerId);
      Fluttertoast.showToast(msg: "Banner deleted!");
      _fetchBanners();
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to delete banner: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _deletingBannerId = null);
    }
  }

  Future<void> _toggleBannerActive(String bannerId) async {
    if (!mounted) return;
    final banner = _banners.firstWhere((b) => b.id == bannerId);
    final newStatus = !banner.isActive;

    if (mounted) setState(() => _togglingBannerId = bannerId);

    try {
      await _supabase
          .from('banners')
          .update({'is_active': newStatus})
          .eq('id', bannerId);
      Fluttertoast.showToast(msg: "Banner status updated!");
      _fetchBanners(); // Refresh list
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to update banner status: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _togglingBannerId = null);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Banners'),
        // actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _fetchBanners)],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBanners,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Add New Banner', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: InputDecoration(
                          labelText: 'Image URL (or pick below)',
                          hintText: 'https://example.com/banner.jpg',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: (){
                                _imageUrlController.clear();
                                setState(() => _selectedImageFile = null);
                              }
                          )
                      ),
                      validator: (value) {
                        // Not strictly required if _selectedImageFile is present
                        if (_selectedImageFile == null && (value == null || value.isEmpty)) {
                          return 'Please enter an image URL or pick an image.';
                        }
                        if (value != null && value.isNotEmpty && !Uri.tryParse(value)!.isAbsolute) {
                          return 'Please enter a valid URL.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image_search_outlined),
                      label: Text(_selectedImageFile == null ? 'Pick Image from Gallery' : 'Change Image (${_selectedImageFile!.name.substring(0, ( _selectedImageFile!.name.length > 20 ? 20 : _selectedImageFile!.name.length)).trimRight()}${_selectedImageFile!.name.length > 20 ? "..." : ""})') ,
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondaryContainer),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: 'Title (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: _isUploading ? const SizedBox.shrink() : const Icon(Icons.add_photo_alternate_outlined),
                      label: _isUploading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                          : const Text('Add Banner'),
                      onPressed: _isUploading ? null : _addBanner,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20, thickness: 1),
            Expanded(
              child: _isLoadingBanners
                  ? const Center(child: CircularProgressIndicator())
                  : _loadingError != null
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_loadingError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ))
                  : _banners.isEmpty
                  ? const Center(child: Text('No banners found. Add one above!'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
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


// lib/user/family/family_edit_screen.dart
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class EditScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const EditScreen({Key? key, required this.member}) : super(key: key);

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _relationController;
  late TextEditingController _phoneController;
  String _imageUrl = '';
  File? _newImage;
  final _picker = ImagePicker();
  final cloudinary = CloudinaryPublic('dts8hgf4f', 'family_members');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member['name']);
    _relationController = TextEditingController(text: widget.member['relation']);
    _phoneController = TextEditingController(text: widget.member['phone']);
    _imageUrl = widget.member['imageUrl'] ?? '';
  }

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Permission denied')));
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) setState(() => _newImage = File(picked.path));
  }

  Future<String> _uploadImage() async {
    if (_newImage == null) return _imageUrl;
    try {
      final r = await cloudinary.uploadFile(CloudinaryFile.fromFile(_newImage!.path));
      return r.secureUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
      return _imageUrl;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _relationController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All fields are required')));
      }
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    if (mounted) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final url = await _uploadImage();
    if (!mounted) return;

    Navigator.pop(context);
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'relation': _relationController.text.trim(),
      'phone': _phoneController.text.trim(),
      'imageUrl': url,
    });
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Member'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Member Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 24),
              _buildTextField(_nameController, 'Name', Icons.person),
              _buildTextField(_relationController, 'Relation', Icons.family_restroom),
              _buildTextField(_phoneController, 'Phone', Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 24),
              const Text(
                'Profile Picture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _newImage != null
                            ? FileImage(_newImage!)
                            : (_imageUrl.isNotEmpty ? NetworkImage(_imageUrl) : null),
                        child: _newImage == null && _imageUrl.isEmpty
                            ? const Icon(Icons.person, size: 60, color: Colors.blueAccent)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 20,
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _isSaving
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
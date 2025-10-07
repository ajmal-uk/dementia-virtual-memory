// lib/user/family/family_edit_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

final logger = Logger();

class EditScreen extends StatefulWidget {
  final String memberId;
  final Map<String, dynamic> memberData;

  const EditScreen({super.key, required this.memberId, required this.memberData});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _image;
  String? _existingImageUrl;
  final _picker = ImagePicker();
  final cloudinary = CloudinaryPublic('dts8hgf4f', 'family_members');
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize text controllers with existing member data
    _nameController.text = widget.memberData['name'] ?? '';
    _relationController.text = widget.memberData['relation'] ?? '';
    _phoneController.text = widget.memberData['phone'] ?? '';
    _existingImageUrl = widget.memberData['imageUrl'] ?? '';
  }

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission denied')),
        );
      }
      return;
    }
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() => _image = File(picked.path));
      }
    } catch (e) {
      logger.e('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  static Uint8List _processImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    img.Image resized = image;
    const maxSize = 512;
    if (image.width > maxSize || image.height > maxSize) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: maxSize);
      } else {
        resized = img.copyResize(image, height: maxSize);
      }
    }
    return img.encodeJpg(resized, quality: 85);
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return _existingImageUrl;
    try {
      final bytes = await _image!.readAsBytes();
      final processedBytes = await compute(_processImage, bytes);
      final r = await cloudinary
          .uploadFile(CloudinaryFile.fromBytesData(processedBytes, identifier: 'family_member.jpg'))
          .timeout(const Duration(seconds: 30));
      return r.secureUrl;
    } catch (e) {
      logger.e('Image upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
      return _existingImageUrl;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _relationController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All fields are required')),
        );
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

    try {
      final url = await _uploadImage();
      if (!mounted) return;

      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      await _firestore
          .collection('user')
          .doc(uid)
          .collection('family_members')
          .doc(widget.memberId)
          .update({
        'name': _nameController.text.trim(),
        'relation': _relationController.text.trim(),
        'phone': _phoneController.text.trim(),
        'imageUrl': url ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Return to family screen
    } catch (e) {
      logger.e('Error updating member: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Member'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Member Details',
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
                      backgroundImage: _image != null
                          ? FileImage(_image!)
                          : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                              ? NetworkImage(_existingImageUrl!)
                              : null,
                      child: _image == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty)
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
                    child: const Text('Update Member', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
          ],
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
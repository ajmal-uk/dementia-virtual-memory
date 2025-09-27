// lib/user/family/family_add_screen.dart
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({Key? key}) : super(key: key);

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _image;
  final _picker = ImagePicker();
  final cloudinary = CloudinaryPublic('dts8hgf4f', 'family_members');

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Permission denied')));
      }
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return '';
    return cloudinary.uploadFile(CloudinaryFile.fromFile(_image!.path)).then(
      (r) => r.secureUrl,
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
        return '';
      },
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _relationController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('All fields are required')));
      return;
    }

    // show loading dialog to prevent “freeze” perception
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );

    final url = await _uploadImage();
    if (!mounted) return;

    Navigator.pop(context); // close loading
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'relation': _relationController.text.trim(),
      'phone': _phoneController.text.trim(),
      'imageUrl': url ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Add Member', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        color: Colors.lightBlue[100],
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: _fieldDecoration('Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _relationController,
              decoration: _fieldDecoration('Relation'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration('Phone'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _pickImage, child: const Text('Pick Image')),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Selected: ${_image!.path.split('/').last}'),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

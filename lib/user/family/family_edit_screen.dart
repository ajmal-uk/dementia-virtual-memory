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
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  Future<String> _uploadImage() async {
    if (_newImage == null) return _imageUrl;
    try {
      final r = await cloudinary.uploadFile(CloudinaryFile.fromFile(_newImage!.path));
      return r.secureUrl;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return _imageUrl;
    }
  }

  Future<void> _save() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final url = await _uploadImage();
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'relation': _relationController.text.trim(),
      'phone': _phoneController.text.trim(),
      'imageUrl': url,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: const Text('Edit Member', style: TextStyle(color: Colors.white))),
      body: Container(
        color: Colors.lightBlue[100],
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _nameController, decoration: _dec('Name')),
            const SizedBox(height: 10),
            TextField(controller: _relationController, decoration: _dec('Relation')),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, decoration: _dec('Phone')),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _pickImage, child: const Text('Pick New Image')),
            if (_newImage != null) Text('Selected: ${_newImage!.path.split('/').last}'),
            if (_imageUrl.isNotEmpty) Text('Current URL: $_imageUrl'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

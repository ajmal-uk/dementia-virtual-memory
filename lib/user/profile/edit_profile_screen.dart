// lib/user/profile/edit_profile_screen.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _localityController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  DateTime? _dob;
  String? _gender;
  String _profileImageUrl = '';
  File? _newProfileImage;
  final _picker = ImagePicker();
  final cloudinary = CloudinaryPublic('dts8hgf4f', 'user_image');

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.userData['fullName']);
    _usernameController = TextEditingController(text: widget.userData['username']);
    _bioController = TextEditingController(text: widget.userData['bio']);
    _phoneController = TextEditingController(text: widget.userData['phoneNo']);
    _localityController = TextEditingController(text: widget.userData['locality']);
    _cityController = TextEditingController(text: widget.userData['city']);
    _stateController = TextEditingController(text: widget.userData['state']);
    _dob = widget.userData['dob']?.toDate();
    _gender = widget.userData['gender'];
    _profileImageUrl = widget.userData['profileImageUrl'] ?? '';
  }

  Future<void> _pickImage() async {
    if (await Permission.photos.request().isGranted) {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _newProfileImage = File(picked.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_newProfileImage == null) return _profileImageUrl;
    try {
      final response = await cloudinary.uploadFile(CloudinaryFile.fromFile(_newProfileImage!.path));
      return response.secureUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return _profileImageUrl;
    }
  }

  Future<void> _saveChanges() async {
    final url = await _uploadImage();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('user').doc(uid).update({
        'fullName': _fullNameController.text,
        'username': _usernameController.text,
        'bio': _bioController.text,
        'phoneNo': _phoneController.text,
        'profileImageUrl': url,
        'locality': _localityController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
        'gender': _gender,
      });
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _fullNameController, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio')),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
            ElevatedButton(onPressed: _pickImage, child: const Text('Pick New Profile Image')),
            if (_newProfileImage != null) Text('Selected: ${_newProfileImage!.path.split('/').last}'),
            if (_profileImageUrl.isNotEmpty) Text('Current URL: $_profileImageUrl'),
            TextField(controller: _localityController, decoration: const InputDecoration(labelText: 'Locality')),
            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
            TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'State')),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(_dob == null ? 'Select DOB' : DateFormat('yyyy-MM-dd').format(_dob!)),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dob ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _dob = picked);
                  },
                ),
              ],
            ),
            DropdownButton<String>(
              value: _gender,
              hint: const Text('Select Gender'),
              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saveChanges, child: const Text('Save Changes')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // dispose controllers
    super.dispose();
  }
}
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
  bool _isSaving = false;
  List<Map<String, dynamic>> _emergencyContacts = [];

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
    
    final genderFromData = widget.userData['gender'];
    if (genderFromData is String) {
      _gender = genderFromData.toLowerCase();
    } else {
      _gender = 'male'; 
    }
    
    _profileImageUrl = widget.userData['profileImageUrl'] ?? '';
    _emergencyContacts = List<Map<String, dynamic>>.from(widget.userData['emergencyContacts'] ?? []);
  }

  Future<void> _pickImage() async {
    if (await Permission.photos.request().isGranted) {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() => _newProfileImage = File(picked.path));
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_newProfileImage == null) return _profileImageUrl;
    try {
      final response = await cloudinary.uploadFile(CloudinaryFile.fromFile(_newProfileImage!.path));
      return response.secureUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
      return _profileImageUrl;
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving || !mounted) return;
    setState(() => _isSaving = true);
    final url = await _uploadImage();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && mounted) {
      try {
        await FirebaseFirestore.instance.collection('user').doc(uid).update({
          'fullName': _fullNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'bio': _bioController.text.trim(),
          'phoneNo': _phoneController.text.trim(),
          'profileImageUrl': url,
          'locality': _localityController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
          'gender': _gender?.toLowerCase(), 
          'emergencyContacts': _emergencyContacts,
        });
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
        }
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _pickDob() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
    }
  }

  void _addEmergencyContact() {
    _showContactDialog();
  }

  void _editEmergencyContact(int index) {
    _showContactDialog(index: index);
  }

  void _deleteEmergencyContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }

  void _showContactDialog({int? index}) {
    final isEdit = index != null;
    final nameController = TextEditingController(text: isEdit ? _emergencyContacts[index]['name'] : '');
    final relationController = TextEditingController(text: isEdit ? _emergencyContacts[index]['relation'] : '');
    final phoneController = TextEditingController(text: isEdit ? _emergencyContacts[index]['number'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Contact' : 'Add Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: relationController, decoration: const InputDecoration(labelText: 'Relation')),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final relation = relationController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isNotEmpty && relation.isNotEmpty && phone.isNotEmpty) {
                  final contact = {'name': name, 'relation': relation, 'number': phone};
                  setState(() {
                    if (isEdit) {
                      _emergencyContacts[index] = contact;
                    } else {
                      _emergencyContacts.add(contact);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        backgroundImage: _newProfileImage != null
                            ? FileImage(_newProfileImage!)
                            : (_profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) : null),
                        child: (_newProfileImage == null && _profileImageUrl.isEmpty)
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
              const SizedBox(height: 24),
              const Text(
                'Personal Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
              ),
              const SizedBox(height: 8),
              _buildTextField(_fullNameController, 'Full Name', Icons.person),
              _buildTextField(_usernameController, 'Username', Icons.alternate_email),
              _buildTextField(_bioController, 'Bio', Icons.info, maxLines: 3),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(_dob == null ? 'Select DOB' : DateFormat('yyyy-MM-dd').format(_dob!)),
                  trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  onTap: _pickDob,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _gender,
                hint: const Text('Select Gender'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  DropdownMenuItem(value: 'male', child: const Text('Male')),
                  DropdownMenuItem(value: 'female', child: const Text('Female')),
                  DropdownMenuItem(value: 'other', child: const Text('Other')),
                ],
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 24),
              const Text(
                'Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
              ),
              const SizedBox(height: 8),
              _buildTextField(_localityController, 'Locality', Icons.location_on),
              _buildTextField(_cityController, 'City', Icons.location_city),
              _buildTextField(_stateController, 'State', Icons.map),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Emergency Contacts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                    onPressed: _addEmergencyContact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_emergencyContacts.isEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No emergency contacts added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: _emergencyContacts.asMap().entries.map((entry) {
                    int idx = entry.key;
                    Map<String, dynamic> contact = entry.value;
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.emergency, color: Colors.red),
                        title: Text(contact['name'] ?? ''),
                        subtitle: Text(
                          'Relation: ${contact['relation'] ?? ''}\\nPhone: ${contact['number'] ?? ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editEmergencyContact(idx),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEmergencyContact(idx),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 32),
              _isSaving
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : ElevatedButton(
                      onPressed: _saveChanges,
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
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
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _localityController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }
}
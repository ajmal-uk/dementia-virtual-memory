// lib/register_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class RegisterPage extends StatefulWidget {
  final String role;
  const RegisterPage({super.key, required this.role});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController localityController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();

  // User specific
  DateTime? dob;
  String? gender;
  final TextEditingController emergencyNameController = TextEditingController();
  final TextEditingController emergencyRelationController =
      TextEditingController();
  final TextEditingController emergencyPhoneController =
      TextEditingController();

  // Caretaker specific
  final TextEditingController experienceYearsController =
      TextEditingController();
  final TextEditingController experienceBioController = TextEditingController();
  final TextEditingController graduationYearController =
      TextEditingController();
  final TextEditingController graduationFromController =
      TextEditingController();

  File? _profileImage;
  File? _certificate;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();
  bool _loading = false;

  final cloudinary = CloudinaryPublic(
    'dts8hgf4f',
    'default',
    cache: false,
  ); // default not used, use preset in upload

  Future<void> _pickProfileImage() async {
    if (await Permission.photos.request().isGranted) {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null)
      setState(() => _certificate = File(result.files.first.path!));
  }

  Future<String?> _uploadFile(File file, String preset) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Auto,
          folder: preset,
        ),
        uploadPreset: preset,
      );
      return response.secureUrl;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return null;
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final username = usernameController.text.trim();
      final phone = phoneController.text.trim();
      final snapUsername = await _firestore
          .collection(widget.role)
          .where('username', isEqualTo: username)
          .get();
      if (snapUsername.docs.isNotEmpty) throw 'Username already exists';

      final snapPhone = await _firestore
          .collection(widget.role)
          .where('phoneNo', isEqualTo: phone)
          .get();
      if (snapPhone.docs.isNotEmpty) throw 'Phone number already exists';

      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final uid = credential.user?.uid;
      if (uid != null) {
        String? profileUrl = 'https://res.cloudinary.com/dts8hgf4f/image/upload/v1758882470/user_jvnx80.png';
        if (_profileImage != null) {
          profileUrl = await _uploadFile(
            _profileImage!,
            widget.role == 'user' ? 'user_image' : 'care_taker_image',
          );
        }
        Map<String, dynamic> data = {
          'uid': uid,
          'fullName': nameController.text.trim(),
          'username': username,
          'email': emailController.text.trim(),
          'phoneNo': phone,
          'bio': bioController.text.trim(),
          'profileImageUrl': profileUrl ?? '',
          'locality': localityController.text.trim(),
          'city': cityController.text.trim(),
          'state': stateController.text.trim(),
          'createdAt': Timestamp.now(),
          'currentConnectionId': null,
          'emergencyContacts': [],
          'members': [],
          'reports_sent': [],
          'playerIds': [],
          'isBanned': false,
        };
        if (widget.role == 'user') {
          data.addAll({
            'dob': dob != null ? Timestamp.fromDate(dob!) : null,
            'gender': gender,
            'emergencyContacts': [
              {
                'name': emergencyNameController.text.trim(),
                'relation': emergencyRelationController.text.trim(),
                'number': emergencyPhoneController.text.trim(),
              },
            ],
          });
        } else if (widget.role == 'caretaker') {
          String? certUrl;
          if (_certificate != null) {
            certUrl = await _uploadFile(_certificate!, 'graduation');
          }
          data.addAll({
            'dob': dob != null ? Timestamp.fromDate(dob!) : null,
            'gender': gender,
            'experienceYears':
                int.tryParse(experienceYearsController.text.trim()) ?? 0,
            'experienceBio': experienceBioController.text.trim(),
            'graduationOnNursing': {
              'year': graduationYearController.text.trim(),
              'from': graduationFromController.text.trim(),
              'uploadCertificateUrl': certUrl ?? '',
            },
            'isApprove': false,
            'isRemove': false,
            'roadmap': [],
          });
        }
        await _firestore.collection(widget.role).doc(uid).set(data);
        // Add player ID
        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null) {
          await _firestore.collection(widget.role).doc(uid).update({
            'playerIds': FieldValue.arrayUnion([playerId]),
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.role == 'user';
    return Scaffold(
      appBar: AppBar(title: Text('Register as ${widget.role.toUpperCase()}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            TextField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            TextField(
              controller: localityController,
              decoration: const InputDecoration(labelText: 'Locality'),
            ),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            TextField(
              controller: stateController,
              decoration: const InputDecoration(labelText: 'State'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  dob == null
                      ? 'Select DOB'
                      : DateFormat('yyyy-MM-dd').format(dob!),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(1960),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => dob = picked);
                  },
                ),
              ],
            ),
            DropdownButton<String>(
              value: gender,
              hint: const Text('Select Gender'),
              items: [
                'Male',
                'Female',
                'Other',
              ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (value) => setState(() => gender = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickProfileImage,
              child: const Text('Pick Profile Image'),
            ),
            if (_profileImage != null)
              Text('Selected: ${_profileImage!.path.split('/').last}'),
            if (isUser) ...[
              const SizedBox(height: 16),
              TextField(
                controller: emergencyNameController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Name',
                ),
              ),
              TextField(
                controller: emergencyRelationController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Relation',
                ),
              ),
              TextField(
                controller: emergencyPhoneController,
                decoration: const InputDecoration(labelText: 'Emergency Phone'),
              ),
            ],
            if (!isUser) ...[
              TextField(
                controller: experienceYearsController,
                decoration: const InputDecoration(
                  labelText: 'Experience Years',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: experienceBioController,
                decoration: const InputDecoration(labelText: 'Experience Bio'),
              ),
              TextField(
                controller: graduationYearController,
                decoration: const InputDecoration(labelText: 'Graduation Year'),
              ),
              TextField(
                controller: graduationFromController,
                decoration: const InputDecoration(labelText: 'Graduation From'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickCertificate,
                child: const Text('Pick Graduation Certificate'),
              ),
              if (_certificate != null)
                Text('Selected: ${_certificate!.path.split('/').last}'),
            ],
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: Text('Register as ${widget.role}'),
                  ),
          ],
        ),
      ),
    );
  }
}
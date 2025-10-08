import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'careTaker/caretaker_bottom_nav.dart';
import 'user/user_bottom_nav.dart';

enum CaregiverType { relative, nurse }

enum UserGender { male, female, other }

enum FormSection { personal, address, caretaker, review }

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
  final TextEditingController experienceYearsController =
      TextEditingController();
  final TextEditingController relationController = TextEditingController();
  final TextEditingController expBioController = TextEditingController();
  final TextEditingController gradNursingController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _loading = false;

  CaregiverType _caregiverType = CaregiverType.relative;
  UserGender _selectedGender = UserGender.male;
  DateTime? _selectedDOB;
  String? _selectedProfileImagePath;
  String? _selectedCertificatePath;

  FormSection _currentSection = FormSection.personal;

  final ImagePicker _picker = ImagePicker();

  static const String defaultProfileImageUrl =
      'https://res.cloudinary.com/dts8hgf4f/image/upload/v1758882470/user_jvnx80.png';

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    experienceYearsController.dispose();
    relationController.dispose();
    bioController.dispose();
    localityController.dispose();
    cityController.dispose();
    stateController.dispose();
    expBioController.dispose();
    gradNursingController.dispose();
    super.dispose();
  }

  void _nextSection() {
    if (!_validateCurrentSection()) return;

    setState(() {
      switch (_currentSection) {
        case FormSection.personal:
          _currentSection = FormSection.address;
          break;
        case FormSection.address:
          if (widget.role == 'caretaker') {
            _currentSection = FormSection.caretaker;
          } else {
            _currentSection = FormSection.review;
          }
          break;
        case FormSection.caretaker:
          _currentSection = FormSection.review;
          break;
        case FormSection.review:
          _register();
          break;
      }
    });
  }

  void _previousSection() {
    setState(() {
      switch (_currentSection) {
        case FormSection.address:
          _currentSection = FormSection.personal;
          break;
        case FormSection.caretaker:
          _currentSection = FormSection.address;
          break;
        case FormSection.review:
          if (widget.role == 'caretaker') {
            _currentSection = FormSection.caretaker;
          } else {
            _currentSection = FormSection.address;
          }
          break;
        case FormSection.personal:
          break;
      }
    });
  }

  bool _validateCurrentSection() {
    switch (_currentSection) {
      case FormSection.personal:
        if (nameController.text.trim().isEmpty) {
          _showErrorDialog('Full Name is required');
          return false;
        }
        if (usernameController.text.trim().isEmpty) {
          _showErrorDialog('Username is required');
          return false;
        }
        if (emailController.text.trim().isEmpty) {
          _showErrorDialog('Email is required');
          return false;
        }
        if (!RegExp(
          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        ).hasMatch(emailController.text.trim())) {
          _showErrorDialog('Please enter a valid email address');
          return false;
        }
        if (passwordController.text.trim().isEmpty) {
          _showErrorDialog('Password is required');
          return false;
        }
        if (passwordController.text.length < 6) {
          _showErrorDialog('Password must be at least 6 characters long');
          return false;
        }
        if (phoneController.text.trim().isEmpty) {
          _showErrorDialog('Phone number is required');
          return false;
        }
        if (_selectedDOB == null) {
          _showErrorDialog('Date of Birth is required');
          return false;
        }
        return true;
      case FormSection.address:
        if (bioController.text.trim().isEmpty) {
          _showErrorDialog('Bio is required');
          return false;
        }
        if (localityController.text.trim().isEmpty) {
          _showErrorDialog('Locality is required');
          return false;
        }
        if (cityController.text.trim().isEmpty) {
          _showErrorDialog('City is required');
          return false;
        }
        if (stateController.text.trim().isEmpty) {
          _showErrorDialog('State is required');
          return false;
        }
        return true;
      case FormSection.caretaker:
        if (_caregiverType == CaregiverType.relative) {
          if (relationController.text.trim().isEmpty) {
            _showErrorDialog('Please enter your relation to the patient');
            return false;
          }
        } else if (_caregiverType == CaregiverType.nurse) {
          if (experienceYearsController.text.trim().isEmpty) {
            _showErrorDialog('Experience years is required for nurses');
            return false;
          }
          if (expBioController.text.trim().isEmpty) {
            _showErrorDialog('Experience bio is required for nurses');
            return false;
          }
          if (gradNursingController.text.trim().isEmpty) {
            _showErrorDialog('Nursing qualification is required for nurses');
            return false;
          }

          if (_selectedCertificatePath == null) {
            _showErrorDialog(
              'Graduation certificate is required for nurse registration',
            );
            return false;
          }
        }
        return true;
      case FormSection.review:
        return true;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Validation Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000),
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
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDOB) {
      setState(() {
        _selectedDOB = picked;
      });
    }
  }

  void _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedProfileImagePath = image.path;
      });
    }
  }

  void _pickCertificate() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedCertificatePath = image.path;
      });
    }
  }

  Future<String?> _uploadFile(String? filePath, String preset) async {
    if (filePath == null) return null;

    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];

    if (cloudName == null || cloudName.isEmpty) {
      if (mounted) {
        _showErrorDialog(
          'Cloudinary configuration error. Please try again later.',
        );
      }
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = preset
        ..fields['cloud_name'] = cloudName;

      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final secureUrl = responseData['secure_url'];

        if (secureUrl is String && secureUrl.isNotEmpty) return secureUrl;
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    String? profileUrl;
    String? certificateUrl;

    try {
      final username = usernameController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();

      final snapUsername = await _firestore
          .collection(widget.role)
          .where('username', isEqualTo: username)
          .get();
      if (snapUsername.docs.isNotEmpty) {
        throw 'Username "$username" is already taken. Please choose a different username.';
      }

      final snapEmail = await _firestore
          .collection(widget.role)
          .where('email', isEqualTo: email)
          .get();
      if (snapEmail.docs.isNotEmpty) {
        throw 'Email "$email" is already registered. Please use a different email or try logging in.';
      }

      if (_selectedProfileImagePath != null) {
        profileUrl = await _uploadFile(
          _selectedProfileImagePath,
          'care_taker_image',
        );
      } else {
        profileUrl = defaultProfileImageUrl;
      }

      if (widget.role == 'caretaker' && _caregiverType == CaregiverType.nurse) {
        certificateUrl = await _uploadFile(
          _selectedCertificatePath,
          'graduation',
        );

        if (certificateUrl == null) {
          throw 'Failed to upload graduation certificate. Please try again.';
        }
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );
      final uid = credential.user?.uid;

      if (uid != null) {
        try {
          OneSignal.login(uid);
        } catch (e) {
          debugPrint('OneSignal login failed during registration: $e');
        }

        Map<String, dynamic> data = {
          'uid': uid,
          'fullName': nameController.text.trim(),
          'username': username,
          'email': email,
          'phoneNo': phone,
          'createdAt': Timestamp.now(),
          'gender': _selectedGender.name,
          'dateOfBirth': Timestamp.fromDate(_selectedDOB!),
          'bio': bioController.text.trim(),
          'locality': localityController.text.trim(),
          'city': cityController.text.trim(),
          'state': stateController.text.trim(),
          'profileImageUrl': profileUrl!,
          'isConnected': false,
          'currentConnectionId': null,
          'emergencyContacts': [],
          'members': [],
          'reports_sent': [],
          'playerIds': [],
          'isBanned': false,
        };

        if (widget.role == 'caretaker') {
          data['caregiverType'] = _caregiverType.name;

          if (_caregiverType == CaregiverType.relative) {
            data['relation'] = relationController.text.trim();
            data['experienceYears'] = 0;
            data['experienceBio'] = '';
            data['graduationOnNursing'] = '';
            data['graduationCertificateUrl'] = '';
          } else {
            data['experienceYears'] =
                int.tryParse(experienceYearsController.text.trim()) ?? 0;
            data['relation'] = '';
            data['experienceBio'] = expBioController.text.trim();
            data['graduationOnNursing'] = gradNursingController.text.trim();
            data['graduationCertificateUrl'] = certificateUrl ?? '';
          }

          data.addAll({'isApprove': false, 'roadmap': []});
        }

        await _firestore.collection(widget.role).doc(uid).set(data);

        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null) {
          await _firestore.collection(widget.role).doc(uid).update({
            'playerIds': FieldValue.arrayUnion([playerId]),
          });
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastRole', widget.role);

        if (mounted) {
          _showSuccessDialog('Registration successful! Welcome to DVMA.');

          Widget targetScreen = const SizedBox();

          if (widget.role == 'user') {
            targetScreen = const UserBottomNav();
          } else if (widget.role == 'caretaker') {
            targetScreen = const CareTaker();
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String message = 'Registration failed. Please try again.';

        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              message =
                  'This email is already registered. Please use a different email or try logging in.';
              break;
            case 'weak-password':
              message =
                  'Password is too weak. Please choose a stronger password.';
              break;
            case 'invalid-email':
              message =
                  'The email address is invalid. Please check and try again.';
              break;
            case 'operation-not-allowed':
              message =
                  'Email/password accounts are not enabled. Please contact support.';
              break;
            default:
              message = 'Authentication error: ${e.message}';
          }
        } else if (e is String) {
          message = e;
        }

        _showErrorDialog(message);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildFilePicker({
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
    required IconData icon,
    bool isRequired = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected ? Colors.green.withOpacity(0.05) : Colors.white,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.green
                      : Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.blueAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRequired ? '$label *' : label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSelected ? 'File selected ✓' : 'Tap to select file',
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.green : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                color: isSelected ? Colors.green : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(CaregiverType value, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _caregiverType == value
              ? Colors.blueAccent
              : Colors.grey.shade300,
          width: _caregiverType == value ? 2 : 1,
        ),
        color: _caregiverType == value
            ? Colors.blueAccent.withOpacity(0.05)
            : Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Radio<CaregiverType>(
          value: value,
          groupValue: _caregiverType,
          onChanged: (CaregiverType? selectedValue) {
            setState(() {
              _caregiverType = selectedValue!;
            });
          },
          activeColor: Colors.blueAccent,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildGenderChip(UserGender value, String title) {
    final isSelected = _selectedGender == value;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedGender = value;
        });
      },
      selectedColor: Colors.blueAccent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildProgressIndicator() {
    final sections = widget.role == 'caretaker'
        ? ['Personal', 'Address', 'Caretaker', 'Review']
        : ['Personal', 'Address', 'Review'];

    final currentIndex = _currentSection.index;
    final totalSections = sections.length;

    return Column(
      children: [
        Stack(
          children: [
            LinearProgressIndicator(
              value: (currentIndex + 1) / totalSections,
              backgroundColor: Colors.grey.shade200,
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
            Positioned(
              right: 0,
              child: Text(
                '${((currentIndex + 1) / totalSections * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            final isActive = index <= currentIndex;
            final isCurrent = index == currentIndex;

            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.blueAccent
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(color: Colors.blueAccent, width: 3)
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        isActive ? Icons.check : Icons.circle,
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        size: isActive ? 18 : 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrent
                          ? Colors.blueAccent
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPersonalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Personal Information',
          subtitle: 'Tell us about yourself',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 24),
        _buildTextField(nameController, 'Full Name', Icons.person),
        _buildTextField(usernameController, 'Username', Icons.alternate_email),
        _buildTextField(emailController, 'Email Address', Icons.email_outlined),
        _buildTextField(
          passwordController,
          'Password',
          Icons.lock_outline,
          obscureText: true,
        ),
        _buildTextField(
          phoneController,
          'Phone Number',
          Icons.phone_iphone,
          keyboardType: TextInputType.phone,
        ),

        _buildFilePicker(
          label: 'Profile Image',
          onTap: _pickProfileImage,
          isSelected: _selectedProfileImagePath != null,
          icon: Icons.camera_alt,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Optional - Default image will be used if not selected',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Gender *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildGenderChip(UserGender.male, 'Male'),
            const SizedBox(width: 12),
            _buildGenderChip(UserGender.female, 'Female'),
            const SizedBox(width: 12),
            _buildGenderChip(UserGender.other, 'Other'),
          ],
        ),

        const SizedBox(height: 16),
        Text(
          'Date of Birth *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedDOB == null
                      ? 'Select your date of birth'
                      : '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDOB == null
                        ? Colors.grey.shade500
                        : Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Address Information',
          subtitle: 'Where are you located?',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          bioController,
          'Bio',
          Icons.description_outlined,
          maxLines: 3,
        ),
        _buildTextField(
          localityController,
          'Locality/Area',
          Icons.location_on_outlined,
        ),
        _buildTextField(cityController, 'City', Icons.location_city_outlined),
        _buildTextField(stateController, 'State', Icons.public_outlined),
      ],
    );
  }

  Widget _buildCaretakerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Caretaker Details',
          subtitle: 'Tell us about your caregiving experience',
          icon: Icons.medical_services_outlined,
        ),
        const SizedBox(height: 24),

        Text(
          'I am registering as a: *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        _buildRadio(
          CaregiverType.relative,
          'Family Relative',
          'Caring for a family member or relative',
        ),
        _buildRadio(
          CaregiverType.nurse,
          'Professional Nurse',
          'Registered nurse with professional qualifications',
        ),
        const SizedBox(height: 16),

        if (_caregiverType == CaregiverType.relative) ...[
          _buildTextField(
            relationController,
            'Relation to Patient',
            Icons.family_restroom_outlined,
          ),
        ] else ...[
          _buildTextField(
            experienceYearsController,
            'Years of Experience',
            Icons.work_history_outlined,
            keyboardType: TextInputType.number,
          ),
          _buildTextField(
            expBioController,
            'Professional Experience',
            Icons.description_outlined,
            maxLines: 3,
          ),
          _buildTextField(
            gradNursingController,
            'Nursing Qualification',
            Icons.school_outlined,
          ),
          _buildFilePicker(
            label: 'Graduation Certificate',
            onTap: _pickCertificate,
            isSelected: _selectedCertificatePath != null,
            icon: Icons.assignment_outlined,
            isRequired: true,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Graduation certificate is required for nurse registration',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Review Information',
          subtitle: 'Please verify all details before submitting',
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 24),

        _buildReviewSectionTitle('Personal Information'),
        _buildReviewItem('Full Name', nameController.text),
        _buildReviewItem('Username', usernameController.text),
        _buildReviewItem('Email', emailController.text),
        _buildReviewItem('Phone', phoneController.text),
        _buildReviewItem('Gender', _selectedGender.name.toUpperCase()),
        _buildReviewItem(
          'Date of Birth',
          _selectedDOB != null
              ? '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}'
              : 'Not selected',
        ),
        _buildReviewItem(
          'Profile Image',
          _selectedProfileImagePath != null ? 'Uploaded' : 'Default image',
        ),

        _buildReviewSectionTitle('Address Information'),
        _buildReviewItem('Bio', bioController.text),
        _buildReviewItem('Locality', localityController.text),
        _buildReviewItem('City', cityController.text),
        _buildReviewItem('State', stateController.text),

        if (widget.role == 'caretaker') ...[
          _buildReviewSectionTitle('Caretaker Details'),
          _buildReviewItem(
            'Caregiver Type',
            _caregiverType == CaregiverType.relative
                ? 'Family Relative'
                : 'Professional Nurse',
          ),
          if (_caregiverType == CaregiverType.relative)
            _buildReviewItem('Relation to Patient', relationController.text),
          if (_caregiverType == CaregiverType.nurse) ...[
            _buildReviewItem(
              'Years of Experience',
              '${experienceYearsController.text} years',
            ),
            _buildReviewItem('Professional Experience', expBioController.text),
            _buildReviewItem(
              'Nursing Qualification',
              gradNursingController.text,
            ),
            _buildReviewItem(
              'Graduation Certificate',
              _selectedCertificatePath != null ? 'Uploaded ✓' : 'Not uploaded',
            ),
          ],
        ],

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'By submitting, you agree to our Terms of Service and Privacy Policy',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: TextStyle(
                color: value.isEmpty
                    ? Colors.grey.shade500
                    : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Register as ${widget.role == 'caretaker' ? 'Caregiver' : 'User'}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent, Color(0xFFE3F2FD), Colors.white],
            stops: [0.0, 0.2, 0.2],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildProgressIndicator(),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentSection == FormSection.personal)
                        _buildPersonalSection(),
                      if (_currentSection == FormSection.address)
                        _buildAddressSection(),
                      if (_currentSection == FormSection.caretaker)
                        _buildCaretakerSection(),
                      if (_currentSection == FormSection.review)
                        _buildReviewSection(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentSection != FormSection.personal)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousSection,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.blueAccent),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back_ios, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_currentSection != FormSection.personal)
                  const SizedBox(width: 16),
                  Expanded(
                    child: _loading
                        ? Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _nextSection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentSection == FormSection.review
                                      ? 'Complete Registration'
                                      : 'Continue',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_currentSection != FormSection.review)
                                  const Row(
                                    children: [
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_ios, size: 16),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

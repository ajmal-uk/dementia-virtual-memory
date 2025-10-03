import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  final TextEditingController experienceYearsController = TextEditingController();
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

  // Default profile image URL
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
        if (nameController.text.trim().isEmpty ||
            usernameController.text.trim().isEmpty ||
            emailController.text.trim().isEmpty ||
            passwordController.text.trim().isEmpty ||
            phoneController.text.trim().isEmpty ||
            _selectedDOB == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill in all personal information fields.'),
            ),
          );
          return false;
        }
        return true;
      case FormSection.address:
        if (bioController.text.trim().isEmpty ||
            localityController.text.trim().isEmpty ||
            cityController.text.trim().isEmpty ||
            stateController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill in all address fields.'),
            ),
          );
          return false;
        }
        return true;
      case FormSection.caretaker:
        if (_caregiverType == CaregiverType.relative) {
          if (relationController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter your relation to the patient.'),
              ),
            );
            return false;
          }
        } else if (_caregiverType == CaregiverType.nurse) {
          if (experienceYearsController.text.trim().isEmpty ||
              expBioController.text.trim().isEmpty ||
              gradNursingController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please complete all nurse-specific experience fields.',
                ),
              ),
            );
            return false;
          }
          // Certificate validation for nurses
          if (_selectedCertificatePath == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please upload your graduation certificate as a nurse.',
                ),
              ),
            );
            return false;
          }
        }
        return true;
      case FormSection.review:
        return true;
    }
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

  // Cloudinary upload logic
  Future<String?> _uploadFile(String? filePath, String preset) async {
    if (filePath == null) return null;

    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];

    if (cloudName == null || cloudName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: CLOUDINARY_CLOUD_NAME missing or empty in .env',
            ),
          ),
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
      final phone = phoneController.text.trim();

      // Check for existing username
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

      // Upload profile image or use default
      if (_selectedProfileImagePath != null) {
        profileUrl = await _uploadFile(
          _selectedProfileImagePath,
          'care_taker_image',
        );
      } else {
        // Use default profile image if none selected
        profileUrl = defaultProfileImageUrl;
      }

      // Upload certificate for nurses
      if (widget.role == 'caretaker' && _caregiverType == CaregiverType.nurse) {
        certificateUrl = await _uploadFile(
          _selectedCertificatePath,
          'graduation',
        );
        
        // Double check certificate upload for nurses
        if (certificateUrl == null) {
          throw 'Failed to upload graduation certificate. Please try again.';
        }
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final uid = credential.user?.uid;

      if (uid != null) {
        Map<String, dynamic> data = {
          'uid': uid,
          'fullName': nameController.text.trim(),
          'username': username,
          'email': emailController.text.trim(),
          'phoneNo': phone,
          'createdAt': Timestamp.now(),
          'gender': _selectedGender.name,
          'dateOfBirth': Timestamp.fromDate(_selectedDOB!),
          'bio': bioController.text.trim(),
          'locality': localityController.text.trim(),
          'city': cityController.text.trim(),
          'state': stateController.text.trim(),
          'profileImageUrl': profileUrl ?? defaultProfileImageUrl, // Ensure default is used
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

        // Add player ID
        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null) {
          await _firestore.collection(widget.role).doc(uid).update({
            'playerIds': FieldValue.arrayUnion([playerId]),
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful')),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString().contains('firebase_auth')
            ? (e as FirebaseAuthException).message ?? e.toString()
            : e.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $message')),
        );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _inputDecoration(
            isRequired ? '$label *' : label, 
            icon
          ).copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            fillColor: isSelected ? Colors.green.withOpacity(0.1) : Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isSelected ? '$label Uploaded' : 'Click to Upload $label',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? Colors.green : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.upload_file,
                color: isSelected ? Colors.green : Colors.blueAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(CaregiverType value, String title) {
    return Expanded(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
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
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildGenderRadio(UserGender value, String title) {
    return Expanded(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        leading: Radio<UserGender>(
          value: value,
          groupValue: _selectedGender,
          onChanged: (UserGender? selectedValue) {
            setState(() {
              _selectedGender = selectedValue!;
            });
          },
          activeColor: Colors.blueAccent,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  // Progress indicator
  Widget _buildProgressIndicator() {
    final sections = widget.role == 'caretaker'
        ? ['Personal', 'Address', 'Caretaker', 'Review']
        : ['Personal', 'Address', 'Review'];
    
    final currentIndex = _currentSection.index;
    final totalSections = sections.length;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (currentIndex + 1) / totalSections,
          backgroundColor: Colors.grey[300],
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 16),
        // Section labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            return Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: index <= currentIndex ? Colors.blueAccent : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index <= currentIndex ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: index == currentIndex ? FontWeight.bold : FontWeight.normal,
                    color: index == currentIndex ? Colors.blueAccent : Colors.grey[600],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Personal Information Section
  Widget _buildPersonalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(nameController, 'Full Name', Icons.person),
        _buildTextField(usernameController, 'Username', Icons.alternate_email),
        _buildTextField(emailController, 'Email', Icons.email),
        _buildTextField(
          passwordController,
          'Password',
          Icons.lock,
          obscureText: true,
        ),
        _buildTextField(
          phoneController,
          'Phone Number',
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),

        // Profile Image Upload
        _buildFilePicker(
          label: 'Profile Image',
          onTap: _pickProfileImage,
          isSelected: _selectedProfileImagePath != null,
          icon: Icons.person_pin,
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            '* If no profile image is selected, a default image will be used',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        // Gender Selection
        const SizedBox(height: 8),
        const Text(
          'Gender:',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildGenderRadio(UserGender.male, 'Male'),
            _buildGenderRadio(UserGender.female, 'Female'),
            _buildGenderRadio(UserGender.other, 'Other'),
          ],
        ),

        // Date of Birth Picker
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: _inputDecoration('Date of Birth', Icons.calendar_today),
              child: Text(
                _selectedDOB == null
                    ? 'Select Date of Birth'
                    : '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Address Section
  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          bioController,
          'Bio (Tell us about yourself)',
          Icons.info_outline,
          maxLines: 3,
        ),
        _buildTextField(localityController, 'Locality', Icons.location_on),
        _buildTextField(cityController, 'City', Icons.location_city),
        _buildTextField(stateController, 'State', Icons.public),
      ],
    );
  }

  // Caretaker Section
  Widget _buildCaretakerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caretaker Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 16),

        // Caregiver Type Radio Button Selection
        const Text(
          'I am registering as a:',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildRadio(CaregiverType.relative, 'Relative'),
            _buildRadio(CaregiverType.nurse, 'Nurse'),
          ],
        ),
        const SizedBox(height: 16),

        // Conditional Input Field
        if (_caregiverType == CaregiverType.relative) ...[
          _buildTextField(
            relationController,
            'Relation to Patient',
            Icons.family_restroom,
          ),
        ] else ...[
          _buildTextField(
            experienceYearsController,
            'Experience Years (in years)',
            Icons.work_history,
            keyboardType: TextInputType.number,
          ),
          _buildTextField(
            expBioController,
            'Experience Bio',
            Icons.description,
            maxLines: 3,
          ),
          _buildTextField(
            gradNursingController,
            'Nursing Qualification/Graduation',
            Icons.school,
          ),
          _buildFilePicker(
            label: 'Graduation Certificate (Image)',
            onTap: _pickCertificate,
            isSelected: _selectedCertificatePath != null,
            icon: Icons.note_alt,
            isRequired: true,
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '* Graduation certificate is required for nurse registration',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Review Section
  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 16),
        
        // Personal Info Review
        _buildReviewItem('Full Name', nameController.text),
        _buildReviewItem('Username', usernameController.text),
        _buildReviewItem('Email', emailController.text),
        _buildReviewItem('Phone', phoneController.text),
        _buildReviewItem('Gender', _selectedGender.name),
        _buildReviewItem('Date of Birth', 
          _selectedDOB != null 
            ? '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}'
            : 'Not selected'
        ),
        _buildReviewItem('Profile Image', 
          _selectedProfileImagePath != null ? 'Uploaded' : 'Default image will be used'
        ),
        
        // Address Info Review
        _buildReviewItem('Bio', bioController.text),
        _buildReviewItem('Locality', localityController.text),
        _buildReviewItem('City', cityController.text),
        _buildReviewItem('State', stateController.text),
        
        // Caretaker Specific Review
        if (widget.role == 'caretaker') ...[
          _buildReviewItem('Caregiver Type', _caregiverType.name),
          if (_caregiverType == CaregiverType.relative)
            _buildReviewItem('Relation', relationController.text),
          if (_caregiverType == CaregiverType.nurse) ...[
            _buildReviewItem('Experience Years', experienceYearsController.text),
            _buildReviewItem('Experience Bio', expBioController.text),
            _buildReviewItem('Nursing Qualification', gradNursingController.text),
            _buildReviewItem('Graduation Certificate', 
              _selectedCertificatePath != null ? 'Uploaded' : 'Not uploaded'
            ),
          ]
        ],
        
        const SizedBox(height: 16),
        Text(
          'Please review your information before submitting.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.grey : Colors.black54,
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
        title: Text('Register as ${widget.role.toUpperCase()}'),
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
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildProgressIndicator(),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
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

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  // Back Button
                  if (_currentSection != FormSection.personal)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousSection,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  if (_currentSection != FormSection.personal)
                    const SizedBox(width: 16),

                  // Next/Submit Button
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.blueAccent,
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
                            ),
                            child: Text(
                              _currentSection == FormSection.review
                                  ? 'Submit'
                                  : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: _inputDecoration(label, icon),
        obscureText: obscureText,
        keyboardType: keyboardType,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: Colors.blueAccent),
    );
  }
}
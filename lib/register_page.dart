import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Enum to manage the state of the caretaker type radio buttons
enum CaregiverType { relative, nurse }

// Enum for Gender selection
enum UserGender { male, female, other }

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

  // Caretaker specific: Experience years (reused for nurse)
  final TextEditingController experienceYearsController =
      TextEditingController();
  // Controller for relation (used for relative)
  final TextEditingController relationController = TextEditingController();
  // Nurse specific
  final TextEditingController expBioController = TextEditingController();
  final TextEditingController gradNursingController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _loading = false;

  // State variables
  CaregiverType _caregiverType = CaregiverType.relative;
  UserGender _selectedGender = UserGender.male;
  DateTime? _selectedDOB;

  // File upload state (String stores the local path or XFile.path)
  String? _selectedProfileImagePath;
  String? _selectedCertificatePath;

  // Image Picker instance
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000), // Default to year 2000
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

  // Use ImagePicker for profile image
  void _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedProfileImagePath = image.path;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image selected.')),
        );
      });
    }
  }

  // Use ImagePicker for certificate image (optional for nurse)
  void _pickCertificate() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedCertificatePath = image.path;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate image selected.')),
        );
      });
    }
  }

  // Cloudinary upload logic - Uses CLOUDINARY_CLOUD_NAME from .env
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
        ..fields['upload_preset'] =
            preset // Use the specific preset
        ..fields['cloud_name'] = cloudName;

      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final secureUrl = responseData['secure_url'];

        // Ensure a String URL is returned
        if (secureUrl is String && secureUrl.isNotEmpty) return secureUrl;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload succeeded but no valid URL found.'),
            ),
          );
        }
        return null;
      } else {
        if (mounted) {
          // Attempt to get a detailed error message from Cloudinary
          String errorMessage = response.body;
          try {
            final errorResponse = json.decode(response.body);
            errorMessage = errorResponse['error']?['message'] ?? response.body;
          } catch (_) {
            // response body wasn't JSON, use it as is
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cloudinary upload failed: $errorMessage')),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error during file upload: $e')));
      }
      return null;
    }
  }

  Future<void> _register() async {
    // Basic form validation for non-empty fields
    if (nameController.text.trim().isEmpty ||
        usernameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        bioController.text.trim().isEmpty ||
        localityController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        stateController.text.trim().isEmpty ||
        _selectedDOB == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fill in all mandatory text fields and select Date of Birth.',
            ),
          ),
        );
      }
      return;
    }

    // Caretaker specific validation for conditional fields
    if (widget.role == 'caretaker') {
      if (_caregiverType == CaregiverType.relative &&
          relationController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your relation to the patient.'),
            ),
          );
        }
        return;
      }
      if (_caregiverType == CaregiverType.nurse) {
        // Only validate required nurse fields (images are optional)
        if (experienceYearsController.text.trim().isEmpty ||
            expBioController.text.trim().isEmpty ||
            gradNursingController.text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please complete all nurse-specific experience fields (Years, Bio, Qualification).',
                ),
              ),
            );
          }
          return;
        }
      }
    }

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

      // UPLOAD PROFILE IMAGE using the requested preset: 'care_taker_image'
      profileUrl = await _uploadFile(
        _selectedProfileImagePath,
        'care_taker_image',
      );

      // UPLOAD CERTIFICATE IMAGE (Nurse only) using the requested preset: 'graduation'
      if (widget.role == 'caretaker' && _caregiverType == CaregiverType.nurse) {
        certificateUrl = await _uploadFile(
          _selectedCertificatePath,
          'graduation',
        );
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
          'profileImageUrl': profileUrl ?? '', // Save URL (or empty string)
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
            // CaregiverType.nurse
            data['experienceYears'] =
                int.tryParse(experienceYearsController.text.trim()) ?? 0;
            data['relation'] = '';
            data['experienceBio'] = expBioController.text.trim();
            data['graduationOnNursing'] = gradNursingController.text.trim();
            data['graduationCertificateUrl'] =
                certificateUrl ?? ''; // Save URL (or empty string)
          }

          // Existing caretaker fields
          data.addAll({'isApprove': false, 'isRemove': false, 'roadmap': []});
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
        // Handle specific Firebase/Auth exceptions if needed
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

  // MODIFIED: Tighter padding and Flexible text to fix the 7-pixel overflow
  Widget _buildFilePicker({
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration:
              _inputDecoration(
                label,
                isSelected ? Icons.check_circle : icon,
              ).copyWith(
                // Tighter padding to prevent overflow
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                fillColor: isSelected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.white,
                prefixIcon: null, // Removed prefix icon since it's in the Row
              ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Use Flexible to prevent text overflow
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

  // Helper function to build the radio buttons (Caretaker Type)
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

  // Helper function to build the radio buttons (Gender)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          true, // Ensure content resizes when keyboard appears
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registration Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 24),

              // Basic Fields
              _buildTextField(nameController, 'Full Name', Icons.person),
              _buildTextField(
                usernameController,
                'Username',
                Icons.alternate_email,
              ),
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

              // Profile Image Upload (Optional) - Uses 'care_taker_image' preset
              _buildFilePicker(
                label: 'Profile Image (Optional)',
                onTap: _pickProfileImage,
                isSelected: _selectedProfileImagePath != null,
                icon: Icons.person_pin,
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
              const SizedBox(height: 8),

              // Date of Birth Picker
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      'Date of Birth',
                      Icons.calendar_today,
                    ),
                    child: Text(
                      _selectedDOB == null
                          ? 'Select Date of Birth'
                          : '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),

              // Bio
              _buildTextField(
                bioController,
                'Bio (Tell us about yourself)',
                Icons.info_outline,
                maxLines: 3,
              ),

              const SizedBox(height: 16),
              const Text(
                'Address Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 8),

              // Locality, City, State
              _buildTextField(
                localityController,
                'Locality',
                Icons.location_on,
              ),
              _buildTextField(cityController, 'City', Icons.location_city),
              _buildTextField(stateController, 'State', Icons.public),

              if (widget.role == 'caretaker') ...[
                const SizedBox(height: 24),
                const Text(
                  'Caretaker Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 8),

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
                  // Show Relation Tag input
                  _buildTextField(
                    relationController,
                    'Relation to Patient',
                    Icons.family_restroom,
                  ),
                ] else ...[
                  // Show Nurse-specific fields
                  _buildTextField(
                    experienceYearsController,
                    'Experience Years (in years)',
                    Icons.work_history,
                    keyboardType: TextInputType.number,
                  ),
                  // Experience Bio
                  _buildTextField(
                    expBioController,
                    'Experience Bio',
                    Icons.description,
                    maxLines: 3,
                  ),
                  // Graduation on Nursing
                  _buildTextField(
                    gradNursingController,
                    'Nursing Qualification/Graduation',
                    Icons.school,
                  ),
                  // Graduation Certificate Upload (Nurse Only - Optional) - Uses 'graduation' preset
                  _buildFilePicker(
                    label: 'Graduation Certificate (Image) (Optional)',
                    onTap: _pickCertificate,
                    isSelected: _selectedCertificatePath != null,
                    icon: Icons.note_alt,
                  ),
                ],
              ],

              const SizedBox(height: 32),
              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        'Register as ${widget.role}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ],
          ),
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

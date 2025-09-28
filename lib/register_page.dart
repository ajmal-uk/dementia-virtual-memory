// lib/register_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

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

  // Caretaker specific (keep minimal)
  final TextEditingController experienceYearsController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _loading = false;

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
        Map<String, dynamic> data = {
          'uid': uid,
          'fullName': nameController.text.trim(),
          'username': username,
          'email': emailController.text.trim(),
          'phoneNo': phone,
          'createdAt': Timestamp.now(),
          'currentConnectionId': null,
          'emergencyContacts': [],
          'members': [],
          'reports_sent': [],
          'playerIds': [],
          'isBanned': false,
        };
        if (widget.role == 'caretaker') {
          data.addAll({
            'experienceYears': int.tryParse(experienceYearsController.text.trim()) ?? 0,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful')),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensure content resizes when keyboard appears
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
            colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registration Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 24),
              _buildTextField(nameController, 'Full Name', Icons.person),
              _buildTextField(usernameController, 'Username', Icons.alternate_email),
              _buildTextField(emailController, 'Email', Icons.email),
              _buildTextField(passwordController, 'Password', Icons.lock, obscureText: true),
              _buildTextField(phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
              if (widget.role == 'caretaker') ...[
                const SizedBox(height: 24),
                const Text(
                  'Caretaker Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
                const SizedBox(height: 8),
                _buildTextField(experienceYearsController, 'Experience Years', Icons.work_history, keyboardType: TextInputType.number),
              ],
              const SizedBox(height: 32),
              _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text('Register as ${widget.role}', style: const TextStyle(fontSize: 18, color: Colors.white)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType? keyboardType}) {
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
        obscureText: obscureText,
        keyboardType: keyboardType,
      ),
    );
  }
}
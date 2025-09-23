import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  final String role; // 'user' or 'caretaker'
  const RegisterPage({Key? key, required this.role}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Common fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // User-specific fields
  DateTime? dob;
  final TextEditingController bioController = TextEditingController();
  final TextEditingController emergencyNameController = TextEditingController();
  final TextEditingController emergencyPhoneController = TextEditingController();

  final TextEditingController experienceController = TextEditingController();

  void _register() {
    // TODO: Implement Firebase registration + Firestore saving here
    if (widget.role == 'user') {
      // Collect all user data
      final userData = {
        'name': nameController.text,
        'email': emailController.text,
        'dob': dob?.toIso8601String(),
        'bio': bioController.text,
        'emergency_contacts': [
          {
            'name': emergencyNameController.text,
            'phone': emergencyPhoneController.text,
          }
        ],
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registering User: $userData')),
      );
    } else {
      // caretaker
      final caretakerData = {
        'name': nameController.text,
        'email': emailController.text,
        'experience': experienceController.text,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registering Caretaker: $caretakerData')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.role == 'user';

    return Scaffold(
      appBar: AppBar(
        title: Text('Register as ${widget.role.toUpperCase()}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            if (isUser) ...[
              // Date of Birth
              Row(
                children: [
                  Text(dob == null
                      ? 'Select Date of Birth'
                      : 'DOB: ${dob!.toLocal().toString().split(' ')[0]}'),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(1960),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => dob = picked);
                    },
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'Short Bio'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: emergencyNameController,
                decoration: const InputDecoration(labelText: 'Emergency Contact Name'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: emergencyPhoneController,
                decoration: const InputDecoration(labelText: 'Emergency Contact Phone'),
              ),
              const SizedBox(height: 16),
            ],

            if (!isUser) ...[
              TextField(
                controller: experienceController,
                decoration:
                    const InputDecoration(labelText: 'Years of Experience'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton(
              onPressed: _register,
              child: Text('Register as ${widget.role}'),
            ),
          ],
        ),
      ),
    );
  }
}

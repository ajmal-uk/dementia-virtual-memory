// lib/login_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin/admin_bottom_nav.dart';
import 'careTaker/care_taker.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'user/user_bottom_nav.dart';

class LoginPage extends StatefulWidget {
  final String role;
  const LoginPage({Key? key, required this.role}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final uid = credential.user?.uid;

      if (uid != null) {
        final doc = await _firestore.collection(widget.role).doc(uid).get();

        if (doc.exists) {
          final data = doc.data()!;

          // --- FIX: Specific Banned Check and Message ---
          if (data['isBanned'] == true) {
            await _auth.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Login failed: Account has been banned by the Administrator.',
                  ),
                ),
              );
            }
            // Stop function execution immediately
            return;
          }
          // --- END FIX ---

          // Add player ID
          final playerId = OneSignal.User.pushSubscription.id;
          if (playerId != null) {
            await _firestore.collection(widget.role).doc(uid).update({
              'playerIds': FieldValue.arrayUnion([playerId]),
            });
          }

          // Save the role for auto-login
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastRole', widget.role);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logged in as ${widget.role}')),
            );
          }

          // Navigation
          if (widget.role == 'user') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserBottomNav()),
            );
          } else if (widget.role == 'caretaker') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CareTaker()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminBottomNav()),
            );
          }
        } else {
          // If Firestore document doesn't exist for the role
          await _auth.signOut(); // Sign out the Firebase user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login failed: Invalid role for this account.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Firebase Auth errors will land here (e.g., wrong password)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage(role: widget.role)),
    );
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == 'admin';
    return Scaffold(
      resizeToAvoidBottomInset:
          true, // Ensure content resizes when keyboard appears
      body: Container(
        decoration: BoxDecoration(
          // Corrected use of withValues
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // Add SingleChildScrollView to handle keyboard overflow
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.role.toUpperCase()} Login',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(
                      Icons.email,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: Colors.blueAccent,
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _loading
                    ? const CircularProgressIndicator(color: Colors.blueAccent)
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Text(
                          'Login as ${widget.role}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                if (!isAdmin)
                  TextButton(
                    onPressed: _goToRegister,
                    child: const Text(
                      "Don't have an account? Sign up here",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

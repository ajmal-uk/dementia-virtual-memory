// lib/login_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin/admin_bottom_nav.dart';
import 'careTaker/caretaker_bottom_nav.dart';
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
  bool _obscurePassword = true;

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
      final email = credential.user?.email;

      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed: Missing user id.')),
          );
        }
        return;
      }

      // Try getting document by UID first
      DocumentSnapshot<Map<String, dynamic>> docByUid = await _firestore
          .collection(widget.role)
          .doc(uid)
          .get();

      Map<String, dynamic>? data;
      DocumentReference<Map<String, dynamic>>? docRef;

      if (docByUid.exists && docByUid.data() != null) {
        data = docByUid.data();
        docRef = _firestore.collection(widget.role).doc(uid);
      } else {
        // Fallback: try finding the document by email (useful for admin docs created manually)
        if (email != null && email.isNotEmpty) {
          final query = await _firestore
              .collection(widget.role)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final qdoc = query.docs.first;
            data = qdoc.data();
            docRef = qdoc.reference;

            // Optional: store uid into that document to help future lookups
            try {
              await qdoc.reference.update({'uid': uid});
            } catch (_) {
              // ignore update errors
            }
          }
        }
      }

      if (data == null || docRef == null) {
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed: Invalid role for this account.')),
          );
        }
        return;
      }

      // Ban check
      if (data['isBanned'] == true) {
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: Your ${widget.role} account has been banned by the Administrator.'),
            ),
          );
        }
        return;
      }

      // Add OneSignal player id to the found document
      try {
        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null && playerId.isNotEmpty) {
          await docRef.update({
            'playerIds': FieldValue.arrayUnion([playerId]),
          });
        }
      } catch (_) {
        // If OneSignal call fails, ignore - don't block login
      }

      // Save role for auto-login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastRole', widget.role);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in as ${widget.role}')),
        );
      }

      // Navigate to the appropriate home screen
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
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
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
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
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
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.email, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
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
                            style: const TextStyle(fontSize: 18, color: Colors.white),
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
      ),
    );
  }
}

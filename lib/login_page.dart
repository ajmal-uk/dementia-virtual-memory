import 'package:flutter/material.dart';
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

  void _login() {
    // TODO: Implement Firebase login here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged in as ${widget.role}')),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
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
    });
  }

  void _goToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterPage(role: widget.role),
      ),
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
      appBar: AppBar(
        title: Text('${widget.role.toUpperCase()} Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login as ${widget.role}'),
            ),
            const SizedBox(height: 16),
            if (!isAdmin)
              TextButton(
                onPressed: _goToRegister,
                child: const Text('Don\'t have an account? Sign up here'),
              ),
          ],
        ),
      ),
    );
  }
}

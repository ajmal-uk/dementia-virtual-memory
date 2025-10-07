// New File: lib/user/profile/support_screen.dart
// This is the new Support/Help page that fetches the email from Firestore and allows contacting via email

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? _supportEmail;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadSupportEmail();
  }

  Future<void> _loadSupportEmail() async {
    try {
      final doc = await _firestore.collection('api').doc('qHsy9xZJJanFlWFDx7ag').get();
      if (doc.exists) {
        setState(() {
          _supportEmail = doc.data()?['email'] as String?;
          _isLoading = false;
        });
      } else {
        throw Exception('Document not found');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _contactSupport() async {
    if (_supportEmail == null) return;
    final uri = Uri(scheme: 'mailto', path: _supportEmail);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support & Help'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? const Center(child: Text('Error loading support information'))
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need help?',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Contact our support team via email:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.email, color: Colors.blueAccent),
                            title: Text(_supportEmail ?? 'No email available'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: _contactSupport,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

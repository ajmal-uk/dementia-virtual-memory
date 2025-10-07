import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../welcome_page.dart';
import '../report_page.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authenticated user found.')),
        );
      }
      return;
    }

    try {
      final docSnapshot =
          await _firestore.collection('caretaker').doc(user.uid).get();

      if (docSnapshot.exists && mounted) {
        setState(() {
          _userData = docSnapshot.data()!;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User profile data not found in Firestore.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile data: $e')),
        );
      }
    }
  }

  // --- Log Out Function ---
  void _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomePage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Helper to display experience/relation based on type
  String _getRoleDetail() {
    final type = _userData?['caregiverType'];
    if (type == 'nurse') {
      final years = _userData?['experienceYears'] ?? 0;
      return 'Experience: $years years (Nurse)';
    } else if (type == 'relative') {
      final relation = _userData?['relation'] ?? 'N/A';
      return 'Relation: $relation (Relative)';
    }
    return 'Role: Caretaker';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          backgroundColor: Colors.indigo,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.indigo),
        ),
      );
    }

    final profileImageUrl = _userData?['profileImageUrl'];

    Widget profileImageWidget;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      profileImageWidget = CircleAvatar(
        radius: 60,
        backgroundImage: NetworkImage(profileImageUrl),
        backgroundColor: Colors.indigo.shade50,
      );
    } else {
      profileImageWidget = CircleAvatar(
        radius: 60,
        backgroundColor: Colors.indigo.shade50,
        child: const Icon(Icons.person, size: 60, color: Colors.indigo),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 50),

            // Profile Card
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    profileImageWidget,
                    const SizedBox(height: 16),
                    Text(
                      _userData?['fullName'] ?? 'User Name Not Set',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getRoleDetail(),
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact: ${_userData?['phoneNo'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Reports Sent Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading:
                        const Icon(Icons.file_present, color: Colors.indigo),
                    title: const Text(
                      'Reports Sent',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportPage(reporterRole: 'caretaker'),
                        ),
                      );
                    },
                  ),

                  // 🔹 Added Report Option
                  ListTile(
                    leading: const Icon(Icons.report, color: Colors.orange),
                    title: const Text('Report',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ReportPage(reporterRole: 'caretaker'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Log Out Setting
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

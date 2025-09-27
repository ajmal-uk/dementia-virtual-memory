// lib/user/profile/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('user').doc(uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (_userData != null) {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProfileScreen(userData: _userData ?? {}),
                  ),
                );
                if (updated == true && mounted) {
                  _loadUserData();
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading profile data',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _userData == null
          ? const Center(
              child: Text(
                'No user data available',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: NetworkImage(
                          _userData!['profileImageUrl'] ?? '',
                        ),
                        onBackgroundImageError: (_, __) =>
                            const Icon(Icons.person, size: 60),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _userData!['fullName'] ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Center(child: Text('@${_userData!['username'] ?? ''}')),
                    const SizedBox(height: 24),
                    _buildInfoRow('Bio:', _userData!['bio']),
                    _buildInfoRow('Email:', _userData!['email']),
                    _buildInfoRow('Phone:', _userData!['phoneNo']),
                    _buildInfoRow(
                      'DOB:',
                      _userData!['dob'] != null
                          ? DateFormat(
                              'yyyy-MM-dd',
                            ).format(_userData!['dob'].toDate())
                          : '',
                    ),
                    _buildInfoRow('Gender:', _userData!['gender']),
                    const SizedBox(height: 16),
                    const Text(
                      'Location:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _buildInfoRow('Locality:', _userData!['locality']),
                    _buildInfoRow('City:', _userData!['city']),
                    _buildInfoRow('State:', _userData!['state']),
                    const SizedBox(height: 16),
                    const Text(
                      'Emergency Contacts:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...(_userData!['emergencyContacts'] as List? ?? []).map(
                      (e) => ListTile(
                        title: Text(e['name'] ?? ''),
                        subtitle: Text(
                          'Relation: ${e['relation'] ?? ''}, Phone: ${e['number'] ?? ''}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        '$label ${value ?? ''}',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

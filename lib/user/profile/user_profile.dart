// lib/user/profile/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
        if (doc.exists && mounted) {
          setState(() {
            _userData = doc.data();
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer for $number')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              if (_userData != null && mounted) {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(userData: _userData ?? {}),
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
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
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
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                      color: Colors.blueAccent,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Personal Information'),
                            _buildCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(Icons.info, 'Bio:', _userData!['bio']),
                                  _buildInfoRow(Icons.email, 'Email:', _userData!['email']),
                                  _buildInfoRow(Icons.phone, 'Phone:', _userData!['phoneNo']),
                                  _buildInfoRow(
                                      Icons.cake,
                                      'DOB:',
                                      _userData!['dob'] != null
                                          ? DateFormat('yyyy-MM-dd').format(_userData!['dob'].toDate())
                                          : ''),
                                  _buildInfoRow(Icons.person, 'Gender:', _userData!['gender']),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Location'),
                            _buildCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(Icons.location_on, 'Locality:', _userData!['locality']),
                                  _buildInfoRow(Icons.location_city, 'City:', _userData!['city']),
                                  _buildInfoRow(Icons.map, 'State:', _userData!['state']),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Emergency Contacts'),
                            const SizedBox(height: 8),
                            _buildEmergencyContacts(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            backgroundImage: (_userData!['profileImageUrl'] != null &&
                    _userData!['profileImageUrl'].toString().isNotEmpty)
                ? NetworkImage(_userData!['profileImageUrl'])
                : null,
            child: (_userData!['profileImageUrl'] == null ||
                    _userData!['profileImageUrl'].toString().isEmpty)
                ? const Icon(Icons.person, size: 60, color: Colors.blueAccent)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _userData!['fullName'] ?? 'No Name',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          Text(
            '@${_userData!['username'] ?? ''}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
    );
  }

  Widget _buildCard(Widget child) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    final contacts = _userData!['emergencyContacts'] as List?;
    if (contacts == null || contacts.isEmpty) {
      return _buildCard(
        const Center(
          child: Text(
            'No emergency contacts added',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    } else {
      return Column(
        children: contacts.map((e) {
          return _buildCard(
            ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: Text(e['name'] ?? ''),
              subtitle: Text(
                'Relation: ${e['relation'] ?? ''}\nPhone: ${e['number'] ?? ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.phone, color: Colors.green),
                onPressed: () {
                  if (e['number'] != null && e['number'].toString().isNotEmpty) {
                    _callNumber(e['number']);
                  }
                },
              ),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ${value ?? 'Not set'}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
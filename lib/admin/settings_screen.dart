import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../welcome_page.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _emailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _supportEmailController = TextEditingController(); 

  String? _currentApiUrl;
  String? _currentSupportEmail;
  final String _apiDocId = 'qHsy9xZJJanFlWFDx7ag';

  @override
  void initState() {
    super.initState();
    _fetchApiUrl();
  }

  Future<void> _fetchApiUrl() async {
    try {
      final doc = await _firestore.collection('api').doc(_apiDocId).get();
      if (doc.exists) {
        setState(() {
          _currentApiUrl = doc.data()?['apiURL'];
          _apiUrlController.text = _currentApiUrl ?? '';
          _currentSupportEmail = doc.data()?['email'];
          _supportEmailController.text = _currentSupportEmail ?? '';
        });
      } else {
        debugPrint('API document not found.');
      }
    } catch (e) {
      debugPrint('Error fetching API URL: $e');
    }
  }

  Future<void> _updateApiUrl() async {
    final newUrl = _apiUrlController.text.trim();
    if (newUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid API URL')),
      );
      return;
    }

    try {
      
      await _firestore.collection('api').doc(_apiDocId).update({
        'apiURL': newUrl,
      });

      setState(() {
        _currentApiUrl = newUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL updated successfully')),
      );
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating API URL: $e')),
      );
    }
  }

  
  Future<void> _updateSupportEmail() async {
    final newEmail = _supportEmailController.text.trim();
    if (newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid support email')),
      );
      return;
    }

    try {
      await _firestore.collection('api').doc(_apiDocId).update({
        'email': newEmail,
      });

      setState(() {
        _currentSupportEmail = newEmail;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support email updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating support email: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
    );
  }

  Future<void> _addAdmin() async {
    final email = _emailController.text.trim();
    final password = _adminPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid != null) {
        await _firestore.collection('admin').doc(uid).set({
          'email': email,
          'createdAt': Timestamp.now(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin added successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding admin: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.blue),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _logout,
            ),
          ),

          const SizedBox(height: 8),

          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              leading: const Icon(Icons.add_moderator, color: Colors.green),
              title: const Text('Add Admin', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextField(
                        controller: _adminPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addAdmin,
                        child: const Text('Add Admin'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              leading: const Icon(Icons.api, color: Colors.blue),
              title: const Text('Change API URL', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_currentApiUrl ?? 'No API URL set'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _apiUrlController,
                        decoration: const InputDecoration(labelText: 'New API URL'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _updateApiUrl,
                        child: const Text('Update API URL'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              leading: const Icon(Icons.email, color: Colors.purple),
              title: const Text('Change Support Email', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_currentSupportEmail ?? 'No support email set'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _supportEmailController,
                        decoration: const InputDecoration(labelText: 'New Support Email'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _updateSupportEmail,
                        child: const Text('Update Support Email'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

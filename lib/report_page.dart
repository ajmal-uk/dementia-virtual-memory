import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportPage extends StatefulWidget {
  final String reporterRole; 
  const ReportPage({super.key, required this.reporterRole});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isConnected = false;
  String? _connectedUsername;
  bool _reportSpecific = true; 
  bool _userFound = false;

  @override
  void initState() {
    super.initState();
    _loadConnectionInfo();
  }

  Future<void> _loadConnectionInfo() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await _firestore.collection(widget.reporterRole).doc(uid).get();
      final data = userDoc.data();
      final isConnected = data?['isConnected'] == true;
      final connectionId = data?['currentConnectionId'] as String?;

      if (isConnected && connectionId != null) {
        final connectionDoc = await _firestore.collection('connections').doc(connectionId).get();
        String? connectedUid;
        if (widget.reporterRole == 'user') {
          connectedUid = connectionDoc.data()?['caretaker_uid'];
        } else {
          connectedUid = connectionDoc.data()?['user_uid'];
        }

        if (connectedUid != null) {
          final targetColl = widget.reporterRole == 'user' ? 'caretaker' : 'user';
          final connectedDoc = await _firestore.collection(targetColl).doc(connectedUid).get();
          final username = connectedDoc.data()?['username'] as String?;

          if (username != null && mounted) {
            setState(() {
              _isConnected = true;
              _connectedUsername = username;
              _usernameController.text = username;
              _userFound = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading connection: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchUser() async {
    if (_usernameController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a username')),
        );
      }
      return;
    }

    final coll = widget.reporterRole == 'user' ? 'caretaker' : 'user';
    final snap = await _firestore
        .collection(coll)
        .where('username', isEqualTo: _usernameController.text.trim())
        .get();

    if (mounted) {
      setState(() => _userFound = snap.docs.isNotEmpty);
    }

    if (!_userFound && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
    }
  }

  Future<void> _submitReport() async {
    if (_titleController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title is required')),
        );
      }
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description is required')),
        );
      }
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String? reportedUid;
    String? reportedRole;

    if (_reportSpecific) {
      if (!_userFound) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please search and verify the user first')),
          );
        }
        return;
      }

      final coll = widget.reporterRole == 'user' ? 'caretaker' : 'user';
      final snap = await _firestore
          .collection(coll)
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (snap.docs.isEmpty) return;

      reportedUid = snap.docs.first.id;
      reportedRole = coll;
    } else {
      reportedRole = 'app';
    }

    await _firestore.collection('reports').add({
      'sender_uid': uid,
      'sender_role': widget.reporterRole,
      'reported_uid': reportedUid,
      'reported_role': reportedRole,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'created_at': Timestamp.now(),
      'seen': false,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetRole = widget.reporterRole == 'user' ? 'Caretaker' : 'User';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Report'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Specific User'),
                    selected: _reportSpecific,
                    onSelected: (sel) {
                      if (mounted) {
                        setState(() => _reportSpecific = sel);
                      }
                    },
                    selectedColor: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('App/General Issue'),
                    selected: !_reportSpecific,
                    onSelected: (sel) {
                      if (mounted) {
                        setState(() => _reportSpecific = !sel);
                      }
                    },
                    selectedColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_reportSpecific) ...[
              Text(
                'Search $targetRole to Report',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isConnected && _connectedUsername != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connected $targetRole: @$_connectedUsername (prefilled)',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: '$targetRole Username',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchUser,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_userFound)
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('User found', style: TextStyle(color: Colors.green)),
                  ],
                ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Report Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Detailed Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}
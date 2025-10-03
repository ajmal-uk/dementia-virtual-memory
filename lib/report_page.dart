import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportPage extends StatefulWidget {
  final String reporterRole; // 'user' or 'caretaker'
  const ReportPage({super.key, required this.reporterRole});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _userFound = false;

  Future<void> _searchUser() async {
    final coll = widget.reporterRole == 'user' ? 'caretaker' : 'user';
    final snap = await FirebaseFirestore.instance
        .collection(coll)
        .where('username', isEqualTo: _usernameController.text.trim())
        .get();
    setState(() => _userFound = snap.docs.isNotEmpty);
  }

  Future<void> _submitReport() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final coll = widget.reporterRole == 'user' ? 'caretaker' : 'user';
    final snap = await FirebaseFirestore.instance
        .collection(coll)
        .where('username', isEqualTo: _usernameController.text.trim())
        .get();

    if (snap.docs.isEmpty) return;

    final reportedUid = snap.docs.first.id;

    await FirebaseFirestore.instance.collection('reports').add({
      'sender_uid': uid,
      'sender_role': widget.reporterRole,
      'reported_uid': reportedUid,
      'reported_role': coll,
      'title': _titleController.text,
      'description': _descriptionController.text,
      'created_at': Timestamp.now(),
      'seen': false,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetRole = widget.reporterRole == 'user' ? 'Caretaker' : 'User';
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Search $targetRole Username'),
            ),
            ElevatedButton(onPressed: _searchUser, child: const Text('Search')),
            if (_userFound) ...[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              ElevatedButton(onPressed: _submitReport, child: const Text('Submit')),
            ],
          ],
        ),
      ),
    );
  }
}
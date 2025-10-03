import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/notification_helper.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  bool _isIndividual = true;
  bool _isUser = true;
  bool _isPatient = true;
  bool _isCaretaker = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and message required')));
      }
      return;
    }

    List<String> playerIds = [];
    if (_isIndividual) {
      final coll = _isUser ? 'user' : 'caretaker';
      final snap = await FirebaseFirestore.instance.collection(coll).where('username', isEqualTo: _usernameController.text.trim()).get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
        }
        return;
      }
      playerIds = List<String>.from(snap.docs.first.data()['playerIds'] ?? []);
    } else {
      if (_isPatient) {
        final snap = await FirebaseFirestore.instance.collection('user').get();
        for (var doc in snap.docs) {
          playerIds.addAll(List<String>.from(doc.data()['playerIds'] ?? []));
        }
      }
      if (_isCaretaker) {
        final snap = await FirebaseFirestore.instance.collection('caretaker').get();
        for (var doc in snap.docs) {
          playerIds.addAll(List<String>.from(doc.data()['playerIds'] ?? []));
        }
      }
    }

    await sendNotification(playerIds, '${_titleController.text}: ${_messageController.text}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ChoiceChip(label: const Text('Individual'), selected: _isIndividual, onSelected: (sel) => setState(() => _isIndividual = sel)),
                ChoiceChip(label: const Text('All'), selected: !_isIndividual, onSelected: (sel) => setState(() => _isIndividual = !sel)),
              ],
            ),
            if (_isIndividual) ...[
              Row(
                children: [
                  ChoiceChip(label: const Text('User'), selected: _isUser, onSelected: (sel) => setState(() => _isUser = sel)),
                  ChoiceChip(label: const Text('Caretaker'), selected: !_isUser, onSelected: (sel) => setState(() => _isUser = !sel)),
                ],
              ),
              TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username')),
            ] else ...[
              CheckboxListTile(title: const Text('Patients'), value: _isPatient, onChanged: (val) => setState(() => _isPatient = val!)),
              CheckboxListTile(title: const Text('Caretakers'), value: _isCaretaker, onChanged: (val) => setState(() => _isCaretaker = val!)),
            ],
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _messageController, decoration: const InputDecoration(labelText: 'Message')),
            ElevatedButton(onPressed: _send, child: const Text('Send')),
          ],
        ),
      ),
    );
  }
}
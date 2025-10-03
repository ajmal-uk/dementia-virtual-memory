// New file: lib/admin/user_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/notification_helper.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _caretakerData;
  bool _isLoading = true;
  bool _hasError = false;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final userDoc = await _firestore.collection('user').doc(widget.userId).get();
      if (userDoc.exists) {
        _userData = userDoc.data();
        final connectionId = _userData?['currentConnectionId'];
        if (connectionId != null) {
          final connectionDoc = await _firestore.collection('connections').doc(connectionId).get();
          final caretakerUid = connectionDoc.data()?['caretaker_uid'];
          if (caretakerUid != null) {
            final caretakerDoc = await _firestore.collection('caretaker').doc(caretakerUid).get();
            _caretakerData = caretakerDoc.data();
          }
        }
      } else {
        _hasError = true;
      }
    } catch (e) {
      _hasError = true;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unbindConnection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unbind Connection'),
        content: const Text('Are you sure you want to unbind this user from their caretaker?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unbind'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final connectionId = _userData?['currentConnectionId'];
        if (connectionId != null) {
          await _firestore.collection('connections').doc(connectionId).update({'status': 'unbound'});
          await _firestore.collection('user').doc(widget.userId).update({
            'isConnected': false,
            'currentConnectionId': null,
          });
          final caretakerUid = _caretakerData?['uid'];
          if (caretakerUid != null) {
            await _firestore.collection('caretaker').doc(caretakerUid).update({
              'isConnected': false,
              'currentConnectionId': null,
            });
          }

          // Notify both
          final userPlayerIds = List<String>.from(_userData?['playerIds'] ?? []);
          final caretakerPlayerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
          await sendNotification(userPlayerIds, 'Your connection has been unbound by admin.');
          await sendNotification(caretakerPlayerIds, 'Your connection has been unbound by admin.');

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection unbound')));
          _loadUserData();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _banUser() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter ban reason:'),
            TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ban'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('user').doc(widget.userId).update({'isBanned': true});
        // Unbind if connected
        if (_userData?['isConnected'] == true) {
          _unbindConnection();
        }
        // Notify user
        final userPlayerIds = List<String>.from(_userData?['playerIds'] ?? []);
        await sendNotification(userPlayerIds, 'Your account has been banned. Reason: ${reasonController.text}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned')));
        _loadUserData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _sendNotification() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _messageController, decoration: const InputDecoration(labelText: 'Message')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final playerIds = List<String>.from(_userData?['playerIds'] ?? []);
        await sendNotification(playerIds, '${_titleController.text}: ${_messageController.text}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_hasError) return const Scaffold(body: Center(child: Text('Error loading user data')));

    return Scaffold(
      appBar: AppBar(title: const Text('User Details'), actions: [
        IconButton(icon: const Icon(Icons.notifications), onPressed: _sendNotification),
        IconButton(icon: const Icon(Icons.block), onPressed: _banUser),
        if (_userData?['isConnected'] == true)
          IconButton(icon: const Icon(Icons.link_off), onPressed: _unbindConnection),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User details
            Text('Name: ${_userData?['fullName']}'),
            Text('Username: ${_userData?['username']}'),
            Text('Email: ${_userData?['email']}'),
            Text('Phone: ${_userData?['phoneNo']}'),
            Text('DOB: ${_userData?['dob'] != null ? DateFormat('yyyy-MM-dd').format(_userData?['dob'].toDate()) : ''}'),
            Text('Gender: ${_userData?['gender']}'),
            Text('Bio: ${_userData?['bio']}'),
            Text('Locality: ${_userData?['locality']}'),
            Text('City: ${_userData?['city']}'),
            Text('State: ${_userData?['state']}'),
            if (_caretakerData != null) ...[
              const SizedBox(height: 20),
              const Text('Connected Caretaker:'),
              Text('Name: ${_caretakerData?['fullName']}'),
              Text('Type: ${_caretakerData?['caregiverType']}'),
              // Add more caretaker details as needed
            ],
          ],
        ),
      ),
    );
  }
}
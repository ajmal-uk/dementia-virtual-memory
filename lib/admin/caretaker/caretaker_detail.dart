
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/notification_helper.dart';

class CaretakerDetailScreen extends StatefulWidget {
  final String caretakerId;
  const CaretakerDetailScreen({super.key, required this.caretakerId});

  @override
  State<CaretakerDetailScreen> createState() => _CaretakerDetailScreenState();
}

class _CaretakerDetailScreenState extends State<CaretakerDetailScreen> {
  Map<String, dynamic>? _caretakerData;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasError = false;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCaretakerData();
  }

  Future<void> _loadCaretakerData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final caretakerDoc = await _firestore.collection('caretaker').doc(widget.caretakerId).get();
      if (caretakerDoc.exists) {
        _caretakerData = caretakerDoc.data();
        final connectionId = _caretakerData?['currentConnectionId'];
        if (connectionId != null) {
          final connectionDoc = await _firestore.collection('connections').doc(connectionId).get();
          final userUid = connectionDoc.data()?['user_uid'];
          if (userUid != null) {
            final userDoc = await _firestore.collection('user').doc(userUid).get();
            _userData = userDoc.data();
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
    // Similar to user_detail, but for caretaker
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unbind Connection'),
        content: const Text('Are you sure you want to unbind this caretaker from their user?'),
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
        final connectionId = _caretakerData?['currentConnectionId'];
        if (connectionId != null) {
          await _firestore.collection('connections').doc(connectionId).update({'status': 'unbound'});
          await _firestore.collection('caretaker').doc(widget.caretakerId).update({
            'isConnected': false,
            'currentConnectionId': null,
          });
          final userUid = _userData?['uid'];
          if (userUid != null) {
            await _firestore.collection('user').doc(userUid).update({
              'isConnected': false,
              'currentConnectionId': null,
            });
          }

          // Notify both
          final caretakerPlayerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
          final userPlayerIds = List<String>.from(_userData?['playerIds'] ?? []);
          await sendNotification(caretakerPlayerIds, 'Your connection has been unbound by admin.');
          await sendNotification(userPlayerIds, 'Your connection has been unbound by admin.');

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection unbound')));
          _loadCaretakerData();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _banCaretaker() async {
    // Similar to user ban
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ban Caretaker'),
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
        await _firestore.collection('caretaker').doc(widget.caretakerId).update({'isBanned': true});
        // Unbind if connected
        if (_caretakerData?['isConnected'] == true) {
          _unbindConnection();
        }
        // Notify caretaker
        final caretakerPlayerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
        await sendNotification(caretakerPlayerIds, 'Your account has been banned. Reason: ${reasonController.text}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caretaker banned')));
        _loadCaretakerData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _approveCaretaker() async {
    await _firestore.collection('caretaker').doc(widget.caretakerId).update({'isApprove': true});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caretaker approved')));
    _loadCaretakerData();
  }

  Future<void> _sendNotification() async {
    // Similar to user
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
        final playerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
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
    if (_hasError) return const Scaffold(body: Center(child: Text('Error loading caretaker data')));

    return Scaffold(
      appBar: AppBar(title: const Text('Caretaker Details'), actions: [
        IconButton(icon: const Icon(Icons.notifications), onPressed: _sendNotification),
        IconButton(icon: const Icon(Icons.block), onPressed: _banCaretaker),
        if (_caretakerData?['isConnected'] == true)
          IconButton(icon: const Icon(Icons.link_off), onPressed: _unbindConnection),
        if (_caretakerData?['isApprove'] == false)
          IconButton(icon: const Icon(Icons.check), onPressed: _approveCaretaker),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caretaker details
            Text('Name: ${_caretakerData?['fullName']}'),
            Text('Type: ${_caretakerData?['caregiverType']}'),
            // Add more fields...
            if (_userData != null) ...[
              const SizedBox(height: 20),
              const Text('Connected User:'),
              Text('Name: ${_userData?['fullName']}'),
              // Add more user details
            ],
          ],
        ),
      ),
    );
  }
}
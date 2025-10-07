// user_detail.dart
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

class _UserDetailScreenState extends State<UserDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _caretakerData;
  bool _isLoading = true;
  bool _hasError = false;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unbind Connection', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Are you sure you want to unbind this user from their caretaker?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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

          // Notify both via push
          final userPlayerIds = List<String>.from(_userData?['playerIds'] ?? []);
          final caretakerPlayerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
          await sendNotification(userPlayerIds, 'Your connection has been unbound by admin.');
          await sendNotification(caretakerPlayerIds, 'Your connection has been unbound by admin.');

          // Add to Firestore notifications
          await _firestore.collection('user').doc(widget.userId).collection('notifications').add({
            'type': 'admin',
            'message': 'Your connection has been unbound by admin.',
            'createdAt': Timestamp.now(),
            'isRead': false,
          });
          if (caretakerUid != null) {
            await _firestore.collection('caretaker').doc(caretakerUid).collection('notifications').add({
              'type': 'admin',
              'message': 'Your connection has been unbound by admin.',
              'createdAt': Timestamp.now(),
              'isRead': false,
            });
          }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ban User', style: TextStyle(color: Colors.redAccent)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
        // Notify user via push
        final userPlayerIds = List<String>.from(_userData?['playerIds'] ?? []);
        await sendNotification(userPlayerIds, 'Your account has been banned. Reason: ${reasonController.text}');
        // Add to Firestore notifications
        await _firestore.collection('user').doc(widget.userId).collection('notifications').add({
          'type': 'admin',
          'message': 'Your account has been banned. Reason: ${reasonController.text}',
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned')));
        _loadUserData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unbanUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unban User', style: TextStyle(color: Colors.blueAccent)),
        content: const Text('Are you sure you want to unban this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .update({'isBanned': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unbanned successfully')),
        );
        _loadUserData();
      }
    }
  }

  Future<void> _sendNotification() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        // Add to Firestore notifications
        await _firestore.collection('user').doc(widget.userId).collection('notifications').add({
          'type': 'admin',
          'message': '${_titleController.text}: ${_messageController.text}',
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    if (_hasError) return const Scaffold(body: Center(child: Text('Error loading user data')));

    final isBanned = _userData?['isBanned'] == true;
    Color headerColor = isBanned ? Colors.red.withOpacity(0.8) : Colors.blueAccent.withOpacity(0.8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: _sendNotification),
          if (isBanned)
            IconButton(icon: const Icon(Icons.restore, color: Colors.green), onPressed: _unbanUser),
          if (!isBanned)
            IconButton(icon: const Icon(Icons.block, color: Colors.red), onPressed: _banUser),
          if (_userData?['isConnected'] == true)
            IconButton(icon: const Icon(Icons.link_off, color: Colors.orange), onPressed: _unbindConnection),
        ],
      ),
      body: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(_userData?['profileImageUrl'] ?? ''),
                  backgroundColor: Colors.grey.shade300,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userData?['fullName'] ?? 'Unnamed',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '@${_userData?['username'] ?? ''}',
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            tabs: const [
              Tab(text: 'Personal'),
              Tab(text: 'Address'),
              Tab(text: 'Connection'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Personal Info Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(Icons.person, 'Name', _userData?['fullName'] ?? 'Unnamed'),
                          _buildDetailRow(Icons.alternate_email, 'Username', _userData?['username'] ?? 'N/A'),
                          _buildDetailRow(Icons.email, 'Email', _userData?['email'] ?? 'N/A'),
                          _buildDetailRow(Icons.phone, 'Phone', _userData?['phoneNo'] ?? 'N/A'),
                          _buildDetailRow(Icons.cake, 'DOB', _formatDate(_userData?['dob'])),
                          _buildDetailRow(Icons.transgender, 'Gender', _userData?['gender'] ?? 'N/A'),
                          _buildDetailRow(Icons.description, 'Bio', _userData?['bio'] ?? 'N/A'),
                          _buildDetailRow(Icons.link, 'Connected', _userData?['isConnected'] == true ? 'Yes' : 'No'),
                          _buildDetailRow(Icons.block, 'Banned', _userData?['isBanned'] == true ? 'Yes' : 'No'),
                          _buildDetailRow(Icons.device_unknown, 'Player IDs', (_userData?['playerIds'] as List?)?.join(', ') ?? 'N/A'),
                          _buildDetailRow(Icons.calendar_today, 'Created At', _formatDate(_userData?['createdAt'])),
                        ],
                      ),
                    ),
                  ),
                ),
                // Address Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(Icons.location_on, 'Locality', _userData?['locality'] ?? 'N/A'),
                          _buildDetailRow(Icons.location_city, 'City', _userData?['city'] ?? 'N/A'),
                          _buildDetailRow(Icons.public, 'State', _userData?['state'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                ),
                // Connection Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_caretakerData != null) ...[
                            _buildDetailRow(Icons.person, 'Connected Caretaker Name', _caretakerData?['fullName'] ?? 'Unnamed'),
                            _buildDetailRow(Icons.work, 'Caretaker Type', _caretakerData?['caregiverType'] ?? 'N/A'),
                            _buildDetailRow(Icons.email, 'Caretaker Email', _caretakerData?['email'] ?? 'N/A'),
                            _buildDetailRow(Icons.phone, 'Caretaker Phone', _caretakerData?['phoneNo'] ?? 'N/A'),
                            // Add more caretaker details if needed
                          ] else ...[
                            const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.link_off, size: 64, color: Colors.orange),
                                  SizedBox(height: 16),
                                  Text('No connected caretaker', style: TextStyle(fontSize: 18, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (_userData?['isConnected'] != true)
                            ElevatedButton(
                              onPressed: () {
                                // Add bind logic if needed
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Bind Caretaker'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
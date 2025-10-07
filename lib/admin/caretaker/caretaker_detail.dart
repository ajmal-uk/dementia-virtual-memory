import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/notification_helper.dart';

class CaretakerDetailScreen extends StatefulWidget {
  final String caretakerId;
  const CaretakerDetailScreen({super.key, required this.caretakerId});
  @override
  State<CaretakerDetailScreen> createState() => _CaretakerDetailScreenState();
}

class _CaretakerDetailScreenState extends State<CaretakerDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _caretakerData;
  Map<String, dynamic>? _userData;
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unbind Connection', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Are you sure you want to unbind this caretaker from their user?'),
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

          final caretakerPlayerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
          final userPlayerIds = List<String>.from(_userData?['playerIds'] ?? []);
          await sendNotification(caretakerPlayerIds, 'Your connection has been unbound by admin.');
          await sendNotification(userPlayerIds, 'Your connection has been unbound by admin.');
          await _firestore.collection('caretaker').doc(widget.caretakerId).collection('notifications').add({
            'type': 'admin',
            'message': 'Your connection has been unbound by admin.',
            'createdAt': Timestamp.now(),
            'isRead': false,
          });
          if (userUid != null) {
            await _firestore.collection('user').doc(userUid).collection('notifications').add({
              'type': 'admin',
              'message': 'Your connection has been unbound by admin.',
              'createdAt': Timestamp.now(),
              'isRead': false,
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection unbound')));
          }
          _loadCaretakerData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _banCaretaker() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ban Caretaker', style: TextStyle(color: Colors.redAccent)),
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
        await _firestore.collection('caretaker').doc(widget.caretakerId).update({'isBanned': true});
        if (_caretakerData?['isConnected'] == true) {
          _unbindConnection();
        }
        final caretakerPlayerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
        await sendNotification(caretakerPlayerIds, 'Your account has been banned. Reason: ${reasonController.text}');
        // Add to Firestore notifications
        await _firestore.collection('caretaker').doc(widget.caretakerId).collection('notifications').add({
          'type': 'admin',
          'message': 'Your account has been banned. Reason: ${reasonController.text}',
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caretaker banned')));
        }
        _loadCaretakerData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _unbanCaretaker() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unban Caretaker', style: TextStyle(color: Colors.blueAccent)),
        content: const Text('Are you sure you want to unban this caretaker?'),
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
          .collection('caretaker')
          .doc(widget.caretakerId)
          .update({'isBanned': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caretaker unbanned successfully')),
        );
        _loadCaretakerData();
      }
    }
  }

  Future<void> _approveCaretaker() async {
    await _firestore.collection('caretaker').doc(widget.caretakerId).update({'isApprove': true});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caretaker approved')));
    }
    _loadCaretakerData();
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
        final playerIds = List<String>.from(_caretakerData?['playerIds'] ?? []);
        await sendNotification(playerIds, '${_titleController.text}: ${_messageController.text}');
        // Add to Firestore notifications
        await _firestore.collection('caretaker').doc(widget.caretakerId).collection('notifications').add({
          'type': 'admin',
          'message': '${_titleController.text}: ${_messageController.text}',
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
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
    if (_hasError) return const Scaffold(body: Center(child: Text('Error loading caretaker data')));

    final isBanned = _caretakerData?['isBanned'] == true;
    final isApproved = _caretakerData?['isApprove'] == true;
    Color headerColor = isBanned ? Colors.red.withOpacity(0.8) : !isApproved ? Colors.orange.withOpacity(0.8) : Colors.blueAccent.withOpacity(0.8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caretaker Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: _sendNotification),
          if (isBanned)
            IconButton(icon: const Icon(Icons.restore, color: Colors.green), onPressed: _unbanCaretaker),
          if (!isBanned)
            IconButton(icon: const Icon(Icons.block, color: Colors.red), onPressed: _banCaretaker),
          if (_caretakerData?['isConnected'] == true)
            IconButton(icon: const Icon(Icons.link_off, color: Colors.orange), onPressed: _unbindConnection),
          if (_caretakerData?['isApprove'] == false)
            IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: _approveCaretaker),
        ],
      ),
      body: Column(
        children: [
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
                  backgroundImage: NetworkImage(_caretakerData?['profileImageUrl'] ?? ''),
                  backgroundColor: Colors.grey.shade300,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _caretakerData?['fullName'] ?? 'Unnamed',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '@${_caretakerData?['username'] ?? ''}',
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
              Tab(text: 'Caretaker Info'),
              Tab(text: 'Connection'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
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
                          _buildDetailRow(Icons.email, 'Email', _caretakerData?['email'] ?? 'N/A'),
                          _buildDetailRow(Icons.phone, 'Phone', _caretakerData?['phoneNo'] ?? 'N/A'),
                          _buildDetailRow(Icons.cake, 'DOB', _formatDate(_caretakerData?['dateOfBirth'])),
                          _buildDetailRow(Icons.transgender, 'Gender', _caretakerData?['gender'] ?? 'N/A'),
                          _buildDetailRow(Icons.description, 'Bio', _caretakerData?['bio'] ?? 'N/A'),
                          _buildDetailRow(Icons.location_on, 'Locality', _caretakerData?['locality'] ?? 'N/A'),
                          _buildDetailRow(Icons.location_city, 'City', _caretakerData?['city'] ?? 'N/A'),
                          _buildDetailRow(Icons.public, 'State', _caretakerData?['state'] ?? 'N/A'),
                          _buildDetailRow(Icons.calendar_today, 'Created At', _formatDate(_caretakerData?['createdAt'])),
                        ],
                      ),
                    ),
                  ),
                ),
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
                          _buildDetailRow(Icons.work, 'Type', _caretakerData?['caregiverType'] ?? 'N/A'),
                          if (_caretakerData?['caregiverType'] == 'relative')
                            _buildDetailRow(Icons.family_restroom, 'Relation', _caretakerData?['relation'] ?? 'N/A'),
                          if (_caretakerData?['caregiverType'] == 'nurse') ...[
                            _buildDetailRow(Icons.timeline, 'Experience Years', '${_caretakerData?['experienceYears'] ?? 0} years'),
                            _buildDetailRow(Icons.description, 'Experience Bio', _caretakerData?['experienceBio'] ?? 'N/A'),
                            _buildDetailRow(Icons.school, 'Qualification', _caretakerData?['graduationOnNursing'] ?? 'N/A'),
                            _buildDetailRow(Icons.assignment, 'Certificate URL', _caretakerData?['graduationCertificateUrl'] ?? 'N/A'),
                          ],
                          _buildDetailRow(Icons.check_circle, 'Approved', _caretakerData?['isApprove'] == true ? 'Yes' : 'No'),
                          _buildDetailRow(Icons.block, 'Banned', _caretakerData?['isBanned'] == true ? 'Yes' : 'No'),
                          _buildDetailRow(Icons.link, 'Connected', _caretakerData?['isConnected'] == true ? 'Yes' : 'No'),
                          _buildDetailRow(Icons.device_unknown, 'Player IDs', (_caretakerData?['playerIds'] as List?)?.join(', ') ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                ),
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
                          if (_userData != null) ...[
                            _buildDetailRow(Icons.person, 'Connected User Name', _userData?['fullName'] ?? 'Unnamed'),
                            _buildDetailRow(Icons.email, 'User Email', _userData?['email'] ?? 'N/A'),
                            _buildDetailRow(Icons.phone, 'User Phone', _userData?['phoneNo'] ?? 'N/A'),
                            _buildDetailRow(Icons.cake, 'User DOB', _formatDate(_userData?['dob'])),
                            _buildDetailRow(Icons.transgender, 'User Gender', _userData?['gender'] ?? 'N/A'),
                            _buildDetailRow(Icons.description, 'User Bio', _userData?['bio'] ?? 'N/A'),
                            _buildDetailRow(Icons.location_on, 'User Locality', _userData?['locality'] ?? 'N/A'),
                            _buildDetailRow(Icons.location_city, 'User City', _userData?['city'] ?? 'N/A'),
                            _buildDetailRow(Icons.public, 'User State', _userData?['state'] ?? 'N/A'),
                          ] else ...[
                            const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.link_off, size: 64, color: Colors.orange),
                                  SizedBox(height: 16),
                                  Text('No connected user', style: TextStyle(fontSize: 18, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
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
// lib/careTaker/notifications.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../utils/notification_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  // --- Utility Functions ---

  Future<String> _fetchUserName(String userUid) async {
    try {
      final doc = await _firestore.collection('user').doc(userUid).get();
      return doc.data()?['fullName'] as String? ?? 'User Not Found';
    } catch (e) {
      return 'Error fetching name';
    }
  }

  Future<void> _markAllAsRead() async {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return;

    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        // Handle error silently
      }
    }
  }

  Future<void> _handleCall(String userUid) async {
    try {
      final userDoc = await _firestore.collection('user').doc(userUid).get();
      final phone = userDoc.data()?['phoneNo'] as String?;

      if (phone != null && phone.isNotEmpty) {
        final url = Uri.parse('tel:$phone');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch phone app.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User phone number not available.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting phone number: $e')),
        );
      }
    }
  }

  Future<void> _handleAccept(String notificationId, String userUid, String connectionId) async {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return;

    try {
      // Update connection status
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'accepted',
        'confirmedBy': caretakerUid,
      });

      // Update Caretaker's profile
      await _firestore.collection('caretaker').doc(caretakerUid).update({
        'isConnected': true,
        'currentConnectionId': connectionId,
      });

      // Update User's profile
      await _firestore.collection('user').doc(userUid).update({
        'isConnected': true,
        'currentConnectionId': connectionId,
      });

      // Delete the notification
      await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      // Notify user
      final userDoc = await _firestore.collection('user').doc(userUid).get();
      final playerIds = List<String>.from(userDoc.data()?['playerIds'] ?? []);
      await sendNotification(playerIds, 'Your connection request has been accepted!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection established!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to establish connection: $e')),
        );
      }
    }
  }

  Future<void> _handleDecline(String notificationId, String userUid, String connectionId) async {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return;

    try {
      // Update connection status to rejected
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'rejected',
      });

      // Delete the notification
      await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      // Notify user
      final userDoc = await _firestore.collection('user').doc(userUid).get();
      final playerIds = List<String>.from(userDoc.data()?['playerIds'] ?? []);
      await sendNotification(playerIds, 'Your connection request was declined');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection request declined.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline connection: $e')),
        );
      }
    }
  }

  Future<void> _handleUnbindAccept(String notificationId, String userUid, String connectionId) async {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return;

    try {
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'unbound',
      });

      // Update both profiles
      await _firestore.collection('caretaker').doc(caretakerUid).update({
        'isConnected': false,
        'currentConnectionId': null,
      });

      await _firestore.collection('user').doc(userUid).update({
        'isConnected': false,
        'currentConnectionId': null,
      });

      // Delete the notification
      await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection unbound successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unbind connection: $e')),
        );
      }
    }
  }

  Future<void> _handleUnbindDecline(String notificationId, String connectionId) async {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return;

    try {
      // Revert unbind request
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'accepted',
        'requestedBy': null,
      });

      // Delete the notification
      await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unbind request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline unbind: $e')),
        );
      }
    }
  }

  // --- Stream and UI Builders ---

  Stream<QuerySnapshot> _getNotificationsStream() {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return Stream.empty();

    return _firestore
        .collection('caretaker')
        .doc(caretakerUid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildNotificationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'general';
    final isRead = data['isRead'] as bool? ?? false;
    final senderUid = data['from'] as String?;
    final notificationMessage = data['message'] as String? ?? 'No message.';
    final connectionId = data['connectionId'] as String?;

    TextStyle textStyle = const TextStyle(fontWeight: FontWeight.normal);
    Color cardColor = Colors.white;
    IconData icon = Icons.info;

    if (type == 'connection_request') {
      textStyle = const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
      );
      cardColor = Colors.blue.shade50;
      icon = Icons.person_add;
    } else if (type == 'unbind_request') {
      textStyle = const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.orange,
      );
      cardColor = Colors.orange.shade50;
      icon = Icons.link_off;
    } else if (!isRead) {
      cardColor = Colors.yellow.shade100;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(icon, color: Colors.blueAccent),
              title: (type == 'connection_request' && senderUid != null)
                  ? FutureBuilder<String>(
                      future: _fetchUserName(senderUid),
                      builder: (context, snapshot) {
                        String userName = snapshot.data ?? 'Loading User...';
                        String displayMessage = 'Connection request from $userName.';
                        return Text(displayMessage, style: textStyle);
                      },
                    )
                  : (type == 'unbind_request' && senderUid != null)
                      ? FutureBuilder<String>(
                          future: _fetchUserName(senderUid),
                          builder: (context, snapshot) {
                            String userName = snapshot.data ?? 'Loading User...';
                            String displayMessage = 'Unbind request from $userName.';
                            return Text(displayMessage, style: textStyle);
                          },
                        )
                      : Text(notificationMessage, style: textStyle),
              subtitle: Text(
                'Received: ${DateFormat('MMM dd, hh:mm a').format((data['createdAt'] as Timestamp).toDate())}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            if ((type == 'connection_request' || type == 'unbind_request') && senderUid != null && connectionId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (type == 'connection_request') ...[
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone, size: 18, color: Colors.green),
                          label: const Text('Call', style: TextStyle(fontSize: 13, color: Colors.green)),
                          onPressed: () => _handleCall(senderUid),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18, color: Colors.white),
                          label: const Text('Accept', style: TextStyle(fontSize: 13, color: Colors.white)),
                          onPressed: () => _handleAccept(doc.id, senderUid, connectionId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 18, color: Colors.white),
                          label: const Text('Decline', style: TextStyle(fontSize: 13, color: Colors.white)),
                          onPressed: () => _handleDecline(doc.id, senderUid, connectionId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                          ),
                        ),
                      ),
                    ] else if (type == 'unbind_request') ...[
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone, size: 18, color: Colors.green),
                          label: const Text('Call', style: TextStyle(fontSize: 13, color: Colors.green)),
                          onPressed: () => _handleCall(senderUid),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18, color: Colors.white),
                          label: const Text('Accept', style: TextStyle(fontSize: 13, color: Colors.white)),
                          onPressed: () => _handleUnbindAccept(doc.id, senderUid, connectionId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 18, color: Colors.white),
                          label: const Text('Decline', style: TextStyle(fontSize: 13, color: Colors.white)),
                          onPressed: () => _handleUnbindDecline(doc.id, connectionId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading notifications: ${snapshot.error}'),
            );
          }
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('You have no notifications.'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return _buildNotificationCard(notifications[index]);
            },
          );
        },
      ),
    );
  }
}
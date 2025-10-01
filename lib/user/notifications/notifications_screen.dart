// lib/user/notifications/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();
    return _firestore.collection('user').doc(uid).collection('notifications').orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _markRead(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('user').doc(uid).collection('notifications').doc(id).update({'isRead': true});
    }
  }

  Future<String> _fetchCaretakerName(String caretakerUid) async {
    try {
      final doc = await _firestore.collection('caretaker').doc(caretakerUid).get();
      return doc.data()?['fullName'] as String? ?? 'Caretaker Not Found';
    } catch (e) {
      return 'Error fetching name';
    }
  }

  Future<void> _handleCall(String caretakerUid) async {
    try {
      final caretakerDoc = await _firestore.collection('caretaker').doc(caretakerUid).get();
      final phone = caretakerDoc.data()?['phoneNo'] as String?;

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
            const SnackBar(content: Text('Caretaker phone number not available.')),
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

  Future<void> _handleUnbindAccept(String notificationId, String caretakerUid, String connectionId) async {
    final userUid = _auth.currentUser?.uid;
    if (userUid == null) return;

    try {
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'unbound',
      });

      // Update both profiles
      await _firestore.collection('user').doc(userUid).update({
        'isConnected': false,
        'currentConnectionId': null,
      });

      await _firestore.collection('caretaker').doc(caretakerUid).update({
        'isConnected': false,
        'currentConnectionId': null,
      });

      // Delete the notification
      await _firestore
          .collection('user')
          .doc(userUid)
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
    final userUid = _auth.currentUser?.uid;
    if (userUid == null) return;

    try {
      // Revert unbind request
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'accepted',
        'requestedBy': null,
      });

      // Delete the notification
      await _firestore
          .collection('user')
          .doc(userUid)
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

    if (type == 'unbind_request') {
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
              title: (type == 'unbind_request' && senderUid != null)
                  ? FutureBuilder<String>(
                      future: _fetchCaretakerName(senderUid),
                      builder: (context, snapshot) {
                        String caretakerName = snapshot.data ?? 'Loading Caretaker...';
                        String displayMessage = 'Unbind request from $caretakerName.';
                        return Text(displayMessage, style: textStyle);
                      },
                    )
                  : Text(notificationMessage, style: textStyle),
              subtitle: Text(
                'Received: ${DateFormat('MMM dd, hh:mm a').format((data['createdAt'] as Timestamp).toDate())}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () => _markRead(doc.id),
            ),

            if (type == 'unbind_request' && senderUid != null && connectionId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getNotifications(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
            }
            final notifs = snapshot.data!.docs;
            if (notifs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: notifs.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(notifs[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
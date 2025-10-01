import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

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
    // Mark all notifications as read when the screen loads
    _markAllAsRead();
  }

  // --- Utility Functions ---

  Future<String> _fetchSenderName(String userUid) async {
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

  // UPDATED: Confirmed logic aligns with all user requirements
  Future<void> _handleAccept(String notificationId, String patientUid) async {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return;

    try {
      // 1. Update Caretaker's profile (CARETAKER points to PATIENT)
      await _firestore.collection('caretaker').doc(caretakerUid).update({
        'isConnected': true, // Set our current user's isConnected to true (✅)
        'currentConnectionId':
            patientUid, // Set currentConnectionId to 'from' value (patient UID) (✅)
      });

      // 2. Update Patient's profile (PATIENT points back to CARETAKER)
      await _firestore.collection('user').doc(patientUid).update({
        'isConnected': true,
        'currentConnectionId': caretakerUid,
      });

      // 3. Delete the notification to clean up the list
      await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

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

  // UPDATED: Confirmed logic aligns with all user requirements
  Future<void> _handleDecline(String notificationId) async {
    final caretakerUid = _auth.currentUser?.uid;
    if (caretakerUid == null) return;

    try {
      // Delete the document in the notifications subcollection (✅)
      await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

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
                      future: _fetchSenderName(senderUid),
                      builder: (context, snapshot) {
                        String senderName =
                            snapshot.data ?? 'Loading Sender...';

                        // Use the fetched name in the message
                        String displayMessage =
                            'Connection request from ${senderName}.';

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

            if (type == 'connection_request' && senderUid != null)
              // Action Buttons (Overflow Fix Applied)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.phone,
                          size: 18,
                          color: Colors.green,
                        ),
                        label: const Text(
                          'Call',
                          style: TextStyle(fontSize: 13, color: Colors.green),
                        ),
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
                        icon: const Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Accept',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                        onPressed: () => _handleAccept(doc.id, senderUid),
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
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Decline',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                        onPressed: () => _handleDecline(doc.id),
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

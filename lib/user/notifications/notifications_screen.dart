// lib/user/notifications/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
                final notif = notifs[index].data() as Map<String, dynamic>;
                final id = notifs[index].id;
                final timestamp = notif['createdAt'] as Timestamp?;
                final isRead = notif['isRead'] as bool? ?? false;

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: isRead ? Colors.grey[100] : Colors.white,
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications,
                      color: isRead ? Colors.grey : Colors.blueAccent,
                    ),
                    title: Text(notif['message'] ?? 'No message'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notif['type'] ?? 'General'),
                        if (timestamp != null)
                          Text(
                            DateFormat('MMM dd, yyyy hh:mm a').format(timestamp.toDate()),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: isRead ? null : const Icon(Icons.fiber_new, color: Colors.orange),
                    onTap: () => _markRead(id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
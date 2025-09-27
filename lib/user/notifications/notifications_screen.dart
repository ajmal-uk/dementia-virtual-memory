// lib/user/notifications/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('Error: ${snapshot.error}');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final notifs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final notif = notifs[index].data() as Map<String, dynamic>;
              final id = notifs[index].id;
              return ListTile(
                title: Text(notif['message'] ?? ''),
                subtitle: Text(notif['type'] ?? ''),
                trailing: notif['isRead'] ? null : const Icon(Icons.fiber_new),
                onTap: () => _markRead(id),
              );
            },
          );
        },
      ),
    );
  }
}
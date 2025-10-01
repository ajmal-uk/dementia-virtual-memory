// lib/careTaker/notifications.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../utils/notification_helper.dart';
import 'user_detail_screen.dart';  // Assume this file is created as per the additional code below

final logger = Logger();

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getNotificationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();
    return _firestore
        .collection('caretaker')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _markAsRead(String notifId) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore
          .collection('caretaker')
          .doc(uid)
          .collection('notifications')
          .doc(notifId)
          .update({'isRead': true});
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userUid) async {
    try {
      final doc = await _firestore.collection('user').doc(userUid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      logger.e('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> _acceptConnection(String connectionId, String userUid, String caretakerUid) async {
    try {
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'accepted',
        'confirmedBy': caretakerUid,
      });

      await _firestore.collection('caretaker').doc(caretakerUid).update({
        'isConnected': true,
        'currentConnectionId': connectionId,
      });

      await _firestore.collection('user').doc(userUid).update({
        'isConnected': true,
        'currentConnectionId': connectionId,
      });

      // Notify user
      final userDoc = await _firestore.collection('user').doc(userUid).get();
      final playerIds = List<String>.from(userDoc.data()?['playerIds'] ?? []);
      await sendNotification(playerIds, 'Your connection request has been accepted');

      await _firestore
          .collection('user')
          .doc(userUid)
          .collection('notifications')
          .add({
            'type': 'connection_accepted',
            'message': 'Connection request accepted by caretaker',
            'from': caretakerUid,
            'to': userUid,
            'createdAt': Timestamp.now(),
            'isRead': false,
          });

      // Reject other pending connections and remove their notifications
      final otherConnections = await _firestore
          .collection('connections')
          .where('caretaker_uid', isEqualTo: caretakerUid)
          .where('status', isEqualTo: 'pending')
          .where(FieldPath.documentId, isNotEqualTo: connectionId)
          .get();

      for (var connDoc in otherConnections.docs) {
        final otherUserUid = connDoc.data()['user_uid'];
        await connDoc.reference.update({'status': 'rejected'});

        // Notify the rejected user
        final otherUserDoc = await _firestore.collection('user').doc(otherUserUid).get();
        final otherPlayerIds = List<String>.from(otherUserDoc.data()?['playerIds'] ?? []);
        await sendNotification(otherPlayerIds, 'Your connection request has been rejected');

        await _firestore
            .collection('user')
            .doc(otherUserUid)
            .collection('notifications')
            .add({
              'type': 'connection_rejected',
              'message': 'Connection request rejected by caretaker',
              'from': caretakerUid,
              'to': otherUserUid,
              'createdAt': Timestamp.now(),
              'isRead': false,
            });

        // Remove the notification from caretaker's side
        final notifQuery = await _firestore
            .collection('caretaker')
            .doc(caretakerUid)
            .collection('notifications')
            .where('type', isEqualTo: 'connection_request')
            .where('from', isEqualTo: otherUserUid)
            .get();
        for (var notifDoc in notifQuery.docs) {
          await notifDoc.reference.delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection accepted')));
      }
    } catch (e) {
      logger.e('Error accepting connection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectConnection(String connectionId, String userUid, String caretakerUid) async {
    try {
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'rejected',
      });

      // Notify user
      final userDoc = await _firestore.collection('user').doc(userUid).get();
      final playerIds = List<String>.from(userDoc.data()?['playerIds'] ?? []);
      await sendNotification(playerIds, 'Your connection request has been rejected');

      await _firestore
          .collection('user')
          .doc(userUid)
          .collection('notifications')
          .add({
            'type': 'connection_rejected',
            'message': 'Connection request rejected by caretaker',
            'from': caretakerUid,
            'to': userUid,
            'createdAt': Timestamp.now(),
            'isRead': false,
          });

      // Remove the notification from caretaker's side
      final notifQuery = await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .where('type', isEqualTo: 'connection_request')
          .where('from', isEqualTo: userUid)
          .get();
      for (var notifDoc in notifQuery.docs) {
        await notifDoc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection rejected')));
      }
    } catch (e) {
      logger.e('Error rejecting connection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmUnbind(String connectionId, String userUid, String caretakerUid) async {
    try {
      await _firestore.collection('connections').doc(connectionId).update({
        'status': 'unbound',
      });

      await _firestore.collection('caretaker').doc(caretakerUid).update({
        'isConnected': false,
        'currentConnectionId': null,
      });

      await _firestore.collection('user').doc(userUid).update({
        'isConnected': false,
        'currentConnectionId': null,
      });

      // Notify user
      final userDoc = await _firestore.collection('user').doc(userUid).get();
      final playerIds = List<String>.from(userDoc.data()?['playerIds'] ?? []);
      await sendNotification(playerIds, 'Unbind confirmed');

      await _firestore
          .collection('user')
          .doc(userUid)
          .collection('notifications')
          .add({
            'type': 'unbind_confirmed',
            'message': 'Unbind confirmed by caretaker',
            'from': caretakerUid,
            'to': userUid,
            'createdAt': Timestamp.now(),
            'isRead': false,
          });

      // Remove the unbind notification from caretaker's side
      final notifQuery = await _firestore
          .collection('caretaker')
          .doc(caretakerUid)
          .collection('notifications')
          .where('type', isEqualTo: 'unbind_request')
          .where('from', isEqualTo: userUid)
          .get();
      for (var notifDoc in notifQuery.docs) {
        await notifDoc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unbound successfully')));
      }
    } catch (e) {
      logger.e('Error confirming unbind: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications / Requests'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final notifs = snapshot.data?.docs ?? [];
          if (notifs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }
          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final notif = notifs[index].data() as Map<String, dynamic>;
              final notifId = notifs[index].id;
              final type = notif['type'] as String?;
              final fromUid = notif['from'] as String?;
              final isRead = notif['isRead'] as bool? ?? false;

              return FutureBuilder<Map<String, dynamic>?>(
                future: fromUid != null ? _fetchUserData(fromUid) : Future.value(null),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const ListTile(title: Text('Loading...'));
                  }
                  final userData = userSnap.data;
                  final userName = userData?['fullName'] ?? 'Unknown User';

                  return ListTile(
                    leading: const Icon(Icons.notification_important),
                    title: Text(type == 'connection_request' 
                        ? 'Connection Request from $userName'
                        : type == 'unbind_request'
                            ? 'Unbind Request from $userName'
                            : notif['message'] ?? 'Notification'),
                    trailing: isRead ? null : const Icon(Icons.new_releases),
                    onTap: () async {
                      await _markAsRead(notifId);
                      if (fromUid != null && userData != null) {
                        final uid = _auth.currentUser?.uid;
                        if (uid != null) {
                          final connections = await _firestore
                              .collection('connections')
                              .where('caretaker_uid', isEqualTo: uid)
                              .where('user_uid', isEqualTo: fromUid)
                              .get();
                          final connectionDoc = connections.docs.firstOrNull;
                          if (connectionDoc != null) {
                            final connectionId = connectionDoc.id;
                            if (type == 'connection_request') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDetailScreen(
                                    userUid: fromUid,
                                    userData: userData,
                                    onAccept: () => _acceptConnection(connectionId, fromUid, uid),
                                    onReject: () => _rejectConnection(connectionId, fromUid, uid),
                                  ),
                                ),
                              );
                            } else if (type == 'unbind_request') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDetailScreen(
                                    userUid: fromUid,
                                    userData: userData,
                                    onConfirmUnbind: () => _confirmUnbind(connectionId, fromUid, uid),
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
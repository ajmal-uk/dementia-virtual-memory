// lib/user/caretaker/caretaker_requests_screen.dart
// lib/user/caretaker/caretaker_requests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'caretaker_detail_screen.dart';

final logger = Logger();

class CaretakerRequestsScreen extends StatefulWidget {
  const CaretakerRequestsScreen({super.key});

  @override
  State<CaretakerRequestsScreen> createState() => _CaretakerRequestsScreenState();
}

class _CaretakerRequestsScreenState extends State<CaretakerRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final connectionsQuery = await _firestore
          .collection('connections')
          .where('user_uid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .get();

      final pendingUids = connectionsQuery.docs.map((doc) => doc.data()['caretaker_uid']).toList().toSet().toList();

      if (pendingUids.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final query = await _firestore
          .collection('caretaker')
          .where('uid', whereIn: pendingUids)
          .get();

      setState(() {
        _pendingRequests = query.docs;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Error loading pending requests: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? const Center(child: Text('No pending requests'))
              : ListView.builder(
                  itemCount: _pendingRequests.length,
                  itemBuilder: (context, index) {
                    final caretaker = _pendingRequests[index].data() as Map<String, dynamic>;
                    final caretakerUid = _pendingRequests[index].id;
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CaretakerDetailScreen(
                              caretakerUid: caretakerUid,
                              caretakerData: caretaker,
                              onConnect: () {}, // No connect for pending
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(caretaker['profileImageUrl'] ?? ''),
                        child: const Icon(Icons.person),
                      ),
                      title: Text(caretaker['fullName'] ?? ''),
                      subtitle: Text('@${caretaker['username'] ?? ''} - Pending'),
                    );
                  },
                ),
    );
  }
}
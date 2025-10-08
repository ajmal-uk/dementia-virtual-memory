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
          .get();

      final sortedDocs = connectionsQuery.docs.toList()
        ..sort((a, b) {
          final aTimestamp = a.data()['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          final bTimestamp = b.data()['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          return bTimestamp.compareTo(aTimestamp);
        });

      final pendingUids = sortedDocs.map((doc) => doc.data()['caretaker_uid'] as String?).whereType<String>().toSet().toList();

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e')),
        );
      }
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
              : RefreshIndicator(
                  onRefresh: _loadPendingRequests,
                  child: ListView.builder(
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final caretaker = _pendingRequests[index].data() as Map<String, dynamic>;
                      final caretakerUid = _pendingRequests[index].id;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CaretakerDetailScreen(
                                  caretakerUid: caretakerUid,
                                  caretakerData: caretaker,
                                  onConnect: () {}, 
                                ),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            backgroundImage: (caretaker['profileImageUrl'] != null &&
                                    caretaker['profileImageUrl'].toString().isNotEmpty)
                                ? NetworkImage(caretaker['profileImageUrl'])
                                : null,
                            child: (caretaker['profileImageUrl'] == null ||
                                    caretaker['profileImageUrl'].toString().isEmpty)
                                ? const Icon(Icons.person, color: Colors.blueAccent)
                                : null,
                          ),
                          title: Text(caretaker['fullName'] ?? ''),
                          subtitle: Text('@${caretaker['username'] ?? ''} - Pending'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
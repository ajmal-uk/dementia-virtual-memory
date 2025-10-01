// lib/user/caretaker/connection_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class ConnectionHistoryScreen extends StatefulWidget {
  const ConnectionHistoryScreen({super.key});

  @override
  State<ConnectionHistoryScreen> createState() => _ConnectionHistoryScreenState();
}

class _ConnectionHistoryScreenState extends State<ConnectionHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Query past connections: status == 'unbound' or 'rejected', etc.
      final query = await _firestore
          .collection('connections')
          .where('user_uid', isEqualTo: uid)
          .where('status', whereIn: ['unbound', 'rejected', 'expired']) // Assume these statuses
          .orderBy('timestamp', descending: true)
          .get();

      final historyUids = query.docs.map((doc) => doc.data()['caretaker_uid']).toList().toSet().toList();

      if (historyUids.isNotEmpty) {
        final caretakersQuery = await _firestore
            .collection('caretaker')
            .where('uid', whereIn: historyUids)
            .get();

        setState(() {
          _history = caretakersQuery.docs;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      logger.e('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection History'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No connection history'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final caretaker = _history[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(caretaker['profileImageUrl'] ?? ''),
                        child: const Icon(Icons.person),
                      ),
                      title: Text(caretaker['fullName'] ?? ''),
                      subtitle: Text('Past connection: ${caretaker['caregiverType'] ?? ''}'),
                    );
                  },
                ),
    );
  }
}
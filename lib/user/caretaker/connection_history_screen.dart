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
      // NOTE: Ensure a composite index is created in Firestore for the 'connections' collection
      // on fields: user_uid (Ascending), status (Ascending)
      // If index error occurs, create it via the link in the error log.
      // To avoid index on orderBy, we fetch without orderBy and sort in code.
      // Adjusted statuses: removed 'expired' as it's not used in the app
      final query = await _firestore
          .collection('connections')
          .where('user_uid', isEqualTo: uid)
          .where('status', whereIn: ['unbound', 'rejected'])
          .get();

      // Sort in code: descending by timestamp
      final sortedDocs = query.docs.toList()
        ..sort((a, b) {
          final aTimestamp = a.data()['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          final bTimestamp = b.data()['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          return bTimestamp.compareTo(aTimestamp);
        });

      final historyUids = sortedDocs.map((doc) => doc.data()['caretaker_uid'] as String?).whereType<String>().toSet().toList();

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
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
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final caretaker = _history[index].data() as Map<String, dynamic>;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
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
                          subtitle: Text('Past connection: ${caretaker['caregiverType'] ?? ''}'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
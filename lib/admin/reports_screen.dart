import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedTab = 'Unseen';

  /// Fetch all reports ordered by created_at (descending).
  /// We filter in code to avoid composite index requirement.
  Stream<QuerySnapshot> _getReportsStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Mark a report as seen
  Future<void> _markAsSeen(String id) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(id)
        .update({'seen': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          /// Tab selector (Unseen / Seen)
          Row(
            children: [
              ChoiceChip(
                label: const Text('Unseen'),
                selected: _selectedTab == 'Unseen',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedTab = 'Unseen');
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Seen'),
                selected: _selectedTab == 'Seen',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedTab = 'Seen');
                  }
                },
              ),
            ],
          ),

          /// Reports list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                // Filter in code based on 'seen' status
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final seen = data['seen'] as bool? ?? false;
                  return (_selectedTab == 'Unseen') ? !seen : seen;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No reports'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: ListTile(
                        title: Text(data['title'] ?? 'No title'),
                        subtitle: Text(data['description'] ?? 'No description'),
                        trailing: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () => _markAsSeen(doc.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'caretaker_detail.dart';
import 'banned_caretakers.dart';

class CaretakersScreen extends StatefulWidget {
  const CaretakersScreen({super.key});

  @override
  State<CaretakersScreen> createState() => _CaretakersScreenState();
}

class _CaretakersScreenState extends State<CaretakersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _selectedTab = 'Approved';

  @override
  void initState() {
    super.initState();

    // Listen for search input changes
    _searchController.addListener(
      () => setState(() => _search = _searchController.text.toLowerCase()),
    );
  }

  /// Get caretakers stream ordered by fullName
  Stream<QuerySnapshot> _getCaretakersStream() {
    return FirebaseFirestore.instance
        .collection('caretaker')
        .orderBy('fullName')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caretakers'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.block),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BannedCaretakersScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blueAccent.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            /// Search Field
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                ),
              ),
            ),

            /// Choice Chips (Tabs)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Approved'),
                  selected: _selectedTab == 'Approved',
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedTab = 'Approved');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Unapproved'),
                  selected: _selectedTab == 'Unapproved',
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedTab = 'Unapproved');
                  },
                ),
              ],
            ),

            /// Caretakers List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getCaretakersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Filter based on approval status
                  final approveFiltered = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['isApprove'] == (_selectedTab == 'Approved');
                  }).toList();

                  // Filter based on search text
                  final filteredDocs = approveFiltered.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final username =
                        (data['username'] as String?)?.toLowerCase() ?? '';
                    return username.contains(_search);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('No caretakers found'));
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (data['profileImageUrl'] != null &&
                                    data['profileImageUrl'].isNotEmpty)
                                ? NetworkImage(data['profileImageUrl'])
                                : null,
                            child: (data['profileImageUrl'] == null ||
                                    data['profileImageUrl'].isEmpty)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(data['fullName'] ?? 'Unnamed'),
                          subtitle: Text('@${data['username'] ?? ''}'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CaretakerDetailScreen(caretakerId: doc.id),
                            ),
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
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_detail.dart';

class BannedUsersScreen extends StatefulWidget {
  const BannedUsersScreen({super.key});

  @override
  State<BannedUsersScreen> createState() => _BannedUsersScreenState();
}

class _BannedUsersScreenState extends State<BannedUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      () => setState(() => _search = _searchController.text.toLowerCase()),
    );
  }

  Stream<QuerySnapshot> _getBannedUsersStream() {
    return FirebaseFirestore.instance
        .collection('user')
        .orderBy('fullName')
        .snapshots();
  }

  Future<void> _unbanUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Unban User'),
        content: const Text('Are you sure you want to unban this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(id)
          .update({'isBanned': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unbanned')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banned Users')),
      body: Column(
        children: [
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getBannedUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final bannedDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isBanned'] == true;
                }).toList();

                final filteredDocs = bannedDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final username =
                      (data['username'] as String?)?.toLowerCase() ?? '';
                  return username.contains(_search);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No banned users'));
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
                        trailing: IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          onPressed: () => _unbanUser(doc.id),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserDetailScreen(userId: doc.id),
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
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

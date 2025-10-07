import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_detail.dart';
import '../../utils/notification_helper.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _selectedTab = 'All';
  Timer? _debounce;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _search = _searchController.text.toLowerCase());
    });
  }

  Stream<QuerySnapshot> _getUsersStream() {
    return _firestore
        .collection('user')
        .orderBy('fullName')
        .snapshots();
  }

  Future<void> _banUser(String id) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ban User', style: TextStyle(color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter ban reason:'),
            TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ban'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final doc = await _firestore.collection('user').doc(id).get();
        final data = doc.data();
        if (data == null) return;

        await _firestore.collection('user').doc(id).update({'isBanned': true});
        if (data['isConnected'] == true) {
          final connectionId = data['currentConnectionId'];
          if (connectionId != null) {
            final connDoc = await _firestore.collection('connections').doc(connectionId).get();
            final connData = connDoc.data();
            if (connData != null) {
              final caretakerUid = connData['caretaker_uid'];
              if (caretakerUid != null) {
                final caretakerDoc = await _firestore.collection('caretaker').doc(caretakerUid).get();
                final caretakerData = caretakerDoc.data();

                await connDoc.reference.update({'status': 'unbound'});
                await doc.reference.update({'isConnected': false, 'currentConnectionId': null});
                await caretakerDoc.reference.update({'isConnected': false, 'currentConnectionId': null});

                final userPlayerIds = List<String>.from(data['playerIds'] ?? []);
                final caretakerPlayerIds = List<String>.from(caretakerData?['playerIds'] ?? []);

                await sendNotification(userPlayerIds, 'Your connection has been unbound by admin.');
                await sendNotification(caretakerPlayerIds, 'Your connection has been unbound by admin.');

                await doc.reference.collection('notifications').add({
                  'type': 'admin',
                  'message': 'Your connection has been unbound by admin.',
                  'createdAt': Timestamp.now(),
                  'isRead': false,
                });
                await caretakerDoc.reference.collection('notifications').add({
                  'type': 'admin',
                  'message': 'Your connection has been unbound by admin.',
                  'createdAt': Timestamp.now(),
                  'isRead': false,
                });
              }
            }
          }
        }
        final userPlayerIds = List<String>.from(data['playerIds'] ?? []);
        await sendNotification(userPlayerIds, 'Your account has been banned. Reason: ${reasonController.text}');
        await doc.reference.collection('notifications').add({
          'type': 'admin',
          'message': 'Your account has been banned. Reason: ${reasonController.text}',
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _unbanUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unban User', style: TextStyle(color: Colors.blueAccent)),
        content: const Text('Are you sure you want to unban this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore
          .collection('user')
          .doc(id)
          .update({'isBanned': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unbanned successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
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
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedTab == 'All',
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedTab = 'All');
                      },
                      selectedColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Active'),
                      selected: _selectedTab == 'Active',
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedTab = 'Active');
                      },
                      selectedColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Banned'),
                      selected: _selectedTab == 'Banned',
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedTab = 'Banned');
                      },
                      selectedColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(seconds: 1));
                  setState(() {});
                },
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getUsersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final username = (data['username'] as String?)?.toLowerCase() ?? '';
                      final isBanned = data['isBanned'] as bool? ?? false;

                      bool tabMatch = true;
                      if (_selectedTab == 'Active') {
                        tabMatch = !isBanned;
                      } else if (_selectedTab == 'Banned') {
                        tabMatch = isBanned;
                      }
                      return tabMatch && username.contains(_search);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('No users found', style: const TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final profileImageUrl = data['profileImageUrl'] as String?;

                        final isBanned = data['isBanned'] as bool? ?? false;
                        Color? cardColor = isBanned ? Colors.red[50] : Colors.green[50];

                        return Card(
                          color: cardColor,
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                              child: (profileImageUrl == null || profileImageUrl.isEmpty)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(data['fullName'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('@${data['username'] ?? ''}'),
                            trailing: IconButton(
                              icon: Icon(isBanned ? Icons.restore : Icons.block, color: isBanned ? Colors.green : Colors.red),
                              onPressed: () => isBanned ? _unbanUser(doc.id) : _banUser(doc.id),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserDetailScreen(userId: doc.id),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
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
    _debounce?.cancel();
    super.dispose();
  }
}
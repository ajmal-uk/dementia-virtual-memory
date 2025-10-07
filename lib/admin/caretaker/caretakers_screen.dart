import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'caretaker_detail.dart';
import '../../utils/notification_helper.dart';

class CaretakersScreen extends StatefulWidget {
  const CaretakersScreen({super.key});

  @override
  State<CaretakersScreen> createState() => _CaretakersScreenState();
}

class _CaretakersScreenState extends State<CaretakersScreen> {
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

  Stream<QuerySnapshot> _getCaretakersStream() {
    return _firestore
        .collection('caretaker')
        .orderBy('fullName')
        .snapshots();
  }

  Future<void> _banCaretaker(String id) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ban Caretaker', style: TextStyle(color: Colors.redAccent)),
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
        final doc = await _firestore.collection('caretaker').doc(id).get();
        final data = doc.data();
        if (data == null) return;

        await _firestore.collection('caretaker').doc(id).update({'isBanned': true});
        if (data['isConnected'] == true) {
          final connectionId = data['currentConnectionId'];
          if (connectionId != null) {
            final connDoc = await _firestore.collection('connections').doc(connectionId).get();
            final connData = connDoc.data();
            if (connData != null) {
              final userUid = connData['user_uid'];
              if (userUid != null) {
                final userDoc = await _firestore.collection('user').doc(userUid).get();
                final userData = userDoc.data();

                await connDoc.reference.update({'status': 'unbound'});
                await doc.reference.update({'isConnected': false, 'currentConnectionId': null});
                await userDoc.reference.update({'isConnected': false, 'currentConnectionId': null});

                final caretakerPlayerIds = List<String>.from(data['playerIds'] ?? []);
                final userPlayerIds = List<String>.from(userData?['playerIds'] ?? []);

                await sendNotification(caretakerPlayerIds, 'Your connection has been unbound by admin.');
                await sendNotification(userPlayerIds, 'Your connection has been unbound by admin.');

                await doc.reference.collection('notifications').add({
                  'type': 'admin',
                  'message': 'Your connection has been unbound by admin.',
                  'createdAt': Timestamp.now(),
                  'isRead': false,
                });
                await userDoc.reference.collection('notifications').add({
                  'type': 'admin',
                  'message': 'Your connection has been unbound by admin.',
                  'createdAt': Timestamp.now(),
                  'isRead': false,
                });
              }
            }
          }
        }
        final caretakerPlayerIds = List<String>.from(data['playerIds'] ?? []);
        await sendNotification(caretakerPlayerIds, 'Your account has been banned. Reason: ${reasonController.text}');
        await doc.reference.collection('notifications').add({
          'type': 'admin',
          'message': 'Your account has been banned. Reason: ${reasonController.text}',
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caretaker banned')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _unbanCaretaker(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unban Caretaker', style: TextStyle(color: Colors.blueAccent)),
        content: const Text('Are you sure you want to unban this caretaker?'),
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
          .collection('caretaker')
          .doc(id)
          .update({'isBanned': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caretaker unbanned successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caretakers', style: TextStyle(color: Colors.white)),
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
                  stream: _getCaretakersStream(),
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
                            Text('No caretakers found', style: const TextStyle(fontSize: 18, color: Colors.grey)),
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

                        final isBanned = data['isBanned'] as bool? ?? false;
                        final isApprove = data['isApprove'] as bool? ?? false;
                        Color? cardColor;
                        if (isBanned) {
                          cardColor = Colors.red[50];
                        } else if (!isApprove) {
                          cardColor = Colors.orange[50];
                        } else {
                          cardColor = Colors.green[50];
                        }

                        return Card(
                          color: cardColor,
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundImage: (data['profileImageUrl'] != null && data['profileImageUrl'].isNotEmpty)
                                  ? NetworkImage(data['profileImageUrl'])
                                  : null,
                              child: (data['profileImageUrl'] == null || data['profileImageUrl'].isEmpty)
                                  ? const Icon(Icons.person, size: 25)
                                  : null,
                            ),
                            title: Text(
                              data['fullName'] ?? 'Unnamed',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('@${data['username'] ?? ''}'),
                                Text('Type: ${data['caregiverType'] ?? 'Unknown'}'),
                                Text('Connected: ${data['isConnected'] == true ? 'Yes' : 'No'}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(isBanned ? Icons.restore : Icons.block, color: isBanned ? Colors.green : Colors.red),
                              onPressed: () => isBanned ? _unbanCaretaker(doc.id) : _banCaretaker(doc.id),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CaretakerDetailScreen(caretakerId: doc.id),
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
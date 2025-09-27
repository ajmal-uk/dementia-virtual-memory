// lib/user/family/family_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_add_screen.dart';
import 'family_edit_screen.dart';
import 'family_scanner_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _searchController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _members = [];
  String _search = '';
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(
      () => setState(() => _search = _searchController.text.toLowerCase()),
    );
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      final docRef = _firestore.collection('user').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        // ensure document exists with empty array
        await docRef.set({'members': []});
        _members = [];
      } else {
        final data = doc.data();
        _members = List<Map<String, dynamic>>.from(data?['members'] ?? []);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _updateMembers(List<Map<String, dynamic>> newMembers) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('user').doc(uid).update({
        'members': newMembers,
      });
      await _loadMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating members: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_search.isEmpty) return _members;
    return _members
        .where(
          (m) =>
              (m['name'] ?? '').toLowerCase().contains(_search) ||
              (m['relation'] ?? '').toLowerCase().contains(_search),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Family', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        color: Colors.lightBlue[100],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'search',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Error loading family members',
                            style: TextStyle(fontSize: 18, color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadMembers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _filteredMembers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.family_restroom,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No family members yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first family member',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (member['imageUrl'] ?? '').isNotEmpty
                                ? NetworkImage(member['imageUrl'])
                                : null,
                            child: (member['imageUrl'] ?? '').isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(member['name'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('relation: ${member['relation'] ?? ''}'),
                              Text('phone: ${member['phone'] ?? ''}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  final updatedMember = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EditScreen(member: member),
                                    ),
                                  );
                                  if (updatedMember != null) {
                                    final newMembers =
                                        List<Map<String, dynamic>>.from(
                                          _members,
                                        );
                                    newMembers[_members.indexOf(member)] =
                                        updatedMember;
                                    await _updateMembers(newMembers);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Family Member'),
                                      content: const Text('Are you sure?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final newMembers =
                                        List<Map<String, dynamic>>.from(
                                          _members,
                                        );
                                    newMembers.removeAt(
                                      _members.indexOf(member),
                                    );
                                    await _updateMembers(newMembers);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.add),
                    onPressed: () async {
                      final newMember = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddScreen(),
                        ),
                      );
                      if (newMember != null) {
                        final newMembers = List<Map<String, dynamic>>.from(
                          _members,
                        )..add(newMember);
                        await _updateMembers(newMembers);
                      }
                    },
                  ),
                  FloatingActionButton(
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.camera_alt),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScannerScreen(
                            members: _members
                                .map(
                                  (m) => m.map(
                                    (k, v) => MapEntry(k, v?.toString() ?? ''),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      );
                      if (result != null && result['matchFound'] && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Match found: ${result['memberName']}',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

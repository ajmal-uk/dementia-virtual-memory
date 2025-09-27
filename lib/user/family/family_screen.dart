// lib/user/family/family_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
      if (uid == null) {
        throw Exception('User not logged in');
      }

      final docRef = _firestore.collection('user').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({'members': []});
        _members = [];
      } else {
        final data = doc.data();
        _members = List<Map<String, dynamic>>.from(data?['members'] ?? []);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating members: $e')));
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

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer for $number')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search family members...',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
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
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                child: const Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : _filteredMembers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
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
                          : RefreshIndicator(
                              onRefresh: _loadMembers,
                              color: Colors.blueAccent,
                              child: ListView.builder(
                                itemCount: _filteredMembers.length,
                                itemBuilder: (context, index) {
                                  final member = _filteredMembers[index];
                                  return Card(
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage: (member['imageUrl'] ?? '').isNotEmpty
                                            ? NetworkImage(member['imageUrl'])
                                            : null,
                                        child: (member['imageUrl'] ?? '').isEmpty
                                            ? const Icon(Icons.person, color: Colors.blueAccent)
                                            : null,
                                      ),
                                      title: Text(member['name'] ?? 'Unnamed'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Relation: ${member['relation'] ?? ''}'),
                                          Text('Phone: ${member['phone'] ?? ''}'),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () async {
                                              final updatedMember = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EditScreen(member: member),
                                                ),
                                              );
                                              if (updatedMember != null && mounted) {
                                                final newMembers = List<Map<String, dynamic>>.from(_members);
                                                newMembers[_members.indexOf(member)] = updatedMember;
                                                await _updateMembers(newMembers);
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Delete Family Member'),
                                                  content: const Text('Are you sure?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true && mounted) {
                                                final newMembers = List<Map<String, dynamic>>.from(_members);
                                                newMembers.removeAt(_members.indexOf(member));
                                                await _updateMembers(newMembers);
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.phone, color: Colors.green),
                                            onPressed: () {
                                              final phone = member['phone'];
                                              if (phone != null && phone.isNotEmpty) {
                                                _callNumber(phone);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.extended(
                    backgroundColor: Colors.orange,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Member', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      final newMember = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddScreen(),
                        ),
                      );
                      if (newMember != null && mounted) {
                        final newMembers = List<Map<String, dynamic>>.from(_members)..add(newMember);
                        await _updateMembers(newMembers);
                      }
                    },
                  ),
                  FloatingActionButton.extended(
                    backgroundColor: Colors.orange,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text('Scan', style: TextStyle(color: Colors.white)),
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
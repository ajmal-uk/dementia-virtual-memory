// lib/user/family/family_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'family_add_screen.dart';
import 'family_edit_screen.dart';
import 'family_scanner_screen.dart';

final logger = Logger();

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _searchController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _search = '';
  bool _isAdding = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _search = _searchController.text.toLowerCase()),
    );
  }

  Stream<QuerySnapshot> _getFamilyMembersStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();
    return _firestore
        .collection('user')
        .doc(uid)
        .collection('family_members')
        .orderBy('name')
        .snapshots();
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

  Widget _buildMemberImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.person, color: Colors.blueAccent);
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, color: Colors.blueAccent);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blueAccent,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Column(
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFamilyMembersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.blueAccent));
                }
      
                if (snapshot.hasError) {
                  logger.e('Error loading family members: ${snapshot.error}');
                  return Center(
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
                          onPressed: () => setState(() {}),
                          style:
                              ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }
      
                final docs = snapshot.data?.docs ?? [];
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final relation = (data['relation'] ?? '').toString().toLowerCase();
                  return name.contains(_search) || relation.contains(_search);
                }).toList();
      
                return Column(
                  children: [
                    Expanded(
                      child: filteredDocs.isEmpty
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
                          : RefreshIndicator(
                              onRefresh: () async => setState(() {}),
                              child: ListView.builder(
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  final doc = filteredDocs[index];
                                  final member = doc.data() as Map<String, dynamic>;
                                  return Card(
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.grey[300],
                                        child: _buildMemberImage(member['imageUrl']),
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
                                              final editContext = context; // Capture context
                                              try {
                                                await Navigator.push(
                                                  editContext,
                                                  MaterialPageRoute(
                                                    builder: (context) => EditScreen(
                                                      memberId: doc.id, // Pass the document ID
                                                      memberData: doc.data() as Map<String, dynamic>, // Pass the member data
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                logger.e('Error navigating to edit screen: $e');
                                                if (editContext.mounted) {
                                                  ScaffoldMessenger.of(editContext).showSnackBar(
                                                    SnackBar(content: Text('Error opening edit screen: $e')),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              final deleteContext = context; // Capture context
                                              final confirm = await showDialog<bool>(
                                                context: deleteContext,
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
                                                          backgroundColor: Colors.red),
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text(
                                                        'Delete',
                                                        style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true && deleteContext.mounted) {
                                                try {
                                                  await doc.reference.delete();
                                                } catch (e) {
                                                  logger.e('Error deleting member: $e');
                                                  if (deleteContext.mounted) {
                                                    ScaffoldMessenger.of(deleteContext)
                                                        .showSnackBar(
                                                      SnackBar(content: Text('Error deleting: $e')),
                                                    );
                                                  }
                                                }
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
                    // Move buttons inside StreamBuilder to access snapshot
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _isAdding
                              ? const CircularProgressIndicator(color: Colors.orange)
                              : FloatingActionButton.extended(
                                  backgroundColor: Colors.orange,
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text('Add Member',
                                      style: TextStyle(color: Colors.white)),
                                  onPressed: () async {
                                    final addContext = context; // Capture context
                                    setState(() => _isAdding = true);
                                    try {
                                      await Navigator.push(
                                        addContext,
                                        MaterialPageRoute(
                                          builder: (context) => const AddScreen(),
                                        ),
                                      );
                                    } catch (e) {
                                      logger.e('Error navigating to add screen: $e');
                                      if (addContext.mounted) {
                                        ScaffoldMessenger.of(addContext).showSnackBar(
                                          SnackBar(
                                              content: Text('Error opening add screen: $e')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _isAdding = false);
                                    }
                                  },
                                ),
                          _isScanning
                              ? const CircularProgressIndicator(color: Colors.orange)
                              : FloatingActionButton.extended(
                                  backgroundColor: Colors.orange,
                                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                                  label:
                                      const Text('Scan', style: TextStyle(color: Colors.white)),
                                  onPressed: () async {
                                    final scanContext = context; // Capture context
                                    setState(() => _isScanning = true);
                                    try {
                                      final result = await Navigator.push(
                                        scanContext,
                                        MaterialPageRoute(
                                          builder: (context) => ScannerScreen(
                                            members: snapshot.data?.docs.map((doc) {
                                                  final data = doc.data() as Map<String, dynamic>;
                                                  return {
                                                    'name': data['name'] ?? '',
                                                    'relation': data['relation'] ?? '',
                                                    'imageUrl': data['imageUrl'] ?? '',
                                                  };
                                                }).toList() ?? [],
                                          ),
                                        ),
                                      );
                                      if (result != null && result['matchFound'] && scanContext.mounted) {
                                        ScaffoldMessenger.of(scanContext).showSnackBar(
                                          SnackBar(
                                            content: Text('Match found: ${result['memberName']}'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      logger.e('Error navigating to ScannerScreen: $e');
                                      if (scanContext.mounted) {
                                        ScaffoldMessenger.of(scanContext).showSnackBar(
                                          SnackBar(content: Text('Error opening scanner: $e')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _isScanning = false);
                                    }
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
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
// lib/user/home/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'add_task_page.dart';
import 'edit_task_page.dart';
import '../notifications/notifications_screen.dart';

final logger = Logger();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String _selectedTab = 'All';

  @override
  void initState() {
    super.initState();
    _checkBanned();
  }

  Future<void> _checkBanned() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('user').doc(uid).get();
      if (doc.data()?['isBanned'] == true) {
        await _auth.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
      }
    } catch (e) {
      // If permission denied here, user must update Firestore security rules.
      logger.e('Error checking banned status: $e');
    }
  }

  /// Note: to avoid requiring a composite Firestore index (completed ASC + createdAt DESC),
  /// we subscribe to documents ordered by createdAt (single-field index, auto-built)
  /// and apply the completed filter client-side.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getTasksStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    final coll = _firestore.collection('user').doc(uid).collection('to_dos');

    // Order by createdAt (single-field ordering — does not require a composite index).
    final baseStream = coll.orderBy('createdAt', descending: true).snapshots();

    // Map to documents and apply client-side filter based on _selectedTab.
    return baseStream.map((snap) {
      final allDocs = snap.docs;
      if (_selectedTab == 'Completed') {
        return allDocs
            .where((d) => (d.data()['completed'] as bool? ?? false))
            .toList();
      } else if (_selectedTab == 'InCompleted') {
        return allDocs
            .where((d) => !(d.data()['completed'] as bool? ?? false))
            .toList();
      } else {
        return allDocs;
      }
    });
  }

  /// Get remaining tasks. If Firestore returns an index error for the `where` query,
  /// fallback to fetching all and counting client-side.
  Future<int> _getRemaining() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final coll = _firestore.collection('user').doc(uid).collection('to_dos');

    try {
      // Preferred: server-side count by where().
      final snap = await coll.where('completed', isEqualTo: false).get();
      return snap.docs.length;
    } catch (e) {
      final err = e.toString();
      logger.w('Error getting remaining tasks (trying fallback): $err');
      // If it's index-related or any other issue, fallback to downloading all docs and counting.
      try {
        final all = await coll.get();
        final count = all.docs
            .where((d) => !(d.data()['completed'] as bool? ?? false))
            .length;
        return count;
      } catch (e2) {
        logger.e('Fallback failed getting remaining tasks: $e2');
        return 0;
      }
    }
  }

  Future<void> _deleteTask(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _firestore
            .collection('user')
            .doc(uid)
            .collection('to_dos')
            .doc(id)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting task: $e')));
        }
      }
    }
  }

  Future<void> _toggleTaskStatus(String id, bool current) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('user')
          .doc(uid)
          .collection('to_dos')
          .doc(id)
          .update({'completed': !current});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating task: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // top bar
          Container(
            color: Colors.blue,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.yellow),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // remaining count
          FutureBuilder<int>(
            future: _getRemaining(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox();
              }
              if (snap.hasError) {
                // If permission denied, real fix is to update Firestore rules.
                final err = snap.error.toString();
                logger.e('Remaining-count error: $err');
                return _errorBanner('Error loading remaining count');
              }
              final int remaining = snap.data ?? 0;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${remaining.toString().padLeft(3, '0')} Remaining',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),

          // filter buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _filterButton('All'),
              _filterButton('InCompleted'),
              _filterButton('Completed'),
            ],
          ),

          // task list (uses client-side filtering to avoid composite index requirement)
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: _getTasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // If permission denied: user must update Firestore rules.
                  final err = snapshot.error.toString();
                  logger.e('Task stream error: $err');
                  final permissionDenied =
                      err.contains('permission-denied') ||
                      err.contains('PERMISSION_DENIED');
                  final needsIndex =
                      err.contains('requires an index') ||
                      err.contains('FAILED_PRECONDITION');

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            permissionDenied
                                ? 'Permission error: check Firestore rules for user read access.'
                                : needsIndex
                                ? 'Firestore index is missing.\nCreate composite index: completed ASC + createdAt DESC.'
                                : 'Failed to load tasks.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data ?? [];
                if (docs.isEmpty) return _emptyState();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final task = doc.data();
                    final id = doc.id;
                    final completed = task['completed'] as bool? ?? false;
                    final description = task['description'] ?? '';

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: completed ? Colors.white : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['task'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (description.isNotEmpty)
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              completed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: completed ? Colors.green : Colors.red,
                            ),
                            onPressed: () => _toggleTaskStatus(id, completed),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditTaskPage(
                                    taskName: task['task'] ?? '',
                                    description: description,
                                  ),
                                ),
                              );
                              if (updated != null) {
                                final uid = _auth.currentUser?.uid;
                                if (uid != null) {
                                  try {
                                    await _firestore
                                        .collection('user')
                                        .doc(uid)
                                        .collection('to_dos')
                                        .doc(id)
                                        .update({
                                          'task': updated['task'],
                                          'description': updated['description'],
                                        });
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error updating: $e'),
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () async {
          final newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskPage()),
          );
          if (newTask != null) {
            final uid = _auth.currentUser?.uid;
            if (uid != null) {
              try {
                await _firestore
                    .collection('user')
                    .doc(uid)
                    .collection('to_dos')
                    .add({
                      'task': newTask['task'],
                      'description': newTask['description'],
                      'completed': false,
                      'createdAt': Timestamp.now(),
                      'createdBy': 'user',
                    });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding task: $e')),
                  );
                }
              }
            }
          }
        },
      ),
    );
  }

  Widget _filterButton(String label) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _selectedTab == label ? Colors.white : Colors.grey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _selectedTab == label ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String text) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.red[100],
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.red, fontSize: 16),
      textAlign: TextAlign.center,
    ),
  );

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tasks yet. Add one to get started!',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

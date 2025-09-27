
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifications/notifications_screen.dart';
import '../../utils/notification_helper.dart';
import 'add_task_page.dart';
import 'edit_task_page.dart';

final logger = Logger();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String _selectedTab = 'Today';

  @override
  void initState() {
    super.initState();
    _checkBanned();
    _generateDailyTasks();
  }

  Future<void> _checkBanned() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || !mounted) return;
    try {
      final doc = await _firestore.collection('user').doc(uid).get();
      if (doc.data()?['isBanned'] == true) {
        await _auth.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/welcome');
        }
      }
    } catch (e) {
      logger.e('Error checking banned status: $e');
    }
  }

  Future<void> _generateDailyTasks() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastGenerate = prefs.getString('last_generate_date');
    if (lastGenerate == todayStr) return;

    try {
      final recurringSnap = await _firestore
          .collection('user')
          .doc(uid)
          .collection('recurring_tasks')
          .get();
      for (var rec in recurringSnap.docs) {
        final data = rec.data();
        final dailyDue = data['dailyDueTime'];
        if (dailyDue == null) continue;

        final today = DateTime.now();
        final dueDate = DateTime(
            today.year, today.month, today.day, dailyDue['hour'], dailyDue['min']);
        final dueTs = Timestamp.fromDate(dueDate);

        final reminder = data['dailyReminderTime'];
        Timestamp? reminderTs;
        if (reminder != null) {
          final remDate = DateTime(today.year, today.month, today.day,
              reminder['hour'], reminder['min']);
          reminderTs = Timestamp.fromDate(remDate);
        }

        final existing = await _firestore
            .collection('user')
            .doc(uid)
            .collection('to_dos')
            .where('recurringId', isEqualTo: rec.id)
            .where('dueDate', isEqualTo: dueTs)
            .get();

        if (existing.docs.isEmpty) {
          await _firestore.collection('user').doc(uid).collection('to_dos').add({
            'task': data['task'],
            'description': data['description'],
            'completed': false,
            'createdAt': Timestamp.now(),
            'dueDate': dueTs,
            'reminderTime': reminderTs,
            'recurringId': rec.id,
            'createdBy': 'system',
          });

          if (reminderTs != null && reminderTs.toDate().isAfter(DateTime.now())) {
            final userPlayerIds = await _getUserPlayerIds();
            final caretakerPlayerIds = await _getCaretakerPlayerIds();
            final all = [...userPlayerIds, ...caretakerPlayerIds];
            await scheduleNotification(
                all, 'Daily Task Reminder: ${data['task']}', reminderTs.toDate());
          }
        }
      }
      await prefs.setString('last_generate_date', todayStr);
    } catch (e) {
      logger.e('Error generating daily tasks: $e');
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getTasksStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    if (_selectedTab == 'Recurring') {
      return _firestore
          .collection('user')
          .doc(uid)
          .collection('recurring_tasks')
          .orderBy('createdAt', descending: true)
          .limit(50) // Limit to improve performance
          .snapshots()
          .map((snap) => snap.docs);
    }

    final coll = _firestore.collection('user').doc(uid).collection('to_dos');
    final todayStart = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 1)).add(const Duration(hours: 24)));
    final todayEnd = Timestamp.fromDate(DateTime.now().add(const Duration(days: 1)));

    Stream<QuerySnapshot<Map<String, dynamic>>> baseStream;

    if (_selectedTab == 'Today') {
      baseStream = coll
          .where('dueDate', isGreaterThanOrEqualTo: todayStart)
          .where('dueDate', isLessThan: todayEnd)
          .orderBy('dueDate', descending: false)
          .limit(50)
          .snapshots();
    } else if (_selectedTab == 'Upcoming') {
      baseStream = coll
          .where('dueDate', isGreaterThanOrEqualTo: todayEnd)
          .orderBy('dueDate', descending: false)
          .limit(50)
          .snapshots();
    } else if (_selectedTab == 'Completed') {
      baseStream = coll
          .where('completed', isEqualTo: true)
          .orderBy('dueDate', descending: true)
          .limit(50)
          .snapshots();
    } else {
      baseStream = coll.orderBy('dueDate', descending: true).limit(50).snapshots();
    }

    return baseStream.map((snap) => snap.docs);
  }

  Future<int> _getRemainingToday() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final coll = _firestore.collection('user').doc(uid).collection('to_dos');
    final todayStart = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 1)).add(const Duration(hours: 24)));
    final todayEnd = Timestamp.fromDate(DateTime.now().add(const Duration(days: 1)));

    try {
      final snap = await coll
          .where('completed', isEqualTo: false)
          .where('dueDate', isGreaterThanOrEqualTo: todayStart)
          .where('dueDate', isLessThan: todayEnd)
          .get();
      return snap.docs.length;
    } catch (e) {
      logger.e('Error getting remaining today: $e');
      return 0;
    }
  }

  Future<void> _deleteTask(String id, bool isTemplate) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
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
    if (confirm == true && mounted) {
      try {
        final coll = isTemplate ? 'recurring_tasks' : 'to_dos';
        await _firestore
            .collection('user')
            .doc(uid)
            .collection(coll)
            .doc(id)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }

  Future<void> _toggleTaskStatus(String id, bool current) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || !mounted) return;
    try {
      await _firestore
          .collection('user')
          .doc(uid)
          .collection('to_dos')
          .doc(id)
          .update({'completed': !current});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error updating task: $e')));
      }
    }
  }

  Future<List<String>> _getCaretakerPlayerIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _firestore.collection('user').doc(uid).get();
    final connectionId = userDoc.data()?['currentConnectionId'];
    if (connectionId == null) return [];

    final connectionDoc =
        await _firestore.collection('connections').doc(connectionId).get();
    final caretakerUid = connectionDoc.data()?['caretaker_uid'];
    if (caretakerUid == null) return [];

    final caretakerDoc =
        await _firestore.collection('caretaker').doc(caretakerUid).get();
    return List<String>.from(caretakerDoc.data()?['playerIds'] ?? []);
  }

  Future<List<String>> _getUserPlayerIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final userDoc = await _firestore.collection('user').doc(uid).get();
    return List<String>.from(userDoc.data()?['playerIds'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dementia Tasks',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          FutureBuilder<int>(
            future: _getRemainingToday(),
            builder: (context, snap) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.greenAccent, Colors.green],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        snap.connectionState == ConnectionState.waiting
                            ? '0'
                            : (snap.data ?? 0).toString().padLeft(3, '0'),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Remaining Today',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('Today'),
                const SizedBox(width: 8),
                _filterChip('Upcoming'),
                const SizedBox(width: 8),
                _filterChip('Completed'),
                const SizedBox(width: 8),
                _filterChip('All'),
                const SizedBox(width: 8),
                _filterChip('Recurring'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: _getTasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  logger.e('Task stream error: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load tasks.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: () {
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return _emptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (mounted) setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final task = doc.data();
                      final id = doc.id;
                      final isTemplate = _selectedTab == 'Recurring';
                      final completed = isTemplate ? false : (task['completed'] as bool? ?? false);
                      final description = task['description'] as String? ?? '';
                      final dueDate = task['dueDate'] as Timestamp?;
                      final reminderTime = task['reminderTime'] as Timestamp?;
                      final Map<String, dynamic>? dailyDueTime = isTemplate ? task['dailyDueTime'] as Map<String, dynamic>? : null;
                      final Map<String, dynamic>? dailyReminderTime = isTemplate ? task['dailyReminderTime'] as Map<String, dynamic>? : null;

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: completed ? Colors.grey[200] : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: isTemplate
                              ? const Icon(Icons.repeat, color: Colors.blue, size: 32)
                              : Icon(
                                  completed
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: completed ? Colors.green : Colors.red,
                                  size: 32,
                                ),
                          title: Text(
                            task['task'] as String? ?? 'Untitled',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration:
                                  completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    description,
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ),
                              if (!isTemplate && dueDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Due: ${DateFormat('MMM dd, yyyy hh:mm a').format(dueDate.toDate())}',
                                    style: const TextStyle(color: Colors.blueGrey),
                                  ),
                                ),
                              if (!isTemplate && reminderTime != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Reminder: ${DateFormat('MMM dd, yyyy hh:mm a').format(reminderTime.toDate())}',
                                    style: const TextStyle(color: Colors.orange),
                                  ),
                                ),
                              if (isTemplate && dailyDueTime != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Daily Due: ${dailyDueTime['hour'].toString().padLeft(2, '0')}:${dailyDueTime['min'].toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.blueGrey),
                                  ),
                                ),
                              if (isTemplate && dailyReminderTime != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Daily Reminder: ${dailyReminderTime['hour'].toString().padLeft(2, '0')}:${dailyReminderTime['min'].toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  if (!mounted) return;
                                  final Map<String, dynamic>? updated = await Navigator.push<Map<String, dynamic>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditTaskPage(
                                        taskName: task['task'] as String? ?? '',
                                        description: description,
                                        dueDate: dueDate?.toDate(),
                                        reminderTime: reminderTime?.toDate(),
                                        isTemplate: isTemplate,
                                        dailyDueTime: dailyDueTime,
                                        dailyReminderTime: dailyReminderTime,
                                      ),
                                    ),
                                  );
                                  if (updated != null && mounted) {
                                    final uid = _auth.currentUser?.uid;
                                    if (uid != null) {
                                      try {
                                        final coll = isTemplate ? 'recurring_tasks' : 'to_dos';
                                        await _firestore
                                            .collection('user')
                                            .doc(uid)
                                            .collection(coll)
                                            .doc(id)
                                            .update({
                                              'task': updated['task'],
                                              'description': updated['description'],
                                              if (isTemplate)
                                                'dailyDueTime': updated['dailyDueTime'],
                                              if (isTemplate)
                                                'dailyReminderTime': updated['dailyReminderTime'],
                                              if (!isTemplate)
                                                'dueDate': updated['dueDate'] != null
                                                    ? Timestamp.fromDate(updated['dueDate'] as DateTime)
                                                    : null,
                                              if (!isTemplate)
                                                'reminderTime': updated['reminderTime'] != null
                                                    ? Timestamp.fromDate(updated['reminderTime'] as DateTime)
                                                    : null,
                                            });

                                        if (!isTemplate && updated['reminderTime'] != null) {
                                          final userPlayerIds = await _getUserPlayerIds();
                                          final caretakerPlayerIds = await _getCaretakerPlayerIds();
                                          final allPlayerIds = [...userPlayerIds, ...caretakerPlayerIds];

                                          await scheduleNotification(
                                            allPlayerIds,
                                            'Task Reminder: ${updated['task']}',
                                            updated['reminderTime'] as DateTime,
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error updating: $e')),
                                          );
                                        }
                                      }
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTask(id, isTemplate),
                              ),
                            ],
                          ),
                          onTap: isTemplate ? null : () => _toggleTaskStatus(id, completed),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          if (!mounted) return;
          final newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTaskPage(isTemplate: _selectedTab == 'Recurring')),
          );
          if (newTask != null && mounted) {
            final uid = _auth.currentUser?.uid;
            if (uid != null) {
              try {
                final isTemplate = newTask['recurring'] == 'Daily';
                final coll = isTemplate ? 'recurring_tasks' : 'to_dos';
                await _firestore.collection('user').doc(uid).collection(coll).add({
                  'task': newTask['task'],
                  'description': newTask['description'],
                  if (!isTemplate) 'completed': false,
                  'createdAt': Timestamp.now(),
                  if (!isTemplate)
                    'dueDate': newTask['dueDate'] != null
                        ? Timestamp.fromDate(newTask['dueDate'] as DateTime)
                        : null,
                  if (!isTemplate)
                    'reminderTime': newTask['reminderTime'] != null
                        ? Timestamp.fromDate(newTask['reminderTime'] as DateTime)
                        : null,
                  if (isTemplate) 'dailyDueTime': newTask['dailyDueTime'],
                  if (isTemplate) 'dailyReminderTime': newTask['dailyReminderTime'],
                  'createdBy': 'user',
                });

                if (!isTemplate && newTask['reminderTime'] != null) {
                  final userPlayerIds = await _getUserPlayerIds();
                  final caretakerPlayerIds = await _getCaretakerPlayerIds();
                  final allPlayerIds = [...userPlayerIds, ...caretakerPlayerIds];

                  await scheduleNotification(
                    allPlayerIds,
                    'New Task Reminder: ${newTask['task']}',
                    newTask['reminderTime'] as DateTime,
                  );
                }

                if (isTemplate) {
                  await _generateDailyTasks();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding: $e')),
                  );
                }
              }
            }
          }
        },
      ),
    );
  }

  Widget _filterChip(String label) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 14)),
      selected: _selectedTab == label,
      onSelected: (selected) {
        if (selected && mounted) {
          setState(() => _selectedTab = label);
        }
      },
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey[300],
      labelStyle: TextStyle(
          color: _selectedTab == label ? Colors.white : Colors.black),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No items yet. Add one!',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/notification_helper.dart';
import 'caretaker_map_screen.dart';
import 'family_scanner.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _patientUid;
  String? _patientName;
  String? _patientImageUrl;  
  bool _isConnected = false;
  bool _isLoading = true;

  String _selectedSubTab = 'Tasks'; // Top nav: Tasks, Members, Profile
  TabController? _tabController;

  String _selectedTaskTab = 'Today'; // Sub-tabs for Tasks

  // For task addition
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _reminderTime;

  // Patient's family members
  List<Map<String, dynamic>> _patientMembers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final caretakerUid = _auth.currentUser?.uid;

    if (caretakerUid == null || !mounted) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final caretakerDoc = await _firestore.collection('caretaker').doc(caretakerUid).get();
      final data = caretakerDoc.data();

      final isConnectedField = data?['isConnected'] as bool? ?? false;
      final connectionId = data?['currentConnectionId'] as String?;

      if (isConnectedField && connectionId != null && connectionId.isNotEmpty) {
        final connectionDoc = await _firestore.collection('connections').doc(connectionId).get();
        final patientUid = connectionDoc.data()?['user_uid'] as String?;

        if (patientUid != null) {
          final patientDoc = await _firestore.collection('user').doc(patientUid).get();

          if (patientDoc.exists) {
            if (mounted) {
              setState(() {
                _patientUid = patientUid;
                _patientName = patientDoc.data()?['fullName'] ?? 'Unknown Patient';
                _patientImageUrl = patientDoc.data()?['profileImageUrl'] ?? '';
                _patientMembers = List<Map<String, dynamic>>.from(patientDoc.data()?['members'] ?? []);
                _isConnected = true;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _patientUid = null;
          _isConnected = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking connection: $e')),
        );
        setState(() {
          _patientUid = null;
          _isConnected = false;
          _isLoading = false;
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getTasksStream() {
    if (_patientUid == null) return Stream.empty();

    final coll = _firestore.collection('user').doc(_patientUid).collection('to_dos');

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));
    final todayStart = Timestamp.fromDate(todayMidnight);
    final todayEnd = Timestamp.fromDate(tomorrowMidnight);

    final recurringColl = _firestore.collection('user').doc(_patientUid).collection('recurring_tasks');

    if (_selectedTaskTab == 'Recurring') {
      return recurringColl.orderBy('createdAt', descending: true).snapshots();
    } else if (_selectedTaskTab == 'Today') {
      return coll
          .where('dueDate', isGreaterThanOrEqualTo: todayStart)
          .where('dueDate', isLessThan: todayEnd)
          .orderBy('dueDate', descending: false)
          .snapshots();
    } else if (_selectedTaskTab == 'Upcoming') {
      return coll.where('dueDate', isGreaterThanOrEqualTo: todayEnd).orderBy('dueDate', descending: false).snapshots();
    } else if (_selectedTaskTab == 'Completed') {
      return coll.where('completed', isEqualTo: true).snapshots();
    } else if (_selectedTaskTab == 'All') {
      return coll.orderBy('dueDate', descending: true).snapshots();
    } else {
      return Stream.empty();
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('MMM dd, hh:mm a').format(ts.toDate());
  }

  String _formatTimeMap(Map<String, dynamic>? timeMap) {
    if (timeMap == null) return 'N/A';
    final hour = (timeMap['hour'] as int? ?? 0).toString().padLeft(2, '0');
    final min = (timeMap['min'] as int? ?? 0).toString().padLeft(2, '0');
    return '$hour:$min';
  }

  Widget _buildPatientDetails() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('👤 Patient Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Name: ${_patientName ?? 'Loading...'}'),
          const Text('Age: 65'),
          const Text('Condition: Dementia, recovering from surgery'),
        ]),
      ),
    );
  }

  Widget _buildTaskCard(DocumentSnapshot doc) {
    final task = doc.data() as Map<String, dynamic>;
    final isTemplate = _selectedTaskTab == 'Recurring';

    final completed = isTemplate ? false : (task['completed'] as bool? ?? false);
    final title = task['task'] as String? ?? 'Untitled Task';
    final details = task['description'] as String? ?? 'No details provided.';
    final dueDate = task['dueDate'] as Timestamp?;
    final reminderTime = task['reminderTime'] as Timestamp?;

    final Map<String, dynamic>? dailyDueTime = task['dailyDueTime'] as Map<String, dynamic>?;
    final Map<String, dynamic>? dailyReminderTime = task['dailyReminderTime'] as Map<String, dynamic>?;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        key: Key(doc.id),
        leading: Icon(
          isTemplate ? Icons.repeat : (completed ? Icons.check_circle : Icons.list_alt),
          color: isTemplate ? Colors.indigo : (completed ? Colors.green : Colors.orange),
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: completed ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: isTemplate
            ? const Text('Daily Template', style: TextStyle(color: Colors.blue))
            : Text(
                'Status: ${completed ? 'Completed' : 'Pending'} | Due: ${_formatTimestamp(dueDate)}',
                style: TextStyle(color: completed ? Colors.green : Colors.red),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (details.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('Details: $details')),
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 8),
              Text('Created At: ${_formatTimestamp(task['createdAt'] as Timestamp?)}'),
              Text('Created By: ${task['createdBy'] as String? ?? 'N/A'}'),
              if (!isTemplate) Text('Scheduled Reminder: ${reminderTime is Timestamp ? _formatTimestamp(reminderTime) : 'None'}'),
              if (isTemplate) ...[
                Text('Daily Due Time: ${_formatTimeMap(dailyDueTime)}'),
                Text('Daily Reminder Time: ${_formatTimeMap(dailyReminderTime)}'),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedTaskTab == label,
      onSelected: (sel) {
        if (sel) setState(() => _selectedTaskTab = label);
      },
    );
  }

  Widget _buildNotConnectedState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 80, color: Colors.red),
            SizedBox(height: 16),
            Text('Not Connected to any Patient', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Please ensure your profile is linked to a patient user to view and manage tasks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _openFaceScanner() {
    if (!_isConnected || _patientUid == null || _patientName == null || _patientImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open scanner: Not connected')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          members: [
            {
              'name': _patientName!,
              'relation': 'Patient',
              'imageUrl': _patientImageUrl!,
            }
          ],
        ),
      ),
    );
  }

  Future<void> _addTask() async {
    if (_patientUid == null) return;

    final newTask = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _taskController,
                decoration: InputDecoration(
                  labelText: 'Task Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_dueDate == null ? 'Set Due Date' : DateFormat('MMM dd, hh:mm a').format(_dueDate!)),
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null && mounted) {
                      setState(() {
                        _dueDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.alarm),
                label: Text(_reminderTime == null ? 'Set Reminder (Optional)' : DateFormat('MMM dd, hh:mm a').format(_reminderTime!)),
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null && mounted) {
                      setState(() {
                        _reminderTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (_taskController.text.isEmpty || _dueDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task name and due date required')));
              return;
            }
            Navigator.pop(context, {
              'task': _taskController.text,
              'description': _descController.text,
              'dueDate': _dueDate,
              'reminderTime': _reminderTime,
            });
            _taskController.clear();
            _descController.clear();
            _dueDate = null;
            _reminderTime = null;
          }, child: const Text('Add')),
        ],
      ),
    );

    if (newTask != null) {
      try {
        await _firestore.collection('user').doc(_patientUid).collection('to_dos').add({
          'task': newTask['task'],
          'description': newTask['description'],
          'completed': false,
          'createdAt': Timestamp.now(),
          'dueDate': Timestamp.fromDate(newTask['dueDate']),
          'reminderTime': newTask['reminderTime'] != null ? Timestamp.fromDate(newTask['reminderTime']) : null,
          'createdBy': 'caretaker',
        });

        if (newTask['reminderTime'] != null) {
          final patientDoc = await _firestore.collection('user').doc(_patientUid).get();
          final patientPlayerIds = List<String>.from(patientDoc.data()?['playerIds'] ?? []);
          await sendNotification(patientPlayerIds, 'New task added by caretaker: ${newTask['task']}');
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task added successfully')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding task: $e')));
      }
    }
  }

  Widget _buildPatientProfile() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('user').doc(_patientUid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Error loading profile'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(data['profileImageUrl'] ?? ''),
                  child: data['profileImageUrl'] == null ? const Icon(Icons.person, size: 60) : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  data['fullName'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '@${data['username'] ?? ''}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Personal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildInfoRow('Email', data['email'] ?? ''),
              _buildInfoRow('Phone', data['phoneNo'] ?? ''),
              _buildInfoRow('Gender', data['gender'] ?? ''),
              _buildInfoRow('DOB', data['dob'] != null ? DateFormat('MMM dd, yyyy').format(data['dob'].toDate()) : ''),
              _buildInfoRow('Bio', data['bio'] ?? ''),
              const SizedBox(height: 16),
              const Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildInfoRow('Locality', data['locality'] ?? ''),
              _buildInfoRow('City', data['city'] ?? ''),
              _buildInfoRow('State', data['state'] ?? ''),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(value.isEmpty ? 'N/A' : value),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    if (_patientMembers.isEmpty) {
      return const Center(child: Text('No family members added'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patientMembers.length,
      itemBuilder: (context, index) {
        final member = _patientMembers[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(member['imageUrl'] ?? ''),
            ),
            title: Text(member['name'] ?? ''),
            subtitle: Text(member['relation'] ?? ''),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...'), backgroundColor: Colors.indigo),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isConnected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caretaker View'), centerTitle: true, backgroundColor: Colors.indigo),
        body: _buildNotConnectedState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Patient: ${_patientName ?? 'N/A'}'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      floatingActionButton: _isConnected && _patientUid != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_selectedSubTab == 'Tasks')
                  FloatingActionButton.extended(
                    heroTag: 'add_task_btn',
                    onPressed: _addTask,
                    label: const Text('Add Task', style: TextStyle(color: Colors.white)),
                    icon: const Icon(Icons.add_task, color: Colors.white),
                    backgroundColor: Colors.orange,
                  ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'face_scan_btn',
                  onPressed: _openFaceScanner,
                  label: const Text('Face Scan', style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.face_unlock_outlined, color: Colors.white),
                  backgroundColor: Colors.indigo,
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'track_location_btn',
                  onPressed: () {
                    if (_patientUid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CaretakerMapScreen(patientId: _patientUid!),
                        ),
                      );
                    }
                  },
                  label: const Text('Track Location', style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.location_on_outlined, color: Colors.white),
                  backgroundColor: Colors.green,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          _buildPatientDetails(),
          const Divider(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Tasks'),
              Tab(text: 'Members'),
              Tab(text: 'Profile'),
            ],
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.indigo,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _buildFilterChip('Today'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Upcoming'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Completed'),
                          const SizedBox(width: 8),
                          _buildFilterChip('All'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Recurring'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _getTasksStream(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No $_selectedTaskTab tasks found.'));
                          }

                          var docs = snapshot.data!.docs;
                          if (_selectedTaskTab == 'Completed') {
                            docs.sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>;
                              final bData = b.data() as Map<String, dynamic>;
                              final aDate = (aData['dueDate'] as Timestamp?)?.toDate() ?? DateTime(0);
                              final bDate = (bData['dueDate'] as Timestamp?)?.toDate() ?? DateTime(0);
                              return bDate.compareTo(aDate);
                            });
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) => _buildTaskCard(docs[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                _buildMembersSection(),
                _buildPatientProfile(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _taskController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
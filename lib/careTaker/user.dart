import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class User extends StatefulWidget {
  const User({super.key});

  @override
  State<User> createState() => _UserState();
}

class _UserState extends State<User> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  String? _patientUid;
  String? _patientName;
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  // --- Connection & Patient Data Fetch ---
  Future<void> _checkConnectionStatus() async {
    final caretakerUid = _auth.currentUser?.uid;

    if (caretakerUid == null || !mounted) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final caretakerDoc = await _firestore.collection('caretaker').doc(caretakerUid).get();
      final data = caretakerDoc.data();

      // 1. Check if connected is true
      final isConnectedField = data?['isConnected'] as bool? ?? false;
      // 2. The connection ID IS the Patient's UID (as per new requirements)
      final patientUid = data?['currentConnectionId'] as String?;

      if (isConnectedField && patientUid != null && patientUid.isNotEmpty) {
        
        // Fetch patient's name using their UID
        final patientDoc = await _firestore.collection('user').doc(patientUid).get();

        if (patientDoc.exists) {
            if (mounted) {
              setState(() {
                _patientUid = patientUid;
                _patientName = patientDoc.data()?['fullName'] ?? 'Unknown Patient';
                _isConnected = true;
                _isLoading = false; // FINALLY DONE LOADING
              });
            }
            return;
        }
      }
      
      // If any step failed, or isConnected is false/missing
      if (mounted) {
        setState(() {
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
          _isConnected = false;
          _isLoading = false;
        });
      }
    }
  }

  // --- CRUD Operations against Firestore ---

  void _addOrEditTask({DocumentSnapshot? existingDoc}) {
    final isEditing = existingDoc != null;
    final data = existingDoc?.data() as Map<String, dynamic>?;

    final titleController = TextEditingController(text: data?['task'] ?? '');
    final detailController = TextEditingController(text: data?['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Task' : 'Add Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Task Title (Required)'),
            ),
            TextField(
              controller: detailController,
              decoration: const InputDecoration(labelText: 'Details (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final taskTitle = titleController.text.trim();
              final taskDetails = detailController.text.trim();

              if (taskTitle.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task title cannot be empty')));
                return;
              }

              // Use a basic Timestamp for dueDate if it doesn't exist (simpler implementation)
              final now = DateTime.now();
              final defaultDueDate = Timestamp.fromDate(DateTime(now.year, now.month, now.day).add(const Duration(hours: 9)));


              final taskData = <String, dynamic>{
                'task': taskTitle,
                'description': taskDetails,
                'completed': data?['completed'] ?? false,
                'createdAt': data?['createdAt'] ?? Timestamp.now(),
                // Use existing or a default time
                'dueDate': data?['dueDate'] ?? defaultDueDate,
                'reminderTime': data?['reminderTime'],
                'createdBy': data?['createdBy'] ?? 'caretaker',
                // Keep other required fields null if not set
                'recurringId': data?['recurringId'],
              };

              try {
                if (isEditing) {
                  // UPDATE existing task
                  await _firestore
                      .collection('user')
                      .doc(_patientUid)
                      .collection('to_dos')
                      .doc(existingDoc!.id)
                      .update(taskData);
                } else {
                  // ADD new task
                  await _firestore
                      .collection('user')
                      .doc(_patientUid)
                      .collection('to_dos')
                      .add(taskData);
                }
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving task: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleCompletion(String taskId, bool currentStatus) async {
    try {
      await _firestore
          .collection('user')
          .doc(_patientUid)
          .collection('to_dos')
          .doc(taskId)
          .update({'completed': !currentStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
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
        await _firestore
            .collection('user')
            .doc(_patientUid)
            .collection('to_dos')
            .doc(taskId)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting task: $e')));
        }
      }
    }
  }

  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image captured. Upload functionality required.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  // --- UI Builders ---

  Widget _buildPatientDetails() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👤 Patient Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Name: ${_patientName ?? 'Loading...'}'),
            const Text('Age: 65'), // Static for now
            const Text('Condition: Dementia, recovering from surgery'), // Static for now
            const Text('Room: 203B'), // Static for now
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(DocumentSnapshot doc) {
    final task = doc.data() as Map<String, dynamic>;
    final taskId = doc.id;
    final completed = task['completed'] as bool? ?? false;
    final title = task['task'] as String? ?? 'Untitled Task';
    final details = task['description'] as String? ?? 'No details provided.';
    final dueDate = task['dueDate'] as Timestamp?;
    
    // Helper to format the time
    String formatTime(Timestamp? ts) {
      if (ts == null) return 'No Time Set';
      // Use the 'hh:mm a' format for clarity
      return DateFormat('MMM dd, hh:mm a').format(ts.toDate());
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        key: Key(taskId),
        title: Row(
          children: [
            IconButton(
              icon: Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: completed ? Colors.green : Colors.grey,
              ),
              onPressed: () => _toggleCompletion(taskId, completed),
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  decoration: completed ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: dueDate != null ? Text('Due: ${formatTime(dueDate)}', style: TextStyle(color: completed ? Colors.green : Colors.red)) : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Align(alignment: Alignment.centerLeft, child: Text(details)),
          ),
          // Displaying additional task fields as per structure
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dueDate != null) Text('Due Date: ${formatTime(dueDate)}'),
                if (task['reminderTime'] is Timestamp) Text('Reminder: ${formatTime(task['reminderTime'] as Timestamp)}'),
                if (task['createdBy'] is String) Text('Created By: ${task['createdBy']}'),
              ],
            ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _addOrEditTask(existingDoc: doc),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteTask(taskId),
              ),
            ],
          ),
        ],
      ),
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
            Text(
              'Not Connected to any Patient',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return  Scaffold(
        appBar: AppBar(title: Text('Loading...'), backgroundColor: Colors.indigo),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Not Connected State
    if (!_isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Caretaker View'),
          centerTitle: true,
          backgroundColor: Colors.indigo,
          automaticallyImplyLeading: false, // NO BACK BUTTON
        ),
        body: _buildNotConnectedState(),
      );
    }

    // Connected State
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient: ${_patientName ?? 'N/A'}'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        automaticallyImplyLeading: false, // NO BACK BUTTON
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addOrEditTask(),
            tooltip: 'Add Task',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPatientDetails(),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Today\'s Tasks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('user')
                  .doc(_patientUid) // Use the directly obtained Patient UID
                  .collection('to_dos')
                  // Ordering by dueDate or createdAt is generally better for ToDos
                  .orderBy('dueDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading tasks: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No tasks found for this patient.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(snapshot.data!.docs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCamera,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
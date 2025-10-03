import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _patientUid;
  String? _patientName;
  bool _isConnected = false;
  bool _isLoading = true;

  // State for filtering tabs
  String _selectedTab = 'Today';

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
      final caretakerDoc = await _firestore
        .collection('caretaker')
        .doc(caretakerUid)
        .get();
      final data = caretakerDoc.data();

      // Check for isConnected and currentConnectionId
      final isConnectedField = data?['isConnected'] as bool? ?? false;
      final connectionId = data?['currentConnectionId'] as String?;

      if (isConnectedField && connectionId != null && connectionId.isNotEmpty) {
        final connectionDoc = await _firestore
          .collection('connections')
          .doc(connectionId)
          .get();
        final patientUid = connectionDoc.data()?['user_uid'] as String?;

        if (patientUid != null) {
          final patientDoc = await _firestore
            .collection('user')
            .doc(patientUid)
            .get();

          if (patientDoc.exists) {
            if (mounted) {
              setState(() {
                _patientUid = patientUid;
                _patientName =
                  patientDoc.data()?['fullName'] ?? 'Unknown Patient';
                _isConnected = true;
                _isLoading = false; // FINALLY DONE LOADING
              });
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _patientUid = null; // Ensure patient UID is null if not connected
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

  // --- Task Stream Filtering Function ---
  Stream<QuerySnapshot<Map<String, dynamic>>> _getTasksStream() {
    if (_patientUid == null) return Stream.empty();

    final coll = _firestore.collection('user').doc(_patientUid).collection('to_dos');

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));
    final todayStart = Timestamp.fromDate(todayMidnight);
    final todayEnd = Timestamp.fromDate(tomorrowMidnight);

    // FIX: Using correct path for recurring tasks
    final recurringColl = _firestore
      .collection('user')
      .doc(_patientUid)
      .collection('recurring_tasks');

    if (_selectedTab == 'Recurring') {
      return recurringColl.orderBy('createdAt', descending: true).snapshots();
    } else if (_selectedTab == 'Today') {
      return coll
        .where('dueDate', isGreaterThanOrEqualTo: todayStart)
        .where('dueDate', isLessThan: todayEnd)
        .orderBy('dueDate', descending: false)
        .snapshots();
    } else if (_selectedTab == 'Upcoming') {
      return coll
        .where('dueDate', isGreaterThanOrEqualTo: todayEnd)
        .orderBy('dueDate', descending: false)
        .snapshots();
    } else if (_selectedTab == 'Completed') {
      // Non-indexed query for Completed tab (sorted locally)
      return coll.where('completed', isEqualTo: true).snapshots();
    } else if (_selectedTab == 'All') {
      return coll.orderBy('dueDate', descending: true).snapshots();
    } else {
      return Stream.empty();
    }
  }

  // --- Utility Methods ---

  // Helper to format Timestamp (safe)
  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('MMM dd, hh:mm a').format(ts.toDate());
  }

  // Helper to format Time Map (safe)
  String _formatTimeMap(Map<String, dynamic>? timeMap) {
    if (timeMap == null) return 'N/A';
    final hour = (timeMap['hour'] as int? ?? 0).toString().padLeft(2, '0');
    final min = (timeMap['min'] as int? ?? 0).toString().padLeft(2, '0');
    return '$hour:$min';
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
            const Text(
              '👤 Patient Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Name: ${_patientName ?? 'Loading...'}'),
            const Text('Age: 65'), // Static for now
            const Text(
              'Condition: Dementia, recovering from surgery',
            ), // Static for now
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(DocumentSnapshot doc) {
    // We can safely cast data()! to Map<String, dynamic> since we check doc.exists in the StreamBuilder
    final task = doc.data() as Map<String, dynamic>;
    final isTemplate = _selectedTab == 'Recurring';

    // Fields from Firestore document
    final completed = isTemplate
      ? false
      : (task['completed'] as bool? ?? false);
    final title = task['task'] as String? ?? 'Untitled Task';
    final details = task['description'] as String? ?? 'No details provided.';
    final dueDate = task['dueDate'] as Timestamp?;
    final reminderTime = task['reminderTime'] as Timestamp?;

    final Map<String, dynamic>? dailyDueTime =
      task['dailyDueTime'] as Map<String, dynamic>?;
    final Map<String, dynamic>? dailyReminderTime =
      task['dailyReminderTime'] as Map<String, dynamic>?;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: ExpansionTile(
        key: Key(doc.id),
        leading: Icon(
          isTemplate
            ? Icons.repeat
            : (completed ? Icons.check_circle : Icons.list_alt),
          color: isTemplate
            ? Colors.indigo
            : (completed ? Colors.green : Colors.orange),
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: completed ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Display status/due date in subtitle
        subtitle: isTemplate
          ? const Text('Daily Template', style: TextStyle(color: Colors.blue))
          : Text(
              'Status: ${completed ? 'Completed' : 'Pending'} | Due: ${_formatTimestamp(dueDate)}',
              style: TextStyle(color: completed ? Colors.green : Colors.red),
            ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description (if present)
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('Details: $details'),
                  ),
                const Divider(height: 1, color: Colors.grey),
                const SizedBox(height: 8),

                // Displaying conditional fields
                Text(
                  'Created At: ${_formatTimestamp(task['createdAt'] as Timestamp?)}',
                ),
                Text('Created By: ${task['createdBy'] as String? ?? 'N/A'}'),

                if (!isTemplate) ...[
                  Text(
                    'Scheduled Reminder: ${reminderTime is Timestamp ? _formatTimestamp(reminderTime) : 'None'}',
                  ),
                ],

                if (isTemplate) ...[
                  Text('Daily Due Time: ${_formatTimeMap(dailyDueTime)}'),
                  Text(
                    'Daily Reminder Time: ${_formatTimeMap(dailyReminderTime)}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    return ChoiceChip(
      label: const Text('Approved'),
      selected: _selectedTab == 'Approved',
      onSelected: (sel) {
        if (sel) setState(() => _selectedTab = 'Approved');
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

  // --- Face Scanner Navigation Handler (UPDATED) ---
  void _openFaceScanner() {
    // Only navigate if connected and patientUid is known
    if (_isConnected && _patientUid != null) {
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open scanner: Not connected to a patient.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.indigo,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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

    // Only show the FloatingActionButton if _isConnected is true and we have a patient UID
    final showScannerButton = _isConnected && _patientUid != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Patient: ${_patientName ?? 'N/A'}'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        automaticallyImplyLeading: false, // NO BACK BUTTON
        actions: const [
          // Add/Edit buttons removed for read-only view
        ],
      ),
      // FLOATING ACTION BUTTON IMPLEMENTATION: Conditional on connection status
      floatingActionButton: showScannerButton
        ? FloatingActionButton.extended(
            onPressed: _openFaceScanner,
            label: const Text('Face Scan', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.face_unlock_outlined, color: Colors.white),
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
          )
        : null, // Don't show the button if not connected
      body: Column(
        children: [
          _buildPatientDetails(),
          const Divider(),
          // Task Filtering Chips
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _getTasksStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading tasks: ${snapshot.error}'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${_selectedTab} tasks found for this patient.',
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                // FIX: Manual Sorting for 'Completed' tab
                if (_selectedTab == 'Completed') {
                  docs.sort((a, b) {
                    // FIX IS HERE: Explicitly cast the data() result to Map<String, dynamic>
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aDate =
                      (aData['dueDate'] as Timestamp?)?.toDate() ??
                      DateTime(0);
                    final bDate =
                      (bData['dueDate'] as Timestamp?)?.toDate() ??
                      DateTime(0);

                    // Sort descending (newest completed tasks first)
                    return bDate.compareTo(aDate);
                  });
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(docs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
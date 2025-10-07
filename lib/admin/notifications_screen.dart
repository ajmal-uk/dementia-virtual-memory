import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/notification_helper.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  bool _isIndividual = true;
  bool _isUser = true;
  bool _isPatient = true;
  bool _isCaretaker = false;
  bool _scheduleNotification = false;
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.now();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and message required')));
      }
      return;
    }

    List<String> playerIds = [];
    final message = '${_titleController.text}: ${_messageController.text}';

    if (_isIndividual) {
      final coll = _isUser ? 'user' : 'caretaker';
      final snap = await FirebaseFirestore.instance.collection(coll).where('username', isEqualTo: _usernameController.text.trim()).get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
        }
        return;
      }
      playerIds = List<String>.from(snap.docs.first.data()['playerIds'] ?? []);
      await snap.docs.first.reference.collection('notifications').add({
        'type': 'admin',
        'message': message,
        'createdAt': Timestamp.now(),
        'isRead': false,
      });
    } else {
      if (_isPatient) {
        final snap = await FirebaseFirestore.instance.collection('user').get();
        for (var doc in snap.docs) {
          playerIds.addAll(List<String>.from(doc.data()['playerIds'] ?? []));
          await doc.reference.collection('notifications').add({
            'type': 'admin',
            'message': message,
            'createdAt': Timestamp.now(),
            'isRead': false,
          });
        }
      }
      if (_isCaretaker) {
        final snap = await FirebaseFirestore.instance.collection('caretaker').get();
        for (var doc in snap.docs) {
          playerIds.addAll(List<String>.from(doc.data()['playerIds'] ?? []));
          // Add to Firestore notifications for each caretaker
          await doc.reference.collection('notifications').add({
            'type': 'admin',
            'message': message,
            'createdAt': Timestamp.now(),
            'isRead': false,
          });
        }
      }
    }

    DateTime? scheduledTime = _scheduleNotification ? DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    ) : null;

    if (scheduledTime != null && scheduledTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled time must be in the future')));
      return;
    }

    if (scheduledTime != null) {
      await scheduleNotification(playerIds, message, scheduledTime);
    } else {
      await sendNotification(playerIds, message);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent/scheduled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notifications'), backgroundColor: Colors.blue),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Individual'),
                      selected: _isIndividual,
                      onSelected: (sel) => setState(() => _isIndividual = sel),
                      selectedColor: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Broadcast'),
                      selected: !_isIndividual,
                      onSelected: (sel) => setState(() => _isIndividual = !sel),
                      selectedColor: Colors.blueAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isIndividual) ...[
                  const Text(
                    'Recipient Type',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('User'),
                        selected: _isUser,
                        onSelected: (sel) => setState(() => _isUser = sel),
                        selectedColor: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Caretaker'),
                        selected: !_isUser,
                        onSelected: (sel) => setState(() => _isUser = !sel),
                        selectedColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Broadcast To',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('All Patients'),
                    value: _isPatient,
                    onChanged: (val) => setState(() => _isPatient = val!),
                    activeColor: Colors.blueAccent,
                  ),
                  CheckboxListTile(
                    title: const Text('All Caretakers'),
                    value: _isCaretaker,
                    onChanged: (val) => setState(() => _isCaretaker = val!),
                    activeColor: Colors.blueAccent,
                  ),
                ],
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Schedule Notification'),
                  value: _scheduleNotification,
                  onChanged: (val) => setState(() => _scheduleNotification = val),
                  activeColor: Colors.blueAccent,
                ),
                if (_scheduleNotification) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(_scheduledDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_scheduledTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Message Content',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send Notification', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
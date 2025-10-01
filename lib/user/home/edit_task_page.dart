// lib/user/home/edit_task_page.dart
// lib/user/home/edit_task_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditTaskPage extends StatefulWidget {
  final String taskName;
  final String description;
  final DateTime? dueDate;
  final DateTime? reminderTime;
  final bool isTemplate;
  final Map<String, dynamic>? dailyDueTime;
  final Map<String, dynamic>? dailyReminderTime;

  const EditTaskPage({
    super.key,
    required this.taskName,
    required this.description,
    this.dueDate,
    this.reminderTime,
    this.isTemplate = false,
    this.dailyDueTime,
    this.dailyReminderTime,
  });

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  late TextEditingController _taskController;
  late TextEditingController _descController;
  DateTime? _dueDate;
  DateTime? _reminderTime;
  TimeOfDay? _dailyDueTime;
  TimeOfDay? _dailyReminderTime;

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(text: widget.taskName);
    _descController = TextEditingController(text: widget.description);
    _dueDate = widget.dueDate;
    _reminderTime = widget.reminderTime;
    if (widget.dailyDueTime != null) {
      _dailyDueTime = TimeOfDay(hour: widget.dailyDueTime!['hour'], minute: widget.dailyDueTime!['min']);
    }
    if (widget.dailyReminderTime != null) {
      _dailyReminderTime = TimeOfDay(hour: widget.dailyReminderTime!['hour'], minute: widget.dailyReminderTime!['min']);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _dueDate != null ? TimeOfDay.fromDateTime(_dueDate!) : TimeOfDay.now(),
      );
      if (time != null && mounted) {
        setState(() {
          _dueDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _pickReminderTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _reminderTime != null ? TimeOfDay.fromDateTime(_reminderTime!) : TimeOfDay.now(),
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
  }

  Future<void> _pickDailyDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyDueTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _dailyDueTime = picked);
  }

  Future<void> _pickDailyReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyReminderTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _dailyReminderTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isTemplate = widget.isTemplate;
    return Scaffold(
      appBar: AppBar(
        title: Text(isTemplate ? 'Edit Template' : 'Edit Task'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Task Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _taskController,
                decoration: InputDecoration(
                  labelText: 'Task Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.task),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (!isTemplate)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(_dueDate == null ? 'Set Due Date & Time' : DateFormat('MMM dd, yyyy hh:mm a').format(_dueDate!)),
                    trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                    onTap: _pickDueDate,
                  ),
                ),
              if (!isTemplate) const SizedBox(height: 8),
              if (!isTemplate)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(_reminderTime == null ? 'Set Reminder (optional)' : DateFormat('MMM dd, yyyy hh:mm a').format(_reminderTime!)),
                    trailing: const Icon(Icons.alarm, color: Colors.orange),
                    onTap: _pickReminderTime,
                  ),
                ),
              if (isTemplate)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(_dailyDueTime == null ? 'Set Daily Due Time' : _dailyDueTime!.format(context)),
                    trailing: const Icon(Icons.access_time, color: Colors.blueAccent),
                    onTap: _pickDailyDueTime,
                  ),
                ),
              if (isTemplate) const SizedBox(height: 8),
              if (isTemplate)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(_dailyReminderTime == null ? 'Set Daily Reminder (optional)' : _dailyReminderTime!.format(context)),
                    trailing: const Icon(Icons.alarm, color: Colors.orange),
                    onTap: _pickDailyReminderTime,
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_taskController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task name cannot be empty')),
                    );
                    return;
                  }
                  if (isTemplate && _dailyDueTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Daily due time required')),
                    );
                    return;
                  }
                  final map = <String, dynamic>{
                    'task': _taskController.text.trim(),
                    'description': _descController.text.trim(),
                  };
                  if (isTemplate) {
                    map['dailyDueTime'] = _dailyDueTime != null 
                      ? {'hour': _dailyDueTime!.hour, 'min': _dailyDueTime!.minute} 
                      : null;
                    map['dailyReminderTime'] = _dailyReminderTime != null 
                      ? {'hour': _dailyReminderTime!.hour, 'min': _dailyReminderTime!.minute} 
                      : null;
                  } else {
                    map['dueDate'] = _dueDate;
                    map['reminderTime'] = _reminderTime;
                  }
                  Navigator.pop(context, map);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
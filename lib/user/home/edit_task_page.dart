import 'package:flutter/material.dart';

class EditTaskPage extends StatefulWidget {
  final String taskName;
  final String description;

  const EditTaskPage({
    super.key,
    required this.taskName,
    required this.description,
  });

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  late TextEditingController _taskController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(text: widget.taskName);
    _descController = TextEditingController(text: widget.description);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Task')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'Task name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'task': _taskController.text.trim(),
                  'description': _descController.text.trim(),
                });
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

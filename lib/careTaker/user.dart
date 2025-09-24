import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class User extends StatefulWidget {
  const User({super.key});

  @override
  State<User> createState() => _UserState();
}

class _UserState extends State<User> {
  final List<Map<String, dynamic>> _tasks = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tasks.addAll([
      {
        'title': 'Check blood pressure',
        'details': 'Measure and record patient’s BP at 9 AM.',
        'completed': false,
        'expanded': false,
      },
      {
        'title': 'Administer medication',
        'details': 'Give prescribed antibiotics after breakfast.',
        'completed': false,
        'expanded': false,
      },
      {
        'title': 'Physical therapy',
        'details': 'Assist with leg exercises for 20 minutes.',
        'completed': false,
        'expanded': false,
      },
    ]);
  }

  void _addOrEditTask({Map<String, dynamic>? existingTask, int? index}) {
    final titleController =
        TextEditingController(text: existingTask?['title'] ?? '');
    final detailController =
        TextEditingController(text: existingTask?['details'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingTask == null ? 'Add Task' : 'Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: detailController,
              decoration: const InputDecoration(labelText: 'Details'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTask = {
                'title': titleController.text,
                'details': detailController.text,
                'completed': false,
                'expanded': false,
              };
              setState(() {
                if (existingTask != null && index != null) {
                  _tasks[index] = newTask;
                } else {
                  _tasks.add(newTask);
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleExpansion(int index) {
    setState(() {
      _tasks[index]['expanded'] = !(_tasks[index]['expanded'] ?? false);
    });
  }

  void _toggleCompletion(int index) {
    setState(() {
      _tasks[index]['completed'] = !(_tasks[index]['completed'] ?? false);
    });
  }

  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image captured: ${photo.name}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  Widget _buildPatientDetails() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('👤 Patient Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Name: Abhinav'),
            Text('Age: 65'),
            Text('Condition: Hypertension, recovering from surgery'),
            Text('Room: 203B'),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(int index) {
    final task = _tasks[index];
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            IconButton(
              icon: Icon(
                task['completed'] == true
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task['completed'] == true ? Colors.green : Colors.grey,
              ),
              onPressed: () => _toggleCompletion(index),
            ),
            Expanded(
              child: Text(
                task['title'] ?? '',
                style: TextStyle(
                  decoration: task['completed'] == true
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
        initiallyExpanded: task['expanded'] == true,
        onExpansionChanged: (_) => _toggleExpansion(index),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(task['details'] ?? ''),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _addOrEditTask(existingTask: task, index: index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient: Abhinav'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
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
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) => _buildTaskCard(index),
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

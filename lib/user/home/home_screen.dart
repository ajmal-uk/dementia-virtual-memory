import 'package:flutter/material.dart';
import 'add_task_page.dart';
import 'edit_task_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedTab = 'InCompleted';

  // Better structured tasks
  final List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Buy groceries',
      'description': 'Milk, Bread, Eggs',
      'completed': false,
      'createdAt': DateTime.now(),
      'createdBy': 'user'
    },
    {
      'title': 'Doctor Appointment',
      'description': 'Visit Dr. Smith at 5 PM',
      'completed': true,
      'createdAt': DateTime.now(),
      'createdBy': 'caretaker'
    },
  ];

  List<Map<String, dynamic>> get _filteredTasks {
    if (_selectedTab == 'All') return _tasks;
    if (_selectedTab == 'Completed') {
      return _tasks.where((task) => task['completed']).toList();
    }
    return _tasks.where((task) => !task['completed']).toList();
  }

  int get _remaining {
    return _tasks.where((task) => !task['completed']).length;
  }

  void _deleteTask(int index) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _tasks.removeAt(index);
      });
    }
  }

  void _toggleTaskStatus(int index) {
    setState(() {
      _tasks[index]['completed'] = !_tasks[index]['completed'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          /// Top bar
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
                  onPressed: () {},
                ),
              ],
            ),
          ),

          /// Remaining count
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_remaining.toString().padLeft(3, '0')} Remaining',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          /// Filter tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _filterButton('All'),
              _filterButton('InCompleted'),
              _filterButton('Completed'),
            ],
          ),

          /// Task List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: task['completed'] ? Colors.white : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      /// Title & description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            if (task['description'] != null &&
                                task['description'].toString().isNotEmpty)
                              Text(
                                task['description'],
                                style: const TextStyle(fontSize: 14, color: Colors.black54),
                              ),
                          ],
                        ),
                      ),

                      /// Status Icon (toggle on tap)
                      GestureDetector(
                        onTap: () => _toggleTaskStatus(index),
                        child: Icon(
                          task['completed'] ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: task['completed'] ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 16),

                      /// Edit button
                      GestureDetector(
                        onTap: () async {
                          final updatedTask = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EditTaskPage(
      taskName: task['title'],
      description: task['description'], // ✅ now passing description
    ),
  ),
);

                          if (updatedTask != null && updatedTask.isNotEmpty) {
                            setState(() {
                              _tasks[index]['title'] = updatedTask;
                            });
                          }
                        },
                        child: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      const SizedBox(width: 16),

                      /// Delete button
                      GestureDetector(
                        onTap: () => _deleteTask(index),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      /// Floating Buttons
      floatingActionButton: FloatingActionButton(
        heroTag: 'addTask',
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () async {
          final newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskPage()),
          );
          if (newTask != null && newTask.isNotEmpty) {
            setState(() {
              _tasks.add({
                'title': newTask,
                'description': '', // optional, can extend AddTaskPage to accept description
                'completed': false,
                'createdAt': DateTime.now(),
                'createdBy': 'user',
              });
            });
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
}

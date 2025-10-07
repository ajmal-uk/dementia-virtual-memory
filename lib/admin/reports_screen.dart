import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'caretaker/caretaker_detail.dart';
import 'users/user_detail.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedTab = 'Unseen';
  String _search = '';
  String _selectedRole = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  Stream<QuerySnapshot> _getReportsStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> _markAsSeen(String id) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(id)
        .update({'seen': true});
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate());
  }

  void _navigateToDetail(String id, String role) {
    if (role == 'caretaker') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CaretakerDetailScreen(caretakerId: id)),
      );
    } else if (role == 'user') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => UserDetailScreen(userId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Unseen'),
                      selected: _selectedTab == 'Unseen',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTab = 'Unseen');
                        }
                      },
                      backgroundColor: Colors.red.withAlpha(51),
                      selectedColor: Colors.red,
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Seen'),
                      selected: _selectedTab == 'Seen',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTab = 'Seen');
                        }
                      },
                      backgroundColor: Colors.green.withAlpha(51),
                      selectedColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _search = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedRole,
                        items: ['All', 'user', 'caretaker'].map((role) {
                          return DropdownMenuItem(value: role, child: Text(role.capitalize()));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedRole = value);
                          }
                        },
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDateRange),
                  ],
                ),
              ],
            ),
          ),
      
          // Reports list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
      
                final docs = snapshot.data?.docs ?? [];
      
                // Filter in code based on 'seen' status
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final seen = data['seen'] as bool? ?? false;
                  final roleMatch = _selectedRole == 'All' || data['sender_role'] == _selectedRole.toLowerCase();
                  final searchMatch = ((data['title'] as String?)?.toLowerCase() ?? '').contains(_search) ||
                      ((data['description'] as String?)?.toLowerCase() ?? '').contains(_search);
                  bool dateMatch = true;
                  if (_startDate != null && _endDate != null) {
                    final ts = data['created_at'] as Timestamp;
                    final dt = ts.toDate();
                    dateMatch = dt.isAfter(_startDate!) && dt.isBefore(_endDate!.add(const Duration(days: 1)));
                  }
                  return ((_selectedTab == 'Unseen') ? !seen : seen) && roleMatch && searchMatch && dateMatch;
                }).toList();
      
                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No reports'));
                }
      
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
      
                    final reportedUid = data['reported_uid'] as String?;
                    final reportedRole = data['reported_role'] as String?;
      
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        leading: const Icon(Icons.report_problem, color: Colors.red),
                        title: Text(
                          data['title'] ?? 'No title',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'From: ${data['sender_role'].toUpperCase()} • ${_formatDate(data['created_at'])}',
                          style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (reportedUid != null && reportedRole != null && reportedRole != 'app') ...[
                                  GestureDetector(
                                    onTap: () => _navigateToDetail(reportedUid, reportedRole),
                                    child: Text(
                                      'Reported: ${reportedRole.capitalize()} (ID: $reportedUid)',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ] else ...[
                                  const Text(
                                    'Reported: App/General Issue',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  data['description'] ?? 'No description',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _markAsSeen(doc.id),
                                  child: const Text('Mark as Seen'),
                                ),
                              ],
                            ),
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
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
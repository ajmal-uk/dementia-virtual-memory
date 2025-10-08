import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final String _chatStorageKey = 'dementia_ai_chat_history';
  final List<String> _userInputHistory = [];
  final _firestore = FirebaseFirestore.instance;
  final _gemini = Gemini.instance;
  late SharedPreferences _prefs;

  List<Map<String, String>> _chatHistory = [];
  Map<String, dynamic>? _userData;
  int _remainingTasks = 0;
  int _completedTasks = 0;
  String _systemPrompt = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeStorage();
    _fetchUserData();
  }

  Future<void> _initializeStorage() async {
    _prefs = await SharedPreferences.getInstance();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final String? chatHistoryJson = _prefs.getString(_chatStorageKey);
      if (chatHistoryJson != null) {
        final List<dynamic> decodedList = json.decode(chatHistoryJson);
        if (mounted) {
          setState(() {
            _chatHistory = decodedList
                .map((item) => Map<String, String>.from(item))
                .toList();
          });
        }
      }
    } catch (e) {
      log('Error loading chat history: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final String chatHistoryJson = json.encode(_chatHistory);
      await _prefs.setString(_chatStorageKey, chatHistoryJson);
    } catch (e) {
      log('Error saving chat history: $e');
    }
  }

  void _addMessageToHistory(Map<String, String> message) {
    if (message['role'] != 'error') {
      if (mounted) {
        setState(() {
          _chatHistory.add(message);
        });
      }
      _saveChatHistory();
    } else {
      if (mounted) {
        setState(() {
          _chatHistory.add(message);
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _chatHistory.removeWhere((msg) =>
                  msg['role'] == 'error' &&
                  msg['message'] == message['message']);
            });
          }
        });
      }
    }
  }

  Future<void> _fetchUserData() async {
  try {
    if (mounted) setState(() => _isLoading = true);

    final uid = currentUserId;

    final userDoc = await _firestore.collection('user').doc(uid).get();
    if (userDoc.exists && mounted) {
      setState(() {
        _userData = userDoc.data();
      });
    }

    final today = DateTime.now();
    final todayStart = Timestamp.fromDate(
      DateTime(today.year, today.month, today.day),
    );
    final todayEnd = Timestamp.fromDate(
      DateTime(today.year, today.month, today.day, 23, 59, 59),
    );

    final tasksSnap = await _firestore
        .collection('user')
        .doc(uid)
        .collection('to_dos')
        .where('dueDate', isGreaterThanOrEqualTo: todayStart)
        .where('dueDate', isLessThanOrEqualTo: todayEnd)
        .get();

    final incompleteTasks = tasksSnap.docs
        .where((doc) => doc.data()['completed'] == false)
        .map((doc) {
      final data = doc.data();
      final dueTime = data['dueDate'] != null
          ? DateFormat('hh:mm a').format((data['dueDate'] as Timestamp).toDate())
          : 'Unknown time';
      return '- ${data['task']} (Due: $dueTime)';
    }).toList();

    if (mounted) {
      setState(() {
        _remainingTasks = incompleteTasks.length;
        _completedTasks = tasksSnap.docs.length - incompleteTasks.length;

        _systemPrompt = '''
You are a compassionate AI assistant named "Dementia Helper" for a person with dementia.
- Provide gentle reminders about tasks.
- Remind about incomplete tasks with names and due times.
- Offer emotional support and guidance.
- Keep responses concise, calm, and positive.

User Info:
- Name: ${_userData?['fullName'] ?? 'User'}
- Age: ${_calculateAge(_userData?['dob']) ?? 'Unknown'}
- Today's date: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}

Today's incomplete tasks:
${incompleteTasks.isEmpty ? 'No pending tasks' : incompleteTasks.join('\n')}

Summary:
- Remaining tasks: $_remainingTasks
- Completed tasks: $_completedTasks

Always start conversations with a warm greeting and address the user by name if important. If the user mentions tasks, reference the summary above. Encourage completion of remaining tasks gently. If asked about past events, suggest checking the diary. Never overwhelm with too much information.
''';

        if (_chatHistory.isEmpty) {
          _addMessageToHistory({
            'role': 'model',
            'message':
                'Hello ${_userData?['fullName'] ?? 'there'}! You have $_remainingTasks tasks left for today. I\'m your Dementia Helper. How can I assist you?',
          });
        }
      });
    }
  } catch (e) {
    log('Error fetching user data: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


  int? _calculateAge(Timestamp? dob) {
    if (dob == null) return null;
    final birthDate = dob.toDate();
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> clearChatHistory() async {
    try {
      await _prefs.remove(_chatStorageKey);
      if (mounted) {
        setState(() {
          _chatHistory = [];
          _addMessageToHistory({
            'role': 'model',
            'message':
                'Hello ${_userData?['fullName'] ?? 'there'}! I\'m your Dementia Helper. How can I assist you today? You have $_remainingTasks tasks left for today.',
          });
        });
      }
    } catch (e) {
      log('Error clearing chat history: $e');
    }
  }

  Future<void> _showClearChatDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Clear Chat History'),
          content: const Text(
            'Are you sure you want to clear all chat history? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                clearChatHistory();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat history cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    _userInputHistory.add(userMessage);
    if (_userInputHistory.length > 5) {
      _userInputHistory.removeAt(0);
    }

    _addMessageToHistory({'role': 'user', 'message': userMessage});

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final conversation = [
        Content(parts: [Part.text(_systemPrompt)], role: 'user'),
        ..._chatHistory.map(
          (msg) => Content(
            parts: [Part.text(msg['message']!)],
            role: msg['role'],
          ),
        ),
        Content(parts: [Part.text(userMessage)], role: 'user'),
      ];
      final response = await _gemini.chat(conversation);
      if (mounted) {
        setState(() {
          _addMessageToHistory({
            'role': 'model',
            'message': response?.output ?? 'No response received',
          });
        });
      }
    } catch (e) {
      log('Error in chat: $e');
      if (mounted) {
        setState(() {
          _addMessageToHistory({
            'role': 'error',
            'message':
                'Response not loading. Please try again or check your internet connection.',
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildMessageBubble(String message, String role,
      {bool isLoading = false}) {
    bool isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 18.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20.0),
            topRight: const Radius.circular(20.0),
            bottomLeft: isUser ? const Radius.circular(20.0) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 4.0,
            ),
          ],
        ),
        child: isLoading
            ? const LoadingAnimation()
            : Text(
                message,
                style: TextStyle(
                  fontSize: 16.0,
                  color: isUser ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      itemCount: _chatHistory.length + (_isLoading ? 1 : 0),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemBuilder: (context, index) {
        if (index == _chatHistory.length && _isLoading) {
          return _buildMessageBubble('', 'model', isLoading: true);
        }
        final message = _chatHistory[index];
        return _buildMessageBubble(message['message']!, message['role']!)
            .animate()
            .fadeIn(duration: 300.ms)
            .slideX(begin: message['role'] == 'user' ? 0.2 : -0.2);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage('assets/aiIcon.png'),
              backgroundColor: Colors.blueAccent,
              radius: 30,
            ),
            const SizedBox(width: 10),
            const Text(
              'Dementia Helper',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          if (_chatHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _showClearChatDialog,
              tooltip: 'Clear chat history',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading && _chatHistory.isEmpty
                  ? const Center(child: LoadingAnimation())
                  : _chatHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'Start a conversation with Dementia Helper',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        )
                      : _buildChatList(),
            ),
            const Divider(height: 1),
            Container(
              color: Colors.grey[200],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(
                                color: Colors.black54, fontSize: 16),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 5,
                          onSubmitted: (_) {
                            final message = _controller.text;
                            _controller.clear();
                            _sendMessage(message);
                          },
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () {
                          final message = _controller.text;
                          _controller.clear();
                          _sendMessage(message);
                        },
                        splashColor: Colors.blueAccent.withOpacity(0.3),
                        splashRadius: 25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
      ),
    );
  }
}
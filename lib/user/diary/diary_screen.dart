// lib/user/diary/diary_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _diaries = [];
  bool _isLoading = true;
  bool _hasError = false;
  DateTime _currentDate = DateTime.now();
  bool _hasToday = false;
  final int _charLimit = 2000;
  Timer? _debounce;
  late TextEditingController _todayController;
  bool _showedLimitToast = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _todayController = TextEditingController();
    _todayController.addListener(() {
      setState(() {});
    });
    _pageController = PageController();
    _loadDiaries();
  }

  Future<void> _loadDiaries() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final snap = await _firestore
            .collection('user')
            .doc(uid)
            .collection('diary')
            .orderBy('createdAt', descending: true)
            .get();
        if (mounted) {
          // Reverse to have oldest first, newest last
          _diaries = snap.docs.reversed.toList();
          _currentDate = DateTime.now();
          final todayStr = DateFormat('yyyy-MM-dd').format(_currentDate);
          _hasToday = _diaries.any((doc) => doc.id == todayStr);
          String todayContent = '';
          if (_hasToday) {
            final todayDoc = _diaries.firstWhere((doc) => doc.id == todayStr);
            todayContent = todayDoc['content'] ?? '';
          }
          _todayController.text = todayContent;
          _showedLimitToast = false;
          _isLoading = false;
          // Jump to last page (newest)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(_diaries.length + (_hasToday ? 0 : 1) - 1);
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print('Error loading diaries: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _saveContent(String dateStr, String content) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('user')
          .doc(uid)
          .collection('diary')
          .doc(dateStr)
          .set({
        'content': content,
        'updatedAt': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(), // For new entries
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Error saving diary: $e');
      }
    }
  }

  Widget _buildPage(DateTime date, String content, {bool editable = false}) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final controller = editable ? _todayController : TextEditingController(text: content);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(5, 5), // Shadow for book page effect
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM dd, yyyy').format(date),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: editable
                ? TextField(
                    controller: controller,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Write your diary here...',
                      border: InputBorder.none,
                      counterText: '${_todayController.text.length}/$_charLimit',
                      counterStyle: TextStyle(color: _todayController.text.length == _charLimit ? Colors.red : Colors.grey),
                    ),
                    onChanged: (text) {
                      _debounce?.cancel();
                      if (text.length > _charLimit) {
                        _todayController.text = text.substring(0, _charLimit);
                        _todayController.selection = TextSelection.collapsed(offset: _charLimit);
                        if (!_showedLimitToast) {
                          Fluttertoast.showToast(msg: 'Try to compress the content in the diary');
                          _showedLimitToast = true;
                        }
                      } else {
                        if (text.length < _charLimit) _showedLimitToast = false;
                      }
                      _debounce = Timer(const Duration(milliseconds: 500), () => _saveContent(dateStr, _todayController.text));
                    },
                  )
                : Text(
                    content.isEmpty ? 'No content' : content,
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    }

    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading diary', style: TextStyle(fontSize: 18, color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDiaries,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final itemCount = _diaries.length + (_hasToday ? 0 : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Diary'),
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
        child: itemCount == 0
            ? const Center(
                child: Text(
                  'No diaries yet. Start writing today!',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDiaries,
                color: Colors.blueAccent,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index == itemCount - 1 && !_hasToday) {
                      // Blank editable page for today (at the end)
                      return Transform(
                        transform: Matrix4.identity()..setEntry(3, 2, 0.001), // Subtle 3D tilt for flip effect
                        child: _buildPage(_currentDate, '', editable: true),
                      );
                    }

                    final doc = _diaries[index];
                    final dateStr = doc.id;
                    final date = DateTime.parse(dateStr);
                    final content = doc['content'] as String? ?? '';
                    final isToday = dateStr == DateFormat('yyyy-MM-dd').format(_currentDate);

                    return Transform(
                      transform: Matrix4.identity()..setEntry(3, 2, 0.001), // Subtle 3D tilt for flip effect
                      child: _buildPage(date, content, editable: isToday),
                    );
                  },
                  physics: const BouncingScrollPhysics(), // For book-like bounce
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _todayController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
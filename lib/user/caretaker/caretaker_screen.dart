// lib/user/caretaker/caretaker_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/notification_helper.dart';

class CaretakerScreen extends StatefulWidget {
  const CaretakerScreen({super.key});

  @override
  State<CaretakerScreen> createState() => _CaretakerScreenState();
}

class _CaretakerScreenState extends State<CaretakerScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String? _currentConnectionId;
  Map<String, dynamic>? _connectedCaretaker;
  List<QueryDocumentSnapshot> _availableCaretakers = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final userDoc = await _firestore.collection('user').doc(uid).get();
        if (!userDoc.exists) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
          return;
        }
        
        _currentConnectionId = userDoc.data()?['currentConnectionId'];

        if (_currentConnectionId != null) {
          final connectionDoc = await _firestore
              .collection('connections')
              .doc(_currentConnectionId)
              .get();
          if (connectionDoc.exists) {
            final status = connectionDoc.data()?['status'];
            if (status == 'unbind_requested') {
              // Show dialog for unbind request
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Unbind Request Pending'),
                    content: const Text(
                      'An unbind request is pending confirmation from the caretaker.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                setState(() {
                  _connectedCaretaker = null;
                  _isLoading = false;
                });
              }
            } else {
              final caretakerUid = connectionDoc.data()?['caretaker_uid'];
              if (caretakerUid != null) {
                final caretakerDoc = await _firestore
                    .collection('caretaker')
                    .doc(caretakerUid)
                    .get();
                if (mounted) {
                  setState(() {
                    _connectedCaretaker = caretakerDoc.data();
                    _isLoading = false;
                  });
                }
              } else {
                if (mounted) {
                  setState(() {
                    _connectedCaretaker = null;
                    _isLoading = false;
                  });
                }
              }
            }
          } else {
            if (mounted) {
              setState(() {
                _connectedCaretaker = null;
                _isLoading = false;
              });
            }
          }
        } else {
          final query = await _firestore
              .collection('caretaker')
              .where('isApprove', isEqualTo: true)
              .where('isRemove', isEqualTo: false)
              .where('currentConnectionId', isNull: true)
              .get();
          if (mounted) {
            setState(() {
              _availableCaretakers = query.docs;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _sendRequest(String caretakerUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        // Check if there's already a pending request
        final existingRequests = await _firestore
            .collection('connections')
            .where('user_uid', isEqualTo: uid)
            .where('caretaker_uid', isEqualTo: caretakerUid)
            .where('status', isEqualTo: 'pending')
            .get();
        
        if (existingRequests.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You already have a pending request to this caretaker')),
            );
          }
          return;
        }

        await _firestore.collection('connections').add({
          'user_uid': uid,
          'caretaker_uid': caretakerUid,
          'status': 'pending',
          'timestamp': Timestamp.now(),
          'confirmedBy': null,
        });

        // Notify caretaker
        final caretakerDoc = await _firestore
            .collection('caretaker')
            .doc(caretakerUid)
            .get();
        final playerIds = List<String>.from(
          caretakerDoc.data()?['playerIds'] ?? [],
        );
        await sendNotification(playerIds, 'New connection request from user');

        // Add to notifications subcollection
        await _firestore
            .collection('caretaker')
            .doc(caretakerUid)
            .collection('notifications')
            .add({
              'type': 'connection_request',
              'message': 'Connection request from user $uid',
              'from': uid,
              'to': caretakerUid,
              'createdAt': Timestamp.now(),
              'isRead': false,
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent!')));
          _loadData();
        }
      } catch (e) {
        print('Error sending request: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _requestUnbind() async {
    if (!mounted) return;

    if (_currentConnectionId != null) {
      try {
        await _firestore
            .collection('connections')
            .doc(_currentConnectionId)
            .update({
              'status': 'unbind_requested',
              'confirmedBy': _auth.currentUser?.uid,
            });

        // Notify caretaker
        final connectionDoc = await _firestore
            .collection('connections')
            .doc(_currentConnectionId)
            .get();
        final caretakerUid = connectionDoc.data()?['caretaker_uid'];
        if (caretakerUid != null) {
          final caretakerDoc = await _firestore
              .collection('caretaker')
              .doc(caretakerUid)
              .get();
          final playerIds = List<String>.from(
            caretakerDoc.data()?['playerIds'] ?? [],
          );
          await sendNotification(playerIds, 'Unbind request from user');

          await _firestore
              .collection('caretaker')
              .doc(caretakerUid)
              .collection('notifications')
              .add({
                'type': 'unbind_request',
                'message': 'Unbind request from user',
                'from': _auth.currentUser?.uid,
                'to': caretakerUid,
                'createdAt': Timestamp.now(),
                'isRead': false,
              });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unbind request sent')));
          _loadData();
        }
      } catch (e) {
        print('Error requesting unbind: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caretaker'), backgroundColor: Colors.blueAccent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading caretaker data',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_connectedCaretaker != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connected Caretaker'), backgroundColor: Colors.blueAccent, elevation: 0),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(
                      _connectedCaretaker!['profileImageUrl'] ?? '',
                    ),
                    onBackgroundImageError: (_, __) => const Icon(Icons.person, size: 60, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _connectedCaretaker!['fullName'] ?? 'Unnamed',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  Text(
                    'Experience: ${_connectedCaretaker!['experienceYears'] ?? 0} years',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _requestUnbind,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Request Unbind', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green, size: 32),
                    onPressed: () async {
                      final phone = _connectedCaretaker!['phoneNo'];
                      if (phone != null && phone.isNotEmpty) {
                        final url = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not launch phone app')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Available Caretakers'), backgroundColor: Colors.blueAccent, elevation: 0),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
            ),
          ),
          child: _availableCaretakers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No available caretakers at the moment',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: Colors.blueAccent,
                  child: ListView.builder(
                    itemCount: _availableCaretakers.length,
                    itemBuilder: (context, index) {
                      final caretaker = _availableCaretakers[index].data() as Map<String, dynamic>;
                      final caretakerUid = _availableCaretakers[index].id;
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            backgroundImage: NetworkImage(
                              caretaker['profileImageUrl'] ?? '',
                            ),
                            onBackgroundImageError: (_, __) => const Icon(Icons.person, color: Colors.blueAccent),
                          ),
                          title: Text(caretaker['fullName'] ?? 'Unnamed'),
                          subtitle: Text(
                            'Experience: ${caretaker['experienceYears'] ?? 0} years',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.phone, color: Colors.green),
                                onPressed: () async {
                                  final phone = caretaker['phoneNo'];
                                  if (phone != null && phone.isNotEmpty) {
                                    final url = Uri.parse('tel:$phone');
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                    } else if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not launch phone app')),
                                      );
                                    }
                                  }
                                },
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                child: const Text('Send Request', style: TextStyle(color: Colors.white)),
                                onPressed: () => _sendRequest(caretakerUid),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      );
    }
  }
}
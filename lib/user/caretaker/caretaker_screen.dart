// lib/user/caretaker/caretaker_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/notification_helper.dart';
import 'caretaker_detail_screen.dart';
import 'caretaker_requests_screen.dart';
import 'connection_history_screen.dart';

final logger = Logger();

class CaretakerScreen extends StatefulWidget {
  const CaretakerScreen({super.key});

  @override
  State<CaretakerScreen> createState() => _CaretakerScreenState();
}

class _CaretakerScreenState extends State<CaretakerScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String? _currentConnectionId;
  Map<String, dynamic>? _connectedCaretaker;
  List<QueryDocumentSnapshot> _availableCaretakers = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isConnected = false;
  String _search = '';
  String? _unbindStatus; // To track unbind request status

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _search = _searchController.text.toLowerCase()));
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _unbindStatus = null;
    });

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
        _isConnected = userDoc.data()?['isConnected'] ?? false;

        if (_isConnected && _currentConnectionId != null) {
          final connectionDoc = await _firestore
              .collection('connections')
              .doc(_currentConnectionId)
              .get();
          if (connectionDoc.exists) {
            final status = connectionDoc.data()?['status'];
            final requestedBy = connectionDoc.data()?['requestedBy'];
            
            if (status == 'unbind_requested') {
              if (mounted) {
                setState(() {
                  _unbindStatus = (requestedBy == uid) ? 'pending' : 'requested';
                  _isLoading = false;
                });
              }
              return;
            } else if (status == 'unbound') {
              if (mounted) {
                setState(() {
                  _connectedCaretaker = null;
                  _isConnected = false;
                  _isLoading = false;
                });
                await _firestore.collection('user').doc(uid).update({
                  'isConnected': false,
                  'currentConnectionId': null,
                });
              }
              return;
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
          // Load available caretakers without orderBy to avoid index requirement
          final query = await _firestore
              .collection('caretaker')
              .where('isRemove', isEqualTo: false)
              .where('currentConnectionId', isNull: true)
              .get();

          var docs = query.docs;

          // Filter out the currently connected caretaker
          if (_currentConnectionId != null) {
            docs = docs.where((doc) {
              final data = doc.data();
              return data['uid'] != _connectedCaretaker?['uid'];
            }).toList();
          }

          // Sort by fullName client-side
          docs.sort((a, b) {
            final aName = (a.data()['fullName'] as String?) ?? '';
            final bName = (b.data()['fullName'] as String?) ?? '';
            return aName.compareTo(bName);
          });

          if (mounted) {
            setState(() {
              _availableCaretakers = docs;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      logger.e('Error loading data: $e');
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
            .where('status', whereIn: ['pending', 'accepted'])
            .get();
        
        if (existingRequests.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You already have a request or connection with this caretaker')),
            );
          }
          return;
        }

        final ref = await _firestore.collection('connections').add({
          'user_uid': uid,
          'caretaker_uid': caretakerUid,
          'status': 'pending',
          'timestamp': Timestamp.now(),
          'confirmedBy': null,
          'requestedBy': uid,
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

        // Add to notifications subcollection with connectionId
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
              'connectionId': ref.id,  // ADDED
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent!')));
          _loadData();
        }
      } catch (e) {
        logger.e('Error sending request: $e');
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
              'requestedBy': _auth.currentUser?.uid,
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
                'connectionId': _currentConnectionId,  // ADDED
              });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unbind request sent')));
          _loadData();
        }
      } catch (e) {
        logger.e('Error requesting unbind: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _confirmUnbind() async {
    if (!mounted) return;

    if (_currentConnectionId != null) {
      try {
        await _firestore
            .collection('connections')
            .doc(_currentConnectionId)
            .update({
              'status': 'unbound',
            });

        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          await _firestore.collection('user').doc(uid).update({
            'isConnected': false,
            'currentConnectionId': null,
          });
        }

        final connectionDoc = await _firestore
            .collection('connections')
            .doc(_currentConnectionId)
            .get();
        final caretakerUid = connectionDoc.data()?['caretaker_uid'];
        if (caretakerUid != null) {
          await _firestore.collection('caretaker').doc(caretakerUid).update({
            'isConnected': false,
            'currentConnectionId': null,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unbound successfully')));
          _loadData();
        }
      } catch (e) {
        logger.e('Error confirming unbind: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _markAsViewed(String caretakerUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('user').doc(uid).update({
      'lastViewedCaretakers': FieldValue.arrayUnion([
        {'uid': caretakerUid, 'timestamp': Timestamp.now()}
      ]),
    });
  }

  Widget _buildNurseBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.local_hospital,
          size: 16,
          color: Colors.white,
        ),
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

    if (_isConnected && _connectedCaretaker != null) {
      bool showUnbindConfirm = _unbindStatus == 'requested';
      bool showUnbindPending = _unbindStatus == 'pending';

      return Scaffold(
        appBar: AppBar(
          title: const Text('Connected Caretaker'),
          backgroundColor: Colors.blueAccent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.pending_actions),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CaretakerRequestsScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConnectionHistoryScreen()),
              ),
            ),
          ],
        ),
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
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: NetworkImage(
                          _connectedCaretaker!['profileImageUrl'] ?? '',
                        ),
                        child: const Icon(Icons.person, size: 60, color: Colors.blueAccent),
                      ),
                      if (_connectedCaretaker!['caregiverType'] == 'nurse') _buildNurseBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _connectedCaretaker!['fullName'] ?? 'Unnamed',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  Text(
                    '@${_connectedCaretaker!['username'] ?? ''}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    'Experience: ${_connectedCaretaker!['experienceYears'] ?? 0} years',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (showUnbindPending)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Unbind request pending confirmation from caretaker',
                        style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
                      ),
                    ),
                  if (showUnbindConfirm)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Caretaker requested to unbind',
                        style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (!showUnbindPending && !showUnbindConfirm)
                    ElevatedButton(
                      onPressed: _requestUnbind,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Request Unbind', style: TextStyle(color: Colors.white)),
                    ),
                  if (showUnbindConfirm)
                    ElevatedButton(
                      onPressed: _confirmUnbind,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Confirm Unbind', style: TextStyle(color: Colors.white)),
                    ),
                  const SizedBox(height: 10),
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green, size: 32),
                    onPressed: () async {
                      final phone = _connectedCaretaker!['phoneNo'];
                      if (phone != null && phone.isNotEmpty) {
                        final url = Uri.parse('tel:$phone');
                        final can = await canLaunchUrl(url);
                        if (can) {
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
      final filteredCaretakers = _availableCaretakers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final username = (data['username'] as String?)?.toLowerCase() ?? '';
        return username.contains(_search);
      }).toList();

      return Scaffold(
        appBar: AppBar(
          title: const Text('Available Caretakers'),
          backgroundColor: Colors.blueAccent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConnectionHistoryScreen()),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by username...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  ),
                ),
              ),
              Expanded(
                child: filteredCaretakers.isEmpty
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
                          itemCount: filteredCaretakers.length,
                          itemBuilder: (context, index) {
                            final doc = filteredCaretakers[index];
                            final caretaker = doc.data() as Map<String, dynamic>;
                            final caretakerUid = doc.id;
                            final isNurse = caretaker['caregiverType'] == 'nurse';
                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                onTap: () async {
                                  _markAsViewed(caretakerUid);
                                  if (mounted) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CaretakerDetailScreen(
                                          caretakerUid: caretakerUid,
                                          caretakerData: caretaker,
                                          onConnect: () => _sendRequest(caretakerUid),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: NetworkImage(
                                        caretaker['profileImageUrl'] ?? '',
                                      ),
                                      child: const Icon(Icons.person, color: Colors.blueAccent),
                                    ),
                                    if (isNurse) _buildNurseBadge(),
                                  ],
                                ),
                                title: Text('${caretaker['fullName'] ?? 'Unnamed'} (@${caretaker['username'] ?? ''})'),
                                subtitle: Text(
                                  'Experience: ${caretaker['experienceYears'] ?? 0} years | ${caretaker['city'] ?? ''}',
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
                                          final can = await canLaunchUrl(url);
                                          if (can) {
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
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
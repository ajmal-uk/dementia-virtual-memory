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
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _search = _searchController.text.toLowerCase()));
  }

  // REAL-TIME STREAMS

  // Stream for user's connection status
  Stream<DocumentSnapshot> _getUserStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();
    return _firestore.collection('user').doc(uid).snapshots();
  }

  // Stream for available caretakers
  Stream<QuerySnapshot> _getAvailableCaretakersStream() {
    return _firestore
        .collection('caretaker')
        .where('isBanned', isEqualTo: false)
        .where('isConnected', isEqualTo: false)
        .snapshots();
  }

  // Stream for connection details (if connected)
  Stream<DocumentSnapshot?> _getConnectionStream(String? connectionId) {
    if (connectionId == null) return Stream.value(null);
    return _firestore.collection('connections').doc(connectionId).snapshots();
  }

  Stream<DocumentSnapshot?> _getConnectedCaretakerStream(String? caretakerUid) {
    if (caretakerUid == null) return Stream.value(null);
    return _firestore.collection('caretaker').doc(caretakerUid).snapshots();
  }

  // ACTIONS

  Future<void> _sendRequest(String caretakerUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

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

      // Check if caretaker is already connected to someone else
      final caretakerDoc = await _firestore.collection('caretaker').doc(caretakerUid).get();
      final isCaretakerConnected = caretakerDoc.data()?['isConnected'] == true;

      if (isCaretakerConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This caretaker is already connected to another user')),
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
            'message': 'Connection request from user',
            'from': uid,
            'to': caretakerUid,
            'createdAt': Timestamp.now(),
            'isRead': false,
            'connectionId': ref.id,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent!')));
      }
    } catch (e) {
      logger.e('Error sending request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _requestUnbind(String connectionId, String caretakerUid) async {
    if (!mounted) return;

    try {
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .update({
            'status': 'unbind_requested',
            'requestedBy': _auth.currentUser?.uid,
          });

      // Notify caretaker
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
            'connectionId': connectionId,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unbind request sent')));
      }
    } catch (e) {
      logger.e('Error requesting unbind: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmUnbind(String connectionId, String caretakerUid) async {
    if (!mounted) return;

    try {
      await _firestore
          .collection('connections')
          .doc(connectionId)
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

      await _firestore.collection('caretaker').doc(caretakerUid).update({
        'isConnected': false,
        'currentConnectionId': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unbound successfully')));
      }
    } catch (e) {
      logger.e('Error confirming unbind: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cancelUnbindRequest(String connectionId) async {
    if (!mounted) return;

    try {
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .update({
            'status': 'accepted',
            'requestedBy': null,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unbind request cancelled')));
      }
    } catch (e) {
      logger.e('Error cancelling unbind request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caretakers'),
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
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _getUserStream(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (userSnapshot.hasError) {
              return Center(child: Text('Error: ${userSnapshot.error}'));
            }

            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final isConnected = userData?['isConnected'] == true;
            final currentConnectionId = userData?['currentConnectionId'] as String?;

            if (isConnected && currentConnectionId != null) {
              return _buildConnectedState(currentConnectionId);
            } else {
              return _buildAvailableCaretakers();
            }
          },
        ),
      ),
    );
  }

  Widget _buildConnectedState(String connectionId) {
    return StreamBuilder<DocumentSnapshot?>(
      stream: _getConnectionStream(connectionId),
      builder: (context, connectionSnapshot) {
        if (connectionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (connectionSnapshot.hasError || connectionSnapshot.data == null) {
          return Center(child: Text('Error loading connection: ${connectionSnapshot.error}'));
        }

        final connectionData = connectionSnapshot.data?.data() as Map<String, dynamic>?;
        final status = connectionData?['status'] as String?;
        final requestedBy = connectionData?['requestedBy'] as String?;
        final caretakerUid = connectionData?['caretaker_uid'] as String?;

        if (caretakerUid == null) {
          return const Center(child: Text('Error: Invalid connection'));
        }

        // Handle different connection statuses
        if (status == 'unbind_requested') {
          final isRequestedByMe = requestedBy == _auth.currentUser?.uid;
          if (isRequestedByMe) {
            return _buildUnbindPendingState(caretakerUid, connectionId);
          } else {
            return _buildUnbindRequestedState(caretakerUid, connectionId);
          }
        } else if (status == 'unbound') {
          // Auto-refresh to available caretakers
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {});
          });
          return const Center(child: Text('Connection unbound'));
        }

        // Normal connected state
        return StreamBuilder<DocumentSnapshot?>(
          stream: _getConnectedCaretakerStream(caretakerUid),
          builder: (context, caretakerSnapshot) {
            if (caretakerSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (caretakerSnapshot.hasError || caretakerSnapshot.data == null) {
              return Center(child: Text('Error loading caretaker: ${caretakerSnapshot.error}'));
            }

            final caretakerData = caretakerSnapshot.data?.data() as Map<String, dynamic>?;
            return _buildConnectedCaretakerUI(caretakerData!, caretakerUid, connectionId);
          },
        );
      },
    );
  }

  Widget _buildConnectedCaretakerUI(Map<String, dynamic> caretakerData, String caretakerUid, String connectionId) {
    final isNurse = caretakerData['caregiverType'] == 'nurse';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with avatar - Improved with shadow and better padding
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: (caretakerData['profileImageUrl'] != null &&
                                caretakerData['profileImageUrl'].toString().isNotEmpty)
                            ? NetworkImage(caretakerData['profileImageUrl'])
                            : null,
                        child: (caretakerData['profileImageUrl'] == null ||
                                caretakerData['profileImageUrl'].toString().isEmpty)
                            ? const Icon(Icons.person, size: 60, color: Colors.blueAccent)
                            : null,
                      ),
                      if (isNurse) _buildNurseBadge(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  caretakerData['fullName'] ?? 'Unnamed',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '@${caretakerData['username'] ?? ''}',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Details Card - Improved elevation and padding
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.info_outline, 'Bio', caretakerData['bio'] ?? ''),
                    _buildInfoRow(Icons.location_city, 'City', caretakerData['city'] ?? ''),
                    _buildInfoRow(Icons.phone, 'Phone', caretakerData['phoneNo'] ?? ''),
                    if (isNurse) ...[
                      _buildInfoRow(Icons.work_history, 'Experience Years', '${caretakerData['experienceYears'] ?? 0} years'),
                      _buildInfoRow(Icons.description, 'Experience Bio', caretakerData['experienceBio'] ?? ''),
                      _buildInfoRow(Icons.school, 'Nursing Qualification', caretakerData['graduationOnNursing'] ?? ''),
                      if (caretakerData['graduationCertificateUrl']?.isNotEmpty ?? false)
                        _buildInfoRow(Icons.picture_as_pdf, 'Certificate', caretakerData['graduationCertificateUrl']),
                    ] else
                      _buildInfoRow(Icons.family_restroom, 'Relation', caretakerData['relation'] ?? ''),
                  ],
                ),
              ),
            ),
          ),

          // Actions - Improved button styles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final phone = caretakerData['phoneNo'];
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
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Caretaker'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _requestUnbind(connectionId, caretakerUid),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Request Unbind'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (label == 'Certificate')
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(value);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open certificate')),
                        );
                      }
                    },
                    child: const Text(
                      'View Certificate',
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  )
                else
                  Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnbindPendingState(String caretakerUid, String connectionId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pending, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Unbind Request Pending',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waiting for caretaker to confirm the unbind request',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot?>(
              stream: _getConnectedCaretakerStream(caretakerUid),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  return Text(
                    'Caretaker: ${data?['fullName'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 16),
                  );
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _cancelUnbindRequest(connectionId),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Cancel Request', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnbindRequestedState(String caretakerUid, String connectionId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Unbind Request Received',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              'Caretaker has requested to unbind the connection',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot?>(
              stream: _getConnectedCaretakerStream(caretakerUid),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  return Text(
                    'Caretaker: ${data?['fullName'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 16),
                  );
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _confirmUnbind(connectionId, caretakerUid),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm Unbind', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableCaretakers() {
    return Column(
      children: [
        // Search Field - Improved with clear button
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
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Available Caretakers List - Improved with cards and margins
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getAvailableCaretakersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];

              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final username = (data['username'] as String?)?.toLowerCase() ?? '';
                return username.contains(_search);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(
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
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                color: Colors.blueAccent,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final caretaker = doc.data() as Map<String, dynamic>;
                    final caretakerUid = doc.id;
                    final isNurse = caretaker['caregiverType'] == 'nurse';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        onTap: () async {
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
                              backgroundImage: (caretaker['profileImageUrl'] != null &&
                                      caretaker['profileImageUrl'].toString().isNotEmpty)
                                  ? NetworkImage(caretaker['profileImageUrl'])
                                  : null,
                              child: (caretaker['profileImageUrl'] == null ||
                                      caretaker['profileImageUrl'].toString().isEmpty)
                                  ? const Icon(Icons.person, color: Colors.blueAccent)
                                  : null,
                            ),
                            if (isNurse) _buildNurseBadge(),
                          ],
                        ),
                        title: Text('${caretaker['fullName'] ?? 'Unnamed'} (@${caretaker['username'] ?? ''})'),
                        subtitle: Text(
                          isNurse
                              ? 'Experience: ${caretaker['experienceYears'] ?? 0} years | ${caretaker['city'] ?? ''}'
                              : 'Relation: ${caretaker['relation'] ?? 'Unknown'} | ${caretaker['city'] ?? ''}',
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
                            IconButton(
                              icon: const Icon(Icons.person_add, color: Colors.blue),
                              onPressed: () => _sendRequest(caretakerUid),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
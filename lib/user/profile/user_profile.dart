// lib/user/profile/user_profile.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasError = false;
  int _remainingTasks = 0;
  int _completedTasks = 0;
  int _totalTasks = 0;
  List<QueryDocumentSnapshot> _albums = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        // Load user data
        final doc = await _firestore.collection('user').doc(uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _userData = doc.data();
          });
        } else {
          throw Exception('User document not found');
        }

        // Load albums
        final albumSnap = await _firestore
            .collection('user')
            .doc(uid)
            .collection('album')
            .orderBy('createdAt', descending: true)
            .get();
        if (mounted) {
          setState(() {
            _albums = albumSnap.docs;
          });
        }

        // Load today's tasks counts
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

        if (mounted) {
          final incomplete = tasksSnap.docs
              .where((doc) => doc.data()['completed'] == false)
              .length;
          final total = tasksSnap.docs.length;
          final completed = total - incomplete;

          setState(() {
            _remainingTasks = incomplete;
            _completedTasks = completed;
            _totalTasks = total;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('No user logged in');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not launch dialer for $number')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _userData?['username'] ?? "Profile",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue, // ✅ Changed from white to blue
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // ✅ Makes back icon white
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError || _userData == null
              ? const Center(
                  child: Text(
                    "Error loading profile",
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: DefaultTabController(
                    length: 2,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          /// Header with avatar + stats
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 16),
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: (_userData!['profileImageUrl'] !=
                                            null &&
                                        _userData!['profileImageUrl']
                                            .toString()
                                            .isNotEmpty)
                                    ? NetworkImage(
                                        _userData!['profileImageUrl'])
                                    : null,
                                child: (_userData!['profileImageUrl'] == null ||
                                        _userData!['profileImageUrl']
                                            .toString()
                                            .isEmpty)
                                    ? const Icon(Icons.person,
                                        size: 50, color: Colors.grey)
                                    : null,
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStat("Remaining", _remainingTasks.toString()),
                                    _buildStat("Completed", _completedTasks.toString()),
                                    _buildStat("Total", _totalTasks.toString()),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userData!['fullName'] ?? "No Name",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userData!['bio'] ?? "No bio yet",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 6),
                                if (_userData!['email'] != null)
                                  Text(
                                    _userData!['email'],
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.blueGrey),
                                  ),
                                if (_userData!['phoneNo'] != null)
                                  Text(
                                    _userData!['phoneNo'],
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.blueGrey),
                                  ),
                              ],
                            ),
                          ),


                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_userData!['dob'] != null || _userData!['gender'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1.0),
                                    child: Row(
                                      children: [
                                        if (_userData!['dob'] != null)
                                          Expanded(
                                            child: _buildInfoRow(
                                              "Birthday",
                                              DateFormat('yyyy-MM-dd')
                                                  .format(_userData!['dob'].toDate()),
                                            ),
                                          ),
                                        if (_userData!['gender'] != null)
                                          Expanded(
                                            child: _buildInfoRow("Gender", _userData!['gender']),
                                          ),
                                      ],
                                    ),
                                  ),
                                if (_userData!['locality'] != null ||
                                    _userData!['city'] != null ||
                                    _userData!['state'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1.0), 
                                    child: _buildInfoRow(
                                      "Location",
                                      [
                                        _userData!['locality'],
                                        _userData!['city'],
                                        _userData!['state']
                                      ]
                                          .where((e) => e != null && e.toString().isNotEmpty)
                                          .join(", "),
                                    ),
                                  ),
                              ],
                            ),
                          ),


                          const SizedBox(height: 20),

                          /// Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (_userData != null) {
                                        final updated = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditProfileScreen(userData: _userData ?? {}),
                                          ),
                                        );
                                        if (updated == true) {
                                          _loadUserData();
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue, // ✅ Button background color
                                      foregroundColor: Colors.white, // ✅ Text color
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text("Edit Profile"),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue, // ✅ Button background color
                                      foregroundColor: Colors.white, // ✅ Text color
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text("Settings"),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Divider(thickness: 1),
                          const SizedBox(height: 20),

                          const TabBar(
                            tabs: [
                              Tab(icon: Icon(Icons.photo_album)),
                              Tab(icon: Icon(Icons.contacts)),
                            ],
                            indicatorColor: Colors.blueAccent,
                            labelColor: Colors.blueAccent,
                            unselectedLabelColor: Colors.grey,
                          ),

                          SizedBox(
                            height: 300,
                            child: TabBarView(
                              children: [
                                _buildAlbumTab(),
                                _buildEmergencyTab(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildStat(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
      ],
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text(
            "$title: ",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumTab() {
    if (_albums.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_album_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No memories yet. Add one!',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index].data() as Map<String, dynamic>;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullImageScreen(imageUrl: album['imageUrl']),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              album['imageUrl'],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.error));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyTab() {
    final contacts = _userData!['emergencyContacts'] as List? ?? [];
    if (contacts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No emergency contacts',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index] as Map<String, dynamic>;
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.blueAccent),
            title: Text(contact['name'] ?? 'Unknown'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Relation: ${contact['relation'] ?? 'None'}'),
                Text('Phone: ${contact['number'] ?? 'None'}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () {
                final number = contact['number'] as String?;
                if (number != null && number.isNotEmpty) {
                  _callNumber(number);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class FullImageScreen extends StatelessWidget {
  final String imageUrl;
  const FullImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Image.network(imageUrl),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.close),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}
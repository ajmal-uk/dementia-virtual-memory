import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'diary_album/diary_album_screen.dart';
import 'family/family_screen.dart';
import 'home/home_screen.dart';
import 'caretaker/caretaker_screen.dart';
import 'profile/user_profile.dart';
import 'location_service.dart';

class UserBottomNav extends StatefulWidget {
  const UserBottomNav({super.key});

  @override
  State<UserBottomNav> createState() => _UserBottomNavState();
}

class _UserBottomNavState extends State<UserBottomNav> {
  int _selectedIndex = 2;
  final PatientLocationService _locationService = PatientLocationService();
  StreamSubscription<DocumentSnapshot>? _connectionSubscription;
  bool _isConnected = false;

  final List<Widget> _pages = [
    const FamilyScreen(),
    const CaretakerScreen(),
    const HomeScreen(),
    const DiaryAlbumScreen(),
    const UserProfile(),
  ];

  Future<void> _checkBanned() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('user').doc(uid).get();

    if (doc.data()?['isBanned'] == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Account Banned'),
          content: const Text('Your account has been banned.'),
          actions: [
            TextButton(
              onPressed: () async {
                await _cleanup();
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/welcome');
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    }
  }

  void _startConnectionListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _connectionSubscription = FirebaseFirestore.instance
        .collection('user')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final newConnectionStatus = data?['isConnected'] == true;

        if (newConnectionStatus != _isConnected) {
          setState(() => _isConnected = newConnectionStatus);

          if (newConnectionStatus) {
            _startLocationSharing();
          } else {
            _stopLocationSharing();
          }
        }
      }
    }, onError: (error) {
      debugPrint('Connection listener error: $error');
    });
  }

  Future<void> _startLocationSharing() async {
    try {
      await _locationService.startSharingLocation(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location sharing started')),
        );
      }
    } catch (e) {
      debugPrint('Error starting location sharing: $e');
    }
  }

  Future<void> _stopLocationSharing() async {
    try {
      await _locationService.stopSharingLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location sharing stopped')),
        );
      }
    } catch (e) {
      debugPrint('Error stopping location sharing: $e');
    }
  }

  Future<void> _cleanup() async {
    await _stopLocationSharing();
    _locationService.dispose();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  @override
  void initState() {
    super.initState();
    _checkBanned();
    _startConnectionListener();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  Widget _buildAnimatedIcon(IconData icon, int index, String label) {
    final bool isSelected = _selectedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(top: isSelected ? 2 : 8, bottom: isSelected ? 0 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.2 : 1.1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Icon(
              icon,
              color: isSelected ? Colors.blueAccent : Colors.grey[600],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: isSelected
                ? Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.group, 0, 'Family'),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.medical_services, 1, 'Care'),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.home_rounded, 2, 'Home'),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.book_outlined, 3, 'Diary'),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.person_rounded, 4, 'Profile'),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}

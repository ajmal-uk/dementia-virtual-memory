// lib/user/user_bottom_nav.dart (Updated with better location handling)
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
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const FamilyScreen(),
    const CaretakerScreen(),
    const UserProfile(),
    const DiaryAlbumScreen(),
  ];

  final PatientLocationService _locationService = PatientLocationService();
  StreamSubscription<DocumentSnapshot>? _connectionSubscription;
  bool _isConnected = false;

  Future<void> _checkBanned() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('user')
        .doc(uid)
        .get();

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
          setState(() {
            _isConnected = newConnectionStatus;
          });
          
          if (newConnectionStatus) {
            // Start location sharing when connected
            _startLocationSharing();
          } else {
            // Stop location sharing when disconnected
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start location sharing: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Family'),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'CareTaker',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Diary'),
        ],
      ),
    );
  }
}
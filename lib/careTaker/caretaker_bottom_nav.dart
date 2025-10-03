import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'user_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class CareTaker extends StatefulWidget {
  const CareTaker({super.key});

  @override
  State<CareTaker> createState() => _CareTakerState();
}

class _CareTakerState extends State<CareTaker> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    UserScreen(),
    const NotificationsScreen(), 
    const Profile(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _checkBanned() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('caretaker')
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

  @override
  void initState() {
    super.initState();
    _checkBanned();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'User'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notification',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'user.dart';
import 'profile.dart';
import 'notifications.dart';

class CareTaker extends StatefulWidget {
  const CareTaker({super.key});

  @override
  State<CareTaker> createState() => _CareTakerState();
}

class _CareTakerState extends State<CareTaker> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    User(), // From home.dart
    NotificationsScreen(), // From notifications.dart
    Profile(), // From profile.dart
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

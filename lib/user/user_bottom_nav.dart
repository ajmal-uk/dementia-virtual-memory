// lib/user/user_bottom_nav.dart
// lib/user/user_bottom_nav.dart
import 'package:flutter/material.dart';
import 'diary/diary_screen.dart';
import 'family/family_screen.dart';
import 'home/home_screen.dart';
import 'caretaker/caretaker_screen.dart';
import 'profile/user_profile.dart';

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
    const DiaryScreen(), 
  ];

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
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Diary'), // New Diary item
        ],
      ),
    );
  }
}
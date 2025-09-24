import 'package:flutter/material.dart';
import 'family/family.dart';
import 'home/home_screen.dart';

class UserBottomNav extends StatefulWidget {
  const UserBottomNav({Key? key}) : super(key: key);

  @override
  State<UserBottomNav> createState() => _UserBottomNavState();
}

class _UserBottomNavState extends State<UserBottomNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const FamilyScreen(),
    const Center(child: Text('CareTaker Screen')),
    const Center(child: Text('User Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed, // allows more than 3 items
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.group), label: 'Family'),
          BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts), label: 'CareTaker'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'users/users_screen.dart';
import 'caretaker/caretakers_screen.dart';
import 'reports_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class AdminBottomNav extends StatefulWidget {
  const AdminBottomNav({super.key});

  @override
  State<AdminBottomNav> createState() => _AdminBottomNavState();
}

class _AdminBottomNavState extends State<AdminBottomNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const UsersScreen(),
    const CaretakersScreen(),
    const ReportsScreen(),
    const AdminNotificationsScreen(),
    const AdminSettingsScreen(),
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
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Caretakers'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
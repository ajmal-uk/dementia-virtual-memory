import 'package:flutter/material.dart';

class CaretakerBottomNav extends StatefulWidget {
  const CaretakerBottomNav({Key? key}) : super(key: key);

  @override
  State<CaretakerBottomNav> createState() => _CaretakerBottomNavState();
}

class _CaretakerBottomNavState extends State<CaretakerBottomNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const Center(child: Text('Caretaker Dashboard')),
    const Center(child: Text('Caretaker Reports')),
    const Center(child: Text('Caretaker Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

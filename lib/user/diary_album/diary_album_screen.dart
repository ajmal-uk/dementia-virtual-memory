import 'package:flutter/material.dart';
import 'diary_screen.dart';
import 'album_screen.dart';

class DiaryAlbumScreen extends StatefulWidget {
  const DiaryAlbumScreen({super.key});

  @override
  State<DiaryAlbumScreen> createState() => _DiaryAlbumScreenState();
}

class _DiaryAlbumScreenState extends State<DiaryAlbumScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48), 
        child: AppBar(
          backgroundColor: Colors.blueAccent,
          automaticallyImplyLeading: false, 
          titleSpacing: 0,
          title: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Diary'),
              Tab(text: 'Album'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DiaryScreen(),
          AlbumScreen(),
        ],
      ),
    );
  }
}

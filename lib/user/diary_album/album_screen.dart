import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  List<QueryDocumentSnapshot> _albums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snap = await _firestore
          .collection('user')
          .doc(uid)
          .collection('album')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _albums = snap.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Permission permission = source == ImageSource.camera ? Permission.camera : Permission.photos;
    if (await permission.request().isGranted) {
      XFile? image = await _picker.pickImage(source: source);
      if (image != null && mounted) {
        if (source == ImageSource.camera) {
          await _showPreview(image);
        } else {
          await _showTitleDesc(image);
        }
      }
    } else {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission denied for ${source == ImageSource.camera ? 'camera' : 'photos'}')),
        );
      }
    }
  }

  Future<void> _showPreview(XFile image) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Image.file(File(image.path)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retake'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _showTitleDesc(image);
    } else if (confirmed == false && mounted) {
      _pickImage(ImageSource.camera);
    }
  }

  Future<void> _showTitleDesc(XFile image) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload')),
        ],
      ),
    );

    if (result == true && mounted) {
      if (titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title is required')),
        );
        return;
      }

      try {
        final uri = Uri.parse('https://api.cloudinary.com/v1_1/dts8hgf4f/image/upload');
        var request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = 'album_images'
          ..fields['cloud_name'] = 'dts8hgf4f';

        final file = await http.MultipartFile.fromPath('file', image.path);
        request.files.add(file);

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final imageUrl = responseData['secure_url'];

          final uid = _auth.currentUser?.uid;
          if (uid != null) {
            await _firestore.collection('user').doc(uid).collection('album').add({
              'title': titleController.text.trim(),
              'description': descController.text.trim(),
              'imageUrl': imageUrl,
              'createdAt': Timestamp.now(),
            });

            _loadAlbums();
            if(mounted){
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memory added successfully')),
              );
            }
          }
        } else {
          throw 'Upload failed: ${response.body}';
        }
      } catch (e) {
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding memory: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget content;
    if (_albums.isEmpty) {
      content = const Center(child: Text('No memories yet. Add one!'));
    } else {
      content = RefreshIndicator(
        onRefresh: _loadAlbums,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _albums.length,
          itemBuilder: (context, index) {
            final album = _albums[index].data() as Map<String, dynamic>;
            final createdAt = album['createdAt'] as Timestamp?;
            String dateStr = '';
            if (createdAt != null) {
              dateStr = DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate());
            }
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullImageScreen(imageUrl: album['imageUrl']),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          album['imageUrl'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            album['description'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Stack(
      children: [
        content,
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showAddOptions,
            child: const Icon(Icons.add),
          ),
        ),
      ],
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
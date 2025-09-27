// lib/user/family/family_scanner_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
 
class ScannerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  const ScannerScreen({super.key, required this.members});
 
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}
 
class _ScannerScreenState extends State<ScannerScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  XFile? _capturedImage;
  bool _hasCameraError = false;
 
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
 
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _hasCameraError = true;
        });
        return;
      }
      
      final firstCamera = cameras.first;
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      // Assign the future immediately
      _initializeControllerFuture = _controller.initialize();
 
      // Wait for initialization to complete
      await _initializeControllerFuture;
 
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _hasCameraError = true;
      });
    }
  }
 
  @override
  void dispose() {
    try {
      _controller.dispose();
    } catch (e) {
      print('Error disposing camera: $e');
    }
    super.dispose();
  }
 
  Future<void> _captureImage() async {
    try {
      // Wait until controller is initialized
      await _initializeControllerFuture;
 
      final image = await _controller.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      print('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }
 
  Future<void> _sendToApi() async {
    if (_capturedImage == null) return;
 
    try {
      final imageBytes = await _capturedImage!.readAsBytes();
      final base64Image = base64Encode(imageBytes);
 
      final response = await http.post(
        Uri.parse('https://url.com/api/recognize'),
        body: {
          'members': jsonEncode(widget.members.map((m) => {
            'memberName': m['name'],
            'memberRelation': m['relation'],
            'memberImage': m['imageUrl'],  // Sending URL as per updated API expectation
          }).toList()),
          'imageUrl': 'data:image/jpeg;base64,$base64Image',
        },
      ).timeout(const Duration(seconds: 30));
 
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['matchFound']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Match found: ${result['memberName']}')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No matches found')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process image')),
          );
        }
      }
    } catch (e) {
      print('Error sending image to API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image to API: $e')),
        );
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scan', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        color: Colors.lightBlue[100],
        child: _hasCameraError
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera not available',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasCameraError = false;
                        });
                        _initializeCamera();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _capturedImage == null
                ? FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  'Error initializing camera: ${snapshot.error}',
                                  style: const TextStyle(fontSize: 16, color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {});
                                    _initializeCamera();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }
                        return CameraPreview(_controller);
                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else {
                        return const Center(child: Text('Initializing camera...'));
                      }
                    },
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.file(
                        File(_capturedImage!.path),
                        height: 300,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _sendToApi,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('OK', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _capturedImage = null;
                              });
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Retake', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
      floatingActionButton: _capturedImage == null && !_hasCameraError
          ? FloatingActionButton(
              onPressed: _captureImage,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.camera),
            )
          : null,
    );
  }
}
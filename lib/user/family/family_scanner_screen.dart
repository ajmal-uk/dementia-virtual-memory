import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

class ScannerScreen extends StatefulWidget {
  final List<Map<String, String>> members;
  const ScannerScreen({Key? key, required this.members}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;

      _controller = CameraController(firstCamera, ResolutionPreset.medium);
      
      // Assign the future immediately
      _initializeControllerFuture = _controller.initialize();

      // Wait for initialization to complete
      await _initializeControllerFuture;

      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
            'memberImage': m['imageUrl'],
          }).toList()),
          'imageUrl': 'data:image/jpeg;base64,$base64Image',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['matchFound']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match found: ${result['memberName']}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No matches found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
      }
    } catch (e) {
      print('Error sending image to API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error sending image to API')),
      );
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
        child: _capturedImage == null
            ? FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return CameraPreview(_controller);
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error initializing camera'));
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.file(
                    File(_capturedImage!.path),
                    height: 300,
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
      floatingActionButton: _capturedImage == null
          ? FloatingActionButton(
              onPressed: _captureImage,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.camera),
            )
          : null,
    );
  }
}

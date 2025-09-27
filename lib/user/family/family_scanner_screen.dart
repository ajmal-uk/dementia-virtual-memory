// lib/user/family/family_scanner_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';

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
  bool _isProcessing = false;
  ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _confettiController = ConfettiController();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _hasCameraError = true);
        return;
      }

      final firstCamera = cameras.first;
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller.initialize();

      await _initializeControllerFuture;

      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) setState(() => _hasCameraError = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    try {
      await _initializeControllerFuture;

      final image = await _controller.takePicture();
      if (mounted) setState(() => _capturedImage = image);
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
    if (_capturedImage == null || _isProcessing) return;
    if (mounted) setState(() => _isProcessing = true);

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
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && mounted) {
        final result = jsonDecode(response.body);
        if (result['matchFound']) {
          _confettiController.play();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Match Found!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (result['memberImageUrl'] != null && result['memberImageUrl'].isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        result['memberImageUrl'],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 100),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text('Name: ${result['memberName']}'),
                  Text('Relation: ${result['memberRelation']}'),
                  Text('Confidence: ${(result['confidence'] * 100).toStringAsFixed(2)}%'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (mounted) setState(() => _capturedImage = null);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ).then((_) => _confettiController.stop());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No matches found')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
      }
    } catch (e) {
      print('Error sending image to API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image to API: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Family Member'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
              ),
            ),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return CameraPreview(_controller).animate().fadeIn(duration: 500.ms);
                          } else {
                            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
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
                          ).animate().scale(duration: 300.ms, curve: Curves.easeOut),
                          const SizedBox(height: 20),
                          _isProcessing
                              ? const CircularProgressIndicator(color: Colors.blueAccent)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _sendToApi,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('OK', style: TextStyle(color: Colors.white)),
                                    ).animate().slideX(begin: -0.2, duration: 300.ms),
                                    const SizedBox(width: 20),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (mounted) setState(() => _capturedImage = null);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Retake', style: TextStyle(color: Colors.white)),
                                    ).animate().slideX(begin: 0.2, duration: 300.ms),
                                  ],
                                ),
                        ],
                      ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 50,
            ),
          ),
        ],
      ),
      floatingActionButton: _capturedImage == null && !_hasCameraError
          ? FloatingActionButton(
              onPressed: _captureImage,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ).animate().scale(duration: 300.ms)
          : null,
    );
  }
}
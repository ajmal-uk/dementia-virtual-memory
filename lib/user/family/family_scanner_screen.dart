// lib/user/family/family_scanner_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

final logger = Logger();

class ScannerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  const ScannerScreen({super.key, required this.members});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  bool _hasCameraError = false;
  bool _isProcessing = false;
  bool _isLoadingCamera = true;
  bool _isCapturing = false;
  late ConfettiController _confettiController;
  bool _disposed = false;
  bool _isFrontCamera = false;
  List<CameraDescription> _cameras = [];
  final _firestore = FirebaseFirestore.instance;

  // Result info
  Map<String, dynamic>? _resultData;
  bool _noMatch = false;

  // Animation controller for scanning overlay
  late AnimationController _scanAnimationController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_disposed) return;
    setState(() {
      _isLoadingCamera = true;
      _resultData = null;
      _noMatch = false;
      _capturedImage = null;
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is permanently denied. Please enable it in settings.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission denied.')),
          );
        }
      }
      setState(() {
        _hasCameraError = true;
        _isLoadingCamera = false;
      });
      return;
    }

    try {
      await _controller?.dispose();
      _cameras = await availableCameras().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera initialization timed out');
        },
      );
      if (_cameras.isEmpty) {
        if (mounted && !_disposed) {
          setState(() {
            _hasCameraError = true;
            _isLoadingCamera = false;
          });
        }
        return;
      }
      final selectedCamera = _cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (_isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => _cameras.first,
      );
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.low,  // Optimized to lower resolution for faster processing
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _initializeControllerFuture = _controller!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera controller initialization timed out');
        },
      );
      await _initializeControllerFuture;
      if (mounted && !_disposed) {
        setState(() => _isLoadingCamera = false);
      }
    } catch (e) {
      logger.e('Error initializing camera: $e');
      if (mounted && !_disposed) {
        setState(() {
          _hasCameraError = true;
          _isLoadingCamera = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _hasCameraError = false;
      _isLoadingCamera = true;
      _capturedImage = null;
      _resultData = null;
      _noMatch = false;
    });
    await _initializeCamera();
  }

  Future<void> _captureImage() async {
    if (_controller == null ||
        _initializeControllerFuture == null ||
        _hasCameraError ||
        _isLoadingCamera ||
        _isCapturing ||
        _isProcessing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      await _initializeControllerFuture;
      await _controller!.pausePreview();
      final image = await _controller!.takePicture();

      // Process image (flip if front, resize and compress)
      final bytes = await File(image.path).readAsBytes();
      Uint8List processedBytes;
      if (_isFrontCamera) {
        processedBytes = await compute(_flipHorizontal, bytes);
      } else {
        processedBytes = await compute(_resizeAndCompressBytes, bytes);
      }
      await File(image.path).writeAsBytes(processedBytes);

      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.resumePreview();
      }

      if (mounted && !_disposed) {
        setState(() {
          _capturedImage = image;
          _resultData = null;
          _noMatch = false;
          _isCapturing = false;
        });
      }
    } catch (e) {
      logger.e('Error capturing image: $e');
      if (_controller != null && _controller!.value.isInitialized) {
        try {
          await _controller!.resumePreview();
        } catch (_) {}
      }
      if (mounted && !_disposed) setState(() => _isCapturing = false);
    }
  }

  static Uint8List _flipHorizontal(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final flipped = img.flipHorizontal(image);
    return _resizeAndCompress(flipped);
  }

  static Uint8List _resizeAndCompressBytes(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    return _resizeAndCompress(image);
  }

  static Uint8List _resizeAndCompress(img.Image image) {
    const maxSize = 512;
    img.Image resized = image;
    if (image.width > maxSize || image.height > maxSize) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: maxSize);
      } else {
        resized = img.copyResize(image, height: maxSize);
      }
    }
    return img.encodeJpg(resized, quality: 85);
  }

  Future<String> _encodeImage(Uint8List bytes) async {
    return await compute(_encodeBase64, bytes);
  }

  static String _encodeBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  Future<void> _sendToApi() async {
    if (_capturedImage == null || _isProcessing) return;
    if (mounted && !_disposed) setState(() => _isProcessing = true);

    try {
      // Fetch API URL from Firebase
      final apiSnap = await _firestore.collection('api').doc('qHsy9xZJuanFIWFDx7ag').get();
      final apiUrl = apiSnap.data()?['apiURL'] as String?;
      if (apiUrl == null || apiUrl.isEmpty) {
        logger.e('No API URL configured');
        if (mounted && !_disposed) {
          setState(() {
            _resultData = null;
            _noMatch = true;
          });
        }
        return;
      }

      final imageBytes = await _capturedImage!.readAsBytes();
      final base64Image = await _encodeImage(imageBytes);
      final response = await http.post(
        Uri.parse('$apiUrl/recognize'),
        body: {
          'members': jsonEncode(widget.members.map((m) => {
                'memberName': m['name'],
                'memberRelation': m['relation'],
                'memberImage': m['imageUrl'],
              }).toList()),
          'imageUrl': 'data:image/jpeg;base64,$base64Image',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted || _disposed) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['matchFound']) {
          _confettiController.play();
          setState(() {
            _resultData = result;
            _noMatch = false;
          });
        } else {
          setState(() {
            _resultData = null;
            _noMatch = true;
          });
        }
      } else {
        setState(() {
          _resultData = null;
          _noMatch = true;
        });
      }
    } catch (e) {
      logger.e('Error sending image to API: $e');
      if (mounted && !_disposed) {
        setState(() {
          _resultData = null;
          _noMatch = true;
        });
      }
    } finally {
      if (mounted && !_disposed) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Family Member'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFrontCamera ? Icons.camera_rear : Icons.camera_front),
            onPressed: _isLoadingCamera || _isCapturing || _isProcessing
                ? null
                : _toggleCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoadingCamera
              ? const Center(child: CircularProgressIndicator())
              : _hasCameraError
                  ? _buildCameraError()
                  : _capturedImage == null
                      ? _buildCameraPreview()
                      : _buildCapturedImageWithAnimation(),
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
      floatingActionButton: _capturedImage == null &&
              !_hasCameraError &&
              _controller != null &&
              !_isLoadingCamera
          ? FloatingActionButton(
              onPressed: _isCapturing || _isProcessing ? null : _captureImage,
              backgroundColor: Colors.blueAccent,
              child: _isCapturing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCapturedImageWithAnimation() {
    return Stack(
      children: [
        Image.file(
          File(_capturedImage!.path),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                  child: AnimatedBuilder(
                    animation: _scanAnimationController,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment(
                            0, -1 + 2 * _scanAnimationController.value),
                        child: Container(
                          height: 4,
                          width: double.infinity,
                          color: Colors.blueAccent,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 40, // Increased bottom padding
          left: 20,
          right: 20,
          child: _buildBottomControls(),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isProcessing)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _sendToApi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.check),
                label: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _capturedImage = null;
                    _resultData = null;
                    _noMatch = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retake', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        const SizedBox(height: 16),
        if (_resultData != null || _noMatch) _buildResultOverlay(),
      ],
    );
  }

  Widget _buildResultOverlay() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _resultData != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Match Found',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (_resultData!['memberImageUrl'] != null &&
                      _resultData!['memberImageUrl'].isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _resultData!['memberImageUrl'],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Name: ${_resultData!['memberName']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Relation: ${_resultData!['memberRelation']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Confidence: ${(_resultData!['confidence'] * 100).toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No Matches Found',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildCameraPreview() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError || _controller == null) return _buildCameraError();
          return CameraPreview(_controller!).animate().fadeIn(duration: 500.ms);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildCameraError() {
    return Center(
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
            onPressed: () async {
              if (await Permission.camera.isPermanentlyDenied) {
                openAppSettings();
              } else {
                _initializeCamera();
              }
            },
            child: const Text('Retry / Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    _confettiController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }
}
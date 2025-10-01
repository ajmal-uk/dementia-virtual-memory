import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';

final logger = Logger();

class ScannerScreen extends StatefulWidget {
  final String patientUid;
  const ScannerScreen({super.key, required this.patientUid});

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

  // NEW: Store fetched members list here
  List<Map<String, dynamic>> _patientMembers = [];
  bool _isFetchingMembers = true;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    // NEW: Start fetching members before initializing the camera
    _fetchPatientMembers();
  }

  // NEW FUNCTION: Fetch the 'members' array from the patient's document
  Future<void> _fetchPatientMembers() async {
    if (_disposed) return;
    setState(() => _isFetchingMembers = true);
    try {
      final patientDoc =
          await _firestore.collection('user').doc(widget.patientUid).get();

      if (patientDoc.exists) {
        final data = patientDoc.data();
        final membersList = data?['members'] as List<dynamic>?;
        
        if (membersList != null) {
            // Convert List<dynamic> to List<Map<String, dynamic>>
            _patientMembers = membersList
                .whereType<Map<String, dynamic>>()
                .toList();
        }
      }
      // Continue to camera setup only after members are fetched
      await _initializeCamera();
    } catch (e) {
      logger.e('Error fetching patient members: $e');
      if (mounted && !_disposed) {
        setState(() {
            _hasCameraError = true;
            _isLoadingCamera = false;
        });
      }
    } finally {
        if (mounted && !_disposed) setState(() => _isFetchingMembers = false);
    }
  }

  Future<void> _initializeCamera() async {
    if (_disposed || _isFetchingMembers) return; // Wait for members
    setState(() {
      _isLoadingCamera = true;
      _resultData = null;
      _noMatch = false;
      _capturedImage = null;
    });
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
        ResolutionPreset.low, // Optimized to lower resolution for faster processing
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
        _isProcessing || 
        _patientMembers.isEmpty) { // Prevent capture if no members
      if (_patientMembers.isEmpty && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot scan: Patient has no registered family members.')),
        );
      }
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
    if (_capturedImage == null || _isProcessing || _patientMembers.isEmpty) return;
    if (mounted && !_disposed) setState(() => _isProcessing = true);

    try {
      final imageBytes = await _capturedImage!.readAsBytes();
      final base64Image = await _encodeImage(imageBytes);
      
      // LOGIC: Use the fetched _patientMembers list
      final membersPayload = _patientMembers.map((m) => {
          'memberName': m['name'],
          'memberRelation': m['relation'],
          'memberImage': m['imageUrl'],
      }).toList();

      final response = await http.post(
        Uri.parse('https://una-heliotropic-aspersively.ngrok-free.dev/recognize'),
        body: {
          'members': jsonEncode(membersPayload), // Use fetched members
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
    // Show a loading indicator if fetching members OR setting up camera
    if (_isFetchingMembers || _isLoadingCamera) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isFetchingMembers ? 'Loading Patient Data...' : 'Initializing Camera...'),
          backgroundColor: Colors.blueAccent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    // Check if patient has any family members registered
    if (_patientMembers.isEmpty) {
        return Scaffold(
            appBar: AppBar(
                title: const Text('Scan Family Member'),
                backgroundColor: Colors.redAccent,
                elevation: 0,
            ),
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Icon(Icons.group_off, size: 80, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                                'No Family Members Registered',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                'The patient connected to your account has no registered family members to verify against.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Go Back'),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

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
          _hasCameraError
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
              ElevatedButton(
                onPressed: _sendToApi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              ElevatedButton(
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
                child: const Text('Retake', style: TextStyle(fontSize: 16, color: Colors.white)),
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
            onPressed: _initializeCamera,
            child: const Text('Retry'),
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
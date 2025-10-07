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
  bool _isLoadingCamera = true;
  bool _isCapturing = false;
  bool _isProcessing = false;
  bool _disposed = false;
  bool _isFrontCamera = false;

  List<CameraDescription> _cameras = [];
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _resultData;
  bool _noMatch = false;

  late AnimationController _scanAnimationController;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_disposed) return;
    setState(() {
      _isLoadingCamera = true;
      _hasCameraError = false;
      _capturedImage = null;
      _resultData = null;
      _noMatch = false;
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _hasCameraError = true;
        _isLoadingCamera = false;
      });
      return;
    }

    try {
      await _controller?.dispose();
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _hasCameraError = true;
          _isLoadingCamera = false;
        });
        return;
      }

      final selectedCamera = _cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (_isFrontCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      if (mounted && !_disposed) {
        setState(() => _isLoadingCamera = false);
      }
    } catch (e) {
      logger.e('Camera init error: $e');
      setState(() {
        _hasCameraError = true;
        _isLoadingCamera = false;
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _initializeCamera();
  }

  Future<void> _captureImage() async {
    if (_controller == null || _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      await _controller!.pausePreview();
      final image = await _controller!.takePicture();

      final bytes = await File(image.path).readAsBytes();
      Uint8List processedBytes = _isFrontCamera
          ? await compute(_flipHorizontal, bytes)
          : await compute(_resizeAndCompressBytes, bytes);

      await File(image.path).writeAsBytes(processedBytes);

      if (mounted) {
        setState(() {
          _capturedImage = image;
          _isCapturing = false;
        });
      }
      await _controller!.resumePreview();
    } catch (e) {
      logger.e('Capture error: $e');
      setState(() => _isCapturing = false);
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
      resized = img.copyResize(image,
          width: image.width > image.height ? maxSize : null,
          height: image.height >= image.width ? maxSize : null);
    }
    return img.encodeJpg(resized, quality: 85);
  }

  Future<void> _sendToApi() async {
    if (_capturedImage == null || _isProcessing) return;
    setState(() {
      _isProcessing = true;
      _resultData = null;
      _noMatch = false;
    });
    _scanAnimationController.repeat(reverse: true);

    try {
      final apiSnap =
          await _firestore.collection('api').doc('qHsy9xZJJanFlWFDx7ag').get();
      final apiUrl = apiSnap.data()?['apiURL'] as String?;
      if (apiUrl == null || apiUrl.isEmpty) {
        setState(() => _noMatch = true);
        return;
      }

      final bytes = await _capturedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$apiUrl/recognize'),
        body: {
          'members': jsonEncode(widget.members
              .map((m) => {
                    'memberName': m['name'],
                    'memberRelation': m['relation'],
                    'memberImage': m['imageUrl'],
                  })
              .toList()),
          'imageUrl': 'data:image/jpeg;base64,$base64Image',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['matchFound']) {
          _confettiController.play();
          setState(() {
            _resultData = result;
            _noMatch = false;
          });
        } else {
          setState(() => _noMatch = true);
        }
      } else {
        setState(() => _noMatch = true);
      }
    } catch (e) {
      logger.e('API error: $e');
      setState(() => _noMatch = true);
    } finally {
      _scanAnimationController.stop();
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoadingCamera
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _hasCameraError
                  ? _buildCameraError()
                  : _capturedImage == null
                      ? _buildCameraPreview()
                      : _buildCapturedImage(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _capturedImage == null && !_isProcessing
          ? _buildCameraControls()
          : null,
    );
  }

  Widget _buildCameraPreview() {
    return FutureBuilder(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            _controller != null) {
          return CameraPreview(_controller!);
        }
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      },
    );
  }

  Widget _buildCameraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: _toggleCamera,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cameraswitch, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 40),
        GestureDetector(
          onTap: _isCapturing ? null : _captureImage,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Center(
              child: Container(
                width: 65,
                height: 65,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedImage() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            File(_capturedImage!.path),
            fit: BoxFit.cover,
          ),
        ),
        if (_isProcessing) _buildScanAnimationOverlay(),
        if (_resultData != null || _noMatch)
          _buildResultOverlay(),
        if (!_isProcessing && _resultData == null && !_noMatch)
          _buildConfirmButtons(),
      ],
    );
  }

  Widget _buildScanAnimationOverlay() {
    return AnimatedBuilder(
      animation: _scanAnimationController,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: Colors.black38),
            Align(
              alignment:
                  Alignment(0, -1 + 2 * _scanAnimationController.value),
              child: Container(
                height: 4,
                width: double.infinity,
                color: Colors.blueAccent,
              ),
            ),
            const Center(
              child: Text(
                'Scanning...',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmButtons() {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _sendToApi,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check),
            label: const Text('OK', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _capturedImage = null;
                _resultData = null;
                _noMatch = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retake', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_resultData != null)
              Column(
                children: [
                  const Text(
                    'Match Found!',
                    style: TextStyle(
                        fontSize: 22,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_resultData!['memberImageUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _resultData!['memberImageUrl'],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text('Name: ${_resultData!['memberName']}'),
                  Text('Relation: ${_resultData!['memberRelation']}'),
                  Text(
                      'Confidence: ${(_resultData!['confidence'] * 100).toStringAsFixed(2)}%'),
                ],
              )
            else
              const Text(
                'No Match Found',
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800]),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _capturedImage = null;
                      _resultData = null;
                      _noMatch = false;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                ),
              ],
            )
          ],
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildCameraError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, color: Colors.red, size: 64),
          const SizedBox(height: 12),
          const Text('Camera not available',
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeCamera,
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
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
    _scanAnimationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}
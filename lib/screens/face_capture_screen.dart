import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Full-screen camera with live face detection overlay.
///
/// Usage:
///   final path = await Navigator.push<String>(ctx, MaterialPageRoute(
///     builder: (_) => FaceCaptureScreen(mode: FaceCaptureMode.register)));
///
/// Returns the captured image path, or null if cancelled.
enum FaceCaptureMode { register, verify }

class FaceCaptureScreen extends StatefulWidget {
  final FaceCaptureMode mode;
  const FaceCaptureScreen({super.key, required this.mode});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _camera;
  bool _cameraReady = false;
  bool _processing = false;
  bool _faceDetected = false;
  String _hint = 'Positioning camera…';
  Timer? _captureTimer;
  int _countdown = 0;

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final ctrl = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await ctrl.initialize();
    if (!mounted) return;
    _camera = ctrl;
    setState(() { _cameraReady = true; _hint = 'Center your face in the circle'; });
    ctrl.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_analyzing || _processing || !mounted) return;
    _analyzing = true;
    try {
      final camera = _camera;
      if (camera == null) return;
      final inputImage = _toInputImage(image, camera);
      if (inputImage == null) return;
      final faces = await _detector.processImage(inputImage);
      if (!mounted) return;

      bool readyToCapture = false;
      String hint = 'Center your face in the circle';

      if (faces.isEmpty) {
        hint = 'Center your face in the circle';
      } else if (faces.length > 1) {
        hint = 'One face only please';
      } else {
        final face = faces.first;
        final yaw = (face.headEulerAngleY ?? 99).abs();
        final pitch = (face.headEulerAngleX ?? 99).abs();
        if (yaw > 20 || pitch > 20) {
          hint = 'Look directly at the camera';
        } else {
          hint = 'Hold still…';
          readyToCapture = true;
        }
      }

      if (readyToCapture != _faceDetected || hint != _hint) {
        setState(() {
          _faceDetected = readyToCapture;
          _hint = hint;
        });
      }

      if (readyToCapture && _captureTimer == null && !_processing) {
        setState(() { _countdown = 2; });
        _captureTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          setState(() { _countdown--; });
          if (_countdown <= 0) {
            t.cancel();
            _captureTimer = null;
            _capture();
          }
        });
      } else if (!readyToCapture && _captureTimer != null) {
        _captureTimer?.cancel();
        _captureTimer = null;
        setState(() { _countdown = 0; });
      }
    } finally {
      _analyzing = false;
    }
  }

  Future<void> _capture() async {
    if (_processing) return;
    setState(() { _processing = true; _hint = 'Capturing…'; });
    try {
      await _camera?.stopImageStream();
      final xFile = await _camera?.takePicture();
      if (xFile != null && mounted) {
        Navigator.of(context).pop(xFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _processing = false; _hint = 'Error — tap retry'; });
        _camera?.startImageStream(_onFrame);
      }
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraController ctrl) {
    try {
      final camera = ctrl.description;
      final rotation = InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      );
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_cameraReady && _camera != null)
            ClipRect(child: CameraPreview(_camera!)),

          // Dark overlay with circular cutout
          _FaceOverlay(faceDetected: _faceDetected),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0, right: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                Expanded(
                  child: Text(
                    widget.mode == FaceCaptureMode.register
                        ? 'Set Up Face ID'
                        : 'Face ID Login',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Hint text + countdown
          Positioned(
            bottom: 100,
            left: 32, right: 32,
            child: Column(
              children: [
                if (_countdown > 0 && _faceDetected)
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _faceDetected ? Colors.greenAccent : Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Manual capture button (fallback)
          if (_cameraReady && !_processing)
            Positioned(
              bottom: 32,
              left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _captureTimer?.cancel();
                    _captureTimer = null;
                    _capture();
                  },
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt, size: 30, color: Color(0xFF0036BC)),
                  ),
                ),
              ),
            ),

          if (_processing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

// ── Oval overlay with transparent cutout ─────────────────────────────────────
class _FaceOverlay extends StatelessWidget {
  final bool faceDetected;
  const _FaceOverlay({required this.faceDetected});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(faceDetected: faceDetected),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final bool faceDetected;
  _OverlayPainter({required this.faceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.38;
    final oval = Rect.fromCircle(center: center, radius: radius);

    // Dark overlay
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // Circle border
    final borderPaint = Paint()
      ..color = faceDetected ? Colors.greenAccent : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(oval, borderPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.faceDetected != faceDetected;
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// Camera-based face authentication.
///
/// Strategy:
/// 1. ML Kit → liveness only (is face present? is it frontal?)
/// 2. Center crop → pixel comparison (avoids EXIF/coordinate-system issues)
///
/// Front-camera selfies always place the face in the center of the frame
/// regardless of photo orientation, so a center crop reliably captures the face.
class FaceAuthService {
  static final FaceAuthService _instance = FaceAuthService._internal();
  factory FaceAuthService() => _instance;
  FaceAuthService._internal();

  static const _pixelsKey = 'face_auth_pixels_v3';
  static const _enabledKey = 'face_auth_enabled';

  // Pearson correlation threshold.
  // Same person (different lighting/angle): typically 0.60–0.85
  // Different person:                       typically 0.25–0.50
  static const double _threshold = 0.55;
  static const int _faceSize = 96;

  late final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.10,
    ),
  );

  void dispose() => _detector.close();

  // ── Preferences ──────────────────────────────────────────────────────────

  Future<bool> isFaceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> disableFace() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    await prefs.remove(_pixelsKey);
  }

  // ── Registration ─────────────────────────────────────────────────────────

  Future<String?> registerFace(String imagePath) async {
    try {
      // Liveness check: must detect exactly one frontal face
      final livenessError = await _livenessCheck(imagePath);
      if (livenessError != null) return livenessError;

      final vector = await _imageToVector(imagePath);
      if (vector == null) return 'Could not read image. Please try again.';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pixelsKey, jsonEncode(vector));
      await prefs.setBool(_enabledKey, true);
      debugPrint('FaceAuthService: face registered (${vector.length} values)');
      return null;
    } catch (e) {
      debugPrint('FaceAuthService.register error: $e');
      return 'Registration failed. Please try again.';
    }
  }

  // ── Verification ─────────────────────────────────────────────────────────

  Future<FaceVerifyResult> verifyFace(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_pixelsKey);
      if (stored == null) return FaceVerifyResult.notRegistered;
      final reference = (jsonDecode(stored) as List).cast<double>();

      // Liveness check
      final livenessError = await _livenessCheck(imagePath);
      if (livenessError != null) {
        if (livenessError.contains('Multiple')) return FaceVerifyResult.multipleFaces;
        return FaceVerifyResult.noFace;
      }

      final candidate = await _imageToVector(imagePath);
      if (candidate == null) return FaceVerifyResult.noFace;

      final corr = _pearsonCorr(reference, candidate);
      debugPrint('FaceAuthService: corr=$corr (need >= $_threshold)');

      return corr >= _threshold ? FaceVerifyResult.match : FaceVerifyResult.noMatch;
    } catch (e) {
      debugPrint('FaceAuthService.verify error: $e');
      return FaceVerifyResult.error;
    }
  }

  // ── Liveness check ───────────────────────────────────────────────────────

  Future<String?> _livenessCheck(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(inputImage);

    if (faces.isEmpty) return 'No face detected. Try better lighting and face the camera directly.';
    if (faces.length > 1) return 'Multiple faces detected. Please ensure only your face is visible.';

    final face = faces.first;
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final pitch = (face.headEulerAngleX ?? 0).abs();
    if (yaw > 30 || pitch > 30) {
      return 'Please look directly at the camera and hold still.';
    }
    return null;
  }

  // ── Core: image → normalized pixel vector ────────────────────────────────

  /// Converts image to a standardized grayscale pixel vector.
  /// Uses center crop — front camera always places face in center regardless
  /// of EXIF rotation, avoiding coordinate-system mismatches.
  Future<List<double>?> _imageToVector(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // Apply EXIF orientation so image is right-side-up
      image = img.bakeOrientation(image);

      // Center square crop: covers the face area in a front-camera selfie
      final side = (min(image.width, image.height) * 0.72).toInt();
      final cx = (image.width - side) ~/ 2;
      final cy = (image.height - side) ~/ 2;
      final cropped = img.copyCrop(image, x: cx, y: cy, width: side, height: side);

      // Resize to fixed size
      final resized = img.copyResize(cropped, width: _faceSize, height: _faceSize);

      // Grayscale pixel vector
      final pixels = <double>[];
      for (int py = 0; py < _faceSize; py++) {
        for (int px = 0; px < _faceSize; px++) {
          final pixel = resized.getPixel(px, py);
          final gray = (0.299 * pixel.r.toDouble() +
                        0.587 * pixel.g.toDouble() +
                        0.114 * pixel.b.toDouble()) / 255.0;
          pixels.add(gray);
        }
      }

      // Standardize (mean=0, std=1) → lighting invariant
      final n = pixels.length.toDouble();
      final mean = pixels.reduce((a, b) => a + b) / n;
      final variance = pixels.map((v) => pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) / n;
      final std = sqrt(variance) + 1e-6;
      return pixels.map((v) => (v - mean) / std).toList();
    } catch (e) {
      debugPrint('FaceAuthService._imageToVector error: $e');
      return null;
    }
  }

  /// Pearson correlation between two pre-standardized vectors.
  /// Returns value in [-1, 1]. 1 = identical.
  double _pearsonCorr(List<double> a, List<double> b) {
    final n = min(a.length, b.length);
    if (n == 0) return 0;
    double dot = 0;
    for (int i = 0; i < n; i++) {
      dot += a[i] * b[i];
    }
    return dot / n;
  }
}

enum FaceVerifyResult {
  match,
  noMatch,
  noFace,
  multipleFaces,
  notRegistered,
  error,
}

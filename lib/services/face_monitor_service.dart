import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceFrameStatus {
  final bool faceDetected;
  final bool singleFacePresent;
  final bool isCentered;
  final bool isLookingAway;
  final bool eyesOpen;
  final double headYaw;
  final double headRoll;
  final double visibilityPercent;
  final double engagementPercent;
  final int detectedFaces;
  final String coachingText;

  const FaceFrameStatus({
    required this.faceDetected,
    required this.singleFacePresent,
    required this.isCentered,
    required this.isLookingAway,
    required this.eyesOpen,
    required this.headYaw,
    required this.headRoll,
    required this.visibilityPercent,
    required this.engagementPercent,
    required this.detectedFaces,
    required this.coachingText,
  });

  factory FaceFrameStatus.initial() {
    return const FaceFrameStatus(
      faceDetected: false,
      singleFacePresent: false,
      isCentered: false,
      isLookingAway: false,
      eyesOpen: true,
      headYaw: 0,
      headRoll: 0,
      visibilityPercent: 0,
      engagementPercent: 0,
      detectedFaces: 0,
      coachingText: "Initializing camera...",
    );
  }
}

class FaceSessionSummary {
  final double visibilityPercent;
  final double engagementPercent;
  final double centeredPercent;
  final double lookingAwayPercent;
  final double eyesOpenPercent;
  final int noFaceFrames;
  final int multiFaceFrames;

  const FaceSessionSummary({
    required this.visibilityPercent,
    required this.engagementPercent,
    required this.centeredPercent,
    required this.lookingAwayPercent,
    required this.eyesOpenPercent,
    required this.noFaceFrames,
    required this.multiFaceFrames,
  });
}

class FaceMonitorService {
  late final FaceDetector _faceDetector;
  
  int _totalFrames = 0;
  int _faceFrames = 0;
  int _singleFaceFrames = 0;
  int _centeredFrames = 0;
  int _lookingAwayFrames = 0;
  int _eyesOpenFrames = 0;
  int _noFaceFrames = 0;
  int _multiFaceFrames = 0;
  int _engagementFrames = 0;

  FaceMonitorService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.15,
      ),
    );
  }

  Future<FaceFrameStatus?> processCameraImage(
    CameraImage image,
    CameraDescription cameraDescription,
  ) async {
    try {
      // Convert camera image to InputImage
      final inputImage = await _convertToInputImage(image, cameraDescription);
      if (inputImage == null) {
        return null;
      }

      final faces = await _faceDetector.processImage(inputImage);
      
      _totalFrames++;

      if (faces.isEmpty) {
        _noFaceFrames++;
        return FaceFrameStatus(
          faceDetected: false,
          singleFacePresent: false,
          isCentered: false,
          isLookingAway: false,
          eyesOpen: true,
          headYaw: 0,
          headRoll: 0,
          visibilityPercent: _getPercent(_faceFrames, _totalFrames),
          engagementPercent: _getPercent(_engagementFrames, _totalFrames),
          detectedFaces: 0,
          coachingText: " No face detected - Please look at camera",
        );
      }

      _faceFrames++;
      
      final bool singleFacePresent = faces.length == 1;
      if (singleFacePresent) {
        _singleFaceFrames++;
      } else {
        _multiFaceFrames++;
      }

      final Face face = _getLargestFace(faces);
      
      final double yaw = face.headEulerAngleY?.abs() ?? 0;
      final double roll = face.headEulerAngleZ?.abs() ?? 0;
      final bool lookingAway = yaw > 20 || roll > 15;
      if (lookingAway) _lookingAwayFrames++;

      final double leftEye = face.leftEyeOpenProbability ?? 1.0;
      final double rightEye = face.rightEyeOpenProbability ?? 1.0;
      final bool eyesOpen = leftEye > 0.4 && rightEye > 0.4;
      if (eyesOpen) _eyesOpenFrames++;

      final double centerX = face.boundingBox.center.dx / image.width;
      final double centerY = face.boundingBox.center.dy / image.height;
      final bool centered = centerX > 0.25 && centerX < 0.75 && 
                           centerY > 0.20 && centerY < 0.80;
      if (centered) _centeredFrames++;

      final bool engaged = singleFacePresent && centered && !lookingAway && eyesOpen;
      if (engaged) _engagementFrames++;

      String coachingText;
      if (faces.length > 1) {
        coachingText = "Multiple faces detected ";
      } else if (!centered) {
        coachingText = " Center your face ";
      } else if (lookingAway) {
        coachingText = " Look at the camera";
      } else if (!eyesOpen) {
        coachingText = "Keep your eyes open";
      } else {
        coachingText = "✅ Perfect! Great posture";
      }

      return FaceFrameStatus(
        faceDetected: true,
        singleFacePresent: singleFacePresent,
        isCentered: centered,
        isLookingAway: lookingAway,
        eyesOpen: eyesOpen,
        headYaw: yaw,
        headRoll: roll,
        visibilityPercent: _getPercent(_faceFrames, _totalFrames),
        engagementPercent: _getPercent(_engagementFrames, _totalFrames),
        detectedFaces: faces.length,
        coachingText: coachingText,
      );
      
    } catch (e) {
      debugPrint('Face detection error: $e');
      return null;
    }
  }

  Future<InputImage?> _convertToInputImage(
    CameraImage image,
    CameraDescription cameraDescription,
  ) async {
    try {
      final int width = image.width;
      final int height = image.height;
      
      // Handle YUV420 format (Android)
      if (image.format.group == ImageFormatGroup.yuv420) {
        final yPlane = image.planes[0].bytes;
        final uPlane = image.planes[1].bytes;
        final vPlane = image.planes[2].bytes;
        
        final rgbBytes = Uint8List(width * height * 3);
        
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final int yIndex = y * width + x;
            final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
            
            final int yValue = yPlane[yIndex] & 0xFF;
            final int uValue = uPlane[uvIndex] & 0xFF;
            final int vValue = vPlane[uvIndex] & 0xFF;
            
            int r = (yValue + 1.402 * (vValue - 128)).toInt();
            int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).toInt();
            int b = (yValue + 1.772 * (uValue - 128)).toInt();
            
            r = r.clamp(0, 255);
            g = g.clamp(0, 255);
            b = b.clamp(0, 255);
            
            final int rgbIndex = (y * width + x) * 3;
            rgbBytes[rgbIndex] = r;
            rgbBytes[rgbIndex + 1] = g;
            rgbBytes[rgbIndex + 2] = b;
          }
        }
        
        return InputImage.fromBytes(
          bytes: rgbBytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: width,
          ),
        );
      }
      // Handle NV21 format
      else if (image.format.group == ImageFormatGroup.nv21) {
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      }
      // Handle BGRA8888 format (iOS)
      else if (image.format.group == ImageFormatGroup.bgra8888) {
        final bgraBytes = image.planes[0].bytes;
        final rgbBytes = Uint8List(width * height * 3);
        
        for (int i = 0; i < bgraBytes.length; i += 4) {
          final int b = bgraBytes[i];
          final int g = bgraBytes[i + 1];
          final int r = bgraBytes[i + 2];
          
          final int rgbIndex = (i ~/ 4) * 3;
          rgbBytes[rgbIndex] = r;
          rgbBytes[rgbIndex + 1] = g;
          rgbBytes[rgbIndex + 2] = b;
          
        }
        
        return InputImage.fromBytes(
          bytes: rgbBytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: width,
          ),
        );
      }
      
      debugPrint('Unsupported format: ${image.format.group}');
      return null;
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  Face _getLargestFace(List<Face> faces) {
    return faces.reduce((a, b) => 
      a.boundingBox.width * a.boundingBox.height > 
      b.boundingBox.width * b.boundingBox.height ? a : b);
  }

  double _getPercent(int value, int total) {
    if (total == 0) return 0;
    return (value / total * 100).clamp(0, 100);
  }

  FaceSessionSummary buildSessionSummary() {
    final total = _totalFrames == 0 ? 1 : _totalFrames;
    return FaceSessionSummary(
      visibilityPercent: _getPercent(_faceFrames, total),
      engagementPercent: _getPercent(_engagementFrames, total),
      centeredPercent: _getPercent(_centeredFrames, total),
      lookingAwayPercent: _getPercent(_lookingAwayFrames, total),
      eyesOpenPercent: _getPercent(_eyesOpenFrames, total),
      noFaceFrames: _noFaceFrames,
      multiFaceFrames: _multiFaceFrames,
    );
  }

  void resetSession() {
    _totalFrames = 0;
    _faceFrames = 0;
    _singleFaceFrames = 0;
    _centeredFrames = 0;
    _lookingAwayFrames = 0;
    _eyesOpenFrames = 0;
    _noFaceFrames = 0;
    _multiFaceFrames = 0;
    _engagementFrames = 0;
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }
}
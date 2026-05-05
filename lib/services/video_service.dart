import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/logger.dart';
import '../core/constants/app_constants.dart';
import 'firebase_service.dart';

/// VideoService handles 30-second video recordings and uploading to Firebase Storage.
class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  CameraController? _controller;
  CameraDescription? _camera;

  final FirebaseService _firebaseService = FirebaseService();

  /// Initialize camera (call from UI before recording if possible)
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        AppLogger.w('VideoService: No cameras available');
        return;
      }
      _camera = cameras.first;
      _controller = CameraController(_camera!, ResolutionPreset.high, enableAudio: true);
      await _controller!.initialize();
      AppLogger.i('VideoService: Camera initialized');
    } catch (e, st) {
      AppLogger.e('VideoService: Camera initialization failed', e, st);
    }
  }

  /// Start recording for [durationSec] seconds. Returns local file path or null.
  Future<String?> startRecording({required String eventId, int durationSec = AppConstants.sosVideoRecordDurationSec}) async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        await initialize();
        if (_controller == null || !_controller!.value.isInitialized) {
          AppLogger.w('VideoService: Controller not ready');
          return null;
        }
      }

      final dir = await getTemporaryDirectory();
      final filename = '${eventId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${dir.path}/$filename';

      await _controller!.startVideoRecording();
      AppLogger.i('VideoService: Recording started -> $filePath');

      // Wait for duration
      await Future.delayed(Duration(seconds: durationSec));

      final file = await _controller!.stopVideoRecording();
      // Move file to expected path (some platforms return XFile)
      final recordedPath = file.path;
      final recordedFile = File(recordedPath);
      final target = File(filePath);
      await recordedFile.copy(target.path);

      AppLogger.i('VideoService: Recording stopped, saved to $filePath');
      return filePath;
    } catch (e, st) {
      AppLogger.e('VideoService: Recording failed', e, st);
      return null;
    }
  }

  /// Convenience wrapper to record an emergency video with an auto-generated event id.
  /// Returns the local file path when recording completes. The caller may start
  /// this future and continue execution without awaiting it if they wish to
  /// perform other tasks concurrently (e.g., continue SOS orchestration).
  Future<String?> recordEmergencyVideo({int durationSec = AppConstants.sosVideoRecordDurationSec}) async {
    final eventId = 'evid_${DateTime.now().millisecondsSinceEpoch}';
    return await startRecording(eventId: eventId, durationSec: durationSec);
  }

  /// Upload local video file to Firebase Storage under evidence path.
  /// Returns public download URL or null.
  Future<String?> uploadToFirebaseStorage({required String localPath, required String eventId}) async {
    try {
      await _firebaseService.init();
      final file = File(localPath);
      if (!file.existsSync()) {
        AppLogger.w('VideoService: file does not exist $localPath');
        return null;
      }

      final storageRef = _firebaseService.storage.ref().child('${AppConstants.firebaseEvidencePath}/$eventId.mp4');
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.i('VideoService: Uploaded to $downloadUrl');
      return downloadUrl;
    } catch (e, st) {
      AppLogger.e('VideoService: Upload failed', e, st);
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}

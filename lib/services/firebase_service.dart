import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../../firebase_options.dart';

/// FirebaseService centralizes Firebase initialization and exposes
/// commonly used Firebase instances as singletons.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false;

  FirebaseApp? _app;

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseApp? get app => _app; // expose for RTDB instanceFor()

  /// Initialize Firebase if not already initialized. Safe to call multiple times.
  Future<FirebaseApp> init() async {
    if (_initialized && _app != null) return _app!;
    try {
      // If Firebase.apps is non-empty, Firebase was already initialized
      // (e.g. in main() or by a previous call). Reuse the default app.
      if (Firebase.apps.isNotEmpty) {
        _app = Firebase.app();
        _initialized = true;
        return _app!;
      }
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      AppLogger.i('FirebaseService: Firebase initialized');
      return _app!;
    } catch (e, st) {
      AppLogger.e('FirebaseService: Firebase initialization failed', e, st);
      rethrow;
    }
  }

  /// Lightweight Firestore write test for verifying Firebase setup.
  /// Writes a timestamped document to `setup_checks/firebase_smoke_test` only in debug mode.
  Future<void> smokeTest() async {
    if (!kDebugMode) return;

    try {
      await init();
      final doc =
          firestore.collection('setup_checks').doc('firebase_smoke_test');
      await doc.set(<String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'app': 'SheShield',
        'status': 'ok',
      }, SetOptions(merge: true));
      AppLogger.i('FirebaseService: smoke test write succeeded');
    } catch (e, st) {
      AppLogger.e('FirebaseService: smoke test write failed', e, st);
    }
  }
}

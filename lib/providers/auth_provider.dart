import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../core/utils/logger.dart';
import 'app_state.dart';

/// Authentication provider for managing user auth state and operations.
/// Handles Firebase Auth login/signup/logout and user profile management.
class AuthProvider extends ChangeNotifier {
  // Lazy getters — only accessed after Firebase.initializeApp() has completed.
  // Using field initializers like `FirebaseAuth.instance` would crash if
  // the provider is constructed before Firebase is ready.
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  StreamSubscription<User?>? _authStateSubscription;

  // ========== STATE ==========
  User? _currentFirebaseUser;
  UserModel? _currentAppUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Reference to central AppState (set by main.dart via ChangeNotifierProxyProvider)
  AppState? appState;

  // ========== GETTERS ==========
  User? get currentFirebaseUser => _currentFirebaseUser;
  UserModel? get currentAppUser => _currentAppUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentFirebaseUser != null;

  // ========== INITIALIZATION ==========
  AuthProvider({AppState? appState}) {
    this.appState = appState;
    _initializeAuthState();
  }

  /// Initialize auth state on provider creation
  void _initializeAuthState() {
    _currentFirebaseUser = _firebaseAuth.currentUser;
    if (_currentFirebaseUser != null) {
      _loadAppUser();
    }

    // Listen to auth state changes
    _authStateSubscription?.cancel();
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      _currentFirebaseUser = user;
      if (user != null) {
        _loadAppUser();
      } else {
        _currentAppUser = null;
        appState?.clearCurrentUser();
      }
      notifyListeners();
    });
  }

  /// Load app user from Firestore
  Future<void> _loadAppUser() async {
    if (_currentFirebaseUser == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentFirebaseUser!.uid)
          .get();

      if (doc.exists) {
        _currentAppUser = UserModel.fromFirestore(doc);
        appState?.setCurrentUser(_currentAppUser);
        AppLogger.i('App user loaded: ${_currentAppUser?.email}');
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error loading app user', e, stackTrace);
    }
  }

  // ========== LOGIN ==========
  /// Login with email and password
  /// Returns true on success, false on failure
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _currentFirebaseUser = userCredential.user;

      // Load app user data
      await _loadAppUser();

      AppLogger.i('Login successful: ${userCredential.user?.email}');
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      _setLoading(false);
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Login error', e, stackTrace);
      _setError('Login failed');
      _setLoading(false);
      return false;
    }
  }

  // ========== SIGNUP ==========
  /// Signup with email, password, and display name
  /// Returns true on success, false on failure
  Future<bool> signup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _currentFirebaseUser = userCredential.user;

      // Update Firebase Auth profile (replace deprecated updateProfile)
      await userCredential.user?.updateDisplayName(displayName);

      // Create Firestore user document
      final newUser = UserModel(
        userId: userCredential.user!.uid,
        email: email.trim(),
        displayName: displayName,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(newUser.userId)
          .set(newUser.toFirestore());

      _currentAppUser = newUser;
      appState?.setCurrentUser(_currentAppUser);

      AppLogger.i('Signup successful: ${userCredential.user?.email}');
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      _setLoading(false);
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Signup error', e, stackTrace);
      _setError('Signup failed');
      _setLoading(false);
      return false;
    }
  }

  // ========== LOGOUT ==========
  /// Logout current user
  /// Returns true on success
  Future<bool> logout() async {
    _setLoading(true);
    _clearError();

    try {
      await _firebaseAuth.signOut();
      _currentFirebaseUser = null;
      _currentAppUser = null;
      appState?.clearCurrentUser();
      appState?.reset();

      AppLogger.i('Logout successful');
      _setLoading(false);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Logout error', e, stackTrace);
      _setError('Logout failed');
      _setLoading(false);
      return false;
    }
  }

  // ========== UPDATE PROFILE ==========
  /// Update user profile (display name)
  Future<bool> updateProfile({required String displayName}) async {
    if (_currentFirebaseUser == null || _currentAppUser == null) return false;

    try {
      // Update Firebase Auth (replace deprecated updateProfile)
      await _currentFirebaseUser?.updateDisplayName(displayName);

      // Update Firestore
      final updatedUser = _currentAppUser!.copyWith(displayName: displayName);
      await _firestore
          .collection('users')
          .doc(_currentAppUser!.userId)
          .update(updatedUser.toFirestore());

      _currentAppUser = updatedUser;
      appState?.setCurrentUser(_currentAppUser);

      AppLogger.i('Profile updated');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error updating profile', e, stackTrace);
      return false;
    }
  }

  // ========== SETTINGS UPDATES ==========
  /// Update user settings
  Future<bool> updateSettings({
    bool? isStealthModeEnabled,
    bool? isVoiceTriggerEnabled,
    bool? isAudioTriggerEnabled,
    bool? isJourneyModeAutoArm,
  }) async {
    if (_currentAppUser == null) return false;

    try {
      final updates = <String, dynamic>{};

      if (isStealthModeEnabled != null) {
        updates['isStealthModeEnabled'] = isStealthModeEnabled;
      }
      if (isVoiceTriggerEnabled != null) {
        updates['isVoiceTriggerEnabled'] = isVoiceTriggerEnabled;
      }
      if (isAudioTriggerEnabled != null) {
        updates['isAudioTriggerEnabled'] = isAudioTriggerEnabled;
      }
      if (isJourneyModeAutoArm != null) {
        updates['isJourneyModeAutoArm'] = isJourneyModeAutoArm;
      }

      await _firestore
          .collection('users')
          .doc(_currentAppUser!.userId)
          .update(updates);

      // Update local user model
      _currentAppUser = _currentAppUser!.copyWith(
        isStealthModeEnabled:
            isStealthModeEnabled ?? _currentAppUser!.isStealthModeEnabled,
        isVoiceTriggerEnabled:
            isVoiceTriggerEnabled ?? _currentAppUser!.isVoiceTriggerEnabled,
        isAudioTriggerEnabled:
            isAudioTriggerEnabled ?? _currentAppUser!.isAudioTriggerEnabled,
        isJourneyModeAutoArm:
            isJourneyModeAutoArm ?? _currentAppUser!.isJourneyModeAutoArm,
      );

      appState?.setCurrentUser(_currentAppUser);

      AppLogger.i('User settings updated');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error updating settings', e, stackTrace);
      return false;
    }
  }

  // ========== PRIVATE HELPERS ==========
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Handle Firebase Auth exceptions
  void _handleAuthException(FirebaseAuthException e) {
    final message = switch (e.code) {
      'user-not-found' => 'No user found with this email.',
      'wrong-password' => 'Incorrect password.',
      'email-already-in-use' => 'This email is already registered.',
      'weak-password' => 'Password is too weak.',
      'invalid-email' => 'Invalid email address.',
      'operation-not-allowed' => 'This operation is not allowed.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      _ => e.message ?? 'Authentication error occurred',
    };

    _setError(message);
    AppLogger.w('Auth error (${e.code}): $message');
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

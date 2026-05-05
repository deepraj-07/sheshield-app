import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/utils/logger.dart';
import '../core/constants/app_constants.dart';

/// LocationService handles all GPS location operations.
/// Singleton pattern — persistent instance across app lifetime.
/// Provides real-time location tracking and reverse geocoding.
class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  // ========== STATE ==========
  bool _isLocationServiceEnabled = false;
  LocationPermission? _permissionStatus;

  // ========== GETTERS ==========
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  LocationPermission? get permissionStatus => _permissionStatus;

  // ========== INITIALIZATION ==========
  /// Initialize location service — call once on app startup
  Future<bool> initialize() async {
    try {
      // Check if location service is enabled
      _isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!_isLocationServiceEnabled) {
        AppLogger.w('Location service is disabled');
        return false;
      }

      // Request permission
      _permissionStatus = await Geolocator.checkPermission();

      if (_permissionStatus == LocationPermission.denied) {
        _permissionStatus = await Geolocator.requestPermission();
      }

      if (_permissionStatus == LocationPermission.deniedForever) {
        AppLogger.w('Location permission denied forever');
        return false;
      }

      AppLogger.serviceEvent('LocationService', 'Initialized successfully');
      return _permissionStatus == LocationPermission.whileInUse ||
          _permissionStatus == LocationPermission.always;
    } catch (e, stackTrace) {
      AppLogger.e('LocationService initialization error', e, stackTrace);
      return false;
    }
  }

  // ========== GET CURRENT LOCATION ==========
  /// Get current GPS coordinates with timeout
  /// Returns Position or null if failed
  Future<Position?> getCurrentLocation() async {
    try {
      if (!_isLocationServiceEnabled) {
        AppLogger.w('Location service not enabled');
        return null;
      }

      if (_permissionStatus != LocationPermission.whileInUse &&
          _permissionStatus != LocationPermission.always) {
        AppLogger.w('Location permission not granted');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: AppConstants.bluetoothConnectionTimeoutSec),
      );

      AppLogger.i(
        'Current location: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e, stackTrace) {
      AppLogger.e('Error getting current location', e, stackTrace);
      return null;
    }
  }

  /// Get current location with last known fallback
  /// Returns Position or null
  Future<Position?> getCurrentLocationWithFallback() async {
    try {
      // Try to get current position
      final currentPosition = await getCurrentLocation();
      if (currentPosition != null) return currentPosition;

      // Fallback to last known position
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        AppLogger.i('Using last known position');
        return lastPosition;
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Error getting location with fallback', e, stackTrace);
      return null;
    }
  }

  // ========== REVERSE GEOCODING ==========
  /// Get address from coordinates
  /// Returns address string or null if failed
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final address = _buildAddressString(place);

      AppLogger.i('Reverse geocoded address: $address');
      return address;
    } catch (e, stackTrace) {
      AppLogger.e('Error reverse geocoding', e, stackTrace);
      return null;
    }
  }

  /// Build readable address from Placemark
  String _buildAddressString(Placemark place) {
    final components = <String>[
      if (place.street != null && place.street!.isNotEmpty) place.street!,
      if (place.locality != null && place.locality!.isNotEmpty) place.locality!,
      if (place.administrativeArea != null &&
          place.administrativeArea!.isNotEmpty)
        place.administrativeArea!,
      if (place.postalCode != null && place.postalCode!.isNotEmpty)
        place.postalCode!,
      if (place.country != null && place.country!.isNotEmpty) place.country!,
    ];

    return components.join(', ');
  }

  // ========== DISTANCE CALCULATION ==========
  /// Calculate distance between two coordinates in meters
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    try {
      final distance = Geolocator.distanceBetween(
        startLat,
        startLng,
        endLat,
        endLng,
      );

      return distance;
    } catch (e, stackTrace) {
      AppLogger.e('Error calculating distance', e, stackTrace);
      return 0;
    }
  }

  /// Check if position is within radius (in meters)
  bool isWithinRadius(
    double centerLat,
    double centerLng,
    double checkLat,
    double checkLng,
    double radiusMeters,
  ) {
    final distance = calculateDistance(
      centerLat,
      centerLng,
      checkLat,
      checkLng,
    );

    return distance <= radiusMeters;
  }

  // ========== LOCATION TRACKING ==========
  /// Start listening to position updates
  /// Returns Stream of Position updates
  Stream<Position> getPositionStream() {
    try {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: AppConstants.locationDistanceFilterM.toInt(),
          timeLimit: Duration(
            milliseconds: AppConstants.locationUpdateIntervalMs,
          ),
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('Error creating position stream', e, stackTrace);
      return Stream.empty();
    }
  }

  // ========== GOOGLE MAPS HELPERS ==========
  /// Generate Google Maps location URL for sharing
  String generateGoogleMapsUrl(double latitude, double longitude) {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// Generate Google Maps directions URL
  String generateDirectionsUrl(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return 'https://maps.google.com/maps/dir/$startLat,$startLng/$endLat,$endLng';
  }

  // ========== OPENSTREETMAP HELPERS ==========
  /// Generate OSM (OpenStreetMap) URL for location
  String generateOpenStreetMapUrl(double latitude, double longitude) {
    return 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude&zoom=18';
  }

  @override
  String toString() => 'LocationService(enabled: $_isLocationServiceEnabled)';
}

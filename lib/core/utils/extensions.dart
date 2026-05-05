import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Useful extension methods for common Dart and Flutter types.
/// These enhance readability and reduce boilerplate code.

/// Extensions on [String]
extension StringExtensions on String {
  /// Check if string is a valid email
  bool get isEmail {
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    return RegExp(emailRegex).hasMatch(this);
  }

  /// Check if string is a valid URL
  bool get isUrl {
    try {
      Uri.parse(this);
      return startsWith('http://') || startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  /// Check if string is numeric
  bool get isNumeric {
    return double.tryParse(this) != null;
  }

  /// Check if string is empty or whitespace only
  bool get isBlank => trim().isEmpty;

  /// Get initials from a name string
  /// Example: "John Doe" -> "JD"
  String get initials {
    final parts = split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Convert string to title case
  String get toTitleCase {
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Truncate string to max length with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  /// Remove all whitespace
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');

  /// Get clean phone number (digits only)
  String get cleanPhoneNumber => replaceAll(RegExp(r'[^\d+]'), '');
}

/// Extensions on [DateTime]
extension DateTimeExtensions on DateTime {
  /// Format as readable date string (e.g., "Jan 5, 2024")
  String get formattedDate {
    return DateFormat('MMM d, yyyy').format(this);
  }

  /// Format as readable time string (e.g., "2:30 PM")
  String get formattedTime {
    return DateFormat('h:mm a').format(this);
  }

  /// Format as readable date and time (e.g., "Jan 5, 2024 2:30 PM")
  String get formattedDateTime {
    return DateFormat('MMM d, yyyy h:mm a').format(this);
  }

  /// Format as ISO 8601 string
  String get iso8601 => toIso8601String();

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Get time elapsed since this datetime
  /// Returns string like "2 hours ago", "3 days ago"
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return formattedDate;
    }
  }
}

/// Extensions on [double]
extension DoubleExtensions on double {
  /// Format as currency string (e.g., "$99.99")
  String toCurrency({String symbol = '\$'}) {
    return '$symbol${toStringAsFixed(2)}';
  }

  /// Format to N decimal places
  String toDecimalPlaces(int places) {
    return toStringAsFixed(places);
  }

  /// Check if number is between min and max (inclusive)
  bool isBetween(double min, double max) {
    return this >= min && this <= max;
  }

  /// Convert meters to kilometers
  double get toKilometers => this / 1000;

  /// Convert kilometers to meters
  double get toMeters => this * 1000;

  /// Round to nearest value
  double roundToNearest(double nearest) {
    return (this / nearest).round() * nearest;
  }
}

/// Extensions on [int]
extension IntExtensions on int {
  /// Check if number is even
  bool get isEven => this % 2 == 0;

  /// Check if number is odd
  bool get isOdd => this % 2 != 0;

  /// Convert milliseconds to seconds
  double get toSeconds => this / 1000;

  /// Convert seconds to milliseconds
  int get toMilliseconds => this * 1000;

  /// Convert milliseconds to duration
  Duration get toDuration => Duration(milliseconds: this);

  /// Format as time duration string (e.g., "2:30:45")
  String get toTimeDuration {
    final duration = Duration(seconds: this);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Extensions on [BuildContext]
extension BuildContextExtensions on BuildContext {
  /// Get device width
  double get width => MediaQuery.of(this).size.width;

  /// Get device height
  double get height => MediaQuery.of(this).size.height;

  /// Check if device is in portrait mode
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;

  /// Check if device is in landscape mode
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;

  /// Check if device has small screen (< 600 dp)
  bool get isSmallScreen => width < 600;

  /// Check if device has medium screen (600-900 dp)
  bool get isMediumScreen => width >= 600 && width < 900;

  /// Check if device has large screen (>= 900 dp)
  bool get isLargeScreen => width >= 900;

  /// Get device padding (safe area)
  EdgeInsets get padding => MediaQuery.of(this).padding;

  /// Get device view insets (keyboard height, etc)
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;

  /// Check if keyboard is visible
  bool get isKeyboardVisible => viewInsets.bottom > 0;

  /// Get device text scale factor
  double get textScaleFactor => MediaQuery.of(this).textScaleFactor;

  /// Push named route
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    return Navigator.pushNamed<T>(this, routeName, arguments: arguments);
  }

  /// Pop route
  void pop<T>([T? result]) => Navigator.pop(this, result);

  /// Push route and replace current
  Future<T?> pushReplacementNamed<T>(String routeName, {Object? arguments}) {
    return Navigator.pushReplacementNamed<T, Object?>(this, routeName, arguments: arguments);
  }

  /// Show snackbar
  void showSnackBar(String message, {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  /// Show error snackbar
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// Extensions on [List<T>]
extension ListExtensions<T> on List<T> {
  /// Check if list is empty or null
  bool get isEmpty => length == 0;

  /// Check if list is not empty
  bool get isNotEmpty => length > 0;

  /// Get first element safely or return null
  T? get firstOrNull => isNotEmpty ? first : null;

  /// Get last element safely or return null
  T? get lastOrNull => isNotEmpty ? last : null;

  /// Get element at index safely or return null
  T? getOrNull(int index) {
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }

  /// Partition list into chunks of given size
  List<List<T>> partition(int size) {
    if (size <= 0) return [];
    final result = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      result.add(sublist(i, i + size > length ? length : i + size));
    }
    return result;
  }

  /// Remove duplicates from list
  List<T> get unique => toSet().toList();

  /// Check if all elements match condition
  bool allMatch(bool Function(T) condition) => every(condition);

  /// Check if any element matches condition
  bool anyMatch(bool Function(T) condition) => any(condition);
}

/// Extensions on [Map<K, V>]
extension MapExtensions<K, V> on Map<K, V> {
  /// Get value safely or return default
  V? getOrNull(K key) => this[key];

  /// Check if map is empty
  bool get isEmpty => length == 0;

  /// Check if map is not empty
  bool get isNotEmpty => length > 0;

  /// Merge another map into this one
  Map<K, V> merge(Map<K, V> other) {
    return {...this, ...other};
  }
}

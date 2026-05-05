import '../constants/app_strings.dart';
import '../constants/app_constants.dart';

/// Input validation utilities for forms and user inputs.
/// All validation logic centralized for consistency and easy modification.
class Validators {
  /// Validate email format
  /// Returns error message if invalid, null if valid
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.email_hint;
    }
    
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    if (!RegExp(emailRegex).hasMatch(value.trim())) {
      return AppStrings.invalidEmail;
    }
    
    return null;
  }

  /// Validate password strength
  /// Returns error message if invalid, null if valid
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.password_hint;
    }
    
    if (value.length < AppConstants.minPasswordLength) {
      return '${AppStrings.passwordTooShort} (${AppConstants.minPasswordLength})';
    }
    
    return null;
  }

  /// Validate password match (for confirmation)
  /// Returns error message if passwords don't match, null if valid
  static String? validatePasswordMatch(String? password, String? confirmPassword) {
    if (password != confirmPassword) {
      return AppStrings.passwordMismatch;
    }
    return null;
  }

  /// Validate contact name
  /// Returns error message if invalid, null if valid
  static String? validateContactName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '${AppStrings.contactName} is required';
    }
    
    if (value.length > AppConstants.maxContactNameLength) {
      return 'Name must be less than ${AppConstants.maxContactNameLength} characters';
    }
    
    return null;
  }

  /// Validate phone number (basic format)
  /// Accepts 10-15 digit phone numbers with optional +, -, spaces
  /// Returns error message if invalid, null if valid
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '${AppStrings.contactPhone} is required';
    }
    
    // Remove spaces, dashes, +
    final cleanedPhone = value.replaceAll(RegExp(r'[\s\-+]'), '');
    
    // Check if only digits
    if (!RegExp(r'^\d{10,15}$').hasMatch(cleanedPhone)) {
      return 'Phone number must be 10-15 digits';
    }
    
    return null;
  }

  /// Validate display name
  /// Returns error message if invalid, null if valid
  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '${AppStrings.displayName} is required';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (value.length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    return null;
  }

  /// Validate latitude coordinate (-90 to 90)
  /// Returns error message if invalid, null if valid
  static String? validateLatitude(double? value) {
    if (value == null) return 'Invalid latitude';
    if (value < -90 || value > 90) return 'Latitude must be between -90 and 90';
    return null;
  }

  /// Validate longitude coordinate (-180 to 180)
  /// Returns error message if invalid, null if valid
  static String? validateLongitude(double? value) {
    if (value == null) return 'Invalid longitude';
    if (value < -180 || value > 180) return 'Longitude must be between -180 and 180';
    return null;
  }

  /// Validate that a list is not empty
  /// Returns error message if empty, null if valid
  static String? validateListNotEmpty<T>(List<T>? list, String fieldName) {
    if (list == null || list.isEmpty) {
      return '$fieldName cannot be empty';
    }
    return null;
  }

  /// Validate that a list doesn't exceed max count
  /// Returns error message if exceeded, null if valid
  static String? validateListMaxCount<T>(List<T>? list, int maxCount, String fieldName) {
    if (list != null && list.length > maxCount) {
      return '$fieldName cannot have more than $maxCount items';
    }
    return null;
  }

  /// Generic string field validator (non-empty)
  /// Returns error message if invalid, null if valid
  static String? validateRequiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate minimum length for string
  /// Returns error message if too short, null if valid
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  /// Validate maximum length for string
  /// Returns error message if too long, null if valid
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value != null && value.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }
    return null;
  }

  /// Validate URL format
  /// Returns error message if invalid, null if valid
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL is required';
    }
    
    try {
      Uri.parse(value);
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return null;
      }
      return 'URL must start with http:// or https://';
    } catch (e) {
      return 'Invalid URL format';
    }
  }
}

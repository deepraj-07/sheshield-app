import 'dart:io';

import 'package:logger/logger.dart';

/// Centralized logging utility for SheShield app.
/// Provides consistent structured logging across all services.
/// Use this instead of print() for better debugging and log management.
class AppLogger {
  static String _timestamp() => DateTime.now().toIso8601String();

  static String _format(String tag, String message, {String? step}) {
    final stepPart = step == null ? '' : '[$step]';
    return '[${_timestamp()}][$tag]$stepPart $message';
  }

  static final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: ConsoleOutput(),
  );

  /// Log verbose message (for detailed debug info)
  static void v(String message, [dynamic error, StackTrace? stackTrace]) {
    // Use trace level (t) instead of deprecated verbose (v)
    _logger.t(_format('DEBUG', message), error: error, stackTrace: stackTrace);
  }

  /// Log debug message
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(_format('DEBUG', message), error: error, stackTrace: stackTrace);
  }

  /// Log info message
  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_format('INFO', message), error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_format('WARN', message), error: error, stackTrace: stackTrace);
  }

  /// Log error message (with optional exception and stack trace)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_format('ERROR', message), error: error, stackTrace: stackTrace);
  }

  /// Log what the fuck message (critical error)
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    // Use fatal level (f) instead of deprecated wtf
    _logger.f(_format('CRITICAL', message), error: error, stackTrace: stackTrace);
  }

  /// Log a tagged step message in the format [TIME][TAG][STEP] message.
  static void step(String tag, String step, String message) {
    _logger.i(_format(tag, message, step: step));
  }

  /// Log a tagged message.
  static void tag(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_format(tag, message), error: error, stackTrace: stackTrace);
  }

  /// Log a tagged error with stack trace.
  static void taggedError(String tag, String message, dynamic error, StackTrace? stackTrace) {
    _logger.e(_format(tag, message), error: error, stackTrace: stackTrace);
  }

  /// Log service lifecycle events
  static void serviceEvent(String serviceName, String event) {
    tag(serviceName, event);
  }

  /// Log SOS flow step
  static void sosStep(int step, String description) {
    AppLogger.step('SOS', 'STEP $step', description);
  }

  /// Log provider state change
  static void providerStateChange(String providerName, String newState) {
    tag(providerName, 'State changed to: $newState');
  }
}

/// Filter for production/debug logging
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In production, filter out verbose logs
    // In debug, show all logs
    return true; // Show all logs for now (can be toggled via env var)
  }
}

/// Custom output for console logging
class ConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // ignore: avoid_print
      stdout.writeln(line);
    }
  }
}

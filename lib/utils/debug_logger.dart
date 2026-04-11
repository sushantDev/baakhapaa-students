import 'package:flutter/foundation.dart';

/// Centralized debug logging utility for the entire app
/// All debug DebugLogger.info statements should use this instead of direct DebugLogger.info()
class DebugLogger {
  static const String _puppetPrefix = '🎭';
  static const String _authPrefix = '🔐';
  static const String _apiPrefix = '🌐';
  static const String _errorPrefix = '❌';
  static const String _successPrefix = '✅';
  static const String _warningPrefix = '⚠️';
  static const String _infoPrefix = 'ℹ️';

  /// General debug log - only prints in debug mode
  static void log(String message, {String? prefix}) {
    if (kDebugMode) {
      final finalMessage = prefix != null ? '$prefix $message' : message;
      print(finalMessage);
    }
  }

  /// Puppet system specific logs
  static void puppet(String message) {
    if (kDebugMode) {
      print('$_puppetPrefix $message');
    }
  }

  /// Authentication related logs
  static void auth(String message) {
    if (kDebugMode) {
      print('$_authPrefix $message');
    }
  }

  /// API call related logs
  static void api(String message) {
    if (kDebugMode) {
      print('$_apiPrefix $message');
    }
  }

  /// Error logs - only print in debug mode to avoid release performance impact.
  /// For production error tracking, use Sentry instead of print statements.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('$_errorPrefix $message');
      if (error != null) {
        print('Error details: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Success logs
  static void success(String message) {
    if (kDebugMode) {
      print('$_successPrefix $message');
    }
  }

  /// Warning logs
  static void warning(String message) {
    if (kDebugMode) {
      print('$_warningPrefix $message');
    }
  }

  /// Info logs
  static void info(String message) {
    if (kDebugMode) {
      print('$_infoPrefix $message');
    }
  }

  /// Network/API response logs with pretty formatting
  static void apiResponse(String endpoint, Map<String, dynamic> response) {
    if (kDebugMode) {
      print('$_apiPrefix API Response from $endpoint:');
      print('  Success: ${response['success'] ?? 'Unknown'}');
      print('  Code: ${response['code'] ?? 'Unknown'}');
      print('  Message: ${response['message'] ?? 'No message'}');
      if (response['data'] != null) {
        print(
            '  Data keys: ${(response['data'] as Map?)?.keys.join(', ') ?? 'None'}');
      }
    }
  }

  /// Performance logging for tracking operations
  static void performance(String operation, Duration duration) {
    if (kDebugMode) {
      print('⏱️ Performance: $operation took ${duration.inMilliseconds}ms');
    }
  }

  /// Feature flag or conditional logging
  static void feature(String featureName, String message) {
    if (kDebugMode) {
      print('🎛️ Feature [$featureName]: $message');
    }
  }
}

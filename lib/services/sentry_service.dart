import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../utils/debug_logger.dart';

class SentryService {
  // Replace this with your actual Sentry DSN from https://sentry.io
  static const String _dsn =
      'https://0365656c51653c735a02aec448f49620@o4510028176883712.ingest.de.sentry.io/4510028180553808';

  /// Initialize Sentry with configuration
  static Future<void> initSentry(Function() appRunner) async {
    await SentryFlutter.init(
      (options) {
        // Set your Sentry DSN here
        options.dsn = _dsn;

        // Set the sample rate for performance monitoring
        options.tracesSampleRate =
            1.0; // 100% in development, consider lowering in production

        // Set the sample rate for profiling
        options.profilesSampleRate =
            1.0; // 100% in development, consider lowering in production

        // Capture failed HTTP requests
        options.captureFailedRequests = true;

        // Set environment
        options.environment =
            'production'; // Change to 'development' for dev builds

        // Release version
        options.release = 'baakhapaa@3.0.30+113';

        // Additional configurations
        options.attachStacktrace = true;
        options.enableAutoSessionTracking = true;
        options.autoSessionTrackingInterval = Duration(seconds: 30);

        // Debug settings (disable in production)
        options.debug = false; // Set to true for debugging

        // Before send callback to filter or modify events
        options.beforeSend = (SentryEvent event, Hint hint) {
          // You can filter events here
          return event;
        };
      },
      appRunner: appRunner,
    );
  }

  /// Capture custom exception
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? tag,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (tag != null) {
          scope.setTag('custom_tag', tag);
        }
        if (extra != null) {
          scope.setContexts('extra_data', extra);
        }
      },
    );
  }

  /// Capture custom message
  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String? tag,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (tag != null) {
          scope.setTag('custom_tag', tag);
        }
        if (extra != null) {
          scope.setContexts('extra_data', extra);
        }
      },
    );
  }

  /// Add breadcrumb for debugging
  static void addBreadcrumb(
    String message, {
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: data,
      ),
    );
  }

  /// Set user information
  static Future<void> setUser({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic>? data,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: data,
      ));
    });
  }

  /// Clear user information
  static Future<void> clearUser() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Set custom tag
  static Future<void> setTag(String key, String value) async {
    await Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }

  /// Start a transaction for performance monitoring
  static ISentrySpan startTransaction(String name, String operation) {
    return Sentry.startTransaction(name, operation);
  }

  /// Test Sentry integration
  static void testSentryIntegration() {
    try {
      DebugLogger.info('Sentry integration test started');
      addBreadcrumb('Sentry test initiated', category: 'test');
      captureMessage('Sentry integration test successful',
          level: SentryLevel.info);
      DebugLogger.info('Sentry integration is working correctly');
    } catch (e) {
      DebugLogger.info('Sentry integration test failed: $e');
    }
  }
}

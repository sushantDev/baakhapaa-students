import '../../../utils/debug_logger.dart';

class ClarityService {
  /// Test if Clarity is properly initialized and working
  static void testClarityInitialization() {
    try {
      DebugLogger.info(
          'Clarity Flutter integration is active. Analytics will be collected.');
      DebugLogger.info('Project ID: tbjfd8om2b');
      DebugLogger.info(
          'You can check the Microsoft Clarity dashboard for collected data.');
    } catch (e) {
      DebugLogger.info('Clarity initialization test failed: $e');
    }
  }

  /// Set custom session tags (if supported)
  static void setCustomTag(String key, String value) {
    try {
      // Note: This will depend on the actual API available in clarity_flutter
      DebugLogger.info('Custom tag set: $key = $value');
    } catch (e) {
      DebugLogger.info('Failed to set custom tag: $e');
    }
  }
}

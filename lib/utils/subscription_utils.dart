import '../../../utils/debug_logger.dart';

/// Utility functions for handling subscription-related operations
class SubscriptionUtils {
  // Temporary override for testing - set to true to force premium badges
  static const bool _forcePremiumForTesting = false;

  /// Check if a user has an active premium subscription
  static bool hasActiveSubscription(Map<String, dynamic> userData) {
    // Temporary override for testing
    if (_forcePremiumForTesting) {
      DebugLogger.info(
          '🔍 DEBUG: FORCE PREMIUM ENABLED - showing premium badge for testing');
      return true;
    }
    // Check multiple possible field names and locations
    dynamic subscriptionExpiresAt;

    // Check direct fields
    if (userData.containsKey('subscription_expires_at')) {
      subscriptionExpiresAt = userData['subscription_expires_at'];
    } else if (userData.containsKey('subscription_expires')) {
      subscriptionExpiresAt = userData['subscription_expires'];
    } else if (userData.containsKey('subscription_end_date')) {
      subscriptionExpiresAt = userData['subscription_end_date'];
    } else if (userData.containsKey('premium_expires_at')) {
      subscriptionExpiresAt = userData['premium_expires_at'];
    }

    // Check in information object if not found in root
    if (subscriptionExpiresAt == null && userData.containsKey('information')) {
      final info = userData['information'];
      if (info is Map<String, dynamic>) {
        if (info.containsKey('subscription_expires_at')) {
          subscriptionExpiresAt = info['subscription_expires_at'];
        } else if (info.containsKey('subscription_expires')) {
          subscriptionExpiresAt = info['subscription_expires'];
        } else if (info.containsKey('subscription_end_date')) {
          subscriptionExpiresAt = info['subscription_end_date'];
        } else if (info.containsKey('premium_expires_at')) {
          subscriptionExpiresAt = info['premium_expires_at'];
        }
      }
    }

    // Check for subscription object
    if (subscriptionExpiresAt == null && userData.containsKey('subscription')) {
      final subscription = userData['subscription'];
      if (subscription is Map<String, dynamic>) {
        if (subscription.containsKey('expires_at')) {
          subscriptionExpiresAt = subscription['expires_at'];
        } else if (subscription.containsKey('end_date')) {
          subscriptionExpiresAt = subscription['end_date'];
        } else if (subscription.containsKey('expires')) {
          subscriptionExpiresAt = subscription['expires'];
        }
      }
    }

    if (subscriptionExpiresAt == null) {
      DebugLogger.info(
          '🔍 DEBUG: No subscription expiry field found for user: ${userData['username'] ?? userData['email'] ?? 'unknown'}');
      return false;
    }

    try {
      final expiryDate = DateTime.parse(subscriptionExpiresAt.toString());
      final now = DateTime.now();
      final isActive = expiryDate.isAfter(now);

      DebugLogger.info(
          '🔍 DEBUG: User ${userData['username'] ?? userData['email'] ?? 'unknown'} has subscription expiring: $expiryDate (Active: $isActive)');

      return isActive;
    } catch (e) {
      DebugLogger.info(
          '🔍 DEBUG: Error parsing subscription date for user ${userData['username'] ?? userData['email'] ?? 'unknown'}: $e');
      return false;
    }
  }

  /// Get subscription expiry date
  static DateTime? getSubscriptionExpiryDate(Map<String, dynamic> userData) {
    // Use same logic as hasActiveSubscription to find the expiry field
    dynamic subscriptionExpiresAt;

    // Check direct fields
    if (userData.containsKey('subscription_expires_at')) {
      subscriptionExpiresAt = userData['subscription_expires_at'];
    } else if (userData.containsKey('subscription_expires')) {
      subscriptionExpiresAt = userData['subscription_expires'];
    } else if (userData.containsKey('subscription_end_date')) {
      subscriptionExpiresAt = userData['subscription_end_date'];
    } else if (userData.containsKey('premium_expires_at')) {
      subscriptionExpiresAt = userData['premium_expires_at'];
    }

    // Check in information object
    if (subscriptionExpiresAt == null && userData.containsKey('information')) {
      final info = userData['information'];
      if (info is Map<String, dynamic>) {
        if (info.containsKey('subscription_expires_at')) {
          subscriptionExpiresAt = info['subscription_expires_at'];
        } else if (info.containsKey('subscription_expires')) {
          subscriptionExpiresAt = info['subscription_expires'];
        } else if (info.containsKey('subscription_end_date')) {
          subscriptionExpiresAt = info['subscription_end_date'];
        } else if (info.containsKey('premium_expires_at')) {
          subscriptionExpiresAt = info['premium_expires_at'];
        }
      }
    }

    // Check for subscription object
    if (subscriptionExpiresAt == null && userData.containsKey('subscription')) {
      final subscription = userData['subscription'];
      if (subscription is Map<String, dynamic>) {
        if (subscription.containsKey('expires_at')) {
          subscriptionExpiresAt = subscription['expires_at'];
        } else if (subscription.containsKey('end_date')) {
          subscriptionExpiresAt = subscription['end_date'];
        } else if (subscription.containsKey('expires')) {
          subscriptionExpiresAt = subscription['expires'];
        }
      }
    }

    if (subscriptionExpiresAt == null) return null;

    try {
      return DateTime.parse(subscriptionExpiresAt.toString());
    } catch (e) {
      return null;
    }
  }

  /// Get remaining time until subscription expires
  static Duration? getRemainingTime(Map<String, dynamic> userData) {
    final expiryDate = getSubscriptionExpiryDate(userData);
    if (expiryDate == null) return null;

    final now = DateTime.now();
    if (expiryDate.isBefore(now)) return Duration.zero;

    return expiryDate.difference(now);
  }

  /// Format remaining time as a readable string
  static String formatRemainingTime(Duration? duration) {
    if (duration == null || duration.isNegative) {
      return 'Expired';
    }

    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      if (hours > 0) {
        return '${days}d ${hours}h';
      }
      return '${days}d';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '< 1m';
    }
  }

  /// Check if subscription is expiring soon (within 7 days)
  static bool isExpiringSoon(Map<String, dynamic> userData) {
    final remainingTime = getRemainingTime(userData);
    if (remainingTime == null) return false;

    return remainingTime.inDays <= 7 && remainingTime.inDays >= 0;
  }
}

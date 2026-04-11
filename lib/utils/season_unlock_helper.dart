import '../../../utils/debug_logger.dart';

/// Helper utility for consistent season unlock logic across the app
///
/// This provides a centralized way to determine if a season should show
/// a lock icon or be accessible to the user.

/// Determines if a season is unlocked based on its lock and watched status
///
/// Logic:
/// 1. If `is_locked` is `false` → Always unlocked (no lock icon)
/// 2. If `is_locked` is `true` AND `watched` is `true` → Unlocked (user has access)
/// 3. If `is_locked` is `true` AND `watched` is `false` → Locked (show lock icon)
/// 4. If `is_locked` is `null`/undefined → Treat as free season (unlocked)
///
/// Returns `true` if season should be unlocked (no lock icon)
/// Returns `false` if season should be locked (show lock icon)
bool isSeasonUnlocked(Map<String, dynamic> season) {
  try {
    final isLocked = season['is_locked'];
    final watched = season['watched'];

    // If is_locked is false, season is unlocked regardless of watched status
    if (isLocked is bool && !isLocked) {
      return true;
    }

    // If is_locked is true, check if user has watched it
    if (isLocked is bool && isLocked) {
      if (watched is bool && watched) {
        return true; // Watched overrides lock
      } else {
        return false; // Locked and not watched
      }
    }

    // If is_locked is null/undefined, treat as free/unlocked season
    return true;
  } catch (e) {
    DebugLogger.info('Error checking season unlock status: $e');
    return false; // Default to locked on error for safety
  }
}

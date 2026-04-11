import 'dart:io';
import 'package:home_widget/home_widget.dart';
import '../utils/debug_logger.dart';

class HomeWidgetService {
  static const String _appGroupId = 'group.com.baakhapaa.com';
  static const String _androidWidgetName = 'ReadingStreakWidget';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      // Seed default widget data so freshly-pinned widgets render immediately
      final existing = await HomeWidget.getWidgetData<int>('streak_days');
      if (existing == null) {
        await HomeWidget.saveWidgetData<int>('streak_days', 0);
        await HomeWidget.saveWidgetData<int>('total_chapters', 0);
        await HomeWidget.saveWidgetData<int>('total_books', 0);
        await HomeWidget.saveWidgetData<String>('last_book', '');
        await HomeWidget.saveWidgetData<String>('streak_emoji', '📚');
      }
      // Always trigger widget update on init so native widget renders correctly
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _androidWidgetName,
      );
    } catch (e) {
      DebugLogger.error('📱 HomeWidget initialization failed: $e');
    }
  }

  static Future<void> updateWidget({
    required int currentStreak,
    required int totalChapters,
    required int totalBooks,
    String? lastBookTitle,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('streak_days', currentStreak);
      await HomeWidget.saveWidgetData<int>('total_chapters', totalChapters);
      await HomeWidget.saveWidgetData<int>('total_books', totalBooks);
      await HomeWidget.saveWidgetData<String>(
        'last_book',
        lastBookTitle ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'streak_emoji',
        _streakEmoji(currentStreak),
      );
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _androidWidgetName,
      );
    } catch (e) {
      DebugLogger.error('📱 HomeWidget update failed: $e');
    }
  }

  static String _streakEmoji(int days) {
    if (days >= 30) return '🏆';
    if (days >= 14) return '⭐';
    if (days >= 7) return '🔥';
    if (days >= 3) return '📖';
    return '📚';
  }

  /// Prompt user to add reading streak widget to home screen (Android only)
  static Future<bool> requestPinWidget() async {
    try {
      if (!Platform.isAndroid) return false;

      await HomeWidget.requestPinWidget(
        androidName: _androidWidgetName,
      );
      DebugLogger.info('📱 Widget pin requested successfully');
      return true;
    } catch (e) {
      DebugLogger.error('📱 Widget pin request failed: $e');
      return false;
    }
  }
}

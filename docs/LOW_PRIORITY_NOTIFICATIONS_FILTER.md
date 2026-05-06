# Low-Priority Notifications Filter Implementation

## Overview

Low-priority notifications (engagement events like likes, comments, follows, etc.) are now **blocked from appearing in the rewards overlay** but **still show as system notifications** when received.

## Implementation Details

### 1. Rewards Overlay Filtering (`redesigned_rewards_overlay.dart`)

The overlay now filters out all events with `priority == 'low'` in multiple places:

#### initState()

```dart
// Filter out low-priority events from both lists
final highPriorityPusherEvents = widget.pusherEvents
    .where((event) => event.priority != 'low')
    .toList();
final highPriorityNotificationEvents = widget.notificationEvents
    .where((event) => event['priority'] != 'low')
    .toList();
```

#### build()

The same filtering is applied in the build method to ensure only high-priority events are shown.

#### \_buildNotificationSection()

Event cards are built only from filtered high-priority lists:

```dart
if (index < highPriorityPusherEvents.length) {
  final event = highPriorityPusherEvents[index];
  // Build card...
}
```

#### \_dismissCurrentEvent()

Event counting uses filtered lists to ensure correct navigation.

### 2. FCM Foreground Listener (`main.dart`)

Added priority check BEFORE reward notification handling:

```dart
// Check if it's a low-priority notification - show as system notification only
final priority = message.data['priority'];
if (priority == 'low') {
  debug.DebugLogger.info('🔔 FCM: Low-priority notification - showing as system notification');
  _showLocalNotification(message);

  // Update chat count if applicable
  if (message.data.containsKey('msg_type') &&
      message.data.containsKey('conversation_id')) {
    try {
      Auth auth = globalAuth;
      auth.updateUnreadCount();
    } catch (e) {
      debug.DebugLogger.error('Error updating unread count: $e');
      SentryService.captureException(e, tag: 'messaging_error');
    }
  }
  return; // Don't show overlay for low-priority events
}
```

### 3. Assistive Touch Filtering (`assistive_touch.dart`)

Added priority checks in both FCM and Pusher listeners:

#### FCM Listener

```dart
// Check if this is a low-priority notification
final priority = data['priority'];
if (priority == 'low') {
  DebugLogger.info('🔔 ASSISTIVE: Low-priority notification - skipping overlay');
  return; // Don't show overlay, let system notification handle it
}
```

#### Pusher Listener

```dart
// Check if this is a low-priority notification
if (event.priority == 'low') {
  print('🔔 ASSISTIVE: Low-priority Pusher event - skipping overlay');
  return; // Don't show overlay for engagement notifications
}
```

## Event Flow

### Low-Priority Events (likes, comments, follows, donations, etc.)

1. **Backend** sends event with `priority: 'low'`
2. **FCM/Pusher** receives event
3. **main.dart** catches event, checks priority
4. **System notification** shown via `_showLocalNotification()`
5. **Overlay BLOCKED** - event filtered out before reaching overlay
6. **Result**: User sees native Android/iOS notification, NO overlay

### High-Priority Events (rewards, level ups, gifts)

1. **Backend** sends event with `priority: 'high'` or no priority field
2. **FCM/Pusher** receives event
3. **assistive_touch.dart** adds event to queue
4. **Rewards overlay** opens with animated card
5. **Result**: User sees full overlay celebration

## Low-Priority Event Types Supported

All these events have `priority: 'low'` by default:

1. **shorts.liked** - Someone liked your Shorts video
2. **shorts.commented** - Someone commented on your Shorts
3. **shorts.donation_received** - Someone donated to your Shorts
4. **season.commented** - Someone commented on your Episode
5. **season.donation_received** - Someone donated to your Episode
6. **content.view_milestone** - Content reached view milestone (100, 1000, etc.)
7. **user.followed** - Someone followed you
8. **badge.earned** - You earned a badge
9. **referral.joined** - Your referral joined the app
10. **challenge.won** - You won a challenge

## Testing Checklist

- [ ] Send low-priority event (e.g., shorts.liked) → System notification appears
- [ ] Verify NO overlay opens for low-priority event
- [ ] Send high-priority event (e.g., reward_earned) → Overlay opens
- [ ] Test with app in foreground
- [ ] Test with app in background
- [ ] Test with app terminated
- [ ] Verify filtering works for both Pusher and FCM events
- [ ] Test on Android (notification from top/bottom)
- [ ] Test on iOS (banner notification)

## Debug Logging

Look for these logs to verify correct behavior:

**Low-priority event detected:**

```
🔔 FCM: Low-priority notification - showing as system notification
🔔 ASSISTIVE: Low-priority notification - skipping overlay
```

**Filtering stats:**

```
🚀 OVERLAY INIT: Filtered 3 low-priority Pusher events
🚀 OVERLAY INIT: Filtered 2 low-priority notification events
🚀 OVERLAY INIT: Total HIGH-priority events: 1
```

## Files Modified

1. `/lib/main.dart` - FCM foreground listener priority check
2. `/lib/widgets/assistive_touch.dart` - FCM and Pusher listener filtering
3. `/lib/widgets/rewards/redesigned_rewards_overlay.dart` - Multiple filtering points
4. `/lib/services/pusher_service.dart` - Already has priority field in PusherEventData

## Benefits

✅ **Cleaner UX**: Overlay reserved for important rewards/achievements  
✅ **Better engagement**: Users see likes/comments as quick notifications  
✅ **Native feel**: System notifications match Android/iOS platform style  
✅ **No spam**: Prevents overlay fatigue from frequent engagement events  
✅ **Flexible**: Backend controls priority, easy to adjust event categorization

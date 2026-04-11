# 🔌 Pusher Real-Time Integration Guide

## Overview

The app now integrates with Pusher to receive **real-time notifications** from the Laravel backend via the `private-user.{userId}` channel pattern you specified.

## Architecture

```
Backend Event (Laravel)
    ↓
Pusher Broadcasting (real-time WebSocket)
    ↓
PusherService (lib/services/pusher_service.dart)
    ├─ Initializes Pusher client
    ├─ Subscribes to private-user.{userId} channel
    ├─ Binds to 4 events:
    │  ├─ reward.earned
    │  ├─ progress.updated
    │  ├─ gift.available
    │  └─ level.upgraded
    └─ Broadcasts events as PusherEventData
        ↓
        RewardsProvider (state management)
        ├─ Receives events from Pusher stream
        ├─ Updates dashboard data
        └─ Triggers UI updates
        ↓
        RewardsOverlay (UI)
        └─ Shows notification popup
```

## Setup Instructions

### 1. Configure Pusher Credentials

Edit [lib/config/pusher_config.dart](lib/config/pusher_config.dart):

```dart
class PusherConfig {
  static const String appKey = 'your-pusher-key';      // From Pusher Dashboard
  static const String cluster = 'ap2';                  // Your cluster
  static const String authEndpoint = 'https://your-backend.com/broadcasting/auth';
}
```

### 2. Backend Broadcasting Setup (Already Configured in Your Laravel)

Your backend should broadcast like this:

```php
// In your Event class
public function broadcastOn(): array
{
    return [
        new PrivateChannel('private-user.' . $this->user->id),
    ];
}
```

### 3. Automatic Initialization

When the app starts:

1. **AssistiveTouch widget** initializes when mounted
2. **PusherService.setupAndConnect()** is called with the user's ID
3. Pusher client initializes with your credentials
4. Subscribes to `private-user.{userId}` channel
5. **RewardsProvider** starts listening to Pusher events
6. **RewardsOverlay** displays notifications as they arrive

### 4. Enable Pusher Package (if using real device)

Uncomment in [pubspec.yaml](pubspec.yaml):

```yaml
pusher_channels_flutter: ^2.2.1
```

Then run:

```bash
flutter pub get
```

**Note**: The package is currently a mock for iOS compatibility. Replace it with the real package when building for Android/Web.

## Event Handling

### Supported Events

#### 1. **reward.earned** → Coin Display

```
User Action → Backend fires RewardEarned event → Pusher delivers
→ RewardsOverlay shows green card with:
  - Source emoji (Q&A, Ads, Donation, etc.)
  - Coin amount
  - Available coins total
```

**Sources Mapped**:

- `qna` / `q&a` → ❓ Q&A
- `ads` → 📺 Watching Ads
- `product` → 🛍️ Product Interaction
- `referral` → 👥 Referrals
- `donation` → 💝 Donation
- `achievement` → 🏆 Achievement
- `daily_reward` → 🎁 Daily Reward
- `challenge` → 🎯 Challenge Complete
- `order_completed` → ✅ Order Completed
- `level_up` → ⭐ Level Up

#### 2. **progress.updated** → Activity Tracking

```
User progresses → Backend fires ProgressUpdated event
→ Pusher delivers progress data
→ RewardsProvider updates progress bars and counters
```

**Progress Types** (handled):

- `achievement_unlocked` - Show achievement count
- `challenge_completed` - Show challenge progress
- `episode_created` - Show creation stats
- `shorts_created` - Show shorts stats
- And 5 more types...

#### 3. **gift.available** → Claim Notifications

```
User qualifies → Backend fires GiftAvailable event
→ Pusher delivers gift details
→ RewardsOverlay shows cyan card with:
  - Gift type emoji
  - Gift name
  - Claim button
```

**Gift Types Mapped**:

- `achievement_unlock` → 🏆 Achievement Unlock
- `challenge_reward` → 🎯 Challenge Reward
- `level_reward` → ⭐ Level Reward
- `milestone` → 🎯 Milestone Reached
- `seasonal` → 🎄 Seasonal Gift
- `bonus` → ⭐ Bonus Gift
- `referral_bonus` → 👥 Referral Bonus
- `special_offer` → 🎉 Special Offer

#### 4. **level.upgraded** → Level Up Celebration

```
User levels up → Backend fires LevelUpgraded event
→ Pusher delivers level details
→ RewardsOverlay shows purple card with:
  - 🎉 Celebration emoji
  - New level name
  - Congratulations message
```

## Data Flow Example

### Real-Time Scenario

```
User watches ad → Backend earns reward
→ Backend fires:
   RewardEarned {
     source: 'ads',
     amount: 10,
     available_coins: 5060,
     updated_balances: { available: 5060, earned: 9802 }
   }
→ Pusher broadcasts on private-user.2
→ PusherService receives and parses
→ Creates PusherEventData:
   - type: 'reward_earned'
   - source: 'ads'
   - amount: 10
   - availableCoins: 5060
→ Broadcasts to RewardsProvider stream
→ RewardsProvider._handleRewardEarned() updates:
   - availableCoins: 5060
   - earnedCoins: 9802
   - showRewardsOverlay: true
→ RewardsOverlay listens and rebuilds
→ Shows: "📺 10 Coins from Watching Ads"
```

## Debugging

### Enable Logs

All Pusher operations print debug logs:

```
🔌 Pusher: Initializing with key: ...
🔌 Pusher: Connecting...
✅ Pusher: Connected
🔌 Pusher: Subscribing to channel: private-user.2
✅ Pusher: Subscribed to private-user.2
🎯 Pusher: Event received: reward.earned
📨 Pusher: Raw event - Channel: private-user.2, Event: reward.earned
✅ Pusher: Broadcasting event: reward_earned
🎁 PROVIDER: Processing reward earned - Source: ads, Amount: 10
```

### Test Pusher Connection

Check logs when app starts for:

1. "Initializing with key" - Config loaded ✅
2. "Connected" - WebSocket connected ✅
3. "Subscribed to private-user.{userId}" - Channel subscribed ✅

### FCM Fallback

If Pusher doesn't work, FCM will still deliver notifications as backup:

- FCM slightly delayed (push notification)
- RewardsOverlay shows same UI

## File Locations

| File                                                                                 | Purpose                            |
| ------------------------------------------------------------------------------------ | ---------------------------------- |
| [lib/services/pusher_service.dart](lib/services/pusher_service.dart)                 | Main Pusher client & event parsing |
| [lib/config/pusher_config.dart](lib/config/pusher_config.dart)                       | Pusher credentials & settings      |
| [lib/providers/rewards_provider.dart](lib/providers/rewards_provider.dart)           | State management for events        |
| [lib/widgets/assistive_touch.dart](lib/widgets/assistive_touch.dart)                 | Initializes Pusher, shows overlay  |
| [lib/widgets/rewards/rewards_overlay.dart](lib/widgets/rewards/rewards_overlay.dart) | Displays notifications             |

## Next Steps

1. **Update Pusher Config** - Add your real credentials
2. **Test on Backend** - Fire test events from Laravel
3. **Watch Logs** - Verify events arrive in real-time
4. **Implement Missing Handlers** - Add progress.updated UI if needed

## Common Issues

### "Connection state changed: CONNECTED" but no events

- Check if user is subscribed to channel (log "Subscribed to private-user.X")
- Verify event names match binding (reward.earned, not reward_earned)
- Check backend is actually broadcasting events

### Overlay not showing

- Ensure RewardsProvider.listenToPusherEvents() is called
- Check \_pushStreamSubscription is not null
- Verify ForegroundRewardHandler broadcast working

### Events received but data missing

- Verify backend sends all required fields (source, amount, available_coins)
- Check JSON format matches PusherEventData parser
- Look for ❌ "Error parsing event data" in logs

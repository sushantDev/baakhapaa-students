# Rewards System Integration Flow

## Complete Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        BACKEND SYSTEMS                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. User Actions                    2. API Endpoints            │
│     ├─ Complete Challenge           ├─ /api/levels/user-progress│
│     ├─ Watch Episode                ├─ /api/rewards/dashboard   │
│     ├─ Daily Login                  └─ /api/pusher/authenticate │
│     ├─ Complete Quiz                                            │
│     └─ Maintain Streak              3. Event Triggers           │
│                                        ├─ reward_earned         │
│          ↓                             ├─ level_upgraded        │
│                                        ├─ gift_available        │
│  Database Updates                      └─ progress_updated      │
│     ├─ User Progress                                            │
│     ├─ Coin Balance                  4. Pusher Channels         │
│     ├─ Level Status                    └─ private-user-{userId} │
│     └─ Action Counts                                            │
│                                      5. FCM Notifications       │
│          ↓                             └─ Device tokens         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP - SERVICES                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PusherService                    FCM Service                   │
│  ├─ Connect to Pusher             ├─ Listen for messages       │
│  ├─ Subscribe to channels         ├─ Parse notification data   │
│  ├─ Stream events                 └─ Emit to stream            │
│  └─ eventStream                                                 │
│                                   rewardNotificationStream      │
│          ↓                                  ↓                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP - PROVIDERS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Levels Provider                  RewardsProvider               │
│  ├─ fetchUserProgress()           ├─ fetchDashboard()          │
│  ├─ generateLevelHint()           ├─ handleRewardNotification()│
│  ├─ getLevelProgressFor...()      ├─ Store hint/description    │
│  └─ Return progress data          └─ Store progress values     │
│                                                                  │
│          ↓                                  ↓                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP - WIDGETS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  AssistiveTouch Widget                                          │
│  ├─ Listen to pusherService.eventStream                        │
│  ├─ Listen to rewardNotificationStream                         │
│  ├─ Add events to _pusherEvents list                           │
│  ├─ Add notifications to _notificationEvents list              │
│  └─ Show RedesignedRewardsOverlay                              │
│                                                                  │
│          ↓                                                       │
│                                                                  │
│  RedesignedRewardsOverlay                                       │
│  ├─ Display event carousel (PageView)                          │
│  ├─ Show level & task section                                  │
│  ├─ Display progress bar                                        │
│  ├─ Show API hint                                               │
│  ├─ Quick action buttons                                        │
│  └─ Awesome dismissal                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                          USER SEES                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✨ Beautiful overlay with:                                     │
│     ├─ Event celebration (💰🎉🎁📊)                            │
│     ├─ Current level status (⭐ Level 4)                        │
│     ├─ Task progress (2/4 challenges)                           │
│     ├─ Contextual hints (💡)                                    │
│     └─ Quick actions (🎁🚩📈)                                  │
│                                                                  │
│  🎯 User clicks "Awesome!" or quick actions                     │
│  ↓                                                               │
│  ✅ Completes task → Backend updates → New event → Cycle repeats│
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Step-by-Step Flow

### 1. User Action → Backend Processing

```
User completes a challenge
         ↓
Backend detects completion
         ↓
Updates database:
  - Increment action count (current_progress)
  - Check if level completed
  - Calculate new coin balance
         ↓
Triggers event based on update type
```

### 2. Event Emission (Dual Channel)

```
Backend emits event via:
         ↓
    ┌────┴────┐
    ↓         ↓
Pusher     FCM
(Real-time) (Backup)
```

#### Pusher Event Structure

```json
{
  "type": "reward_earned",
  "data": {
    "amount": 50,
    "source": "challenge_completion",
    "balance": 1250,
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### FCM Notification Structure

```json
{
  "notification": {
    "title": "Coins Earned!",
    "body": "You earned 50 coins!"
  },
  "data": {
    "type": "reward_earned",
    "amount": "50",
    "source": "challenge_completion"
  }
}
```

### 3. App Receives Event

#### Via Pusher

```dart
// In AssistiveTouch._setupPusherEventListener()
pusherService.eventStream.listen((event) {
  // event.type = "reward_earned"
  // event.data = { amount: 50, source: "..." }

  setState(() {
    _pusherEvents.add(event); // Add to queue
    _showRewardsOverlay = true;
  });
});
```

#### Via FCM

```dart
// In AssistiveTouch.initState()
rewardNotificationStream.stream.listen((data) {
  // data = { type: "reward_earned", amount: "50", ... }

  setState(() {
    _notificationEvents.add(data); // Add to queue
    _showRewardsOverlay = true;
  });
});
```

### 4. Overlay Opens with Events

```dart
// In AssistiveTouch.build()
if (_showRewardsOverlay)
  RedesignedRewardsOverlay(
    pusherEvents: _pusherEvents,        // [event1, event2, ...]
    notificationEvents: _notificationEvents, // [notif1, ...]
    onClose: () {
      setState(() {
        _showRewardsOverlay = false;
        _pusherEvents.clear();
        _notificationEvents.clear();
      });
    },
  )
```

### 5. Overlay Displays Events

```dart
// In RedesignedRewardsOverlay
final totalEvents =
  widget.pusherEvents.length +
  widget.notificationEvents.length;

PageView.builder(
  itemCount: totalEvents,
  itemBuilder: (context, index) {
    if (index < widget.pusherEvents.length) {
      return _buildPusherEventCard(widget.pusherEvents[index]);
    } else {
      final notifIndex = index - widget.pusherEvents.length;
      return _buildNotificationEventCard(
        widget.notificationEvents[notifIndex]
      );
    }
  },
)
```

### 6. Level & Task Section Updates

```dart
// RewardsProvider fetches latest data
await levelsProvider.fetchUserProgress();

// Extract current level
final currentLevel = response['current_level']['name']; // "Level 4"

// Extract task details
final remainingActions = response['remaining_actions'];
if (remainingActions.isNotEmpty) {
  final action = remainingActions[0];
  _actionTitle = action['action']['title'];
  _actionDescription = action['action']['description'];
  _currentProgress = action['current_progress'];
  _requiredValue = int.parse(action['required_value']);
  _levelHint = action['hint'];
}

// UI displays this data
Text(rewardsProvider.levelName) // "Level 4"
Text('${rewardsProvider.currentProgress}/${rewardsProvider.requiredValue}') // "2/4"
```

### 7. User Interaction

#### Scenario A: View Events

```
User sees: 💰 Coins Earned! (Event 1/3)
         ↓
Swipes or clicks "Awesome!"
         ↓
Sees: 🎉 Level Up! (Event 2/3)
         ↓
Swipes or clicks "Awesome!"
         ↓
Sees: 🎁 New Gift! (Event 3/3)
         ↓
Clicks "Awesome!" on last event
         ↓
Overlay closes, events cleared
```

#### Scenario B: Go to Task

```
User sees: "Challenge Participation 2/4"
         ↓
Reads hint: "Check new challenges in Profile"
         ↓
Clicks "Go to Task" quick action
         ↓
Navigates to LevelsScreen
         ↓
Sees available challenges
         ↓
Completes challenge #3
         ↓
Backend updates → New event → Overlay shows "3/4"
```

#### Scenario C: Collect Daily Rewards

```
User clicks "Daily Rewards" quick action
         ↓
Navigates to PointsScreen
         ↓
Collects today's reward
         ↓
Backend credits coins → Pusher event
         ↓
Returns to app → Overlay shows "Coins Earned!"
```

## Event Priority & Ordering

### Event Queue Management

```dart
List<PusherEventData> _pusherEvents = [
  PusherEventData(type: 'reward_earned', ...),    // Index 0
  PusherEventData(type: 'progress_updated', ...),  // Index 1
  PusherEventData(type: 'level_upgraded', ...),    // Index 2
];

// Displayed in order received (FIFO)
```

### Suggested Backend Priority (Future Enhancement)

```
1. level_upgraded      (Most important)
2. gift_available      (Time-sensitive)
3. reward_earned       (Frequent)
4. progress_updated    (Informational)
```

## API Response Mapping

### /api/levels/user-progress

```json
{
  "current_level": {
    "id": 3,
    "name": "Level 4"
  },
  "next_level": {
    "id": 15,
    "name": "Level 5"
  },
  "progress_percentage": 50,
  "remaining_actions": [
    {
      "action": {
        "id": 1,
        "title": "Challenge Participation",
        "description": "Complete challenges to level up"
      },
      "required_value": "4",
      "current_progress": 2,
      "hint": "Check new challenges in Profile section and participate"
    }
  ]
}
```

Maps to overlay as:

```
Level Badge:        "Level 4"
Next Level:         "Level 5"
Task Title:         "Challenge Participation"
Task Description:   "Complete challenges to level up"
Progress:           "2/4"
Progress Bar:       50% (2÷4)
Hint:              "Check new challenges in Profile section and participate"
```

## Error Handling

### Network Errors

```dart
try {
  await levelsProvider.fetchUserProgress();
} catch (e) {
  // Show cached data or fallback
  _levelName = "Level Unknown";
  _pendingActions = ["Unable to load tasks"];
}
```

### Missing Data

```dart
// Null-safe access
final hint = rewardsProvider.levelHint ?? "Keep up the good work!";
final progress = rewardsProvider.requiredValue > 0
    ? '${rewardsProvider.currentProgress}/${rewardsProvider.requiredValue}'
    : '${rewardsProvider.progressPercentage.toInt()}%';
```

### Event Stream Errors

```dart
_pusherStreamSubscription = pusherService.eventStream.listen(
  (event) { /* handle event */ },
  onError: (error) {
    print('Pusher event error: $error');
    // Fall back to FCM notifications
  },
);
```

## Performance Optimization

### Event Batching (Future)

```dart
// Instead of showing overlay for each event immediately
Timer? _eventBatchTimer;
List<PusherEventData> _pendingEvents = [];

void _handleNewEvent(PusherEventData event) {
  _pendingEvents.add(event);

  // Wait 2 seconds to batch multiple events
  _eventBatchTimer?.cancel();
  _eventBatchTimer = Timer(Duration(seconds: 2), () {
    setState(() {
      _pusherEvents.addAll(_pendingEvents);
      _pendingEvents.clear();
      _showRewardsOverlay = true;
    });
  });
}
```

### Memory Management

```dart
@override
void dispose() {
  _eventPageController.dispose();
  _animationController.dispose();
  _rewardStreamSubscription?.cancel();
  _pusherStreamSubscription?.cancel();
  super.dispose();
}
```

### Cached Data

```dart
// Cache progress data for 5 minutes
DateTime? _lastFetch;
Map<String, dynamic>? _cachedProgress;

Future<void> fetchDashboard(Levels levelsProvider) async {
  if (_lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < Duration(minutes: 5)) {
    return; // Use cached data
  }

  // Fetch fresh data
  await levelsProvider.fetchUserProgress();
  _lastFetch = DateTime.now();
}
```

## Testing & Debugging

### Pusher Event Testing

```bash
# Using Pusher Debug Console
Channel: private-user-123
Event: reward_earned
Data: {
  "amount": 50,
  "source": "test_reward",
  "balance": 1250
}
```

### FCM Notification Testing

```bash
# Using Firebase Console
Send test notification:
  Target: Device token
  Title: "Test Reward"
  Body: "You earned 100 coins!"
  Data: {"type": "reward_earned", "amount": "100"}
```

### Multiple Events Simulation

```dart
// Add test button in debug mode
ElevatedButton(
  onPressed: () {
    setState(() {
      _pusherEvents.addAll([
        PusherEventData(type: 'reward_earned', data: {'amount': 50}),
        PusherEventData(type: 'level_upgraded', data: {'newLevel': 5}),
        PusherEventData(type: 'gift_available', data: {}),
      ]);
      _showRewardsOverlay = true;
    });
  },
  child: Text('Test 3 Events'),
)
```

### Debug Logging

```dart
// In AssistiveTouch
DebugLogger.info('🎁 Received ${_pusherEvents.length} Pusher events');
DebugLogger.info('📧 Received ${_notificationEvents.length} FCM notifications');
DebugLogger.info('📊 Total events to display: ${totalEvents}');
```

## State Synchronization

### Ensuring Data Freshness

```dart
// In AssistiveTouch._toggleMenu()
Future<void> _toggleMenu() async {
  if (!_isMenuOpen) {
    // Fetch fresh data before showing overlay
    final rewardsProvider = Provider.of<RewardsProvider>(context, listen: false);
    final levelsProvider = Provider.of<Levels>(context, listen: false);

    await rewardsProvider.fetchDashboard(levelsProvider);
  }

  setState(() => _isMenuOpen = !_isMenuOpen);
}
```

### Provider Updates

```dart
// RewardsProvider notifies listeners
void handleRewardNotification(Map<String, dynamic> data) {
  // Update state
  _lastRewardAmount = data['amount'];
  _totalCoins = data['balance'];

  // Notify all listening widgets
  notifyListeners();
}
```

## Integration Checklist

### Backend Requirements

- [ ] `/api/levels/user-progress` returns all required fields
- [ ] Pusher events include complete data payloads
- [ ] FCM notifications include data in correct format
- [ ] Events triggered on all user actions
- [ ] Hints generated dynamically

### Frontend Setup

- [ ] Pusher credentials configured
- [ ] FCM initialized properly
- [ ] Providers registered in app
- [ ] AssistiveTouch added to main widget tree
- [ ] Event streams connected

### Testing Scenarios

- [ ] Single Pusher event displays
- [ ] Multiple Pusher events show in carousel
- [ ] FCM notifications work as backup
- [ ] Level progress updates correctly
- [ ] Hints from API display
- [ ] Quick actions navigate properly
- [ ] Events clear after dismissal
- [ ] Overlay refreshes on tap

### User Experience

- [ ] Animations smooth on all devices
- [ ] Text readable on small screens
- [ ] Touch targets large enough
- [ ] Colors accessible (contrast)
- [ ] Loading states handled
- [ ] Error states user-friendly

This integration creates a seamless, real-time reward system that keeps users engaged and motivated!

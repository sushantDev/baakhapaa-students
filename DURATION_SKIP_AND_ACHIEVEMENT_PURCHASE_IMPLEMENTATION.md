# Duration Skip & Achievement Purchase Implementation

## Summary

Successfully implemented duration skip purchasing and achievement buying functionality in the Flutter app to work with existing Laravel backend APIs.

---

## ✅ Changes Made

### 1. Duration Skip Purchase (QuestionScreen)

**File**: `lib/screens/story/question_screen.dart`

#### State Variables (Lines 81-84)

```dart
// Duration skip purchase state
bool _isBuyingDurationSkip = false;
String? _buyDurationSkipError;
```

#### Methods Added

##### `_buyDurationSkip()` Method

- **Purpose**: Purchase duration skips using the Story provider
- **Features**:
  - Calls `storyProvider.buyDurationSkip(episodeId)`
  - Updates episode state with new skip counts
  - Shows success/error feedback via SnackBar
  - Plays success sound effect
  - Prevents multiple simultaneous purchases

##### `_showBuyDurationSkipDialog()` Method

- **Purpose**: Display purchase confirmation dialog
- **Features**:
  - Shows skip cost and user's coin balance
  - Displays insufficient funds warning if needed
  - Purchase/Cancel buttons
  - Loading indicator during purchase
  - Material Design styling with color-coded containers

#### Backend Integration

- **API Endpoint**: `POST /api/episode/{id}/buy-duration-skip`
- **Provider Method**: `Story.buyDurationSkip(episodeId)` (already implemented)
- **Response Updates**:
  - `duration_skips_bought`: Current purchased skip count
  - `duration_skips_remaining`: Available skips left to purchase

---

### 2. Achievement Purchase (Auth Provider & Achievements Screen)

#### File: `lib/providers/auth.dart`

##### `buyAchievement(int achievementId)` Method Added

```dart
Future<Map<String, dynamic>> buyAchievement(int achievementId) async
```

**Features**:

- Calls `POST /api/buy-achievement/{achievement_id}`
- Updates user's coin balance locally
- Returns purchase status and new balance
- Error handling for insufficient coins, already obtained, etc.
- Notifies listeners to update UI

#### File: `lib/screens/user/achievements_screen.dart`

##### New Methods Added

**`_buyAchievement(Map<String, dynamic> achievement)`**

- Validates bypass cost is set
- Checks user has sufficient coins
- Shows confirmation dialog with:
  - Achievement title
  - Purchase cost
  - Current coin balance
  - Purchase/Cancel buttons

**`_processBuyAchievement(int achievementId, String title)`**

- Executes the purchase via Auth provider
- Refreshes achievements list
- Shows success/error messages
- Handles specific error cases:
  - Insufficient coins
  - Already obtained
  - General purchase failures

##### UI Changes

**Buy Button Added to Achievement List Items**

- **Location**: After the main action button in `_buildAchievementListItem()`
- **Condition**: Shows only when:
  - Achievement NOT obtained (`!obtained`)
  - `bypass_cost` is set and > 0
- **Styling**:
  - Yellow/gold gradient background
  - Shopping cart icon
  - "Buy for X coins" label
  - Material Design shadows

---

## 🎯 Backend APIs Used

### Duration Skip Purchase

```
POST /api/episode/{id}/buy-duration-skip
Headers: Authorization: Bearer {token}

Response:
{
  "success": true,
  "data": {
    "duration_skips_bought": 1,
    "duration_skips_remaining": 1,
    "new_coin_balance": 450,
    "cost": 50,
    "episode_title": "Episode Title"
  }
}
```

### Achievement Purchase

```
POST /api/buy-achievement/{achievement_id}
Headers: Authorization: Bearer {token}

Response:
{
  "success": true,
  "data": {
    "new_coin_balance": 400,
    "achievement_id": 5,
    "purchased": true
  }
}
```

---

## 🔧 How to Use

### For Duration Skips:

1. User watches video in `VideoScreen`
2. If `max_duration_skips > 0` and `duration_skips_remaining > 0`, purchase option shows
3. User clicks "Buy Duration Skip"
4. Confirmation dialog appears showing cost and balance
5. On confirmation, API call deducts coins and updates skip count
6. **Note**: Activation logic (actually using the skip) needs to be implemented in `VideoScreen`

### For Achievements:

1. User views achievements in `AchievementsScreen`
2. For achievements with `bypass_cost > 0` that are NOT obtained:
   - A yellow "Buy for X coins" button appears
3. User clicks buy button
4. Confirmation dialog shows:
   - Achievement title
   - Cost in coins
   - User's current balance
5. On confirmation, coins are deducted and achievement is purchased
6. UI refreshes to reflect purchased status

---

## ⚠️ TODO: Duration Skip Activation

The purchase logic is complete, but **activation** (actually using the skip) needs implementation:

### Suggested Implementation (VideoScreen):

```dart
// In VideoScreen.dart, add a button near the countdown timer
if (episode['duration_skips_bought'] > 0 && !_countdownCompleted) {
  ElevatedButton(
    onPressed: () => _useDurationSkip(),
    child: Text('Use Skip (${episode['duration_skips_bought']} available)'),
  )
}

Future<void> _useDurationSkip() async {
  // Show confirmation
  bool? confirm = await showDialog(...);

  if (confirm == true) {
    // Call API: POST /api/episode/{id}/use-duration-skip
    // This API needs to be created in Laravel backend

    // On success:
    setState(() {
      myDuration = Duration.zero; // Skip countdown
      _countdownCompleted = true; // Enable quiz button
      episode['duration_skips_bought']--;
    });
  }
}
```

### Backend API Needed:

```php
// SeasonController.php
public function useDurationSkip($id) {
    // Verify user has purchased skips
    // Decrement duration_skips_bought in episode_user table
    // Return success with new count
}
```

---

## 📊 Database Tables Used

### `episode_user` Table

- `extra_lives_bought`: Tracks purchased extra lives
- `duration_skips_bought`: Tracks purchased duration skips

### `achievement_user` Pivot Table

- `purchased`: Boolean flag for bypass-purchased achievements
- `user_claimed`: Achievement claim status
- `level`: Achievement level

### `user_information` Table

- `available_coins`: User's current coin balance
- `total_used_coins`: Total coins spent

### `coin_logs` Table

- Tracks all coin transactions with platform type
- Platform types: `extra_life`, `duration_skip`, `achievement_purchase`

---

## 🎨 UI/UX Features

### Duration Skip Dialog

- Blue color scheme
- Cost display with coin icon
- Balance display with amber highlight
- Insufficient funds warning (red)
- Loading indicator during purchase
- Material Design rounded corners and shadows

### Achievement Buy Button

- Yellow/gold gradient (matches coin theme)
- Shopping cart icon
- Clear pricing label
- Only shows when purchasable
- Smooth animations and shadows
- Confirmation dialog before purchase

---

## ✅ Testing Checklist

- [ ] Duration skip purchase with sufficient coins
- [ ] Duration skip purchase with insufficient coins
- [ ] Duration skip purchase up to max limit
- [ ] Achievement purchase with bypass cost
- [ ] Achievement purchase with insufficient coins
- [ ] Achievement already obtained (should not show buy button)
- [ ] Coin balance updates correctly after purchases
- [ ] Error messages display correctly
- [ ] Success messages and sound effects work
- [ ] UI refreshes after purchases

---

## 📝 Notes

1. **Episode Data Structure**: The episode object must include these fields from the backend:
   - `duration_skip_cost`
   - `max_duration_skips`
   - `duration_skips_bought`
   - `duration_skips_remaining`

2. **Achievement Data Structure**: Achievements must include:
   - `bypass_cost` (nullable, 0 means not purchasable)
   - `obtained` (0 or 1)
   - `claimed` (0 or 1)

3. **Sound Effects**: Uses `assets/sounds/correct.wav` for success feedback

4. **State Management**: Uses Provider pattern for Auth and Story providers

---

## 🔄 Related Files Modified

1. `lib/screens/story/question_screen.dart` - Duration skip purchase UI
2. `lib/providers/auth.dart` - Achievement purchase API integration
3. `lib/screens/user/achievements_screen.dart` - Achievement buy button UI
4. `lib/providers/story.dart` - (Already had buyDurationSkip method)

---

## 📞 Support

For issues or questions:

- Check Laravel logs for API errors
- Use `DebugLogger.info/error` for Flutter debugging
- Verify episode/achievement data structure matches expected format

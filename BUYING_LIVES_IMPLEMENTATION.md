# Buying Lives Feature Implementation

## Overview

Implemented a complete "Buy Extra Lives" feature that allows players to purchase additional lives during gameplay using coins when they run out of lives.

## Architecture & Flow

```
Player loses all lives
         ↓
Shows "Buy Extra Life" dialog
         ↓
User confirms purchase
         ↓
Deducts coins from user account
         ↓
Increments extra_lives_bought in episode_user table
         ↓
Updates episode data with new totals
         ↓
Resumes gameplay with new lives
```

## Backend Integration

### Two Main Endpoints:

1. **GET /api/v2/episode/{id}** - Fetch episode details with extra lives tracking
   - Returns: `lives`, `extra_lives`, `extra_life_cost`, `extra_lives_bought`, `extra_lives_remaining`, `total_lives`

2. **POST /api/episode/{id}/buy-extra-life** - Purchase one extra life
   - Validates episode allows extra lives
   - Checks user has enough coins
   - Deducts coins and tracks purchase
   - Returns: Updated lives data and new coin balance

## Implementation Details

### 1. Story Provider (`lib/providers/story.dart`)

#### Added Method: `buyExtraLife(int episodeId)`

```dart
Future<Map<String, dynamic>> buyExtraLife(int episodeId) async {
  // Makes POST request to /episode/{id}/buy-extra-life
  // Updates local episode state with new lives data
  // Returns purchase result data
}
```

#### Enhanced `fetchEpisode()`

- Now fetches from `/v2/episode/{episodeId}` endpoint
- Includes extra lives data in response
- Logs available extra lives and cost

### 2. Question Screen (`lib/screens/story/question_screen.dart`)

#### New State Variables:

```dart
bool _isBuyingLife = false;         // Track purchase in progress
String? _buyLifeError;              // Store any purchase errors
```

#### New Methods:

**`_buyExtraLife()`**

- Calls Story provider's buyExtraLife method
- Updates lives state on success
- Shows success/error snackbars
- Prevents multiple concurrent purchases

**`_showBuyExtraLifeDialog()`**

- Shows modal dialog when lives run out
- Displays cost and current coin balance
- Validates sufficient coins
- Options to "Give Up" or "Buy Extra Life"
- Shows loading state during purchase

#### Enhanced `onQuestionComplete()`

- When lives reach 0, checks if extra lives can be purchased
- Shows buy dialog instead of immediately ending game
- Resumes game if purchase succeeds
- Goes to LooseScreen if purchase fails or no extra lives available

#### Enhanced `_buildHeartsDisplay()`

- Shows buy button next to lives count when applicable
- Displays extra lives availability info
- Shows loading spinner during purchase
- Disabled when no extra lives available or insufficient coins

## Game Flow

### When Player Loses Last Life:

1. **Dialog Shows**:
   - "Game Over!" message
   - Cost display (with coin icon)
   - Player's current coins
   - "Give Up" or "Buy Extra Life" buttons

2. **If Player Has Enough Coins**:
   - Can click "Buy Extra Life"
   - API call deducts coins
   - Lives reset to 1
   - Game resumes

3. **If Insufficient Coins**:
   - Button disabled (greyed out)
   - Warning message shown
   - Can only "Give Up"

4. **If No Extra Lives Available**:
   - Dialog doesn't show
   - Goes directly to LooseScreen

## UI Components

### Buy Extra Life Button (In-Game)

- Location: Next to lives counter in top-right
- Shows coin cost
- Visible only when:
  - Extra lives available for episode
  - Cost > 0
  - Not yet purchased max extra lives

### Game Over Dialog

- Modal popup when lives reach 0
- Shows purchase details and validation
- Clean, dark-themed UI matching app design
- Non-dismissible (must choose option)

### Feedback Messages

- **Success**: Green snackbar with new total lives
- **Error**: Red snackbar with error message
- **In-Progress**: Loading spinner during purchase

## Data Flow

```
Episode Data Structure:
{
  ...episode fields...
  'lives': 3,                    // Base lives for episode
  'extra_lives': 5,              // Max extra lives available
  'extra_life_cost': 100,        // Cost per extra life in coins
  'extra_lives_bought': 0,       // User's purchased count
  'extra_lives_remaining': 5,    // Available to purchase
  'total_lives': 3               // Base + bought
}

Purchase Response:
{
  'success': true,
  'extra_lives_bought': 1,       // Updated count
  'extra_lives_remaining': 4,    // Remaining available
  'total_lives': 4,              // New total
  'new_coin_balance': 900,       // After deduction
  'cost': 100,                   // Amount deducted
  'episode_title': '...'         // For logging
}
```

## Error Handling

1. **Insufficient Coins**: Button disabled, warning shown
2. **API Errors**: Caught and displayed as snackbar
3. **Network Issues**: Error message displayed
4. **Max Purchases Reached**: Button unavailable
5. **Invalid Episode**: Falls back to LooseScreen

## Testing Checklist

- [ ] Verify episode data includes extra lives fields
- [ ] Test purchase with sufficient coins
- [ ] Test purchase with insufficient coins
- [ ] Test when max extra lives reached
- [ ] Test when no extra lives available
- [ ] Test dialog shows/hides correctly
- [ ] Verify coins deducted properly
- [ ] Check lives updated in game
- [ ] Test error scenarios (network, API)
- [ ] Verify animations play correctly
- [ ] Check snackbar messages appear
- [ ] Test on low-coin scenarios

## Future Enhancements

1. Analytics tracking for life purchases
2. Daily/weekly purchase limits
3. Bonus extra lives from achievements
4. Alternative payment methods (gems, etc)
5. Progressively increasing costs
6. Special promotions/discounts
7. Combo deals (buy 3, get bonus)

## Files Modified

1. `lib/providers/story.dart`
   - Added `buyExtraLife()` method
   - Enhanced `fetchEpisode()` logging

2. `lib/screens/story/question_screen.dart`
   - Added purchase state variables
   - Added `_buyExtraLife()` method
   - Added `_showBuyExtraLifeDialog()` method
   - Modified `onQuestionComplete()` logic
   - Enhanced `_buildHeartsDisplay()` widget

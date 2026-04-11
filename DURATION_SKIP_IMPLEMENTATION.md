# Duration Skip Implementation Guide

## Overview

This document outlines the complete implementation of the duration skip feature, which allows users to skip the video countdown timer and immediately start the quiz by consuming a purchased duration skip.

## Implementation Date

January 22, 2026

## Feature Description

Users can purchase duration skips (handled by existing `buyDurationSkip()` in Story provider) and then **use** those skips to bypass the video countdown timer, enabling immediate access to the quiz questions.

---

## 📋 Episode Data Structure

The episode object contains the following skip-related fields:

```json
{
  "max_duration_skips": 2, // Maximum skips allowed per episode
  "duration_skip_cost": 20, // Cost in coins to purchase one skip
  "duration_skips_bought": 0, // Number of skips user has purchased
  "duration_skips_remaining": 2, // Number of skips still available to purchase
  "duration": 30 // Video countdown duration in seconds
}
```

---

## 🎯 User Flow

### Scenario 1: User Has No Duration Skips

1. Video screen loads with countdown timer
2. User waits for countdown to complete (30 seconds)
3. "Go To Questions" button becomes enabled
4. User starts quiz

### Scenario 2: User Has Duration Skips Bought

1. Video screen loads with countdown timer
2. **"Use Skip (1)" button appears above countdown** (orange gradient)
3. User taps "Use Skip" button
4. Confirmation dialog shows:
   - Title: "Use Duration Skip?"
   - Message: "Skip the remaining countdown timer and start the quiz immediately!"
   - Displays available skips count
5. User confirms → Skip is used
6. Countdown instantly becomes 0
7. "Go To Questions" button enables immediately
8. Success message: "⏭️ Duration skipped! You can now start the quiz."
9. Skip count decreases: `duration_skips_bought: 1 → 0`

### Scenario 3: User Cancels Skip Dialog

1. User taps "Use Skip" button
2. Dialog appears
3. User taps "Cancel"
4. Dialog closes, countdown continues normally

---

## 🛠️ Technical Implementation

### 1. State Variables Added (VideoScreen)

```dart
// Duration skip usage state
bool _isUsingDurationSkip = false;    // Prevents duplicate API calls
String? _useDurationSkipError;        // Stores error messages
```

### 2. Story Provider Method (story.dart)

**File:** `lib/providers/story.dart`

```dart
Future<Map<String, dynamic>> useDurationSkip(int episodeId) async {
  try {
    final response = await http.post(
      Uri.parse(Url.baakhapaaApi('/episode/$episodeId/use-duration-skip')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );

    final responseData = json.decode(utf8.decode(response.bodyBytes));

    if (responseData['success'] == true) {
      // Update episode locally with new duration skip data
      if (_episode['id'] == episodeId) {
        _episode['duration_skips_bought'] =
            responseData['data']['duration_skips_bought'];
        _episode['duration_skips_remaining'] =
            responseData['data']['duration_skips_remaining'];
        notifyListeners();
      }

      DebugLogger.success('✅ Duration skip used successfully');
      return responseData;
    } else {
      throw Exception(
          responseData['message'] ?? 'Failed to use duration skip');
    }
  } catch (error) {
    DebugLogger.error('❌ Error using duration skip: $error');
    throw error;
  }
}
```

### 3. Use Duration Skip Method (VideoScreen)

**File:** `lib/screens/story/video_screen.dart`

```dart
Future<void> _useDurationSkip() async {
  if (_isUsingDurationSkip) return; // Prevent duplicate calls

  setState(() {
    _isUsingDurationSkip = true;
    _useDurationSkipError = null;
  });

  try {
    final story = Provider.of<Story>(context, listen: false);
    final response = await story.useDurationSkip(episode['id'] as int);

    if (response['success'] == true) {
      // Update local episode data
      setState(() {
        episode['duration_skips_bought'] = response['data']['duration_skips_bought'];
        episode['duration_skips_remaining'] = response['data']['duration_skips_remaining'];

        // Skip countdown - set to 0 to enable questions button
        _countdownCompleted = true;
        myDuration = Duration(seconds: 0);
        countdownTimer?.cancel();
        _isUsingDurationSkip = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏭️ Duration skipped! You can now start the quiz.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      DebugLogger.success('⏭️ Duration skip used successfully');
    } else {
      throw Exception(response['message'] ?? 'Failed to use duration skip');
    }
  } catch (error) {
    setState(() {
      _useDurationSkipError = error.toString();
      _isUsingDurationSkip = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to use skip: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }

    DebugLogger.error('❌ Failed to use duration skip: $error');
  }
}
```

### 4. Confirmation Dialog

```dart
void _showUseDurationSkipDialog() {
  final durationSkipsBought = episode['duration_skips_bought'] as int? ?? 0;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.fast_forward, color: Theme.of(context).primaryColor, size: 28),
          SizedBox(width: 10),
          Text('Use Duration Skip?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skip the remaining countdown timer and start the quiz immediately!',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Skips Available:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  '$durationSkipsBought',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (_useDurationSkipError != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _useDurationSkipError!,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUsingDurationSkip ? null : () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: _isUsingDurationSkip
              ? null
              : () async {
                  Navigator.of(ctx).pop();
                  await _useDurationSkip();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isUsingDurationSkip
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward, size: 20),
                    SizedBox(width: 8),
                    Text('Use Skip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
        ),
      ],
    ),
  );
}
```

### 5. UI Button Implementation

**Location:** Above the countdown timer in VideoScreen's navigation card

```dart
// Show timer or start quiz button for uncompleted quiz
final durationSkipsBought = episode['duration_skips_bought'] as int? ?? 0;
final bool canUseSkip = !_countdownCompleted && durationSkipsBought > 0;

return Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // Duration Skip Button - show when countdown is active and user has skips
    if (canUseSkip) ...[
      InkWell(
        onTap: _isUsingDurationSkip ? null : _showUseDurationSkipDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B00),
                Color(0xFFFF9900),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF6B00).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fast_forward,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'Use Skip ($durationSkipsBought)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ],

    // Main countdown/quiz button
    Stack(
      children: [
        // ... existing countdown/go to questions button code ...
      ],
    ),
  ],
);
```

---

## 🔌 Backend API Endpoint

### Required Endpoint

**URL:** `POST /api/episode/{id}/use-duration-skip`

**Headers:**

```json
{
  "Authorization": "Bearer {authToken}",
  "Content-Type": "application/json",
  "Accept": "application/json"
}
```

**Request Body:** None (episode ID in URL)

**Success Response (200):**

```json
{
  "success": true,
  "code": 0,
  "locale": "en",
  "message": "Duration skip used successfully",
  "data": {
    "duration_skips_bought": 0, // Decremented by 1
    "duration_skips_remaining": 2 // Unchanged
  }
}
```

**Error Response (400):**

```json
{
  "success": false,
  "code": 400,
  "locale": "en",
  "message": "No duration skips available"
}
```

**Error Response (404):**

```json
{
  "success": false,
  "code": 404,
  "locale": "en",
  "message": "Episode not found"
}
```

### Laravel Backend Implementation (Example)

```php
// routes/api.php
Route::post('/episode/{id}/use-duration-skip', [SeasonController::class, 'useDurationSkip'])->middleware('auth:sanctum');

// app/Http/Controllers/SeasonController.php
public function useDurationSkip($episodeId)
{
    $user = auth()->user();

    // Get episode-user relationship
    $episodeUser = DB::table('episode_user')
        ->where('episode_id', $episodeId)
        ->where('user_id', $user->id)
        ->first();

    if (!$episodeUser) {
        return response()->json([
            'success' => false,
            'message' => 'Episode not found'
        ], 404);
    }

    // Check if user has skips available
    if ($episodeUser->duration_skips_bought <= 0) {
        return response()->json([
            'success' => false,
            'message' => 'No duration skips available to use'
        ], 400);
    }

    // Use one skip
    DB::table('episode_user')
        ->where('episode_id', $episodeId)
        ->where('user_id', $user->id)
        ->decrement('duration_skips_bought', 1);

    // Get updated data
    $updatedEpisodeUser = DB::table('episode_user')
        ->where('episode_id', $episodeId)
        ->where('user_id', $user->id)
        ->first();

    // Log the skip usage
    DB::table('coin_logs')->insert([
        'user_id' => $user->id,
        'coins' => 0,
        'description' => "Used duration skip for episode #{$episodeId}",
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    return response()->json([
        'success' => true,
        'code' => 0,
        'locale' => 'en',
        'message' => 'Duration skip used successfully',
        'data' => [
            'duration_skips_bought' => $updatedEpisodeUser->duration_skips_bought,
            'duration_skips_remaining' => $updatedEpisodeUser->duration_skips_remaining,
        ]
    ]);
}
```

---

## 🎨 UI Design

### Button Appearance

**Skip Button (when available):**

- **Color:** Orange gradient (0xFFFF6B00 → 0xFFFF9900)
- **Position:** Above countdown timer
- **Size:** Small, compact (8px vertical, 16px horizontal padding)
- **Shadow:** Orange glow (0.4 alpha, 8px blur)
- **Icon:** `Icons.fast_forward` (white, 16px)
- **Text:** "Use Skip (X)" where X is skip count

**Countdown Timer (disabled state):**

- **Color:** Grey gradient (600 → 800)
- **Icon:** `Icons.timer_outlined` (grey 400)
- **Text:** "HH:MM:SS" format

**Go To Questions (enabled state):**

- **Color:** Green gradient (0x0DFF00 → 0x0D9900)
- **Shadow:** Dark shadow with blur
- **Text:** "Go To Question" (from localization)

---

## ✅ Testing Checklist

### Functional Tests

- [ ] **Skip button visibility**
  - [ ] Button appears when `duration_skips_bought > 0` and countdown active
  - [ ] Button hides when `duration_skips_bought = 0`
  - [ ] Button hides when countdown completes
- [ ] **Skip usage flow**
  - [ ] Dialog opens when skip button tapped
  - [ ] Shows correct skip count in dialog
  - [ ] Cancel button closes dialog without changes
  - [ ] Use Skip button calls API correctly
  - [ ] Loading state shown during API call
  - [ ] Countdown set to 0 after successful skip
  - [ ] "Go To Questions" button enables immediately
  - [ ] Success SnackBar appears
- [ ] **State updates**
  - [ ] `duration_skips_bought` decrements locally
  - [ ] `_countdownCompleted` becomes true
  - [ ] `myDuration` becomes 0
  - [ ] Timer cancelled
  - [ ] Button no longer appears after use
- [ ] **Error handling**
  - [ ] Network error shows error message
  - [ ] "No skips available" error handled
  - [ ] Dialog shows error in red container
  - [ ] Error SnackBar appears

### Edge Cases

- [ ] User taps skip button multiple times rapidly (prevented by `_isUsingDurationSkip`)
- [ ] Network timeout during API call
- [ ] User navigates away during API call
- [ ] Episode data missing or malformed
- [ ] Skip count is 0 but backend says otherwise
- [ ] Backend returns success but wrong data format

### Visual Tests

- [ ] Skip button aligned properly above countdown
- [ ] Orange gradient renders correctly
- [ ] Skip count displays correctly
- [ ] Dialog layout on small screens
- [ ] Dialog layout on large screens
- [ ] Loading spinner in button
- [ ] Error message formatting

---

## 🐛 Known Issues & Limitations

None currently known.

---

## 📈 Future Enhancements

1. **Analytics Tracking**
   - Track skip usage rate per episode
   - Monitor which episodes users skip most
   - A/B test skip pricing

2. **Partial Skips**
   - Instead of skipping to 0, reduce by percentage (e.g., 50%)
   - Allow users to choose skip amount

3. **Skip Bundles**
   - Offer discounted bundles of multiple skips
   - Daily skip rewards

4. **Animation**
   - Add countdown acceleration animation when skip used
   - Coin animation for skip purchase

---

## 📚 Related Documentation

- [EXTRA_LIVES_CRITICAL_FIXES.md](./EXTRA_LIVES_CRITICAL_FIXES.md) - Extra lives implementation
- [BUYING_LIVES_IMPLEMENTATION.md](./BUYING_LIVES_IMPLEMENTATION.md) - Purchase flows
- [API_REQUIREMENTS.md](./API_REQUIREMENTS.md) - Backend API documentation

---

## 🔗 File References

### Modified Files

1. **lib/screens/story/video_screen.dart**
   - Lines 54-56: State variables
   - Lines 825-900: `_useDurationSkip()` method
   - Lines 901-1005: `_showUseDurationSkipDialog()` dialog
   - Lines 2742-2890: UI button implementation

2. **lib/providers/story.dart**
   - Lines 1415-1447: `useDurationSkip()` API method

### Dependencies

- `package:http` - HTTP requests
- `package:provider` - State management
- `Story` provider - Episode data
- `Url` helper - API endpoints
- `DebugLogger` - Debug logging

---

## ✨ Summary

The duration skip feature is now **fully implemented** with:

✅ API integration to use purchased skips  
✅ Beautiful orange gradient button UI  
✅ Confirmation dialog with skip count display  
✅ Instant countdown skip (sets to 0)  
✅ Success/error messaging  
✅ State management and error handling  
✅ Prevention of duplicate API calls  
✅ Proper cleanup and timer cancellation

**Next Step:** Backend API endpoint must be implemented at `/api/episode/{id}/use-duration-skip` following the specification above.

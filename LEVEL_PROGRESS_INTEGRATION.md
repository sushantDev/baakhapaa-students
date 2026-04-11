# Level Progress Integration Guide

## Overview

This document explains how to use the new level progress features in the Assistive Touch/Puppet system.

## What's New

### 1. **Level Progress Data in Puppet Model**

The `PuppetInteraction` model now includes:

- `levelProgress`: Map containing user's current level progress
- `levelHint`: Auto-generated contextual hint based on level requirements

### 2. **Auto-Generated Hints**

The `Levels` provider now includes a `generateLevelHint()` method that creates contextual hints based on the user's next level requirements.

### 3. **Daily Rewards Navigation**

The "Daily Rewards" button in the rewards overlay now navigates to the Points Screen.

## Level Progress Data Structure

Based on the API response from `/api/levels/user-progress`:

```dart
{
  "current_level": {
    "id": 3,
    "name": "Level 4",
    "desc": "This is the forth level...",
    "order": 4
  },
  "next_level": {
    "id": 15,
    "name": "Level 5",
    "desc": "Participate in the challenge",
    "order": 5,
    "actions": [...]
  },
  "progress_percentage": 0,
  "completed_actions": [],
  "remaining_actions": [
    {
      "action": {
        "id": 16,
        "title": "Challenge Participation",
        "type": "number",
        "pivot": {"value": "4"}
      },
      "required_value": "4",
      "current_progress": 2,
      "completed": false
    }
  ],
  "is_max_level": false
}
```

## How to Use

### 1. Backend Integration

When creating puppet interactions via your backend, you can now include level progress data:

```php
// In your Laravel backend
use App\Models\PuppetInteraction;
use Illuminate\Support\Facades\Http;

class PuppetInteractionController extends Controller
{
    public function generateLevelPuppet(Request $request)
    {
        $userId = $request->user()->id;

        // Fetch user's level progress
        $levelProgress = Http::withToken($request->bearerToken())
            ->get(config('app.url') . '/api/levels/user-progress')
            ->json()['data'] ?? null;

        if (!$levelProgress) {
            return response()->json(['message' => 'No level progress'], 404);
        }

        // Generate contextual hint
        $hint = $this->generateHint($levelProgress);

        // Create puppet interaction
        $puppet = PuppetInteraction::create([
            'current_page' => 'HomeScreen',
            'title' => 'Level Progress',
            'puppet_response' => $hint,
            'action_text' => 'View Progress',
            'priority' => 5,
            'is_active' => true,
            'level_progress' => $levelProgress, // Include level progress
            'level_hint' => $hint,
            'go_to_page' => 'PointsScreen', // Navigate to points screen
        ]);

        return response()->json($puppet);
    }

    private function generateHint($levelProgress)
    {
        $remainingActions = $levelProgress['remaining_actions'] ?? [];

        if (empty($remainingActions)) {
            return "You're doing great! Keep it up! 🎉";
        }

        $firstRemaining = $remainingActions[0];
        $action = $firstRemaining['action'];
        $currentProgress = $firstRemaining['current_progress'] ?? 0;
        $requiredValue = (int)$firstRemaining['required_value'];
        $remaining = $requiredValue - $currentProgress;

        $actionTitle = $action['title'] ?? '';

        // Generate contextual hints
        if (stripos($actionTitle, 'challenge') !== false) {
            return "Complete $remaining more " .
                   ($remaining == 1 ? "challenge" : "challenges") .
                   " to reach " .
                   ($levelProgress['next_level']['name'] ?? 'the next level') .
                   "! 🎯";
        }
        elseif (stripos($actionTitle, 'episode') !== false) {
            return "Watch $remaining more " .
                   ($remaining == 1 ? "episode" : "episodes") .
                   " to level up! 📺";
        }
        elseif (stripos($actionTitle, 'daily') !== false) {
            return "Claim your daily rewards for $remaining more " .
                   ($remaining == 1 ? "day" : "days") .
                   " to advance! 🎁";
        }
        elseif (stripos($actionTitle, 'streak') !== false) {
            return "Maintain your streak for $remaining more " .
                   ($remaining == 1 ? "day" : "days") .
                   "! 🔥";
        }
        elseif (stripos($actionTitle, 'quiz') !== false) {
            return "Complete $remaining more " .
                   ($remaining == 1 ? "quiz" : "quizzes") .
                   " correctly! 📝";
        }
        else {
            return "$actionTitle: $currentProgress/$requiredValue - " .
                   "$remaining more to go! 💪";
        }
    }
}
```

### 2. Flutter Usage

In your Flutter app, the level progress is automatically available in the puppet interaction:

```dart
// In any widget that uses PuppetInteractionProvider
final puppet = context.watch<PuppetInteractionProvider>().currentPuppet;

if (puppet?.levelProgress != null) {
  final currentLevel = puppet!.levelProgress!['current_level'];
  final nextLevel = puppet!.levelProgress!['next_level'];
  final progressPercentage = puppet!.levelProgress!['progress_percentage'];
  final remainingActions = puppet!.levelProgress!['remaining_actions'];

  // Show level progress UI
  print('Current Level: ${currentLevel['name']}');
  print('Progress: $progressPercentage%');
  print('Hint: ${puppet.levelHint}');
}
```

### 3. Accessing Level Progress Directly

You can also access level progress directly from the Levels provider:

```dart
// In your widget
final levelsProvider = Provider.of<Levels>(context);

// Get level progress data formatted for assistive touch
final progressData = levelsProvider.getLevelProgressForAssistiveTouch();

if (progressData != null) {
  print('Hint: ${progressData['hint']}');
  print('Progress: ${progressData['progress_percentage']}%');
}

// Or generate a hint on demand
final hint = levelsProvider.generateLevelHint();
if (hint != null) {
  print('Level Hint: $hint');
}
```

## Example Hint Outputs

Based on different level requirements:

- **Challenge**: "Complete 2 more challenges to reach Level 5! 🎯"
- **Episodes**: "Watch 3 more episodes to level up! 📺"
- **Daily Rewards**: "Claim your daily rewards for 5 more days to advance! 🎁"
- **Streak**: "Maintain your streak for 7 more days! 🔥"
- **Quiz**: "Complete 4 more quizzes correctly! 📝"
- **Generic**: "Challenge Participation: 2/4 - 2 more to go! 💪"

## Navigation Flow

### Daily Rewards Button

When users tap "Daily Rewards" in the rewards overlay:

1. Overlay closes
2. Navigates to `PointsScreen`
3. User can see and claim daily rewards

### Level Progress Hint Button

If your puppet includes `go_to_page: 'PointsScreen'`:

1. Puppet message shows the hint
2. "Next" button appears
3. Tapping navigates to Points Screen where user can see full progress

## Best Practices

1. **Refresh Level Progress**: Call `levelsProvider.fetchUserProgress()` after significant user actions (completing episodes, challenges, etc.)

2. **Show Hints Contextually**: Display level hints when users are idle or when they complete an action

3. **Combine with Actions**: Use hints with navigation actions to guide users:

   ```dart
   PuppetInteraction(
     message: puppet.levelHint ?? 'Keep progressing!',
     goToPage: 'PointsScreen',
     actionText: 'View Progress'
   )
   ```

4. **Handle Max Level**: Check `is_max_level` before showing progression hints:
   ```dart
   if (levelsProvider.isMaxLevel) {
     // Show congratulations message
   } else {
     // Show progression hint
   }
   ```

## API Endpoints Used

- `GET /api/levels/user-progress` - Fetches current level progress
- `POST /api/levels/check-level-up` - Checks if user can level up
- `GET /api/levels/all` - Gets all available levels

## Integration Checklist

- [x] Level progress fields added to PuppetInteraction model
- [x] Hint generation method added to Levels provider
- [x] Daily Rewards button navigates to PointsScreen
- [x] Level progress can be passed from backend to Flutter
- [ ] Backend sends level progress with puppet interactions
- [ ] UI displays level progress in assistive touch
- [ ] Analytics tracking for hint interactions

## Testing

1. **Test Hint Generation**:

   ```dart
   final levelsProvider = Provider.of<Levels>(context, listen: false);
   await levelsProvider.fetchUserProgress();
   final hint = levelsProvider.generateLevelHint();
   print('Generated Hint: $hint');
   ```

2. **Test Navigation**:

   - Open rewards overlay
   - Tap "Daily Rewards" button
   - Verify navigation to PointsScreen

3. **Test Progress Data**:
   ```dart
   final progressData = levelsProvider.getLevelProgressForAssistiveTouch();
   print('Progress Data: $progressData');
   ```

## Future Enhancements

- [ ] Add progress bars in puppet messages
- [ ] Show estimated time to next level
- [ ] Celebrate level-ups with special animations
- [ ] Smart timing for hint delivery based on user activity
- [ ] Personalized hints based on user preferences

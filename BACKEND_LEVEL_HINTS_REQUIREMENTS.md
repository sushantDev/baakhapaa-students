# Backend Requirements for Level Progress Hints

## Summary

This document lists the exact fields you need to add to your puppet interactions API to support level progress hints in the Flutter app.

## Database Schema Update

Add these fields to your `puppet_interactions` table (if using database storage):

```sql
ALTER TABLE puppet_interactions
ADD COLUMN level_progress JSON NULL,
ADD COLUMN level_hint TEXT NULL;
```

## API Response Format

### Current Puppet Interaction Response (before)

```json
{
  "id": 123,
  "current_page": "HomeScreen",
  "title": "Welcome!",
  "puppet_response": "Hello! Let me guide you.",
  "action_text": "Got it!",
  "priority": 5,
  "is_active": true,
  "go_to_page": null,
  "action_type": null,
  "action_id": null
}
```

### Enhanced Response (after)

```json
{
  "id": 123,
  "current_page": "HomeScreen",
  "title": "Level Progress",
  "puppet_response": "Complete 2 more challenges to reach Level 5! 🎯",
  "action_text": "View Progress",
  "priority": 5,
  "is_active": true,
  "go_to_page": "PointsScreen",
  "action_type": null,
  "action_id": null,
  "level_progress": {
    "current_level": {
      "id": 3,
      "name": "Level 4",
      "desc": "This is the forth level for users...",
      "order": 4
    },
    "next_level": {
      "id": 15,
      "name": "Level 5",
      "desc": "Participate in the challenge",
      "order": 5,
      "actions": [
        {
          "id": 16,
          "title": "Challenge Participation",
          "type": "number",
          "pivot": { "value": "4" }
        }
      ]
    },
    "progress_percentage": 50,
    "remaining_actions": [
      {
        "action": {
          "id": 16,
          "title": "Challenge Participation",
          "type": "number",
          "pivot": { "value": "4" }
        },
        "required_value": "4",
        "current_progress": 2,
        "completed": false
      }
    ],
    "completed_actions": [],
    "is_max_level": false
  },
  "level_hint": "Complete 2 more challenges to reach Level 5! 🎯"
}
```

## Required Changes to Backend

### 1. Add Fields to Puppet Model (Laravel Example)

```php
// app/Models/PuppetInteraction.php

protected $fillable = [
    'current_page',
    'title',
    'puppet_response',
    'action_text',
    'priority',
    'is_active',
    'go_to_page',
    'action_type',
    'action_id',
    'level_progress',  // NEW: JSON field
    'level_hint',      // NEW: Text field
];

protected $casts = [
    'is_active' => 'boolean',
    'level_progress' => 'array', // Cast JSON to array
];
```

### 2. Hint Generation Logic (Laravel Example)

```php
// app/Services/LevelHintService.php

namespace App\Services;

class LevelHintService
{
    public static function generateHint(array $levelProgress): ?string
    {
        $remainingActions = $levelProgress['remaining_actions'] ?? [];

        if (empty($remainingActions)) {
            return "You're at max level! Keep enjoying Baakhapaa! 🎉";
        }

        $firstRemaining = $remainingActions[0];
        $action = $firstRemaining['action'];
        $currentProgress = $firstRemaining['current_progress'] ?? 0;
        $requiredValue = (int)($firstRemaining['required_value'] ?? 0);
        $remaining = $requiredValue - $currentProgress;

        if ($remaining <= 0) {
            return null; // Action already completed
        }

        $actionTitle = $action['title'] ?? '';
        $nextLevelName = $levelProgress['next_level']['name'] ?? 'the next level';

        // Generate contextual hints based on action type
        return self::getHintForActionType($actionTitle, $remaining, $nextLevelName);
    }

    private static function getHintForActionType(string $actionTitle, int $remaining, string $nextLevelName): string
    {
        $plural = $remaining == 1;

        if (stripos($actionTitle, 'challenge') !== false) {
            return sprintf(
                "Complete %d more %s to reach %s! 🎯",
                $remaining,
                $plural ? "challenge" : "challenges",
                $nextLevelName
            );
        }

        if (stripos($actionTitle, 'episode') !== false) {
            return sprintf(
                "Watch %d more %s to level up! 📺",
                $remaining,
                $plural ? "episode" : "episodes"
            );
        }

        if (stripos($actionTitle, 'daily') !== false) {
            return sprintf(
                "Claim your daily rewards for %d more %s to advance! 🎁",
                $remaining,
                $plural ? "day" : "days"
            );
        }

        if (stripos($actionTitle, 'streak') !== false) {
            return sprintf(
                "Maintain your streak for %d more %s! 🔥",
                $remaining,
                $plural ? "day" : "days"
            );
        }

        if (stripos($actionTitle, 'quiz') !== false) {
            return sprintf(
                "Complete %d more %s correctly! 📝",
                $remaining,
                $plural ? "quiz" : "quizzes"
            );
        }

        // Default generic hint
        return sprintf(
            "%s: %d more to go! 💪",
            $actionTitle,
            $remaining
        );
    }
}
```

### 3. Controller Method to Create Level Progress Puppets

```php
// app/Http/Controllers/Api/PuppetInteractionController.php

use App\Services\LevelHintService;
use Illuminate\Support\Facades\Http;

public function generateLevelProgressPuppet(Request $request)
{
    $user = $request->user();

    // Fetch user's level progress from your levels API
    $response = Http::withToken($request->bearerToken())
        ->get(config('app.url') . '/api/levels/user-progress');

    if (!$response->successful()) {
        return response()->json([
            'success' => false,
            'message' => 'Could not fetch level progress'
        ], 400);
    }

    $levelProgress = $response->json()['data'] ?? null;

    if (!$levelProgress) {
        return response()->json([
            'success' => false,
            'message' => 'No level progress available'
        ], 404);
    }

    // Generate hint
    $hint = LevelHintService::generateHint($levelProgress);

    if (!$hint) {
        return response()->json([
            'success' => false,
            'message' => 'No hints available'
        ], 404);
    }

    // Create or update puppet interaction
    $puppet = PuppetInteraction::updateOrCreate(
        [
            'current_page' => 'HomeScreen',
            'user_id' => $user->id, // If you filter by user
        ],
        [
            'title' => 'Level Progress Update',
            'puppet_response' => $hint,
            'action_text' => 'View Progress',
            'priority' => 5,
            'is_active' => true,
            'level_progress' => $levelProgress,
            'level_hint' => $hint,
            'go_to_page' => 'PointsScreen',
        ]
    );

    return response()->json([
        'success' => true,
        'data' => $puppet
    ]);
}
```

### 4. Automatic Hint Generation on User Progress

Add this to events that change user progress:

```php
// app/Events/UserProgressChanged.php

namespace App\Events;

use App\Models\User;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;

class UserProgressChanged implements ShouldBroadcast
{
    public $user;
    public $progressType;

    public function __construct(User $user, string $progressType)
    {
        $this->user = $user;
        $this->progressType = $progressType;

        // Auto-generate level hint when progress changes
        $this->generateLevelHint();
    }

    private function generateLevelHint()
    {
        // Fetch latest level progress
        $response = Http::get(route('api.levels.user-progress', ['user' => $this->user->id]));

        if ($response->successful()) {
            $levelProgress = $response->json()['data'] ?? null;
            $hint = \App\Services\LevelHintService::generateHint($levelProgress);

            if ($hint) {
                // Create puppet interaction
                \App\Models\PuppetInteraction::create([
                    'current_page' => 'HomeScreen',
                    'title' => 'Level Progress',
                    'puppet_response' => $hint,
                    'action_text' => 'View Progress',
                    'priority' => 5,
                    'is_active' => true,
                    'level_progress' => $levelProgress,
                    'level_hint' => $hint,
                    'go_to_page' => 'PointsScreen',
                ]);
            }
        }
    }

    public function broadcastOn()
    {
        return new PrivateChannel('user.' . $this->user->id);
    }
}
```

## When to Generate Hints

Generate and send level progress hints when:

1. **User completes an episode** → Check if it contributes to level progress
2. **User completes a challenge** → Update hint
3. **User claims daily rewards** → Update streak progress
4. **User answers quiz correctly** → Update quiz progress
5. **User logs in** → Show current level status (optional, don't spam)
6. **Level up occurs** → Congratulate and show next level requirements

## Example Integration Points

### After Episode Completion

```php
// In your episode completion handler
public function markEpisodeComplete(Request $request)
{
    // ... existing episode completion logic ...

    // Trigger level progress check
    event(new UserProgressChanged($user, 'episode_completed'));

    return response()->json(['success' => true]);
}
```

### After Challenge Completion

```php
public function completeChallenge(Request $request)
{
    // ... existing challenge completion logic ...

    // Trigger level progress check
    event(new UserProgressChanged($user, 'challenge_completed'));

    return response()->json(['success' => true]);
}
```

## Testing the Integration

### 1. Test API Endpoint

```bash
curl -X GET "https://student.baakhapaa.com/api/levels/user-progress" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"
```

### 2. Test Hint Generation

```bash
curl -X POST "https://student.baakhapaa.com/api/puppet-interactions/generate-level-hint" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"
```

### 3. Expected Response

```json
{
  "success": true,
  "data": {
    "id": 456,
    "puppet_response": "Complete 2 more challenges to reach Level 5! 🎯",
    "level_progress": { ... },
    "level_hint": "Complete 2 more challenges to reach Level 5! 🎯",
    "go_to_page": "PointsScreen"
  }
}
```

## Summary of Changes

| Component  | Change Required                                             | Status      |
| ---------- | ----------------------------------------------------------- | ----------- |
| Database   | Add `level_progress` (JSON) and `level_hint` (TEXT) columns | ⏳ Pending  |
| Model      | Add fields to `$fillable` and `$casts`                      | ⏳ Pending  |
| Service    | Create `LevelHintService` for hint generation               | ⏳ Pending  |
| Controller | Add endpoint to generate level puppets                      | ⏳ Pending  |
| Events     | Trigger hint generation on progress changes                 | ⏳ Pending  |
| Frontend   | Already implemented ✅                                      | ✅ Complete |

## Next Steps

1. Run database migration to add new columns
2. Implement `LevelHintService`
3. Add controller method for hint generation
4. Trigger hint generation on user actions
5. Test with real user data
6. Monitor hint quality and user engagement

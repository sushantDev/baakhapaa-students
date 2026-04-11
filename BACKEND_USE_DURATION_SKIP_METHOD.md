# Missing Backend Method: useDurationSkip

Add this method to `SeasonController.php` (after the `buyDurationSkip` method):

```php
public function useDurationSkip($id)
{
    $episode = Episode::find($id);

    if (!$episode) {
        return $this->respondNotFound(ApiCode::USER_NOT_FOUND);
    }

    $user = Auth::user();

    // Get episode_user row
    $episodeUser = DB::table('episode_user')
        ->where('user_id', $user->id)
        ->where('episode_id', $episode->id)
        ->first();

    if (!$episodeUser) {
        return $this->respondBadRequest(ApiCode::INVALID_CREDENTIALS, 'No duration skips purchased for this episode');
    }

    // Check if user has duration skips bought
    if ($episodeUser->duration_skips_bought <= 0) {
        return $this->respondBadRequest(ApiCode::INVALID_CREDENTIALS, 'No duration skips available to use');
    }

    // Use the duration skip - decrement the counter
    DB::table('episode_user')
        ->where('user_id', $user->id)
        ->where('episode_id', $episode->id)
        ->decrement('duration_skips_bought', 1);

    // Get updated values
    $updatedEpisodeUser = DB::table('episode_user')
        ->where('user_id', $user->id)
        ->where('episode_id', $episode->id)
        ->first();

    return $this->respond([
        'success' => true,
        'message' => 'Duration skip used successfully',
        'duration_skips_remaining' => $updatedEpisodeUser->duration_skips_bought,
        'episode_title' => $episode->title
    ], 'Duration skip used successfully');
}
```

---

## Add Route to `api.php`

Add this line in your `routes/api.php` file (near the other episode routes):

```php
Route::post('/episode/{id}/use-duration-skip', [SeasonController::class, 'useDurationSkip']);
```

---

## Why This Was Missing

The frontend has both:

- `buyDurationSkip()` - purchases a skip
- `useDurationSkip()` - actually uses the purchased skip to complete the countdown

The backend only had the buy method, not the use method!

---

## What This Method Does

1. **Validates** the user has purchased duration skips for this episode
2. **Decrements** the `duration_skips_bought` counter by 1
3. **Returns** the updated remaining skip count
4. Frontend then completes the countdown and proceeds to quiz

---

## After Adding This

Rebuild the backend, then test:

1. Navigate to episode with timer
2. Click "Buy Skip (20 coins)" → Should purchase successfully
3. Click "Use Skip (1)" → Should complete countdown and show "Start Quiz"

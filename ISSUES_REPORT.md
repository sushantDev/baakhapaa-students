# Application Issues Report

## Critical Issues Found

Based on the application logs, here are all the issues currently present:

---

## 1. ❌ AudioPlayer MissingPluginException (CRITICAL)

**Error:** `MissingPluginException(No implementation found for method init on channel xyz.luan/audioplayers.global)`

**Location:** `lib/screens/story/question_screen.dart:77`

**Root Cause:**

- The audioplayers plugin is not properly linked to iOS native code
- After hot restart, the native plugin registration is lost

**Impact:**

- ❌ Music/sounds not playing when answering questions (correct/wrong sounds)
- ❌ App shows error: "Custom sound not available, using system sound only"

**Fix Required:**

```bash
# 1. Clean build and reinstall pods
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..

# 2. Rebuild the app completely
flutter clean
flutter pub get
flutter run
```

**Code Location:**

- Line 77: `final AudioPlayer _audioPlayer = AudioPlayer();`
- Lines 377-379: Sound playback attempts failing

---

## 2. ❌ AnimationController Used After Dispose (CRITICAL CRASH)

**Error:** `AnimationController.stop() called after AnimationController.dispose()`

**Location:** `lib/screens/story/question_screen.dart:361`

**Stack Trace:**

```
#4      AnimationController.reset (package:flutter/src/animation/animation_controller.dart:394:5)
#5      _QuestionScreenState._handleAnswerSelection (package:baakhapaa/screens/story/question_screen.dart:361:31)
```

**Root Cause:**
When the user loses all lives:

1. Line 322: `_animateHeartLoss()` schedules a navigation to LooseScreen after 1500ms
2. Line 229-238: `dispose()` is called, disposing all animation controllers including `_answerFeedbackController`
3. Line 361: `_answerFeedbackController.reset()` is called AFTER disposal
4. App crashes

**Impact:**

- ❌ App crashes when user answers incorrectly and loses all lives
- ❌ Quiz cannot be completed if user fails

**Fix Required:**

```dart
// In _handleAnswerSelection method around line 361
// Add mounted and controller validity checks

Future<void> _handleAnswerSelection(String answerId, int isCorrect) async {
  if (_showingFeedback) return;

  final bool isCorrectAnswer = isCorrect == 1;

  if (mounted) {
    setState(() {
      _selectedAnswerId = answerId;
      _showingFeedback = true;
      _isCorrectAnswer = isCorrectAnswer;
    });
  }

  _playFeedbackSound(isCorrectAnswer);
  _triggerVibration(isCorrectAnswer);

  // Check if controller is still valid before using it
  if (mounted && _answerFeedbackController != null) {
    _answerFeedbackController.forward();
  }

  await Future.delayed(Duration(milliseconds: 1500));

  // IMPORTANT: Add mounted check AND controller validity check
  if (mounted && !_answerFeedbackController.isAnimating) {
    try {
      _answerFeedbackController.reset();
      setState(() {
        _selectedAnswerId = null;
        _showingFeedback = false;
      });
    } catch (e) {
      // Controller may have been disposed during delay
      DebugLogger.warning('Animation controller already disposed: $e');
    }
  }

  // Only proceed if still mounted
  if (mounted) {
    onQuestionComplete(isCorrect);
  }
}
```

---

## 3. ❌ Generic Error Thrown Without Details

**Error:** `Unhandled Exception: Error`

**Location:** `lib/screens/story/video_screen.dart:904`

**Stack Trace:**

```
#0      _VideoScreenState.goToQuestionScreen (package:baakhapaa/screens/story/video_screen.dart:904:7)
```

**Root Cause:**
The catch block at line 904 rethrows the error without any additional context:

```dart
} catch (error) {
  throw (error);  // <-- Line 904: Unhelpful error rethrow
}
```

**Impact:**

- ❌ Difficult to debug navigation failures
- ❌ No meaningful error messages shown to developers

**Fix Required:**

```dart
// Replace lines 903-905 with:
} catch (error, stackTrace) {
  DebugLogger.error('❌ Failed to navigate to QuestionScreen: $error');
  DebugLogger.error('Stack trace: $stackTrace');
  _showErrorDialog('Failed to start quiz: ${error.toString()}');
  rethrow;  // Use rethrow instead of throw(error)
}
```

---

## 4. ⚠️ setState() Called During Widget Tree Lock

**Error:** `setState() or markNeedsBuild() called when widget tree was locked`

**Location:** Multiple locations throughout the app

**Root Cause:**

- Calling `setState()` during the build phase or while the widget tree is being updated
- Likely happening in async callbacks that complete during navigation transitions

**Impact:**

- ⚠️ Foundation library exceptions (non-fatal but indicates poor state management)
- ⚠️ Potential UI inconsistencies

**Fix Required:**
Wrap all `setState()` calls with checks:

```dart
if (mounted) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      setState(() {
        // state updates
      });
    }
  });
}
```

---

## 5. ⚠️ VideoPlayerController Used After Dispose

**Error:** `A VideoPlayerController was used after being disposed`

**Location:** `lib/screens/story/video_screen.dart:1427` (FlickVideoWithControls)

**Root Cause:**

- The video controller is accessed after the screen is disposed
- Happens during navigation away from video screen to question screen

**Impact:**

- ⚠️ Widget library exceptions
- ⚠️ Memory leaks possible

**Fix Required:**
Add proper cleanup in video_screen.dart dispose method:

```dart
@override
void dispose() {
  // Stop any ongoing operations first
  _stopProgressTracking();

  // Remove listeners before disposing
  if (flickManager?.flickVideoManager?.videoPlayerController != null) {
    flickManager?.flickVideoManager?.videoPlayerController
        ?.removeListener(_onVideoProgressChanged);
  }

  // Dispose flick manager
  if (flickManager != null && !_flickManagerDisposed) {
    flickManager?.dispose();
    _flickManagerDisposed = true;
  }

  // Cancel timers
  _timer?.cancel();

  // Clear puppet interactions
  clearPuppetInteractions();

  super.dispose();
}
```

---

## 6. ⚠️ API Rate Limiting (429 Errors)

**Error:** `Error getting ratings: Exception: Failed to load ratings: 429`

**Root Cause:**

- Too many API requests being made in short succession
- Likely polling or rebuilds triggering repeated API calls

**Impact:**

- ⚠️ Rating features not loading
- ⚠️ Progress updates failing

**Fix Required:**

- Implement debouncing for API calls
- Add caching layer
- Reduce unnecessary API calls during video playback

---

## 7. ⚠️ Null Check Operator on RenderParagraph

**Error:** `Null check operator used on a null value` in `RenderParagraph.text`

**Location:** `package:flutter/src/rendering/paragraph.dart:391`

**Root Cause:**

- A Text widget is being rendered with null text
- Likely happening during widget disposal or navigation

**Impact:**

- ⚠️ Rendering exceptions

**Fix Required:**
Search for Text widgets without null safety and add default values:

```dart
Text(someValue ?? '')  // Instead of Text(someValue)
```

---

## 8. ⚠️ Looking Up Deactivated Widget Ancestor

**Error:** `Looking up a deactivated widget's ancestor is unsafe`

**Root Cause:**

- Widget trying to access context after being removed from tree
- Happens during dispose or navigation transitions

**Impact:**

- ⚠️ Widget inspector exceptions (non-fatal)

**Fix Required:**
Add mounted checks before all context accesses in async operations

---

## Priority Fix Order

### 🔴 CRITICAL (Must fix immediately):

1. **AudioPlayer MissingPluginException** - Complete rebuild with pod install required
2. **AnimationController dispose crash** - Prevents quiz completion

### 🟡 HIGH (Fix soon):

3. **Generic Error rethrow** - Improve error handling
4. **VideoPlayerController after dispose** - Prevent memory leaks

### 🟢 MEDIUM (Fix when possible):

5. **setState during widget lock** - Improve state management
6. **API rate limiting** - Add debouncing and caching
7. **Null check operator** - Add null safety
8. **Deactivated widget ancestor** - Add mounted checks

---

## Testing Checklist

After fixes are applied, test:

- ✅ Navigate from video to quiz
- ✅ Answer questions correctly (hear correct sound)
- ✅ Answer questions incorrectly (hear wrong sound)
- ✅ Lose all lives and reach loose screen without crash
- ✅ Complete quiz successfully
- ✅ Navigation between screens smooth
- ✅ No exceptions in console

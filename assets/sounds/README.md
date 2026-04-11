# Sound Effects for Quiz Questions

This directory contains sound effects for quiz answer feedback.

## Current Implementation

The app currently uses **system sounds** for feedback:

- ✅ **Correct Answer**: System click sound + single 100ms vibration
- ❌ **Wrong Answer**: System alert sound + double vibration pattern (100ms, pause, 100ms)

## Adding Custom Sounds (Optional)

To use custom sound files instead of system sounds:

1. Add your sound files to this directory:

   - `correct.mp3` - For correct answers (recommended: short, upbeat sound ~0.5-1s)
   - `wrong.mp3` - For wrong answers (recommended: short, error sound ~0.5-1s)

2. Update `pubspec.yaml` to include the sounds:

```yaml
flutter:
  assets:
    - assets/sounds/correct.mp3
    - assets/sounds/wrong.mp3
```

3. Uncomment the custom sound lines in `question_screen.dart`:
   - Line ~375: `await _audioPlayer.play(AssetSource('sounds/correct.mp3'));`
   - Line ~380: `await _audioPlayer.play(AssetSource('sounds/wrong.mp3'));`

## Recommended Sound Characteristics

- **Format**: MP3 or WAV
- **Duration**: 0.3 - 1.5 seconds
- **File Size**: < 100KB each
- **Volume**: Normalized, not too loud

## Sound Resources

Free sound effects can be found at:

- https://freesound.org/
- https://mixkit.co/free-sound-effects/
- https://www.zapsplat.com/

Make sure to check the license for any sounds you use.

# 16 KB Page Size Testing Checklist

## Pre-Upload Verification

### ✅ Build Configuration

- [x] AGP 8.7.3 in `android/build.gradle`
- [x] NDK 28.2.13676358 in `android/app/build.gradle`
- [x] `useLegacyPackaging = false` in packagingOptions
- [x] `allowNativeHeapPointerTagging="false"` in AndroidManifest
- [x] AD_ID permission in AndroidManifest
- [x] Gradle 16 KB properties set
- [x] NDK ABI filters configured

## Build Steps

```bash
# Clean build
flutter clean
flutter pub get

# Build release AAB
flutter build appbundle --release
```

**Output**: `build/app/outputs/bundle/release/app-release.aab`

## Testing on 16 KB Device/Emulator

### Step 1: Create 16 KB Emulator

**Option A: Using Android Studio**

1. Open AVD Manager
2. Create Virtual Device
3. Select **Pixel 8** or newer
4. Choose system image with **"16 KB Page Size"** or **"16k"** in name
5. Finish and launch

**Option B: Using Command Line**

```bash
# List available 16 KB images
sdkmanager --list | grep "16kb"

# Install (example)
sdkmanager "system-images;android-35;google_apis;arm64-v8a_16k"

# Create AVD
avdmanager create avd -n "Test_16KB" \
  -k "system-images;android-35;google_apis;arm64-v8a_16k" \
  -d "pixel_8"

# Launch
emulator -avd Test_16KB
```

### Step 2: Verify Page Size

```bash
adb shell getconf PAGE_SIZE
```

**Expected**: `16384` (not 4096)

### Step 3: Install App

```bash
flutter install --release
```

Or manually:

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 4: Test Core Features

| Feature            | Status | Notes                       |
| ------------------ | ------ | --------------------------- |
| App Launch         | ⬜     | Must not crash on startup   |
| Login/Signup       | ⬜     | Firebase auth               |
| Story Browsing     | ⬜     | List, scroll, navigation    |
| Video Playback     | ⬜     | Stories, episodes, shorts   |
| Shorts Quiz        | ⬜     | Question, win, lose screens |
| Audio Feedback     | ⬜     | Correct/wrong sounds        |
| Vibration          | ⬜     | Haptic feedback             |
| Season Unlock      | ⬜     | Purchase flow (Khalti)      |
| Search             | ⬜     | Keyboard, results           |
| Profile            | ⬜     | View, edit                  |
| Camera/Gallery     | ⬜     | Image picker                |
| Share              | ⬜     | Social sharing              |
| Push Notifications | ⬜     | Firebase messaging          |
| Deep Links         | ⬜     | Open from links             |
| Ads                | ⬜     | Google Mobile Ads           |
| Continue Watching  | ⬜     | Resume playback             |
| Tutorial           | ⬜     | First-time user flow        |

### Step 5: Monitor Logs

```bash
# Watch for crashes
adb logcat | grep -E "FATAL|AndroidRuntime|crash"

# Watch for dlopen errors (16 KB specific)
adb logcat | grep -i "dlopen"

# Watch for memory issues
adb logcat | grep -i "couldn't map"
```

**Critical Errors to Watch For**:

- `dlopen failed: couldn't map "/data/app/.../*.so"`
- `Unable to flip between RX and RW memory protection`
- `library alignment error`

## Google Play Console Verification

### Step 1: Upload AAB

1. Go to Google Play Console
2. Navigate to **Testing** → **Internal testing** (or Production)
3. Create new release
4. Upload `app-release.aab`
5. Complete release details
6. **Save** (don't publish yet)

### Step 2: Check App Bundle Explorer

1. In the release, click **App bundle explorer**
2. Look for **"Supports 16 KB page sizes"** section
3. Verify: **✅ YES**

### Step 3: Review Warnings

Expected status:

- ✅ **RESOLVED**: "Your app does not support 16 KB memory page sizes"
- ✅ **RESOLVED**: "AD_ID permission missing"
- ⚠️ **ACCEPTABLE**: "No longer supports 1,115 devices" (expected trade-off)

### Step 4: Download and Test

1. In Internal Testing, add your email as tester
2. Get the testing link
3. Download on 16 KB device/emulator
4. Install from Play Store
5. Test again (Play Store build may differ from local)

## Rollback Plan

If issues found after upload:

1. **Don't publish** the release with issues
2. Review logs to identify problematic library
3. Check if package needs updating:
   ```bash
   flutter pub outdated
   ```
4. Update specific package:
   ```bash
   flutter pub upgrade package_name
   ```
5. Rebuild and retest
6. Upload new version

## Common Issues & Fixes

### Issue: Crash on launch with "dlopen failed"

**Fix**: Library not 16 KB aligned

- Verify NDK version: `grep ndkVersion android/app/build.gradle`
- Should be: `28.2.13676358` or higher
- Clean and rebuild: `flutter clean && flutter build appbundle --release`

### Issue: "Supports 16 KB" shows NO

**Fix**: Configuration not applied

- Verify AGP: `grep "com.android.tools.build:gradle" android/build.gradle`
- Should be: `8.7.3` or higher
- Check `useLegacyPackaging = false` in build.gradle
- Rebuild AAB

### Issue: Specific feature crashes on 16 KB device

**Fix**: Third-party library issue

- Identify library from logcat
- Update to latest version supporting 16 KB
- If no update available, find alternative library

### Issue: Build warnings about NDK version mismatch

**Fix**: Use highest NDK version

- Most plugins use NDK 27.x
- Your app should use NDK 28.x (backward compatible)
- The warning is informational, not blocking

## Success Criteria

Before publishing to production:

- [ ] Build completes without errors
- [ ] NDK r28+ is being used
- [ ] AGP 8.7.3+ is being used
- [ ] App installs on 16 KB emulator
- [ ] App launches without crashes
- [ ] All core features work on 16 KB device
- [ ] No "dlopen" errors in logcat
- [ ] Play Console shows "Supports 16 KB: YES"
- [ ] AD_ID warning resolved
- [ ] Tested actual Play Store download (internal testing)

## Timeline

- **Implementation**: November 27, 2025
- **Testing**: November 27-28, 2025
- **Upload to Play Console**: November 28, 2025
- **Internal Testing**: November 28-29, 2025
- **Production Release**: November 29-30, 2025

**Deadline**: December 1, 2025 (to ensure compliance before any Google Play enforcement)

## Contact & Support

If issues persist:

- Check: [Android 16 KB Guide](https://developer.android.com/guide/practices/page-sizes)
- Community: [Stack Overflow - android-16kb](https://stackoverflow.com/questions/tagged/android-16kb)
- Flutter Issues: [GitHub Flutter Repo](https://github.com/flutter/flutter/issues)

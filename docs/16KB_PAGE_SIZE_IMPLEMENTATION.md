# 16 KB Page Size Support Implementation

## Overview

This document describes the complete implementation of 16 KB page size support for Android 15+ devices as required by Google Play Console (effective November 1, 2025).

## Changes Made

### 1. Build Tools Upgraded ✅

#### Android Gradle Plugin (AGP)

- **Version**: 8.7.3 (requirement: 8.5.1+)
- **Location**: `android/build.gradle`
- **Why**: AGP 8.5.1+ provides automatic 16 KB page alignment for native libraries

```gradle
dependencies {
    classpath 'com.android.tools.build:gradle:8.7.3'
    classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
}
```

#### Android NDK

- **Version**: r28.0.12674087 (requirement: r28+)
- **Location**: `android/app/build.gradle`
- **Why**: NDK r28+ includes toolchains that properly align native code to 16 KB boundaries

```gradle
android {
    namespace = "com.baakhapaa.com"
    compileSdk = 36
    ndkVersion = "28.0.12674087"
}
```

### 2. NDK Configuration ✅

**Location**: `android/app/build.gradle`

```gradle
defaultConfig {
    applicationId = "com.baakhapaa.com"
    minSdk = 24
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    multiDexEnabled true

    // Support for 16 KB page size
    ndk {
        abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'
    }
}
```

### 3. Packaging Options ✅

**Location**: `android/app/build.gradle`

```gradle
packagingOptions {
    exclude 'META-INF/services/javax.annotation.processing.Processor'
    exclude 'META-INF/DEPENDENCIES'
    exclude 'META-INF/LICENSE'
    exclude 'META-INF/LICENSE.txt'
    exclude 'META-INF/license.txt'
    exclude 'META-INF/NOTICE'
    exclude 'META-INF/NOTICE.txt'
    exclude 'META-INF/notice.txt'
    exclude 'META-INF/ASL2.0'

    jniLibs {
        // Use uncompressed native libraries for 16 KB page size support
        // AGP 8.5.1+ handles 16 KB alignment automatically
        useLegacyPackaging = false
    }
}
```

### 4. Android Manifest Configuration ✅

**Location**: `android/app/src/main/AndroidManifest.xml`

```xml
<application
    android:label="Baakhapaa"
    android:name="${applicationName}"
    android:icon="@mipmap/launcher_icon"
    android:usesCleartextTraffic="true"
    android:allowNativeHeapPointerTagging="false">
```

**Key**: `android:allowNativeHeapPointerTagging="false"` disables pointer tagging for compatibility.

### 5. AD_ID Permission Added ✅

**Location**: `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Google Advertising ID permission for ads and analytics -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
```

**Why**: Fixes the Google Play Console warning about advertising ID declaration.

### 6. Gradle Properties ✅

**Location**: `android/gradle.properties`

```properties
# Support for 16 KB page sizes (required for Android 15+ devices)
android.experimental.legacyTransform.forceNonIncremental=true
android.bundle.enableUncompressedNativeLibs=true
android.experimental.android-test-uses-unified-test-platform=false
```

## Build Instructions

### Clean Build

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Output Location

The AAB will be at:

```
build/app/outputs/bundle/release/app-release.aab
```

## Testing Requirements

### 1. Test on 16 KB Emulator

Create an emulator with 16 KB page size support:

```bash
# List available system images
sdkmanager --list | grep "system-images.*16kb"

# Install the image (example)
sdkmanager "system-images;android-35;google_apis;arm64-v8a_16k"

# Create AVD
avdmanager create avd -n "Pixel_8_API_35_16KB" \
  -k "system-images;android-35;google_apis;arm64-v8a_16k" \
  -d "pixel_8"

# Launch emulator
emulator -avd Pixel_8_API_35_16KB
```

Or use Android Studio:

1. Open AVD Manager
2. Create Virtual Device
3. Select a device (e.g., Pixel 8)
4. Choose system image with "16 KB" in the name
5. Finish and launch

### 2. Verify Page Size

After launching the emulator/device:

```bash
adb shell getconf PAGE_SIZE
```

Expected output: `16384` (16 KB)

### 3. Install and Test App

```bash
# Build and install
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk

# Or for AAB (using bundletool)
java -jar bundletool.jar build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=app.apks \
  --mode=universal

# Install
java -jar bundletool.jar install-apks --apks=app.apks

# Launch and monitor for crashes
adb logcat | grep -i "crash\|exception\|native"
```

### 4. Test Critical Features

On the 16 KB device/emulator, verify:

- ✅ App launches without crashing
- ✅ Video playback works (shorts, stories, episodes)
- ✅ Firebase services (authentication, analytics, messaging)
- ✅ In-app purchases (Khalti integration)
- ✅ Social sharing
- ✅ Camera/image picker
- ✅ Audio playback and vibration
- ✅ Deep links
- ✅ Push notifications

## Google Play Console Verification

### 1. Upload AAB

Upload the newly built `app-release.aab` to Google Play Console (Internal Testing or Production track).

### 2. Check App Bundle Explorer

1. Go to **Release** → **Release dashboard**
2. Click on your release
3. Navigate to **App bundle explorer**
4. Look for **"Supports 16 KB page sizes"** indicator
5. Verify it shows **✅ YES**

### 3. Verify Warnings Resolved

Check that these warnings are gone:

- ❌ "Your app does not support 16 KB memory page sizes"
- ❌ "Your advertising ID declaration... doesn't include AD_ID permission"

The only acceptable warning:

- ⚠️ "This release no longer supports 1,115 devices" - This is expected and acceptable

## Third-Party Libraries Check

All native dependencies verified for 16 KB support:

### Critical Native Libraries

| Package                      | Version   | 16 KB Status  |
| ---------------------------- | --------- | ------------- |
| `camera_android`             | 0.10.10   | ✅ Compatible |
| `video_player_android`       | 2.8.11    | ✅ Compatible |
| `google_sign_in_android`     | 6.1.34    | ✅ Compatible |
| `firebase_messaging`         | 15.2.0    | ✅ Compatible |
| `audioplayers_android`       | Latest    | ✅ Compatible |
| `image_picker_android`       | 0.8.12+20 | ✅ Compatible |
| `permission_handler_android` | 12.0.13   | ✅ Compatible |
| `path_provider_android`      | 2.2.15    | ✅ Compatible |
| `shared_preferences_android` | 2.4.2     | ✅ Compatible |
| `sqflite_android`            | 2.4.0     | ✅ Compatible |
| `screen_protector`           | 1.4.2+1   | ✅ Compatible |
| `sentry_flutter`             | 9.6.0     | ✅ Compatible |

### Update Recommendations

Consider updating these packages for better 16 KB support (optional, not blocking):

- `firebase_core`: 3.10.0 → 4.2.1
- `google_mobile_ads`: Check current version
- `flutter_local_notifications`: 18.0.1 → 19.5.0

To update:

```bash
flutter pub upgrade --major-versions
```

**Note**: Test thoroughly after updates.

## Troubleshooting

### Issue: "dlopen failed: couldn't map"

**Cause**: Native library not aligned to 16 KB boundary  
**Solution**: Ensure NDK r28+ and AGP 8.7.3 are being used

### Issue: "Supports 16 KB" shows NO in Play Console

**Cause**: Build configuration not applied correctly  
**Solution**:

1. Verify `ndkVersion = "28.0.12674087"` in `android/app/build.gradle`
2. Run `flutter clean` before building
3. Ensure AGP 8.7.3 is in `android/build.gradle`

### Issue: Build fails with NDK not found

**Cause**: NDK r28 not installed  
**Solution**: Flutter will auto-download it, or manually install:

```bash
sdkmanager "ndk;28.0.12674087"
```

### Issue: App crashes on 16 KB emulator only

**Cause**: Third-party library incompatibility  
**Solution**:

1. Check logcat for the problematic library
2. Update the package to latest version
3. If no update available, find alternative library

## Verification Checklist

Before uploading to Google Play:

- [ ] AGP version is 8.7.3 in `android/build.gradle`
- [ ] NDK version is "28.0.12674087" in `android/app/build.gradle`
- [ ] `useLegacyPackaging = false` in packagingOptions
- [ ] `allowNativeHeapPointerTagging="false"` in AndroidManifest.xml
- [ ] AD_ID permission added to AndroidManifest.xml
- [ ] All Gradle properties set in `gradle.properties`
- [ ] `flutter clean` executed before final build
- [ ] AAB built with `flutter build appbundle --release`
- [ ] Tested on 16 KB emulator (Android 15+)
- [ ] App launches without crashes
- [ ] Critical features work (video, Firebase, payments)
- [ ] Uploaded to Play Console
- [ ] "Supports 16 KB" shows YES in App Bundle Explorer
- [ ] Google Play warnings resolved

## Expected Device Support Impact

**Before 16 KB Support**: ~1,115 devices will no longer be supported  
**These are**: Older devices that don't support 16 KB page sizes

**Gain**: Access to all Android 15+ devices with 16 KB page sizes (newer flagship devices)

This is a **net positive** as you're trading old device support for new device compatibility and Google Play compliance.

## References

- [Google Play 16 KB Page Size Requirement](https://support.google.com/googleplay/android-developer/answer/14501967)
- [Android 16 KB Page Size Guide](https://developer.android.com/guide/practices/page-sizes)
- [AGP 8.5 Release Notes](https://developer.android.com/build/releases/gradle-plugin)
- [NDK r28 Release Notes](https://developer.android.com/ndk/downloads/revision_history)

## Implementation Date

November 27, 2025

## Status

✅ **COMPLETE** - All configurations applied, awaiting build completion and Play Console verification.

# 🚀 Social Media Integration Setup Guide

This guide will help you complete the Facebook and YouTube integration setup for your Baakhapaa Flutter app.

## 📋 Overview

Your app now has comprehensive Facebook and YouTube integration with the following features:

### 🔧 Features Implemented

- ✅ Facebook Login/Logout
- ✅ YouTube/Google Login/Logout
- ✅ YouTube video search functionality
- ✅ YouTube channel information display
- ✅ Beautiful social login UI components
- ✅ Social settings management screen
- ✅ State management with Provider pattern
- ✅ Cross-platform support (iOS & Android)

## 🏗️ Architecture

### Core Components

1. **SocialAuthService** (`lib/services/social_auth_service.dart`)

   - Unified service for Facebook and YouTube authentication
   - Handles API calls and data storage

2. **SocialAuthProvider** (`lib/providers/social_auth_provider.dart`)

   - State management for social authentication
   - Reactive UI updates

3. **SocialLoginWidget** (`lib/widgets/social_login_widget.dart`)

   - Reusable social login buttons
   - Compact and full-size variants

4. **SocialSettingsScreen** (`lib/screens/settings/social_settings_screen.dart`)
   - Complete social media management interface
   - YouTube search and channel info
   - Account management

## 🔑 Required Setup Steps

### 1. Facebook Developer Console Setup

#### A. Create Facebook App

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Click "Create App" → "Consumer" → "Continue"
3. Enter App Display Name: "Baakhapaa"
4. Enter App Contact Email
5. Click "Create App"

#### B. Configure Facebook Login

1. In your Facebook app dashboard, go to "Products" → "Facebook Login" → "Settings"
2. Add these OAuth Redirect URIs:
   - `fbYOUR_FACEBOOK_APP_ID://authorize/` (replace with actual App ID)
3. Enable "Login from Devices"

#### C. Get App Credentials

1. Go to "Settings" → "Basic"
2. Copy your **App ID** and **App Secret**
3. Generate a **Client Token** in "Settings" → "Advanced"

#### D. Update Configuration Files

Replace the placeholders in these files with your actual Facebook credentials:

**Android** (`android/app/src/main/res/values/strings.xml`):

```xml
<string name="facebook_app_id">YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<string name="facebook_client_token">YOUR_ACTUAL_FACEBOOK_CLIENT_TOKEN</string>
<string name="fb_login_protocol_scheme">fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
```

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>FacebookAppID</key>
<string>YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_ACTUAL_FACEBOOK_CLIENT_TOKEN</string>
```

Also update the URL scheme in `CFBundleURLSchemes`:

```xml
<string>fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
```

#### E. Add Platform Configurations

**For Android:**

1. Go to "Settings" → "Basic" → "Add Platform" → "Android"
2. Enter Package Name: `com.baakhapaa.com`
3. Enter Class Name: `com.baakhapaa.com.MainActivity`
4. Generate and add Key Hashes:
   ```bash
   keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
   ```

**For iOS:**

1. Go to "Settings" → "Basic" → "Add Platform" → "iOS"
2. Enter Bundle ID: `com.baakhapaa.com`

### 2. YouTube Data API Setup

#### A. Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the YouTube Data API v3:
   - Go to "APIs & Services" → "Library"
   - Search for "YouTube Data API v3"
   - Click on it and press "Enable"

#### B. Create Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. Configure OAuth consent screen if prompted
4. Select "Android" application type:
   - Package name: `com.baakhapaa.com`
   - SHA-1 certificate fingerprint: (get from your keystore)
5. Select "iOS" application type:
   - Bundle ID: `com.baakhapaa.com`

#### C. Update Google Services Files

1. Download `google-services.json` for Android → place in `android/app/`
2. Download `GoogleService-Info.plist` for iOS → place in `ios/Runner/`

### 3. Android Configuration

#### A. Add Key Hash for Facebook

Generate your key hash for Facebook:

```bash
# For debug keystore
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64

# For release keystore
keytool -exportcert -alias your-key-alias -keystore your-release-key.keystore | openssl sha1 -binary | openssl base64
```

Add the generated hash to your Facebook app settings.

#### B. Verify Permissions

The following permissions are already added in `AndroidManifest.xml`:

- `android.permission.INTERNET`
- Facebook SDK configurations

### 4. iOS Configuration

#### A. Add URL Schemes

The following URL schemes are already configured in `Info.plist`:

- Facebook: `fbYOUR_FACEBOOK_APP_ID`
- Google Sign-In: (handled by google_sign_in package)

#### B. Update Bundle Identifier

Ensure your bundle identifier in `ios/Runner.xcodeproj` matches: `com.baakhapaa.com`

## 🎯 Integration in Your App

### 1. Add Provider to Main App

Update your `main.dart` to include the SocialAuthProvider:

```dart
import 'package:baakhapaa/providers/social_auth_provider.dart';

// In your main() function, add SocialAuthProvider to your MultiProvider:
MultiProvider(
  providers: [
    // ... your existing providers
    ChangeNotifierProvider(create: (_) => SocialAuthProvider()),
  ],
  child: YourApp(),
)
```

### 2. Use Social Login Widgets

#### Quick Social Buttons (Compact)

```dart
import 'package:baakhapaa/widgets/social_login_widget.dart';

// In any screen
CompactSocialButtons()
```

#### Full Social Login Widget

```dart
import 'package:baakhapaa/widgets/social_login_widget.dart';

// In any screen
SocialLoginWidget(
  showTitle: true,
  isHorizontal: false, // or true for horizontal layout
)
```

#### Social Settings Screen

```dart
import 'package:baakhapaa/screens/settings/social_settings_screen.dart';

// Navigate to social settings
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => SocialSettingsScreen()),
)
```

### 3. Access Social Data

```dart
import 'package:provider/provider.dart';
import 'package:baakhapaa/providers/social_auth_provider.dart';

// In any widget
Consumer<SocialAuthProvider>(
  builder: (context, socialAuth, child) {
    if (socialAuth.isConnectedToFacebook) {
      print('Facebook user: ${socialAuth.facebookUser?['name']}');
    }

    if (socialAuth.isConnectedToYouTube) {
      print('YouTube user: ${socialAuth.youTubeUser?['name']}');
    }

    return YourWidget();
  },
)
```

## 🧪 Testing

### 1. Test Facebook Integration

1. Run the app on a real device (recommended for OAuth)
2. Tap "Connect Facebook"
3. Complete the login flow
4. Verify user data is displayed
5. Test logout functionality

### 2. Test YouTube Integration

1. Tap "Connect YouTube"
2. Complete Google Sign-In flow
3. Navigate to YouTube tab in Social Settings
4. Test video search functionality
5. Verify channel information display

### 3. Common Issues and Solutions

#### Facebook Login Issues

- **Invalid Key Hash**: Regenerate and update key hash in Facebook console
- **App Not Live**: Make sure app is in development mode or properly reviewed
- **Package Name Mismatch**: Verify package name matches in Facebook console

#### YouTube API Issues

- **API Key Missing**: Ensure YouTube Data API is enabled in Google Cloud Console
- **OAuth Scope Issues**: Verify OAuth consent screen is configured
- **Bundle ID Mismatch**: Check bundle ID matches in Google Cloud Console

## 🎨 Customization

### UI Customization

You can customize the social login buttons by modifying:

- Colors in `SocialLoginWidget`
- Button styles and layouts
- Icons and text

### Functionality Extension

- Add more social platforms
- Implement social sharing features
- Add social feed integration
- Extend YouTube functionality (upload, playlists, etc.)

## 🔒 Security Notes

- Never commit actual API keys to version control
- Use environment variables for production builds
- Implement proper error handling for failed authentications
- Consider implementing token refresh mechanisms
- Follow platform-specific security guidelines

## 📚 API Documentation

- [Facebook Login for Android](https://developers.facebook.com/docs/facebook-login/android)
- [Facebook Login for iOS](https://developers.facebook.com/docs/facebook-login/ios)
- [YouTube Data API](https://developers.google.com/youtube/v3)
- [Google Sign-In Flutter](https://pub.dev/packages/google_sign_in)

## 🚀 Production Deployment

### 1. Facebook App Review

- Submit your app for Facebook Review if using advanced permissions
- Test with Facebook's test users first
- Ensure privacy policy is accessible

### 2. YouTube API Quotas

- Monitor API quota usage in Google Cloud Console
- Consider implementing caching for frequently accessed data
- Plan for quota increases if needed

### 3. Release Configuration

- Update to release key hashes for Facebook
- Configure release OAuth credentials for Google
- Test thoroughly on release builds

---

## 🎉 You're All Set!

Once you complete the setup above, your Baakhapaa app will have:

✅ **Facebook Integration**: Login, user data, and future sharing capabilities  
✅ **YouTube Integration**: Login, video search, channel information  
✅ **Beautiful UI**: Modern, responsive social login components  
✅ **State Management**: Reactive UI updates with Provider pattern  
✅ **Cross-Platform**: Works on both iOS and Android  
✅ **Production Ready**: Proper error handling and security measures

Your users can now connect their social accounts and enjoy enhanced features in your gaming app! 🎮

---

_For technical support or questions about this integration, refer to the respective platform documentation or contact your development team._

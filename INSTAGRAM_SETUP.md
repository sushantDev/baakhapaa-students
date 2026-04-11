# Instagram Integration Setup Guide

This guide will help you set up Instagram Basic Display API for the Baakhapaa Flutter app.

## Prerequisites

1. **Facebook Developer Account**: Instagram Basic Display API is part of Facebook for Developers
2. **Facebook App**: You need a Facebook app to create an Instagram Basic Display API

## Step 1: Create Facebook App (if not already created)

1. Go to [Facebook for Developers](https://developers.facebook.com/)
2. Click "Create App"
3. Choose "Consumer" app type
4. Enter app details:
   - App Name: "Baakhapaa Gaming"
   - App Contact Email: your email
5. Click "Create App"

## Step 2: Add Instagram Basic Display Product

1. In your Facebook App dashboard, scroll to "Add Products"
2. Find "Instagram Basic Display" and click "Set Up"
3. The Instagram Basic Display product will be added to your app

## Step 3: Configure Instagram Basic Display

1. In the left sidebar, click "Instagram Basic Display" > "Basic Display"
2. Scroll to "Instagram App" section
3. Click "Create New App"
4. Fill in the details:
   - **Display Name**: Baakhapaa Gaming
   - **Authorization Window URI**: `https://socialsizzle.heroku.com/auth/`
   - **Privacy Policy URL**: Your app's privacy policy URL
   - **Terms of Service URL**: Your app's terms of service URL

## Step 4: Configure OAuth Redirect URIs

1. In "Instagram Basic Display" > "Basic Display"
2. Scroll to "Client OAuth Settings"
3. Add the following to "Valid OAuth Redirect URIs":
   - `https://socialsizzle.heroku.com/auth/`
   - `com.baakhapaa.app://oauth/callback` (for mobile app)

## Step 5: Get App Credentials

1. In "Instagram Basic Display" > "Basic Display"
2. Note down:
   - **Instagram App ID**: This is your client ID
   - **Instagram App Secret**: This is your client secret

## Step 6: Update Flutter App Configuration

### Android Configuration

1. Open `android/app/src/main/AndroidManifest.xml`
2. Add the following intent filter inside the main activity:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">

    <!-- Existing configuration -->

    <!-- Instagram OAuth callback -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.baakhapaa.app"
              android:host="oauth"
              android:pathPrefix="/callback" />
    </intent-filter>
</activity>
```

### iOS Configuration

1. Open `ios/Runner/Info.plist`
2. Add the URL scheme for Instagram OAuth:

```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- Existing URL schemes -->

    <!-- Instagram OAuth callback -->
    <dict>
        <key>CFBundleURLName</key>
        <string>com.baakhapaa.app.instagram</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.baakhapaa.app</string>
        </array>
    </dict>
</array>
```

## Step 7: Update Environment Variables

Update your `lib/services/social_auth_service.dart` with the Instagram credentials:

```dart
// Instagram Configuration
static const String _instagramClientId = 'YOUR_INSTAGRAM_APP_ID';
static const String _instagramRedirectUri = 'com.baakhapaa.app://oauth/callback';
```

## Step 8: Test Instagram Integration

1. Build and run your app
2. Go to Settings > Social Media
3. Try connecting Instagram
4. You should be redirected to Instagram's authorization page
5. After authorization, you should be redirected back to your app

## Step 9: App Review and Permissions

### Required Permissions

For Instagram Basic Display, you need:

- `instagram_graph_user_profile` - to read user profile
- `instagram_graph_user_media` - to read user media (if needed)

### App Review Process

1. In Facebook App dashboard, go to "App Review"
2. Submit your app for review with Instagram Basic Display permissions
3. Provide the following:
   - **App description**: Gaming app that allows users to share achievements
   - **Privacy policy**: Link to your privacy policy
   - **Terms of service**: Link to your terms of service
   - **Screen recordings**: Show the Instagram integration flow

## Common Issues and Solutions

### Issue 1: "Invalid OAuth access token"

- **Solution**: Check that your Instagram App ID and secret are correct
- Verify the redirect URI matches exactly what's configured

### Issue 2: "The redirect_uri provided is invalid"

- **Solution**: Ensure the redirect URI in your code matches what's configured in Facebook Developer Console
- Check for typos in the URI

### Issue 3: "This app is in Development Mode"

- **Solution**: Submit your app for App Review to make it available to all users
- During development, add test users in App Roles > Roles

### Issue 4: OAuth callback not working on mobile

- **Solution**: Verify the URL scheme is properly configured in AndroidManifest.xml and Info.plist
- Test the deep link manually: `adb shell am start -W -a android.intent.action.VIEW -d "com.baakhapaa.app://oauth/callback" com.baakhapaa.app`

## Testing with Test Users

1. In Facebook App dashboard, go to "Roles" > "Roles"
2. Add test users who can test the Instagram integration
3. Test users can access the app even before App Review approval

## Security Best Practices

1. **Never commit secrets**: Keep Instagram App Secret in environment variables
2. **Use HTTPS**: Always use HTTPS for redirect URIs in production
3. **Validate tokens**: Always validate tokens on your backend
4. **Token refresh**: Implement proper token refresh logic
5. **Rate limiting**: Respect Instagram's API rate limits

## Production Checklist

- [ ] Instagram App ID configured
- [ ] Redirect URIs properly set
- [ ] Android intent filters configured
- [ ] iOS URL schemes configured
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] App submitted for review
- [ ] Test users can successfully connect
- [ ] Error handling implemented
- [ ] Token refresh logic implemented

## Support

If you encounter issues:

1. Check Facebook Developer Console logs
2. Review Instagram Basic Display API documentation
3. Test with Instagram's API Explorer
4. Contact Facebook Developer Support if needed

## Additional Resources

- [Instagram Basic Display API Documentation](https://developers.facebook.com/docs/instagram-basic-display-api)
- [Facebook App Review Guidelines](https://developers.facebook.com/docs/app-review)
- [Instagram API Rate Limits](https://developers.facebook.com/docs/instagram-basic-display-api/rate-limiting)

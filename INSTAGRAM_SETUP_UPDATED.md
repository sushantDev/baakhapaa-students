# Instagram Integration Setup - Baakhapaa-IG

## 📱 App Details

- **App Name**: Baakhapaa-IG
- **App ID**: 1549951209778593
- **Platform**: Instagram Basic Display API

## 🔧 Current Configuration

The Instagram integration has been updated with your actual app credentials:

```dart
// In lib/services/social_auth_service.dart
static const String _instagramClientId = '1549951209778593';
static const String _instagramRedirectUri = 'https://baakhapaa.com/auth/instagram/callback';
```

## 📋 Setup Checklist

### ✅ Completed

- [x] Instagram App ID configured in service
- [x] Instagram UI components uncommented and working
- [x] Instagram state management implemented
- [x] Instagram login/logout flow implemented
- [x] Instagram connection status tracking
- [x] Instagram settings screen integration

### 🔄 Next Steps Required

1. **Instagram App Setup (Meta Developer Console)**:

   ```
   - Go to https://developers.facebook.com/
   - Navigate to your app: Baakhapaa-IG (1549951209778593)
   - Add Instagram Basic Display product
   - Configure OAuth redirect URIs:
     * https://baakhapaa.com/auth/instagram/callback
   - Add test users for development
   ```

2. **Redirect URI Handling**:
   Since Instagram OAuth requires proper callback handling, you'll need to implement:

   - Web server endpoint to handle the callback
   - OR use a deep link scheme like `baakhapaa://instagram-callback`

3. **Permissions Setup**:
   Current scopes configured:
   - `user_profile` - Basic profile information
   - `user_media` - Access to user's media

## 🎯 How Instagram Login Works Now

1. **User taps "Connect Instagram"**
2. **App opens Instagram OAuth URL**:
   ```
   https://api.instagram.com/oauth/authorize
   ?client_id=1549951209778593
   &redirect_uri=https://baakhapaa.com/auth/instagram/callback
   &scope=user_profile,user_media
   &response_type=code
   ```
3. **User authorizes in browser**
4. **Instagram redirects to callback URL with authorization code**
5. **Your backend exchanges code for access token**
6. **App receives user data and stores connection**

## 🔒 Security Notes

- Never expose client secret in mobile app
- Handle OAuth flow through secure backend
- Store access tokens securely
- Implement token refresh mechanism

## 🚀 Current Status

✅ **Ready for Testing**: The app now compiles successfully with Instagram integration
✅ **UI Complete**: Instagram appears alongside Facebook and YouTube
✅ **Real Credentials**: Using your actual Instagram app ID
⏳ **OAuth Flow**: Needs backend implementation for production use

## 🎮 Demo Mode

For development testing, the app currently:

- Opens Instagram OAuth URL in browser
- Returns mock user data for demo purposes
- Tracks connection status properly
- Shows all UI elements correctly

This allows you to test the complete UI flow while developing the backend OAuth handling.

# 🔧 Google Sign-In Configuration Fix

## ❌ **Current Error:**

```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10)
```

**Error Code 10** = `DEVELOPER_ERROR` - Configuration issue

## 🎯 **Root Cause:**

Your Google Cloud Console doesn't have the correct SHA-1 fingerprint for your debug keystore.

## 🛠️ **Step-by-Step Solution:**

### **1. Your Current SHA-1 Fingerprint:**

```
79:12:2B:B5:1F:DB:1C:BA:7C:90:F5:EC:05:D7:0E:90:C1:98:83:4E
```

### **2. Update Google Cloud Console:**

#### **Step A: Access Google Cloud Console**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **`baakhapaa-flutter`** (Project ID: `baakhapaa-flutter`)

#### **Step B: Navigate to Credentials**

1. Go to **APIs & Services** → **Credentials**
2. Find your Android OAuth 2.0 Client ID:
   ```
   587678856071-mth3vepd88i97t7uek79dupgh1j2g8i7.apps.googleusercontent.com
   ```

#### **Step C: Add SHA-1 Fingerprint**

1. Click **Edit** on the OAuth client
2. In **SHA-1 certificate fingerprints** section, click **+ ADD FINGERPRINT**
3. Add: `79:12:2B:B5:1F:DB:1C:BA:7C:90:F5:EC:05:D7:0E:90:C1:98:83:4E`
4. Click **Save**

#### **Step D: Download Updated Config**

1. After saving, download the updated `google-services.json`
2. Replace the file in: `android/app/google-services.json`

### **3. Alternative: Enable YouTube Data API**

If you haven't enabled the YouTube Data API:

1. In Google Cloud Console, go to **APIs & Services** → **Library**
2. Search for **YouTube Data API v3**
3. Click **Enable**

### **4. Clean and Rebuild**

After updating the configuration:

```bash
cd d:\Offical\baakhapaa_flutter_v3
flutter clean
flutter pub get
flutter build apk --debug
```

## ✅ **Verification Steps:**

1. **Check Package Name Match:**

   - Google Console: `com.baakhapaa.com` ✓
   - AndroidManifest.xml: `com.baakhapaa.com` ✓

2. **Check SHA-1 Added:**

   - Current: `79:12:2B:B5:1F:DB:1C:BA:7C:90:F5:EC:05:D7:0E:90:C1:98:83:4E`
   - Should be added to Google Console

3. **Test on Real Device:**
   - OAuth flows work best on physical devices
   - Avoid using emulators for initial testing

## 🔍 **If Still Not Working:**

### **Check Release SHA-1 (For Production):**

If you plan to release the app, you'll also need to add your release keystore SHA-1:

```bash
keytool -list -v -keystore d:\Offical\baakhapaa_flutter_v3\my-release-key.keystore -alias key -storepass [YOUR_STORE_PASSWORD] -keypass [YOUR_KEY_PASSWORD]
```

### **Debug Steps:**

1. Enable verbose logging in Flutter
2. Check Android logs: `adb logcat | grep -i google`
3. Verify internet connection
4. Try on different devices

## 📞 **Support:**

If the error persists after following these steps:

1. Double-check all SHA-1 fingerprints are correctly added
2. Ensure the `google-services.json` file is updated and in the correct location
3. Try creating a new OAuth client ID in Google Console
4. Contact Google Cloud Support if configuration issues persist

## 🎯 **Expected Result:**

After fixing the configuration, you should be able to:

- ✅ Connect YouTube account successfully
- ✅ See "Connected to YouTube" status in your app
- ✅ No more ApiException: 10 errors

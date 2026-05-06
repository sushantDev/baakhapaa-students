# AdMob Setup Guide — Baakhapaa

## 1. app-ads.txt Setup

`app-ads.txt` prevents ad fraud by telling AdMob that your app is authorized to serve ads.

### Steps

1. On your developer website (e.g., `baakhapaa.com`), create a file at the root:

   ```
   https://baakhapaa.com/app-ads.txt
   ```

2. Paste this exact line into that file:

   ```
   google.com, pub-8105529278923041, DIRECT, f08c47fec0942fa0
   ```

3. Make sure the domain in your **Google Play Store** listing and **App Store** listing exactly matches the domain hosting this file.

4. Wait **24–48 hours**, then check status at:
   [AdMob Console → Apps → app-ads.txt status](https://apps.admob.com)

---

## 2. Ad Units to Create in AdMob

Go to **AdMob Console → Apps → [Your App] → Ad units → Add ad unit**.

You need **2 formats × 2 platforms = 4 ad units** minimum:

| Format           | Platform | Where to create                 | Replace in code                      |
| ---------------- | -------- | ------------------------------- | ------------------------------------ |
| **Banner**       | Android  | AdMob → Ad units → Banner       | `bannerAdUnitId` Android value       |
| **Banner**       | iOS      | AdMob → Ad units → Banner       | `bannerAdUnitId` iOS value           |
| **Interstitial** | Android  | AdMob → Ad units → Interstitial | `interstitialAdUnitId` Android value |
| **Interstitial** | iOS      | AdMob → Ad units → Interstitial | `interstitialAdUnitId` iOS value     |

> Rewarded ad units are **already set** with real production IDs — no action needed.
> Native ads require AdMob editorial review — skip until your app scales.

Once you have the IDs, update `lib/services/ad_service.dart`:

```dart
static String get bannerAdUnitId => Platform.isAndroid
    ? 'ca-app-pub-8105529278923041/YOUR_ANDROID_BANNER_ID'
    : 'ca-app-pub-8105529278923041/YOUR_IOS_BANNER_ID';

static String get interstitialAdUnitId => Platform.isAndroid
    ? 'ca-app-pub-8105529278923041/YOUR_ANDROID_INTERSTITIAL_ID'
    : 'ca-app-pub-8105529278923041/YOUR_IOS_INTERSTITIAL_ID';
```

---

## 3. Where Ads Are Used in the App

### Banner Ads (`BaakhaBannerAd` widget)

| Screen                | File                                              | Placement                                             |
| --------------------- | ------------------------------------------------- | ----------------------------------------------------- |
| Story (Season) Screen | `lib/screens/story/story_screen.dart`             | Between "Continue Watching" and "Challenges" sections |
| Story (Season) Screen | `lib/screens/story/story_screen.dart`             | Between "Challenges" and "Suggested" sections         |
| Episode Screen        | `lib/screens/story/episode_screen.dart`           | Between episode list and suggested content            |
| Story Win Screen      | `lib/screens/story/win_screen.dart`               | Below win result card                                 |
| Shorts Win Screen     | `lib/screens/shorts/shorts_win_screen.dart`       | Below win result card                                 |
| User Profile Screen   | `lib/screens/user/user_screen.dart`               | Between level progress bar and user content           |
| Shop Screen           | `lib/screens/shop/shop_screen.dart`               | Below quick action buttons                            |
| Leaderboard Screen    | `lib/screens/leaderboard/leaderboard_screen.dart` | At the top of leaderboard content                     |

**Total: 8 banner placements across 7 screens**

> Every 4th banner slot shows a **subscription promo card** instead of an AdMob ad
> (for users whose subscription has expired). This is controlled by `_promoFrequency = 4`
> in `AdService`.

---

### Interstitial Ads (`AdService().showInterstitial()`)

| Screen            | File                                        | Trigger                           |
| ----------------- | ------------------------------------------- | --------------------------------- |
| Story Win Screen  | `lib/screens/story/win_screen.dart`         | Every time user wins a story quiz |
| Shorts Win Screen | `lib/screens/shorts/shorts_win_screen.dart` | Every **3rd** shorts quiz win     |
| Shorts Feed       | `lib/screens/shorts/shorts_screen.dart`     | Every **8th** short scrolled past |

**Total: 3 interstitial triggers**

---

### Rewarded Ads (already live with real IDs)

Used when users watch ads to earn coins. Real production ad unit IDs are already
set — these are working in production today.

---

## 4. Ad ID Summary (current state)

| Format       | Android ID                               | iOS ID                                   | Status        |
| ------------ | ---------------------------------------- | ---------------------------------------- | ------------- |
| Banner       | `ca-app-pub-3940256099942544/6300978111` | `ca-app-pub-3940256099942544/2934735716` | ✅ only       |
| Interstitial | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-3940256099942544/4411468910` | ✅ only       |
| Rewarded     | `ca-app-pub-8105529278923041/8001756243` | `ca-app-pub-8105529278923041/5550852727` | ✅ Production |
| Native       | `ca-app-pub-3940256099942544/2247696110` | `ca-app-pub-3940256099942544/3986624511` | ✅ only       |

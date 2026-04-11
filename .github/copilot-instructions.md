# Baakhapaa Flutter App - AI Developer Guidelines

**Version:** 3.0.42 | **App:** Quiz + Gamification Platform | **Language:** Dart/Flutter

## 🏗️ Architecture Overview

### State Management Pattern (Provider)

This app uses **Provider ^6.0.4** with `ChangeNotifier` for state management. Critical understanding:

- **Global Auth Provider** (`lib/providers/auth.dart`): Central authentication state, synced via `tryAutoLogin()`
- **Proxy Providers**: Child providers (Story, Shop, Challenge, Comments) depend on Auth token via `ChangeNotifierProxyProvider`
- **Direct Providers**: Independent state (RewardsProvider, VideoStateProvider, ConnectivityService) initialized in main
- **Listener Pattern**: All API calls trigger `notifyListeners()` → UI rebuilds only affected consumers

**Key files**: `lib/main.dart` (lines 580-720 show provider setup), `lib/providers/auth.dart` (2243 lines, core auth logic)

### Critical Avoid: Infinite Rebuild Loops

**SOLVED PATTERN** (documented in `INFINITE_REBUILD_FIX_SUMMARY.md`):

- ❌ Never call async/futures in UI builders (e.g., `home: Consumer() { fetchData() }`)
- ✅ Move all initialization to `initState()` or first-frame callbacks
- ✅ Use `ChangeNotifierProxyProvider` to pass auth token to dependent providers without fetching in builder
- ✅ Example: Story provider receives token as constructor param, doesn't refetch in builder

## 📱 Content Delivery System

### Dual Content Architecture

- **Stories** (episodes): Video content in seasons, created via `lib/screens/create/story/`
- **Shorts** (quick videos): Standalone quiz videos, similar creation flow
- **Content Creation**: Unified dual-provider pattern (`lib/providers/story_creation.dart`) with flexible API response parsing (5+ patterns for nested/array responses)

### Progressive Loading Strategy

Used extensively for large creator lists (documented in `CREATOR_COUNTS_IMPLEMENTATION.md`):

```
1. Load first 10 creators in parallel → immediate UI
2. Throttle remaining batches (5 items every 200ms) → prevent ANR
3. Cache results to avoid refetch
```

**Pattern**: `Future.wait(..., eagerError: false)` for resilience

## 🔌 External Integrations

| Service               | File                                            | Key Details                                                                   |
| --------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------- |
| **Pusher Real-time**  | `lib/services/pusher_service.dart`              | Events: `reward_earned`, `level_upgraded`, `gift_available` via `eventStream` |
| **FCM Notifications** | `lib/main.dart` (line ~200) + FirebaseMessaging | Complement Pusher; device tokens managed in Auth                              |
| **Payment (Khalti)**  | `lib/services/khalti_service.dart`              | Payment gateway for coins/shop; SDK init in main (line 495)                   |
| **Social Auth**       | `lib/services/social_auth_service.dart`         | Google Sign-In, Apple Sign-In, YouTube/Facebook linking                       |
| **Analytics**         | `lib/services/clarity_service.dart` + Sentry    | Clarity (Microsoft) & Sentry error tracking both initialized early            |
| **Maps/Geolocation**  | Commented out (see pubspec)                     | Location features disabled; address management in `address_screen.dart`       |

## 🎯 Key Developer Workflows

### Build & Run

```bash
# Debug APK (default)
flutter build apk --debug

# Profile (performance testing)
flutter build apk --profile

# Test on device
flutter run -v

# Hot Reload (preserve state)
flutter run  # then press 'r' in terminal

# Hot Restart (reset state)
# Press 'R' in terminal after `flutter run`
```

### Testing & Debugging

- **Debug Logs**: Use `DebugLogger` (util imported as `debug`) not print()
- **Lint Check**: `flutter analyze` (see analysis_options.yaml: most warnings ignored)
- **Unit Tests**: Use `test/` directory (patterns not yet established; new code should add tests)
- **Provider Debugging**: Enable Devtools: `flutter pub global activate devtools && devtools`

## 📋 Project Conventions

### Provider Naming & Structure

- Provider files: `lib/providers/{feature_name}.dart` (e.g., `story.dart`, `rewards_provider.dart`)
- Class definition: `class FeatureName with ChangeNotifier { ... notifyListeners() }`
- Getters for state: `get stateName => _state;` (immutable copies for lists)
- No automatic login in UI builders; use proxy providers or callback pattern

### Screen Organization

- Route const: `static const routeName = '/screen-name'`;
- Mixin usage: Many screens use `PuppetInteractionMixin` (puppet dialog system for tutorial/guidance)
- State: `didChangeDependencies()` for one-time init with `var _isInit = true` flag
- Multi-language support: `l10n` getter from `BuildContext` extension in helpers

### API Response Parsing

Standardized in `lib/providers/story_creation.dart` (lines 90-150):

1. Try `response['data'][key]` (common wrapped response)
2. Try `response[key]` (direct key)
3. Try `response['data']` as list (batch responses)
4. Try `response['items']` (alternate batch key)
5. Last resort: iterate `response['data']` for any matching list

**Pattern**: Assume responses vary; always test multiple patterns.

### Error Handling

- **UI Errors**: Use `showTopSnackBar()` for temporary errors (helpers.dart)
- **Auth Errors**: Redirect to login via navigation
- **Network Errors**: Check `ConnectivityService` state; display offline message
- **Firebase Errors**: Logged to Sentry; avoid rethrowing unless critical

### Media Handling

- **Video Player**: `FlickVideoPlayer` (0.9.0) for stories, `MediaKit` (1.1.10) for shorts
- **Image Loading**: `CachedNetworkImage` with loading placeholders
- **Caching**: Automatic via cached_network_image; no manual cache management needed

## 🐛 Common Pitfalls & Solutions

| Issue                              | Fix                                                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| setState() during widget tree lock | Wrap with `if (mounted) { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(...) }) }` |
| Provider not updating UI           | Verify `notifyListeners()` called; check Consumer/Selector scope matches provider hierarchy                   |
| Deep link not working              | Verify route registered in main.dart routes map; check `deep_link_handler.dart`                               |
| Memory leak in long lists          | Use `AutomaticKeepAliveClientMixin` only if state needed; default is dispose on scroll                        |
| Infinite provider initialization   | Never call async in builder; use ChangeNotifierProxyProvider constructor param instead                        |

## 📁 Key File Locations

- **Entry point**: `lib/main.dart` (915 lines; app initialization, provider tree, routes)
- **Auth core**: `lib/providers/auth.dart` (2243 lines; login, token, user profile)
- **Rewards system**: `lib/providers/rewards_provider.dart` + Pusher integration
- **Multi-language**: `lib/l10n/` (app*localizations*\*.dart for en, ne, zh)
- **Config**: `pubspec.yaml` (165 deps, v3.0.42+125), `firebase_options.dart`, `lib/theme/`
- **Utilities**: `lib/utils/debug_logger.dart` (logging), `lib/models/url.dart` (API base URLs)

## ✨ Recent Patterns & Best Practices

- **Charts**: fl_chart (0.68.0) used in PointsScreen for visualization
- **Refresh**: Custom refresh indicator (4.0.1) with pull-to-refresh + loading states
- **Notifications**: FCM + Pusher dual-layer; Pusher for real-time events, FCM for offline-resilient delivery
- **Level System**: Backend-driven progression; fetched via `/api/levels/user-progress`
- **Rewards Overlay**: Context-aware celebration UI triggered by Pusher events; auto-dismisses or waits for user action

## 🚀 When Adding Features

1. **Create provider** if managing state (inherit ChangeNotifier, add getters, call notifyListeners)
2. **Add routes** to main.dart named routes map
3. **Create screens** in lib/screens/{feature}/ with PuppetInteractionMixin if interactive
4. **Integrate with Auth** via ChangeNotifierProxyProvider if auth-dependent
5. **Add l10n keys** if user-facing text (edit lib/l10n/app_localizations.dart + language files)
6. **Document API calls** in comments if external service (Pusher, Khalti, etc.)
7. **Test offline** using ConnectivityService.isConnected getter

---

**Last Updated**: Jan 2026 | **Confidence**: High (stable architecture, 15+ providers, dual content system production-ready)

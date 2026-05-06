# Auto-Lock Wallet Implementation

## Overview

Implemented automatic wallet locking after a user-configured duration of inactivity. This enhances security by ensuring the wallet requires re-authentication (biometric/OTP) if left unused for a specified time period.

## Features Implemented

### 1. User-Configurable Auto-Lock Duration

- **Location**: [Wallet Security Settings widget](lib/widgets/wallet_security_settings.dart)
- **Duration Range**: 1-30 minutes (default: 5 minutes)
- **Configuration**: Slider control in security settings
- **Persistence**: Duration saved to SharedPreferences with key `wallet_auto_lock_duration`

### 2. Auto-Lock Toggle

- **Location**: [Wallet Security Settings widget](lib/widgets/wallet_security_settings.dart)
- **State**: Toggle to enable/disable auto-lock feature
- **Persistence**: Saved to SharedPreferences with key `wallet_auto_lock_enabled`
- **Default**: Enabled (true)

### 3. Inactivity Timer Implementation

- **Location**: [PointsScreen](lib/screens/user/points_screen.dart)
- **Mechanism**:
  - Timer checks for inactivity every 30 seconds
  - Tracks `_lastUserInteraction` timestamp
  - Compares elapsed time against configured `_autoLockDuration`
  - Automatically locks wallet when inactivity threshold is reached

### 4. User Interaction Tracking

Auto-lock timer resets on any user interaction:

- **Taps**: Direct taps on screen
- **Pans**: Drag/swipe gestures
- **Scrolls**: Vertical scrolling (using NotificationListener)
- **Refresh**: Pull-to-refresh action

### 5. Auto-Lock Behavior

When inactivity timeout is reached:

1. Cancel the auto-lock timer
2. Clear wallet session via `auth.clearWalletSession()`
3. Show informative Snackbar: "Wallet locked due to inactivity. Returning to stories."
4. Navigate to Story Screen using `pushNamedAndRemoveUntil()` (removes all previous screens)
5. Auto-lock timer is reset the next time user accesses the wallet

## Code Changes

### PointsScreen (\_PointsScreenState)

#### Added Properties

```dart
// Auto-lock functionality
bool _isAutoLockEnabled = true;
int _autoLockDuration = 5; // minutes
Timer? _autoLockTimer;
late DateTime _lastUserInteraction = DateTime.now();
```

#### New Methods

**\_loadAutoLockSettings()**

- Loads auto-lock configuration from SharedPreferences
- Reads `wallet_auto_lock_enabled` and `wallet_auto_lock_duration`
- Called on initState

**\_startAutoLockTimer()**

- Creates periodic timer (30-second intervals)
- Only starts if auto-lock is enabled
- Records current time as last user interaction

**\_resetAutoLockTimer()**

- Updates `_lastUserInteraction` timestamp to current time
- Called on every user interaction

**\_checkAndLockIfInactive()**

- Periodic check (every 30 seconds)
- Calculates elapsed time since last interaction
- Calls `_lockWallet()` if threshold exceeded

**\_lockWallet()**

- Cancels the auto-lock timer
- Clears wallet session
- Shows informative message
- Navigates to Story Screen using `pushNamedAndRemoveUntil()` (removes all previous screens including wallet)
- User must re-enter wallet screen to access it again (requires fresh authentication)

#### Modified Methods

**initState()**

- Added call to `_loadAutoLockSettings()`

**didChangeAppLifecycleState()**

- Validates session when app returns to foreground

**dispose()**

- Cancels `_autoLockTimer` on cleanup

**\_checkWalletAccess()**

- Calls `_startAutoLockTimer()` after successful authentication
- Timer starts immediately after auth check completes

**build()**

- Wrapped body with `GestureDetector` for tap and pan detection
- Added `NotificationListener<ScrollNotification>` for scroll detection
- Updated `WalletSecuritySettings.onSettingsChanged` to reload auto-lock settings

## User Experience Flow

```
User Opens Wallet (from Story Screen)
    ↓
Biometric/OTP Authentication
    ↓
Enter Points/Wallet Screen
    ↓
Auto-Lock Timer Starts (e.g., 5 minutes)
    ↓
[User inactive for 5 minutes]
    ↓
System Detects Inactivity
    ↓
Wallet Locked + Session Cleared
    ↓
User Returned to Story Screen
    ↓
User Must Re-Enter Wallet (requires fresh auth)
    ↓
Process Repeats
```

## Security Considerations

1. **Session Clear**: Wallet session is completely cleared, requiring fresh authentication
2. **Biometric Re-auth**: Users must use biometric/OTP again (not automatic)
3. **Configurable**: Users control the timeout duration (1-30 minutes)
4. **Interaction Tracking**: Any user interaction resets the timer
5. **App Lifecycle**: Session validated when app returns from background

## Testing Checklist

- [ ] Auto-lock timer starts after wallet authentication
- [ ] Timer resets on screen taps
- [ ] Timer resets on scroll/pan gestures
- [ ] Timer resets on refresh action
- [ ] Wallet locks after configured minutes of inactivity
- [ ] Lock triggers re-authentication screen
- [ ] Successful re-auth restarts the timer
- [ ] Changing auto-lock duration in settings takes effect immediately
- [ ] Disabling auto-lock stops timer
- [ ] Re-enabling auto-lock restarts timer
- [ ] Timer persists across app lifecycle (paused/resumed)

## Configuration Files Modified

1. **lib/screens/user/points_screen.dart**

   - Added auto-lock state management
   - Added inactivity timer logic
   - Added gesture detection for timer reset
   - Integrated with security settings

2. **lib/widgets/wallet_security_settings.dart**
   - Already had UI for auto-lock configuration
   - Duration slider (1-30 minutes)
   - Enable/disable toggle

## Performance Impact

- **Timer Overhead**: Minimal (checks every 30 seconds)
- **Memory**: Single Timer object (~1KB)
- **CPU**: Negligible (only comparison operation)
- **Storage**: SharedPreferences (< 100 bytes)

## Future Enhancements

1. Add remaining time indicator in UI
2. Show countdown warning before lock
3. Lock on screen timeout (system-level)
4. Different timeouts for different user roles
5. Biometric re-auth without OTP fallback for auto-lock
6. Lock history and audit logging

# Wallet OTP Security Integration

## Overview

Successfully integrated OTP-based authentication for wallet/points screen access using the existing backend APIs with comprehensive wallet authentication screen.

## Backend APIs Used

1. **POST /api/wallet/request-otp** - Sends OTP to user's email
   - Body: `{ "user_id": 2 }`
   - Response includes: `success`, `message`, `expires_in` (in seconds)
2. **POST /api/wallet/verify-otp** - Verifies OTP and returns session token
   - Body: `{ "user_id": 2, "otp": "776984" }`
   - Response includes: `access_token`, `expires_at` (timestamp)
3. **GET /api/wallet** - Protected wallet data endpoint (requires session token)

## Implementation Details

### 1. Auth Provider Updates (`lib/providers/auth.dart`)

Added wallet OTP security methods:

- `hasValidWalletSession` - Getter to check if wallet session is valid
- `requestWalletOtp()` - Requests OTP from backend
- `verifyWalletOtp(String otp)` - Verifies OTP and stores session token
- `loadWalletSession()` - Loads saved session from SharedPreferences
- `clearWalletSession()` - Clears wallet session data

**Session Management:**

- Session tokens stored in SharedPreferences
- Default session expiry: 30 minutes (configurable from backend)
- Automatic session validation on app launch

### 2. Wallet Authentication Screen (`lib/screens/user/wallet_auth_screen.dart`)

Comprehensive authentication screen with multiple security options:

**Features:**

- **OTP Verification** - Primary authentication method using backend OTP APIs
- **PIN Authentication** - Quick 4-digit PIN access (optional)
- **Biometric Authentication** - Fingerprint/Face ID support (optional)
- **Password Verification** - Traditional password auth (fallback)
- **Security Settings** - Manage authentication preferences
- **Session Management** - Stores authentication timestamp
- **Progress Tracking** - Visual step indicator for auth flow
- **Timer-based OTP Resend** - 60-second cooldown between OTP requests

**Authentication Flow:**

1. Check for saved security preferences (Biometric/PIN/OTP)
2. If Biometric enabled → Authenticate with biometric
3. If PIN enabled → Show PIN dialog
4. Otherwise → Request OTP from backend automatically
5. User enters OTP → Verify with backend
6. On success → Return `true` to calling screen
7. On failure/cancel → Return `false`

### 3. Points Screen Integration (`lib/screens/user/points_screen.dart`)

Updated wallet access flow to use comprehensive authentication:

**Flow:**

1. On screen init, check for valid wallet session
2. If no valid session:
   - Navigate to `WalletAuthScreen` (full-screen authentication)
   - Wait for authentication result
   - On success (returned `true`), load wallet data
   - On failure/cancel, return to previous screen
3. If valid session exists, load wallet data directly

## User Experience Flow

### First Access or Expired Session:

1. User navigates to Points/Wallet screen
2. System checks for valid session
3. If no session, navigate to Wallet Authentication Screen
4. **Check security preferences:**
   - If Biometric enabled → Show biometric prompt
   - If PIN enabled → Show PIN dialog
   - Otherwise → Automatically request OTP
5. **OTP Flow (if no quick auth):**
   - OTP sent to registered email
   - User receives email with 6-digit code (valid 5 minutes)
   - User enters OTP in authentication screen
   - On success, session token saved (valid until expiry)
6. Wallet data loads
7. Session token stored for future access

### Subsequent Access (within session):

1. User navigates to Points/Wallet screen
2. Session validated automatically
3. Wallet data loads immediately (no authentication required)

### Quick Authentication (Biometric/PIN):

1. User navigates to Points/Wallet screen
2. Biometric prompt appears (if enabled)
3. User authenticates with fingerprint/face
4. Immediate access (bypasses OTP)

## Security Features

- **Multi-factor Authentication** - OTP via email + optional biometric/PIN
- **Time-limited Session Tokens** - Configurable expiry (e.g., 5 minutes)
- **Secure Token Storage** - SharedPreferences with validation
- **Automatic Session Expiry** - Background validation
- **Backend-controlled Duration** - Server sets token expiry
- **Session Clearing** - On logout or expiration
- **Quick Auth Options** - Biometric & PIN for convenience
- **Fallback Security** - Password + OTP always available

## Testing Checklist

- [ ] OTP email delivery working
- [ ] OTP verification successful
- [ ] Session token stored correctly
- [ ] Session expiry handled properly
- [ ] Resend OTP functionality working
- [ ] Error messages displayed correctly
- [ ] Cancel returns to previous screen
- [ ] Valid session bypasses OTP dialog
- [ ] Session persists across app restarts

## API Request Examples

### Request OTP

```dart
POST /api/wallet/request-otp
Headers: Authorization: Bearer {auth_token}

Response:
{
  "success": true,
  "message": "OTP sent to your email"
}
```

### Verify OTP

```dart
POST /api/wallet/verify-otp
Headers: Authorization: Bearer {auth_token}
Body: {
  "otp": "123456"
}

Response:
{
  "success": true,
  "session_token": "abc123...",
  "expires_in": 30,
  "message": "Wallet access granted"
}
```

## Files Modified

1. `/lib/providers/auth.dart` - Added OTP methods and session management
2. `/lib/screens/user/points_screen.dart` - Integrated WalletAuthScreen navigation
3. `/lib/screens/user/wallet_auth_screen.dart` - Updated to use backend OTP APIs
4. `/lib/widgets/wallet_security_settings.dart` - Security preferences management (existing)
5. `/lib/widgets/wallet_otp_dialog.dart` - Simple OTP dialog (deprecated in favor of full auth screen)

## Notes

- Session expiry time is configurable from backend (default: 30 minutes)
- All API calls include proper error handling
- Loading states prevent duplicate requests
- User feedback provided via SnackBars for all actions

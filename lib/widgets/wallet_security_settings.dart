import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'skeleton_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

/// Security Settings Widget for Wallet
/// Allows users to manage biometric and auto-lock settings
class WalletSecuritySettings extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const WalletSecuritySettings({
    Key? key,
    this.onSettingsChanged,
  }) : super(key: key);

  @override
  State<WalletSecuritySettings> createState() => _WalletSecuritySettingsState();
}

class _WalletSecuritySettingsState extends State<WalletSecuritySettings> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _is2FAEnabled = true;
  bool _isAutoLockEnabled = true;
  int _autoLockDuration = 5; // minutes
  bool _isLoading = true;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (canAuthenticate) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();

        String biometricType = 'Biometric';
        if (availableBiometrics.contains(BiometricType.face)) {
          biometricType = 'Face ID';
        } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
          biometricType = 'Fingerprint';
        } else if (availableBiometrics.contains(BiometricType.strong)) {
          biometricType = 'Biometric';
        }

        setState(() {
          _isBiometricAvailable = availableBiometrics.isNotEmpty;
          _biometricType = biometricType;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('wallet_biometric_enabled') ?? false;
      _is2FAEnabled = prefs.getBool('wallet_2fa_enabled') ?? true;
      _isAutoLockEnabled = prefs.getBool('wallet_auto_lock_enabled') ?? true;
      _autoLockDuration = prefs.getInt('wallet_auto_lock_duration') ?? 5;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wallet_biometric_enabled', _isBiometricEnabled);
    await prefs.setBool('wallet_2fa_enabled', _is2FAEnabled);
    await prefs.setBool('wallet_auto_lock_enabled', _isAutoLockEnabled);
    await prefs.setInt('wallet_auto_lock_duration', _autoLockDuration);
    widget.onSettingsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return ShimmerLoading(
        child: Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet Security',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Protect your wallet with additional security',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2-Factor Authentication (OTP Verification)
          _buildSecurityOption(
            icon: Icons.verified_user,
            title: '2-Factor Authentication',
            subtitle: _is2FAEnabled
                ? 'OTP verification required to access wallet'
                : 'Wallet access without OTP verification',
            trailing: Switch(
              value: _is2FAEnabled,
              onChanged: (value) async {
                if (!value) {
                  // Show confirmation dialog before disabling 2FA
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Disable 2FA?'),
                      content: const Text(
                        'Disabling 2-Factor Authentication will remove OTP verification when accessing your wallet. This makes your wallet less secure.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Disable',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(() => _is2FAEnabled = false);
                    await _saveSettings();
                    _showSuccessSnackbar('2-Factor Authentication disabled');
                  }
                } else {
                  setState(() => _is2FAEnabled = true);
                  await _saveSettings();
                  _showSuccessSnackbar('2-Factor Authentication enabled');
                }
              },
              activeColor: Colors.amber,
            ),
          ),
          const Divider(height: 1, indent: 70),

          // Biometric Login Option
          if (_isBiometricAvailable) ...[
            _buildSecurityOption(
              icon:
                  _biometricType == 'Face ID' ? Icons.face : Icons.fingerprint,
              title: '$_biometricType Login',
              subtitle: 'Use $_biometricType for quick access without OTP',
              trailing: Switch(
                value: _isBiometricEnabled,
                onChanged: (value) async {
                  if (value) {
                    final confirmed = await _enableBiometric();
                    if (confirmed) {
                      setState(() => _isBiometricEnabled = true);
                      await _saveSettings();
                      _showSuccessSnackbar('$_biometricType login enabled');
                    }
                  } else {
                    setState(() => _isBiometricEnabled = false);
                    await _saveSettings();
                    _showSuccessSnackbar('$_biometricType login disabled');
                  }
                },
                activeColor: Colors.amber,
              ),
            ),
            const Divider(height: 1, indent: 70),
          ],

          // Auto-Lock Option
          _buildSecurityOption(
            icon: Icons.timer,
            title: 'Auto-Lock',
            subtitle: _isAutoLockEnabled
                ? 'Wallet locks after $_autoLockDuration minutes of inactivity'
                : 'Wallet will lock when session expires',
            trailing: Switch(
              value: _isAutoLockEnabled,
              onChanged: (value) async {
                setState(() => _isAutoLockEnabled = value);
                await _saveSettings();
              },
              activeColor: Colors.amber,
            ),
          ),

          if (_isAutoLockEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(70, 0, 20, 16),
              child: Row(
                children: [
                  const Text('Lock after: ',
                      style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Slider(
                      value: _autoLockDuration.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: Colors.amber,
                      label: '$_autoLockDuration min',
                      onChanged: (value) {
                        setState(() => _autoLockDuration = value.toInt());
                      },
                      onChangeEnd: (value) {
                        _saveSettings();
                      },
                    ),
                  ),
                  Text(
                    '$_autoLockDuration min',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Session Info
          // _buildSecurityOption(
          //   icon: Icons.info_outline,
          //   title: 'Session Expiry',
          //   subtitle: 'Your wallet session follows the OTP expiry from server',
          //   trailing: const SizedBox.shrink(),
          // ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.grey[700], size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Future<bool> _enableBiometric() async {
    try {
      // Verify biometric works before enabling
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to enable $_biometricType login',
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric error: ${e.message}');

      String errorMessage = 'Failed to enable $_biometricType';
      if (e.code == 'NotAvailable') {
        errorMessage = '$_biometricType is not available on this device';
      } else if (e.code == 'NotEnrolled') {
        errorMessage = 'Please set up $_biometricType in your device settings';
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        errorMessage = '$_biometricType is locked. Please try again later.';
      }

      _showErrorSnackbar(errorMessage);
      return false;
    } catch (e) {
      _showErrorSnackbar('Failed to enable $_biometricType');
      return false;
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

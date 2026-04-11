import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_logger.dart';

class ConnectivityService with ChangeNotifier {
  bool _isConnected = true;
  bool _hasCheckedInitially = false;
  bool _hasActualInternet = true;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  Timer? _periodicInternetCheck;

  bool get isConnected => _isConnected && _hasActualInternet;
  bool get hasNetworkInterface => _isConnected;
  bool get hasActualInternet => _hasActualInternet;
  bool get hasCheckedInitially => _hasCheckedInitially;

  ConnectivityService() {
    _initConnectivity();
    _setupConnectivityListener();
    _startPeriodicInternetCheck();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      DebugLogger.info(
          '📡 Initial connectivity check: $result (type: ${result.runtimeType})');

      final status = result.isNotEmpty ? result.first : ConnectivityResult.none;
      DebugLogger.info('📡 First connectivity result: ${status.name}');
      await _updateConnectionStatus(status);
    } catch (e) {
      DebugLogger.error("📡 Connectivity check failed: $e");
      _isConnected = true;
      _hasActualInternet = true;
      notifyListeners();
    } finally {
      _hasCheckedInitially = true;
      notifyListeners();
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (dynamic results) {
        DebugLogger.info(
            '📡 Connectivity event received: $results (type: ${results.runtimeType})');

        if (results is List<ConnectivityResult>) {
          final status =
              results.isNotEmpty ? results.first : ConnectivityResult.none;
          _updateConnectionStatus(status);
        } else if (results is ConnectivityResult) {
          _updateConnectionStatus(results);
        } else {
          DebugLogger.error(
              '📡 Unknown connectivity result type: ${results.runtimeType}');
        }
      },
    );
  }

  void _startPeriodicInternetCheck() {
    _periodicInternetCheck?.cancel();
    _periodicInternetCheck = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_isConnected) {
          _verifyActualInternet();
        }
      },
    );
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    final wasConnected = _isConnected;
    final hadInternet = _hasActualInternet;
    _isConnected = result != ConnectivityResult.none;

    DebugLogger.info(
      '📡 Network interface: ${_isConnected ? "AVAILABLE" : "NONE"} (Result: ${result.name})',
    );

    if (!_isConnected) {
      _hasActualInternet = false;
    } else {
      await _verifyActualInternet();
    }

    if (wasConnected != _isConnected || hadInternet != _hasActualInternet) {
      notifyListeners();
    }
  }

  Future<void> _verifyActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      final changed = _hasActualInternet != hasInternet;
      _hasActualInternet = hasInternet;

      DebugLogger.info(
        '📡 Internet verify: ${hasInternet ? "ONLINE" : "NO INTERNET"} (changed: $changed)',
      );

      if (changed) notifyListeners();
    } on SocketException catch (_) {
      if (_hasActualInternet) {
        _hasActualInternet = false;
        DebugLogger.info('📡 Internet verify: NO INTERNET (SocketException)');
        notifyListeners();
      }
    } on TimeoutException catch (_) {
      if (_hasActualInternet) {
        _hasActualInternet = false;
        DebugLogger.info('📡 Internet verify: NO INTERNET (Timeout)');
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.error("📡 Internet verify failed: $e");
    }
  }

  Future<void> checkNow() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final status = result.isNotEmpty ? result.first : ConnectivityResult.none;
      await _updateConnectionStatus(status);
    } catch (e) {
      DebugLogger.error("📡 Manual connectivity check failed: $e");
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicInternetCheck?.cancel();
    super.dispose();
  }
}

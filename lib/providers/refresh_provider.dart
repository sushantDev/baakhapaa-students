import 'package:flutter/material.dart';

class RefreshProvider with ChangeNotifier {
  Future<void> Function()? _onRefreshCallback;

  void setRefreshCallback(Future<void> Function() callback) {
    _onRefreshCallback = callback;
  }

  Future<void> refresh() async {
    if (_onRefreshCallback != null) {
      await _onRefreshCallback!();
    }
  }
}

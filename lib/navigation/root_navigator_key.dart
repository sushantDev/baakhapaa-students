import 'package:flutter/material.dart';

/// Same key passed to [MaterialApp.navigatorKey] — use for navigation that
/// must not depend on a nested [BuildContext] (e.g. after closing dialogs).
final GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();

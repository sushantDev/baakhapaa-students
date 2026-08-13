class TabRouteHistory {
  static List<String?> _routeStack = [];

  static void replaceStack(List<String?> stack) {
    _routeStack = List<String?>.from(stack);
  }

  static bool contains(String routeName) {
    return _routeStack.contains(routeName);
  }
}

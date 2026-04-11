import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/refresh_provider.dart';

class RefreshWrapper extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const RefreshWrapper({
    Key? key,
    required this.child,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<RefreshWrapper> createState() => _RefreshWrapperState();
}

class _RefreshWrapperState extends State<RefreshWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RefreshProvider>().setRefreshCallback(widget.onRefresh);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: widget.child,
    );
  }
}

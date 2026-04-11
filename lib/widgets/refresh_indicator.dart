import 'package:flutter/material.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

class BkpRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const BkpRefreshIndicator({
    Key? key,
    required this.child,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      builder: (context, child, controller) {
        return Stack(
          children: [
            child,
            if (controller.state != IndicatorState.idle)
              Positioned(
                top: 35.0 * controller.value,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      value: controller.isDragging || controller.isArmed
                          ? controller.value.clamp(0.0, 1.0)
                          : null,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}

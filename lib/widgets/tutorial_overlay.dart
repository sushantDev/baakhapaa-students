import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/tutorial_flow_provider.dart';

class TutorialOverlay extends StatelessWidget {
  final Widget child;
  final String targetKey;
  final bool showOverlay;

  const TutorialOverlay({
    Key? key,
    required this.child,
    required this.targetKey,
    this.showOverlay = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TutorialFlowProvider>(
      builder: (context, tutorial, _) {
        if (!tutorial.isActive || !showOverlay) return child;

        final bool isCurrentTarget =
            tutorial.getCurrentStepTarget() == targetKey;
        final String message = tutorial.getCurrentStepMessage();

        if (!isCurrentTarget) return child;

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Full screen semi-transparent overlay with blur
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),

              // Highlighted target button with pulsing animation
              Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 1.0, end: 1.2),
                  duration: Duration(seconds: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.5),
                              spreadRadius: 5,
                              blurRadius: 7,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.amber,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: child,
                  ),
                ),
              ),

              // Tutorial message
              Positioned(
                top: MediaQuery.of(context).size.height * 0.4,
                left: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => tutorial.nextStep(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

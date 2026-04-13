import 'package:flutter/material.dart';

class TutorialIndicator extends StatefulWidget {
  final double size;
  final Color color;
  final double opacity;

  const TutorialIndicator({
    Key? key,
    this.size = 50,
    this.color = Colors.red,
    this.opacity = 0.4,
  }) : super(key: key);

  @override
  State<TutorialIndicator> createState() => _TutorialIndicatorState();
}

class _TutorialIndicatorState extends State<TutorialIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  // late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // _slideAnimation = Tween<Offset>(
    //   begin: Offset(-0.3, 0.0),
    //   end: Offset(0.3, 0.0),
    // ).animate(CurvedAnimation(
    //   parent: _animationController,
    //   curve: Curves.easeInOutSine,
    // ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
    // SlideTransition(
    //   position: _slideAnimation,
    //   child: Icon(
    //     Icons.touch_app_rounded,
    //     size: widget.size,
    //     color: widget.color.withValues(alpha: widget.opacity),
    //   ),
    // );
  }
}

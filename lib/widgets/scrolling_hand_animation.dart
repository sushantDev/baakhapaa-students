import 'package:flutter/material.dart';

class ScrollingHandAnimation extends StatefulWidget {
  const ScrollingHandAnimation({Key? key}) : super(key: key);

  @override
  _ScrollingHandAnimationState createState() => _ScrollingHandAnimationState();
}

class _ScrollingHandAnimationState extends State<ScrollingHandAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 0.2),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Icon(
        Icons.touch_app,
        size: 48.0,
        color: Colors.grey,
      ),
    );
  }
}

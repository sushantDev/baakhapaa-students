// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// enum TutorialShape {
//   circle,
//   rectangle,
// }

// class Tutorials extends StatefulWidget {
//   final GlobalKey keyNavigation;
//   final bool showTutorials;
//   final String targetTitle;
//   final String targetDescription;
//   final void Function() afterCompletion;
//   final void Function() onSkip;
//   final bool renderTop;
//   final Widget child;
//   final TutorialShape shape;

//   const Tutorials({
//     Key? key,
//     required this.keyNavigation,
//     required this.showTutorials,
//     required this.targetTitle,
//     required this.targetDescription,
//     required this.afterCompletion,
//     required this.renderTop,
//     required this.child,
//     this.shape = TutorialShape.rectangle,
//     required this.onSkip,
//   }) : super(key: key);

//   @override
//   State<Tutorials> createState() => _TutorialsState();
// }

// class _TutorialsState extends State<Tutorials> {
//   List<TargetFocus> targets = [];
//   late TutorialCoachMark tutorialCoachMark;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.showTutorials) {
//       createTutorial();
//       Future.delayed(Duration(seconds: 1), showTutorial);
//     }
//   }

//   void showTutorial() {
//     tutorialCoachMark.show(context: context);
//   }

//   void createTutorial() {
//     tutorialCoachMark = TutorialCoachMark(
//       targets: _createTargets(),
//       colorShadow: Colors.amber,
//       paddingFocus: 10,
//       opacityShadow: 0.2,
//       imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
//       onClickTarget: (target) {
//         widget.afterCompletion();
//       },
//     );
//   }

//   ShapeLightFocus _getShape(TutorialShape shape) {
//     switch (shape) {
//       case TutorialShape.circle:
//         return ShapeLightFocus.Circle;
//       case TutorialShape.rectangle:
//       default:
//         return ShapeLightFocus.RRect;
//     }
//   }

//   List<TargetFocus> _createTargets() {
//     List<TargetFocus> targets = [];
//     targets.add(
//       TargetFocus(
//         identify: "keyNavigation",
//         keyTarget: widget.keyNavigation,
//         enableOverlayTab: true,
//         shape: _getShape(widget.shape),
//         contents: [
//           TargetContent(
//             align: widget.renderTop ? ContentAlign.top : ContentAlign.bottom,
//             builder: (context, controller) {
//               return Card(
//                 color: Colors.black54,
//                 child: Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: <Widget>[
//                       Text(
//                         widget.targetTitle,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 22,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(
//                         height: 10,
//                       ),
//                       Text(
//                         widget.targetDescription,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                       const SizedBox(
//                         height: 20,
//                       ),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           ElevatedButton(
//                             onPressed: () {
//                               widget.afterCompletion();
//                               controller.next();
//                             },
//                             child: Text("Next"),
//                           ),
//                           ElevatedButton(
//                             onPressed: () {
//                               tutorialCoachMark.finish(); // Close the tutorial
//                               widget.onSkip();
//                             },
//                             child: Text("Skip"),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(
//                         height: 60,
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );

//     return targets;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return widget.child;
//   }
// }

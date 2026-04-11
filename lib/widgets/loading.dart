import 'package:flutter/material.dart';

import 'skeleton_loading.dart';

class Loading extends StatelessWidget {
  const Loading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const FullScreenSkeleton();
  }
}

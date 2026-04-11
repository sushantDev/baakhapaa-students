// import 'package:baakhapaa/helpers/helpers.dart';
// import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/utils/exit_confirmation_dialog.dart';
// import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../../widgets/footer.dart';
import 'shop_screen.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/debug_logger.dart';

class TabViewProduct extends StatefulWidget {
  static const String routeName = '/tab_view_product';

  final GlobalKey<ScaffoldState> scaffoldKey;
  final int initialIndex;

  TabViewProduct({required this.scaffoldKey, this.initialIndex = 0});

  @override
  _TabViewProductState createState() => _TabViewProductState();
}

class _TabViewProductState extends State<TabViewProduct>
    with PuppetInteractionMixin {
  // final GlobalKey _ShopScreenKey = GlobalKey();
  // final GlobalKey _ReedemScreenKey = GlobalKey();
  // int _currentTutorialStepProduct = 1;
  // late SharedPreferences _prefs;
  // bool _showTutorials = true;

  @override
  void initState() {
    super.initState();

    final tutorialProvider =
        Provider.of<TutorialFlowProvider>(context, listen: false);
    // Show tutorial message after init
    if (tutorialProvider.currentStep == 3) {
      if (mounted) {
        tutorialProvider.showCurrentStepMessage(context);
      }
    }

    // Initialize puppet provider with force reset for testing
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        // DEBUG: Force reset puppet limits for testing
        await context
            .read<PuppetInteractionProvider>()
            .forceResetForTesting(context);
        DebugLogger.puppet(
            'DEBUG: TabViewProduct force reset puppet limits for testing');
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });

    // _initializeSharedPreferences();
  }

  // Future<void> _initializeSharedPreferences() async {
  //   _prefs = await SharedPreferences.getInstance();
  //   _loadCurrentTutorialStepProduct();
  // }

  // void _loadCurrentTutorialStepProduct() {
  //   setState(() {
  //     _currentTutorialStepProduct =
  //         _prefs.getInt('currentTutorialStepProduct') ?? 1;
  //     // _showTutorials = _currentTutorialStepProduct < 3;
  //   });
  // }

  // void _SkipStep() async {
  //   setState(() {
  //     _currentTutorialStepProduct = 4;
  //     _showTutorials = _currentTutorialStepProduct < 3;
  //   });

  //   await _prefs.setInt(
  //       'currentTutorialStepProduct', _currentTutorialStepProduct);
  // }

  // void _nextTutorialStep() async {
  //   setState(() {
  //     _showTutorials = _currentTutorialStepProduct < 3;
  //     _currentTutorialStepProduct++;
  //   });

  //   await _prefs.setInt(
  //       'currentTutorialStepProduct', _currentTutorialStepProduct);
  // }

  @override
  Widget build(BuildContext context) {
    return ExitConfirmationDialog.wrapWithExitConfirmation(
      context: context,
      child: Scaffold(
        key: widget.scaffoldKey,
        drawer: Drawer(
          child: NavBar(),
        ),
        body: DefaultTabController(
          length: 2,
          initialIndex: widget.initialIndex,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? Color.fromARGB(255, 9, 9, 9)
                      : Colors.white,
                  Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF082032)
                      : Color.fromARGB(255, 248, 248, 248),
                ],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ShopScreen(),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Footer(2),
      ),
    );
  }
}

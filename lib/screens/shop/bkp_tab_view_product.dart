// ignore_for_file: unused_import

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/utils/exit_confirmation_dialog.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/nav_bar.dart';
import 'package:baakhapaa/widgets/tutorial_indicator.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../../widgets/footer.dart';
import '../gift/gift_screen.dart';
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
        appBar: header(
          context: context,
          titleText: AppLocalizations.of(context)!.store,
          scaffoldKey: widget.scaffoldKey,
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
                // Modern Tab Bar
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF2A2A2A)
                            : Colors.white,
                        Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF1E1E1E)
                            : Colors.grey.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(context.l10n.shop),
                            ],
                          ),
                        ),
                      ),
                      Consumer<TutorialFlowProvider>(
                        builder: (context, tutorial, _) => Tab(
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.redeem_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(context.l10n.redeemLabel),
                                  ],
                                ),
                                if ((tutorial.currentStep == 3 ||
                                        tutorial.currentStep == 10) &&
                                    tutorial.isActive)
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TutorialIndicator(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      ShopScreen(),
                      GiftScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

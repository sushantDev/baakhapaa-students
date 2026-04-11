import 'package:baakhapaa/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/header.dart';
import '../user/orders_screen.dart';
import '../user/point_logs_screen.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';

class TabViewOrder extends StatefulWidget {
  static const String routeName = '/tab_view_log';

  final GlobalKey<ScaffoldState> scaffoldKey;

  TabViewOrder({required this.scaffoldKey});

  @override
  _TabViewOrderState createState() => _TabViewOrderState();
}

class _TabViewOrderState extends State<TabViewOrder>
    with PuppetInteractionMixin {
  final GlobalKey _PointLogKey = GlobalKey();
  final GlobalKey _OrderLogKey = GlobalKey();
  int _currentTutorialStep = 1;

  @override
  void initState() {
    super.initState();

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: context.l10n.transactionLog),
      body: Container(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Modern Tab Header
              Container(
                margin: EdgeInsets.all(16),
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
                      color: Colors.grey.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    padding: EdgeInsets.all(4),
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.amber.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.grey[600],
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: [
                      _currentTutorialStep == 1
                          ? Tab(
                              key: _PointLogKey,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.monetization_on_rounded,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      context.l10n.pointLog,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Tab(
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.monetization_on_rounded,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      context.l10n.pointLog,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      _currentTutorialStep == 2
                          ? Tab(
                              key: _OrderLogKey,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_bag_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      context.l10n.orderHistory,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Tab(
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_bag_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      context.l10n.orderHistory,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  children: [
                    PointLogsScreen(),
                    OrdersScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

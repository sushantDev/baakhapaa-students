import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth.dart';
import '../../widgets/loading.dart';
import '../../widgets/skeleton_loading.dart';

class PointLogsScreen extends StatefulWidget {
  static const routeName = '/point-logs-screen';

  const PointLogsScreen({Key? key}) : super(key: key);

  @override
  State<PointLogsScreen> createState() => _PointLogsScreenState();
}

class _PointLogsScreenState extends State<PointLogsScreen>
    with PuppetInteractionMixin {
  var _isInit = false;
  var _isLoading = true;
  late List<dynamic> _coinLogs = [];
  late Map<String, dynamic> _userInformation = {};
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      _fetchCoinLogs();
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchCoinLogs({int page = 1}) async {
    if (page == 1) {
      setState(() {
        _isLoading = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final response = await auth.getCoinLogs(page: page);

      // Fetch user information to get available coins
      await auth.getUser();

      setState(() {
        if (page == 1) {
          _coinLogs = response['data'];
        } else {
          _coinLogs.addAll(response['data']);
        }
        _userInformation = auth.userInformation ?? {};
        _currentPage = response['current_page'];
        _totalPages = response['last_page'];
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load coin logs'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_currentPage < _totalPages && !_isLoadingMore) {
      await _fetchCoinLogs(page: _currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Loading()
          : Container(
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
                        : Color.fromARGB(255, 188, 186, 186),
                  ],
                ),
              ),
              child: _coinLogs.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await _fetchCoinLogs(page: 1);
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollInfo) {
                            // Load more when we reach 80% of the scroll extent
                            if (scrollInfo.metrics.pixels /
                                    scrollInfo.metrics.maxScrollExtent >
                                0.8) {
                              _loadMoreLogs();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            physics: BouncingScrollPhysics(),
                            itemBuilder: ((context, index) {
                              if (index == _coinLogs.length) {
                                // Show loading indicator at the bottom if loading more
                                return _isLoadingMore
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: ShimmerLoading(
                                          child: SkeletonBox(
                                              width: double.infinity,
                                              height: 60,
                                              borderRadius: 12),
                                        ),
                                      )
                                    : SizedBox.shrink();
                              }
                              return _buildTransactionCard(
                                  _coinLogs[index], index);
                            }),
                            itemCount: _coinLogs.length +
                                (_currentPage < _totalPages ? 1 : 0),
                          ),
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(40),
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
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.amber.shade600],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.monetization_on_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Point Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Color(0xFF082032),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Your point transaction history will appear here when you start earning or spending points.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction, int index) {
    final isDebited = transaction['status'] == 'debited';
    final coin = int.tryParse(transaction['coin']?.toString() ?? '0') ?? 0;
    final remarks = transaction['remarks'] ?? '';
    final date = DateTime.parse(transaction['created_at']);

    // Calculate balance at the time of this transaction
    // Start with current available coins and work backwards
    int currentAvailableCoins =
        int.tryParse(_userInformation['available_coins']?.toString() ?? '0') ??
            0;
    int balanceAtTransaction = currentAvailableCoins;

    // For each transaction from index 0 to current index-1, reverse its effect
    for (int i = 0; i < index; i++) {
      final prevTransaction = _coinLogs[i];
      final prevCoin =
          int.tryParse(prevTransaction['coin']?.toString() ?? '0') ?? 0;
      final prevIsDebited = prevTransaction['status'] == 'debited';

      // Reverse the transaction effect
      if (prevIsDebited) {
        balanceAtTransaction += prevCoin; // Add back what was debited
      } else {
        balanceAtTransaction -= prevCoin; // Subtract what was credited
      }
    }

    // The balance shown should be AFTER this transaction was applied
    // So we don't need to adjust for the current transaction

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
        border: isDebited
            ? Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1)
            : Border.all(color: Colors.green.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDebited
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDebited
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDebited ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        isDebited ? 'Debited' : 'Credited',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Transaction details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon indicator
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDebited
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDebited
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isDebited
                        ? Icons.remove_circle_rounded
                        : Icons.add_circle_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),

                // Transaction info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Remarks with expandable text
                      Container(
                        child: ExpandableText(
                          remarks,
                          expandText: 'more',
                          collapseText: 'less',
                          expandOnTextTap: true,
                          collapseOnTextTap: true,
                          maxLines: 2,
                          linkColor: Colors.blue,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Color(0xFF082032),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Coin amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${isDebited ? '-' : '+'}$coin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isDebited ? Colors.red[600] : Colors.green[600],
                          ),
                        ),
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            'assets/images/coins.png',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Balance after this transaction
                    Text(
                      'Balance: $balanceAtTransaction',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

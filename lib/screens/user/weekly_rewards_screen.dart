import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:provider/provider.dart';
import '../../providers/auth.dart';
import '../../widgets/header.dart';
import '../../widgets/loading.dart';
import '../../utils/debug_logger.dart';

class WeeklyRewardsScreen extends StatefulWidget {
  static const routeName = '/weekly-rewards-screen';

  @override
  _WeeklyRewardsScreenState createState() => _WeeklyRewardsScreenState();
}

class _WeeklyRewardsScreenState extends State<WeeklyRewardsScreen>
    with PuppetInteractionMixin {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyRewardData();
  }

  Future<void> _loadDailyRewardData() async {
    try {
      await Provider.of<Auth>(context, listen: false).fetchDailyRewardsStatus();
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      DebugLogger.error('Error loading rewards data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _claimDailyReward() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);

      // Show a loading indicator while claiming
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Claiming reward...")
            ],
          ),
        ),
      );

      try {
        final result = await auth.claimDailyReward();

        // Close the loading dialog
        Navigator.of(context).pop();

        // Extract reward data from the response
        final reward = result['reward'];

        // Show success message with properly contrasted colors
        if (reward != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'You claimed ${reward['points']} points of ${reward['name']}! Come back tomorrow for more rewards.'),
            backgroundColor: Colors.green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(result['message'] ?? 'Daily reward claimed successfully!'),
            backgroundColor: Colors.green,
          ));
        }

        // Refresh data after successful claim
        await _loadDailyRewardData();
      } catch (claimError) {
        // Close the loading dialog
        Navigator.of(context).pop();

        DebugLogger.error('Claim error: $claimError');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not process claim: $claimError'),
          backgroundColor: Colors.orange,
        ));
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Close the loading dialog if it's open
      Navigator.of(context, rootNavigator: true).pop();

      DebugLogger.error('Error in _claimDailyReward: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to claim reward: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get rewards data from the provider
    final auth = Provider.of<Auth>(context);
    final rewardsData = auth.dailyRewardsData;
    final currentDay = rewardsData['current_day'] ?? 1;
    final canClaimToday = rewardsData['can_claim_today'] ?? false;
    final rewardsList = rewardsData['rewards'] ?? [];
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return Scaffold(
      appBar: header(context: context, titleText: 'Weekly Rewards'),
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
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'DAILY LOGIN REWARDS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Log in daily to collect rewards throughout the week',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Day indicator
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Current Day: $currentDay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Weekly calendar
                    Expanded(
                      child: ListView.builder(
                        itemCount:
                            rewardsList.length > 0 ? rewardsList.length : 7,
                        itemBuilder: (context, index) {
                          final day = index + 1;
                          final bool isCurrentDay = day == currentDay;
                          final bool isPastDay =
                              day < currentDay || (day > 1 && currentDay == 1);
                          final bool isClaimable =
                              isCurrentDay && canClaimToday;

                          // Use reward data if available, or fallback to default
                          final reward = rewardsList.length > index
                              ? rewardsList[index]
                              : null;
                          final title = reward != null
                              ? reward['title']
                              : dayNames[index % 7];
                          final points = reward != null
                              ? reward['points']
                              : (index + 1) * 10;
                          final description =
                              reward != null ? reward['description'] : '';

                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isCurrentDay
                                  ? Colors.amber.shade200
                                  : Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color(0xff222831)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: isCurrentDay
                                  ? Border.all(color: Colors.amber, width: 2)
                                  : null,
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isPastDay
                                      ? Colors.grey
                                      : isClaimable
                                          ? Colors.green
                                          : Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    day.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isCurrentDay
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  // Improve contrast for text on amber background
                                  color: isCurrentDay
                                      ? Colors
                                          .black87 // Darker text on amber background
                                      : Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black87,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$points Points',
                                    style: TextStyle(
                                      // Improve contrast for text on amber background
                                      color: isCurrentDay
                                          ? Colors
                                              .black54 // Darker text on amber background
                                          : Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white70
                                              : Colors.black54,
                                      fontWeight: isCurrentDay
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (description.isNotEmpty)
                                    Text(
                                      description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        // Improve contrast for text on amber background
                                        color: isCurrentDay
                                            ? Colors
                                                .black54 // Darker text on amber background
                                            : Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white70
                                                : Colors.black54,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isPastDay
                                  ? Icon(Icons.check_circle, color: Colors.grey)
                                  : isClaimable
                                      ? ElevatedButton(
                                          onPressed: _claimDailyReward,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor:
                                                Colors.white, // Text color
                                          ),
                                          child: Text('CLAIM'),
                                        )
                                      : isCurrentDay
                                          ? ElevatedButton(
                                              onPressed: null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey,
                                                foregroundColor:
                                                    Colors.white, // Text color
                                              ),
                                              child: Text('CLAIMED'),
                                            )
                                          : Icon(Icons.lock_outline,
                                              color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 20),

                    // Progress bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (currentDay - 1) / 7,
                          backgroundColor: Colors.grey.shade300,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.amber),
                          minHeight: 10,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Complete the week to maximize your rewards!',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Claim button - only show when claimable
                    if (canClaimToday && currentDay <= 7)
                      ElevatedButton(
                        onPressed: _claimDailyReward,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor:
                              Colors.black87, // Text color for contrast
                          padding: EdgeInsets.symmetric(
                              horizontal: 40, vertical: 12),
                        ),
                        child: Text(
                          'CLAIM DAY $currentDay REWARD',
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
    );
  }
}

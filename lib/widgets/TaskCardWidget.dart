import 'package:baakhapaa/screens/user/levels_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/providers/levels.dart';

class TaskCardWidget extends StatelessWidget {
  const TaskCardWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<Levels>(
      builder: (context, levelsProvider, _) {
        final remainingActions = levelsProvider.remainingActions;
        final nextAction =
            remainingActions.isNotEmpty ? remainingActions.first : null;
        final actionData = nextAction?['action'] as Map<String, dynamic>?;
        final title = actionData?['title'] as String? ?? 'All tasks completed';
        final description =
            actionData?['description'] as String? ?? 'Nothing left to do here.';
        final progress = levelsProvider.progressPercentage.clamp(0, 100);
        final progressFactor = (progress / 100).clamp(0.0, 1.0);

        return InkWell(
          onTap: () => {
            Navigator.of(context).pushNamed(LevelsScreen.routeName),
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            height: 200, // Total height including overflow
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main yellow container
                Positioned(
                  top: 35, // Space for the header to overflow
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Color(0xFFFDB528), // Amber/golden yellow
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 50, 160, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Black dot
                          Container(
                            width: 10,
                            height: 10,
                            margin: EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1,
                              ),
                            ),
                          ),

                          SizedBox(width: 12),
                          // Text content and progress
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 10),
                                // Progress bar
                                Container(
                                  width: double.infinity,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE0E0E0),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Filled progress
                                      FractionallySizedBox(
                                        widthFactor: progressFactor,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color(
                                                0xFF8B6239), // Brown color
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Center(
                                          child: Text(
                                            '${progress.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Header with icon and title - positioned outside/above the container
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    height: 70,
                    padding: EdgeInsets.only(right: 10, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/clipboard.png',
                        ),
                        Text(
                          'Your Next Task',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Puppet image positioned outside/overlapping the right edge
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Image.asset(
                    'assets/images/puppetdev.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Example usage in a screen
class TaskScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20),
            TaskCardWidget(),
          ],
        ),
      ),
    );
  }
}

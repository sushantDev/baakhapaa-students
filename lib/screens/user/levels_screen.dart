import 'package:baakhapaa/helpers/helpers.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:provider/provider.dart';
import '../../providers/levels.dart';
import '../../widgets/header.dart';
import '../../widgets/loading.dart';
import '../../utils/debug_logger.dart';

class LevelsScreen extends StatefulWidget {
  static const routeName = '/levels-screen';

  @override
  _LevelsScreenState createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen>
    with PuppetInteractionMixin {
  bool _isLoading = true;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _loadLevelsData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _loadLevelsData() async {
    try {
      final levelsProvider = Provider.of<Levels>(context, listen: false);
      await levelsProvider.fetchUserProgress();
      await levelsProvider.fetchAllLevels();
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      DebugLogger.error('Error loading levels data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLevelUp() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final levelsProvider = Provider.of<Levels>(context, listen: false);
      final result = await levelsProvider.checkLevelUp();

      setState(() {
        _isLoading = false;
      });

      // Show result dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(result['leveled_up'] ? '🎉 Level Up!' : 'Keep Going!'),
          content: Text(result['message'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking level up: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: "LEVELS"),
      body: _isLoading
          ? Loading()
          : Consumer<Levels>(
              builder: (ctx, levelsProvider, _) => SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Level Card
                    _buildCurrentLevelCard(levelsProvider),

                    SizedBox(height: 20),

                    // Progress Card
                    _buildProgressCard(levelsProvider),

                    SizedBox(height: 20),

                    // Actions Progress
                    _buildActionsProgress(levelsProvider),

                    SizedBox(height: 20),

                    // Check Level Up Button
                    Center(
                      child: ElevatedButton(
                        onPressed: _checkLevelUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                        ),
                        child: Text('Check Level Up'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentLevelCard(Levels levelsProvider) {
    final currentLevel = levelsProvider.currentLevel;
    final nextLevel = levelsProvider.nextLevel;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Level',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            if (currentLevel != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentLevel['name'] ?? 'Unknown Level',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  Text(currentLevel['desc'] ?? ''),
                ],
              )
            else
              Text(
                'No current level - Start your journey!',
                style: TextStyle(fontSize: 16),
              ),
            if (nextLevel != null && !levelsProvider.isMaxLevel) ...[
              SizedBox(height: 16),
              Text(
                '${context.l10n.next} ${context.l10n.level}: ${nextLevel['name']}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(nextLevel['desc'] ?? ''),
            ],
            if (levelsProvider.isMaxLevel)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  '🏆 Congratulations! You\'ve reached the maximum level!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(Levels levelsProvider) {
    final progressPercentage = levelsProvider.progressPercentage;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.l10n.progress} ${context.l10n.to} ${context.l10n.next} ${context.l10n.level}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${progressPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressPercentage / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsProgress(Levels levelsProvider) {
    final remainingActions = levelsProvider.remainingActions;
    final completedActions = levelsProvider.completedActions;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.l10n.required}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),

            // Completed Actions
            if (completedActions.isNotEmpty) ...[
              Text(
                '${context.l10n.complete}d ✅',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              ...completedActions
                  .map((action) => _buildActionItem(action, true)),
              SizedBox(height: 12),
            ],

            // Remaining Actions
            if (remainingActions.isNotEmpty) ...[
              Text(
                'Remaining 📋',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
              ...remainingActions
                  .map((action) => _buildActionItem(action, false)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(Map<String, dynamic> actionData, bool isCompleted) {
    final action = actionData['action'];
    final requiredValue = actionData['required_value'];
    final currentProgress = actionData['current_progress'];
    final completed = actionData['completed'] ?? isCompleted;

    final title = action['title'] ?? '';
    final description = action['description'] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: completed ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: completed ? Colors.green : Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 28, top: 4),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          if (currentProgress != null && requiredValue != null)
            Padding(
              padding: EdgeInsets.only(left: 28, top: 4),
              child: Text(
                '${context.l10n.progress}: $currentProgress / ${requiredValue.replaceAll('"', '')}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
// ma kai bolina sabai

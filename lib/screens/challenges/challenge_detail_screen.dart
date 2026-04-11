import 'package:baakhapaa/screens/challenges/challenge_detail_product_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:baakhapaa/providers/challenge.dart';
import 'package:baakhapaa/widgets/loading.dart';
import '../../utils/debug_logger.dart';
import 'challenge_detail_shorts_screen.dart';
import 'challenge_detail_season_screen.dart';
import 'challenge_detail_screens_shared.dart';

// ==================== CHALLENGE DETAIL ROUTER ====================
// This screen acts as a dispatcher/router that routes to the appropriate
// challenge detail screen based on the challenge platform type.
// Supports: Shorts, Seasons (and easily extensible for future types like Products)

class ChallengeDetailScreen extends StatefulWidget {
  static const routeName = '/challenge-detail-screen';

  const ChallengeDetailScreen({Key? key}) : super(key: key);

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  var _isInit = true;
  var _isLoading = true;
  Map<String, dynamic>? challenge;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _fetchChallengeData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchChallengeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get challenge ID from route arguments
      final arguments = ModalRoute.of(context)?.settings.arguments;
      int challengeId;

      if (arguments is Map) {
        challengeId = arguments['id'] ?? arguments['challengeId'] ?? 0;
      } else if (arguments is int) {
        challengeId = arguments;
      } else if (arguments is String) {
        challengeId = int.tryParse(arguments) ?? 0;
      } else {
        challengeId = 0;
      }

      DebugLogger.info('🔍 Router: Loading challenge ID: $challengeId');

      // Fetch challenge from provider
      final challengeProvider = Provider.of<Challenge>(context, listen: false);
      await challengeProvider.fetchChallenges();

      if (!mounted) return;

      final challengeData = challengeProvider.challenges.firstWhere(
        (c) => c['id'] == challengeId,
        orElse: () => <String, dynamic>{
          'id': challengeId,
          'title': 'Unknown Challenge',
          'platform': 'Shorts', // Default to Shorts
        },
      );

      setState(() {
        challenge = challengeData;
        _isLoading = false;
      });

      DebugLogger.success(
          '✅ Router: Challenge loaded - Platform: ${challengeData['platform']}');
    } catch (error) {
      DebugLogger.error('❌ Router: Error loading challenge: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Loading(),
      );
    }

    if (challenge == null) {
      return const Scaffold(
        body: ErrorState(),
      );
    }

    // Route based on platform type
    final String platform = challenge!['platform'] ?? 'Shorts';

    DebugLogger.info('🚦 Router: Routing to $platform challenge screen');

    switch (platform.toLowerCase()) {
      case 'seasons':
      case 'season':
        return ChallengeDetailSeasonScreen(challenge: challenge);

      case 'products':
      case 'product':
        return ChallengeDetailProductScreen(challenge: challenge);

      case 'shorts':
      case 'short':
      default:
        return ChallengeDetailShortsScreen(challenge: challenge);
    }
  }
}

// challenge_detail_screen.dart (Router)
// ├── Dispatches to → challenge_detail_shorts_screen.dart
// │                   ├── Uses → challenge_detail_screens_shared.dart (ChallengeHeader, MyVideoReportCard, etc.)
// │                   └── Uses → challenge_detail_widgets.dart (ChallengeProgressCard, models)
// │
// └── Dispatches to → challenge_detail_season_screen.dart
//                     ├── Uses → challenge_detail_screens_shared.dart (Same shared components)
//                     └── Uses → challenge_detail_widgets.dart (Same widgets)

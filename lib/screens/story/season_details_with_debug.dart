import 'package:flutter/material.dart';
import '../../utils/debug_logger.dart';
import 'episode_screen.dart';

class SeasonDetailsWithDebug extends StatelessWidget {
  final Map<String, dynamic>? detailedSeasonData;
  const SeasonDetailsWithDebug({Key? key, this.detailedSeasonData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final seasonData = detailedSeasonData ?? {};
    int? creatorId;
    if (seasonData['creator_id'] != null) {
      creatorId = seasonData['creator_id'] is int
          ? seasonData['creator_id']
          : int.tryParse(seasonData['creator_id'].toString());
    } else if (seasonData['creator'] is Map &&
        seasonData['creator']['id'] != null) {
      creatorId = seasonData['creator']['id'] is int
          ? seasonData['creator']['id']
          : int.tryParse(seasonData['creator']['id'].toString());
    }
    DebugLogger.api('👤 SeasonDetails creatorId = $creatorId');
    DebugLogger.api(
        '👤 SeasonDetails has creator_id in data: ${seasonData.containsKey("creator_id")}');
    return SeasonDetails(detailedSeasonData: detailedSeasonData);
  }
}

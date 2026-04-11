class RequirementData {
  final String text;
  final int? currentProgress;
  final int? requiredValue;
  final bool isCompleted;
  final String? imageUrl;
  final String? type;
  final int? achievementId;

  const RequirementData({
    required this.text,
    this.currentProgress,
    this.requiredValue,
    this.isCompleted = false,
    this.imageUrl,
    this.type,
    this.achievementId,
  });
}

class LevelData {
  final int number;
  final String title;
  final String subtitle;
  final List<RequirementData> requirements;
  final bool isCurrent;
  final bool isCompleted;
  final int rewardPoints;
  final String? imageUrl;

  const LevelData({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.requirements,
    required this.rewardPoints,
    this.isCurrent = false,
    this.isCompleted = false,
    this.imageUrl,
  });
}

/// Represents a single onboarding slide.
///
/// All assets are served from DigitalOcean Spaces CDN.
/// No backend API — slides are hardcoded locally.
class OnboardingSlide {
  final int id;
  final int order;
  final String? title;
  final String? subtitle;
  final String? bodyText;
  final String? ctaText;
  final String slideType;
  final String? assetPath;
  final String? secondaryAssetPath;
  final String? bgColor;
  final String? accentColor;
  final int? stepNumber;
  final int totalSteps;
  final List<Map<String, dynamic>>? options;
  final bool isSkippable;
  final bool showPuppetAvatar;
  final bool showGiftIcon;
  final String? speechBubble;
  final int autoAdvanceMs;
  final int? quizTimerSeconds;
  final int? quizCorrectIndex;
  final String? hintText;
  final String? infoCardLabel;
  final String? infoCardValue;
  final String? infoCardCaption;
  final int? rewardPoints;

  const OnboardingSlide({
    required this.id,
    required this.order,
    this.title,
    this.subtitle,
    this.bodyText,
    this.ctaText,
    required this.slideType,
    this.assetPath,
    this.secondaryAssetPath,
    this.bgColor,
    this.accentColor,
    this.stepNumber,
    this.totalSteps = 12,
    this.options,
    this.isSkippable = true,
    this.showPuppetAvatar = false,
    this.showGiftIcon = false,
    this.speechBubble,
    this.autoAdvanceMs = 0,
    this.quizTimerSeconds,
    this.quizCorrectIndex,
    this.hintText,
    this.infoCardLabel,
    this.infoCardValue,
    this.infoCardCaption,
    this.rewardPoints,
  });
}

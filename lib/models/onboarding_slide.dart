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

  /// Returns a new [OnboardingSlide] with the given fields overridden.
  /// Used by [OnboardingProvider.slides] to rewrite step numbers dynamically.
  OnboardingSlide copyWith({
    int? stepNumber,
    int? totalSteps,
  }) =>
      OnboardingSlide(
        id: id,
        order: order,
        title: title,
        subtitle: subtitle,
        bodyText: bodyText,
        ctaText: ctaText,
        slideType: slideType,
        assetPath: assetPath,
        secondaryAssetPath: secondaryAssetPath,
        bgColor: bgColor,
        accentColor: accentColor,
        stepNumber: stepNumber ?? this.stepNumber,
        totalSteps: totalSteps ?? this.totalSteps,
        options: options,
        isSkippable: isSkippable,
        showPuppetAvatar: showPuppetAvatar,
        showGiftIcon: showGiftIcon,
        speechBubble: speechBubble,
        autoAdvanceMs: autoAdvanceMs,
        quizTimerSeconds: quizTimerSeconds,
        quizCorrectIndex: quizCorrectIndex,
        hintText: hintText,
        infoCardLabel: infoCardLabel,
        infoCardValue: infoCardValue,
        infoCardCaption: infoCardCaption,
        rewardPoints: rewardPoints,
      );
}

import 'package:flutter/foundation.dart';
import '../models/onboarding_slide.dart';

/// Provides onboarding slide data. All assets hosted on DigitalOcean Spaces CDN.
/// No backend API needed — slides are fully local constants.
class OnboardingProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<OnboardingSlide> get slides => localSlides;

  /// CDN base path for all onboarding assets.
  static const _cdn =
      'https://bkp-v1.blr1.cdn.digitaloceanspaces.com/onboarding';

  /// All image/GIF URLs that should be prefetched when onboarding starts.
  static List<String> get prefetchUrls => [
        '$_cdn/puppet_phone.gif',
        '$_cdn/puppet_intro.gif',
        '$_cdn/puppet_spotlight.png',
        '$_cdn/puppet_helpme.gif',
        '$_cdn/puppet_waving.png',
        '$_cdn/puppet_cables.gif',
        '$_cdn/puppet_level_zero.png',
        '$_cdn/puppet_laughing.gif',
        '$_cdn/puppet_gifts.gif',
        '$_cdn/coin_logo.png',
        '$_cdn/gift.png',
      ];

  /// Hard-coded slides matching Figma design — 17 screens, 14 steps.
  static List<OnboardingSlide> get localSlides => [
        // ── id:0  Step 1/14 — Role selection ───────────────────────────
        const OnboardingSlide(
          id: 0,
          order: 0,
          title: 'What defines you?',
          subtitle:
              'Select a role to personalize your experience and unlock specific features.',
          slideType: 'selection',
          bgColor: '#0D0D0D',
          stepNumber: 1,
          totalSteps: 14,
          ctaText: 'Continue',
          isSkippable: false,
          options: [
            {
              'label': 'Player',
              'subtitle': 'Compete as a player',
              'icon': 'gamepad',
              'preselected': true,
            },
            {
              'label': 'Creator',
              'subtitle': 'Compete as a creator',
              'icon': 'settings',
            },
            {
              'label': 'Vendor',
              'subtitle': 'Unlock vendor privilege',
              'icon': 'store',
            },
          ],
        ),

        // ── id:1  Step 2/14 — Time engagement ──────────────────────────
        const OnboardingSlide(
          id: 1,
          order: 1,
          title: 'How much time do you spend on content engagement?',
          subtitle:
              'This helps us tailor your experience and manage your insights effectively.',
          slideType: 'selection',
          bgColor: '#0D0D0D',
          stepNumber: 2,
          totalSteps: 14,
          ctaText: 'Continue',
          isSkippable: false,
          options: [
            {'label': 'Less than 1 hour', 'preselected': true},
            {'label': '1-3 hours'},
            {'label': '3-5 hours'},
            {'label': '5+ hours'},
          ],
        ),

        // ── id:2  Step 3/14 — Engagement value info ────────────────────
        OnboardingSlide(
          id: 2,
          order: 2,
          slideType: 'info',
          assetPath: '$_cdn/coin_logo.png',
          title: 'Did you know your engagement has value?',
          subtitle:
              'Every interaction you make contributes to the ecosystem. We believe in rewarding our most active members with exclusive benefits as gifts...',
          bgColor: '#0D0D0D',
          stepNumber: 3,
          totalSteps: 14,
          ctaText: 'Continue',
          infoCardLabel: 'AVERAGE REWARD VALUE',
          infoCardValue: '1200+',
          infoCardCaption: 'Personalized Rewards',
        ),

        // ── id:3  Step 4/14 — puppet_phone.gif (auto-advance) ─────────
        OnboardingSlide(
          id: 3,
          order: 3,
          slideType: 'fullscreen_image',
          assetPath: '$_cdn/puppet_phone.gif',
          bgColor: '#0D0D0D',
          stepNumber: 4,
          totalSteps: 14,
          autoAdvanceMs: 4000,
        ),

        // ── id:4  Step 4/14 — puppet_intro.gif → puppet_spotlight.png ──
        OnboardingSlide(
          id: 4,
          order: 4,
          slideType: 'fullscreen_image',
          assetPath: '$_cdn/puppet_intro.gif',
          secondaryAssetPath: '$_cdn/puppet_spotlight.png',
          title: 'Not knowing makes you a puppet...',
          subtitle:
              'Seek truth, gain mastery over yourself. Knowledge is the only key to true autonomy...',
          bodyText:
              'Baakhapaa app is the platform to free you from your strings.',
          bgColor: '#0D0D0D',
          stepNumber: 4,
          totalSteps: 14,
          ctaText: 'Continue',
        ),

        // ── id:5  Step 5/14 — puppet_helpme.gif (auto-advance) ────────
        OnboardingSlide(
          id: 5,
          order: 5,
          slideType: 'fullscreen_image',
          assetPath: '$_cdn/puppet_helpme.gif',
          bgColor: '#0D0D0D',
          stepNumber: 5,
          totalSteps: 14,
          autoAdvanceMs: 6000,
        ),

        // ── id:6  Step 5/14 — quiz prompt with puppet_waving.png bg ───
        OnboardingSlide(
          id: 6,
          order: 6,
          slideType: 'quiz_prompt',
          assetPath: '$_cdn/puppet_waving.png',
          bodyText: 'Click on the quiz button\nto free the puppet.',
          bgColor: '#0D0D0D',
          stepNumber: 5,
          totalSteps: 14,
        ),

        // ── id:7  Step 6/14 — Quiz question ───────────────────────────
        const OnboardingSlide(
          id: 7,
          order: 7,
          slideType: 'quiz',
          title: 'What held the puppet captive?',
          bgColor: '#0D0D0D',
          stepNumber: 6,
          totalSteps: 14,
          ctaText: 'Confirm answer',
          quizTimerSeconds: 7,
          quizCorrectIndex: 0,
          hintText: 'Press to get hint',
          options: [
            {'label': 'A. Wires were holding the puppet captive.'},
            {'label': 'B. Option 1.'},
          ],
        ),

        // ── id:8  Step 7/14 — puppet freed (puppet_cables.gif) ────────
        OnboardingSlide(
          id: 8,
          order: 8,
          slideType: 'fullscreen_image',
          assetPath: '$_cdn/puppet_cables.gif',
          bgColor: '#0D0D0D',
          stepNumber: 7,
          totalSteps: 14,
          autoAdvanceMs: 5000,
        ),

        // ── id:9  Step 8/14 — Puppet thanks you ───────────────────────
        OnboardingSlide(
          id: 9,
          order: 9,
          slideType: 'puppet_intro',
          assetPath: '$_cdn/puppet_level_zero.png',
          title: 'YOU FREED\nTHE PUPPET',
          subtitle: 'Your knowledge broke the chains. The puppet is grateful.',
          bgColor: '#0D0D0D',
          stepNumber: 8,
          totalSteps: 14,
          ctaText: 'Continue',
          speechBubble: 'Thank you for helping me!',
        ),

        // ── id:10  Step 9/14 — Puppet promises help ───────────────────
        OnboardingSlide(
          id: 10,
          order: 10,
          slideType: 'puppet_intro',
          assetPath: '$_cdn/puppet_level_zero.png',
          title: 'A NEW\nPARTNERSHIP',
          subtitle:
              'Together we grow — your curiosity fuels the journey ahead.',
          bgColor: '#0D0D0D',
          stepNumber: 9,
          totalSteps: 14,
          ctaText: 'Continue',
          speechBubble: "I'll help you in your journey",
        ),

        // ── id:11  Step 10/14 — Points earned 20 pts ──────────────────
        const OnboardingSlide(
          id: 11,
          order: 11,
          slideType: 'reward',
          bgColor: '#0D0D0D',
          stepNumber: 10,
          totalSteps: 14,
          showPuppetAvatar: true,
          speechBubble: 'You get points for your positive interaction',
          rewardPoints: 40,
          ctaText: 'Continue',
        ),

        // ── id:12  Step 11/14 — Puppet Dev Level 0 (gold circle) ──────
        OnboardingSlide(
          id: 12,
          order: 12,
          slideType: 'puppet_intro',
          assetPath: '$_cdn/puppet_level_zero.png',
          title: 'PUPPET DEV\nLEVEL 0',
          subtitle:
              'Unlock your true potential with the guidance of the puppet dev.',
          bgColor: '#0D0D0D',
          stepNumber: 11,
          totalSteps: 14,
          speechBubble: "Hi, I'm Puppet dev!",
          ctaText: 'Continue',
        ),

        // ── id:13  Step 12/14 — puppet_laughing.gif (white circle) ────
        OnboardingSlide(
          id: 13,
          order: 13,
          slideType: 'puppet_intro',
          assetPath: '$_cdn/puppet_laughing.gif',
          title: 'PUPPET DEV\nLEVEL 0',
          subtitle:
              'Unlock your true potential with the guidance of the puppet dev.',
          bgColor: '#0D0D0D',
          accentColor: '#FFFFFF',
          stepNumber: 12,
          totalSteps: 14,
          speechBubble: "I'll help you become a\nbetter human!",
          ctaText: 'Continue',
        ),

        // ── id:14  Step 13/14 — puppet_gifts.gif (white circle) + CTA ─
        OnboardingSlide(
          id: 14,
          order: 14,
          slideType: 'puppet_intro',
          assetPath: '$_cdn/puppet_gifts.gif',
          title: 'PUPPET DEV\nLEVEL 0',
          subtitle:
              'Unlock your true potential with the guidance of the puppet dev.',
          bgColor: '#0D0D0D',
          accentColor: '#FFFFFF',
          stepNumber: 13,
          totalSteps: 14,
          ctaText: 'Continue',
          speechBubble: "Feed me good stories\nI'll give you Benefits...",
        ),

        // ── id:15  Step 13/14 — Congratulations 40 pts + Rewards ──────
        const OnboardingSlide(
          id: 15,
          order: 15,
          slideType: 'congratulations',
          title: 'Congratulations!',
          subtitle: 'REWARD UNLOCKED',
          bodyText: "You've earned 40 points for your engagement.",
          bgColor: '#0D0D0D',
          stepNumber: 13,
          totalSteps: 14,
          ctaText: 'Claim Points',
          showPuppetAvatar: true,
          rewardPoints: 40,
        ),

        // ── id:17  Step 14/14 — Login CTA ─────────────────────────────
        const OnboardingSlide(
          id: 17,
          order: 17,
          slideType: 'cta',
          title: 'Login to claim your',
          subtitle: 'Storytelling Benefits.',
          bgColor: '#0D0D0D',
          stepNumber: 14,
          totalSteps: 14,
          ctaText: 'Login to continue',
          isSkippable: false,
          showPuppetAvatar: true,
          showGiftIcon: true,
        ),
      ];
}

# Onboarding Redesign — Implementation Plan V2

**Scope:** 15-screen onboarding flow with puppet character narrative, quiz interaction,
reward animations, and role selection. All assets are local (GIFs/PNGs bundled in-app).
No video player needed. Backend API exists for future admin management.

**Status:** ✅ Implemented — builds cleanly, 15 screens, all animations.

---

## Design System

| Token           | Value          | Usage                                        |
|-----------------|----------------|----------------------------------------------|
| Background      | `#0D0D0D`      | All slide backgrounds                        |
| Accent          | `#F4B625`      | Progress bar, buttons, borders, highlights   |
| White           | `#FFFFFF`      | Headings, step counter text                  |
| Muted           | `#AAAAAA`      | Subtitles, body text                         |
| Card BG         | `#1A1A1A`      | Selection cards, info cards                  |
| Card Border     | `#655017`      | Unselected card borders                      |
| Progress BG     | `#333333`      | Unfilled progress bar                        |
| Skip            | `#BCB097`      | "I'll decide later" text                     |

---

## Screen Flow (15 screens, 12 steps in progress bar)

| #   | Step  | Type              | Content                                                    | Asset                |
|-----|-------|-------------------|------------------------------------------------------------|----------------------|
| 1   | —     | Splash            | Logo fade in → hold → fade out → auto-advance              | `logo_baakhapaa.png` |
| 2   | 1/12  | `selection`       | "What defines you?" Player (pre-selected) / Creator / Vendor | —                  |
| 3   | 2/12  | `selection`       | "How much time on content engagement?" 4 time options      | —                    |
| 4   | 3/12  | `info`            | Coin image, "engagement has value?" + reward stats card     | `coin_logo.png`     |
| 5   | 4/12  | `fullscreen_image`| Puppet silhouette, "Not knowing makes you a puppet..."      | `puppet_intro.gif`  |
| 5.1 | 4/12  | `fullscreen_image`| Puppet close-up, Continue button                            | `puppet_phone.gif`  |
| 6   | 5/12  | `fullscreen_image`| Puppet tied up in chains, auto-advances (3.5s)              | `puppet_cables.gif` |
| 7   | 5/12  | `quiz_prompt`     | Puppet captive + pulsing quiz button, "Click to free"       | `puppet_cables.gif` |
| 8   | 6/12  | `quiz`            | 7s timer, "What held the puppet captive?" 2 options         | —                    |
| 9   | 7/12  | `fullscreen_image`| Puppet freed/escaping, auto-advances (3.5s)                 | `puppet_helpme.gif` |
| 10  | 8/12  | `reward`          | Points fly animation, speech bubble "You've earned 20 pts"  | —                    |
| 11  | 9/12  | `reward`          | Congratulations! Gift icon, 40 points, Claim Points CTA     | —                    |
| 12  | 10/12 | `puppet_intro`    | Puppet grows from header, "Hi, I'm Puppet dev!", Level 0    | `puppet_waving.png` |
| 13  | 10/12 | `puppet_intro`    | Puppet with gifts, "Feed me good stories", Continue          | `puppet_gifts.gif`  |
| 14  | 10/12 | `puppet_intro`    | Puppet spotlight, "I'll help you become better human"        | `puppet_spotlight.png` |
| 15  | 12/12 | `cta`             | "Login to claim your Storytelling Benefits." Login button    | —                    |

---

## Key Animations

1. **Splash** (Screen 1): Logo fades in → holds → fades out → navigates
2. **Progress bar**: `TweenAnimationBuilder` smoothly animates between steps
3. **Selection cards**: `AnimatedContainer` for border/fill transitions
4. **Fullscreen slides**: Auto-advance timer for story progression (configurable ms)
5. **Quiz button pulse**: `AnimationController.repeat(reverse: true)` scale 0.85→1.15
6. **Quiz timer**: Circular countdown with `CircularProgressIndicator`
7. **Points fly**: `SlideTransition` + `FadeTransition` — points animate toward puppet avatar
8. **Reward fade**: `FadeTransition` on gift icon, title, and body
9. **Puppet scale**: `ScaleTransition` with `easeOutBack` curve — puppet grows from 0→1 on puppet_intro slides
10. **Speech bubbles**: Positioned containers with accent background
11. **Arrow path**: `CustomPainter` curved arrow pointing to quiz button

---

## Slide Types & Widget Map

| Type              | Widget              | Behaviour                                          |
|-------------------|---------------------|---------------------------------------------------|
| `selection`       | `_SelectionSlide`   | Radio cards, preselect support, Continue CTA       |
| `info`            | `_InfoSlide`        | Coin image, rich text, info stats card             |
| `fullscreen_image`| `_FullscreenImageSlide` | Edge-to-edge bg, gradient overlay, text overlay |
| `quiz_prompt`     | `_QuizPromptSlide`  | Pulsing quiz button, arrow path, fullscreen bg     |
| `quiz`            | `_QuizSlide`        | Countdown timer, answer options, confirm, hint     |
| `reward`          | `_RewardSlide`      | Points animation, gift icon, congratulations text  |
| `puppet_intro`    | `_PuppetIntroSlide` | Scale animation, speech bubble, gold circle, level |
| `cta`             | `_CtaSlide`         | Final login CTA, puppet avatar, gift icon          |
| `image` / `gif`   | `_AssetSlide`       | Basic fallback — centered image + text + CTA       |

---

## Architecture

```
Cold Start
    │
    ▼
SplashScreen
  • Logo fade in → hold → fade out (2.4s TweenSequence)
  • _navigateAfterSplash():
    │
    ├─── onboarding_completed == true?
    │      └─► tryAutoLogin() → UserScreen / ShortsScreen
    │
    └─── first launch
           └─► fetchSlides() → OnboardingScreen (15 slides PageView)

OnboardingScreen
  • PageView with NeverScrollableScrollPhysics (button-driven)
  • Back arrow (top-left) for navigation
  • Auto-advance timer per slide (configurable)
  • TickerProviderStateMixin for puppet scale animation
  • Complete → SharedPrefs → WelcomeScreen (login)
```

---

## Asset Inventory (`assets/images/onboarding/`)

| File                    | Type | Used In               |
|-------------------------|------|-----------------------|
| `logo_baakhapaa.png`    | PNG  | Splash screen         |
| `coin_logo.png`         | PNG  | Screen 4 (info)       |
| `puppet_intro.gif`      | GIF  | Screen 5 (silhouette) |
| `puppet_phone.gif`      | GIF  | Screen 5.1 (close-up) |
| `puppet_cables.gif`     | GIF  | Screens 6, 7 (tied)   |
| `puppet_helpme.gif`     | GIF  | Screen 9 (freed)      |
| `puppet_waving.png`     | PNG  | Screen 12 (hi)        |
| `puppet_gifts.gif`      | GIF  | Screen 13 (benefits)  |
| `puppet_spotlight.png`  | PNG  | Screen 14 (help)      |
| `puppet_level_zero.png` | PNG  | Header avatar (small)  |
| `puppet_laughing.gif`   | GIF  | Unused (available)     |

---

## Files Modified

### Flutter (`baakhapaa_flutter_v3/`)

| File                                      | Action                                 |
|-------------------------------------------|----------------------------------------|
| `lib/models/onboarding_slide.dart`        | **REWRITTEN** — added quiz/reward/puppet fields |
| `lib/providers/onboarding_provider.dart`  | **REWRITTEN** — 15 slides with all types |
| `lib/screens/auth/onboarding_screen.dart` | **REWRITTEN** — 9 slide widgets + animations |
| `lib/screens/auth/splash_screen.dart`     | **UPDATED** — fade in/hold/out sequence |
| `lib/main.dart`                           | **EDIT** — provider, home, imports      |
| `pubspec.yaml`                            | **EDIT** — registered onboarding assets |

### Backend (`baakhapaa_backend/`)

| File                                                                       | Action    |
|----------------------------------------------------------------------------|-----------|
| `database/migrations/2026_04_06_173106_create_onboarding_slides_table.php` | CREATE    |
| `app/OnboardingSlide.php`                                                  | CREATE    |
| `app/Http/Controllers/api/OnboardingController.php`                        | CREATE    |
| `routes/api.php`                                                           | EDIT      |

---

## Verification Checklist

- [x] `flutter build apk --debug` compiles with zero errors/warnings
- [ ] Splash: logo fades in → holds → fades out → navigates
- [ ] Screen 2: Player pre-selected, 3 role cards with icons
- [ ] Screen 3: 4 time option cards (no icons)
- [ ] Screen 4: Coin image, accent text "engagement has value?", info card
- [ ] Screen 5: Fullscreen puppet silhouette with "puppet..." in accent
- [ ] Screen 5.1: Fullscreen puppet close-up with Continue
- [ ] Screen 6: Puppet tied GIF auto-advances after 3.5s
- [ ] Screen 7: Pulsing quiz button, arrow path, "Click to free"
- [ ] Screen 8: Timer countdown, 2 answer options, Confirm, correct = green
- [ ] Screen 9: Puppet freed GIF auto-advances after 3.5s
- [ ] Screen 10: Points fly animation, puppet avatar in header
- [ ] Screen 11: Gift icon, "Congratulations!", Claim Points button
- [ ] Screen 12: Puppet grows to center (scale anim), "Hi, I'm Puppet dev!"
- [ ] Screen 13: Puppet gifts GIF in circle, speech bubble, Continue
- [ ] Screen 14: Puppet spotlight in circle, speech bubble
- [ ] Screen 15: "Login to claim", Login button → WelcomeScreen
- [ ] Progress bar animates smoothly between steps
- [ ] Back arrow works on all screens except first
- [ ] Re-launch skips onboarding after completion

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/onboarding_slide.dart';
import '../../providers/connectivity_service.dart';
import '../../providers/onboarding_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/shorts/shorts_screen.dart';
import '../../widgets/app_button.dart';

// Keep legacy class alias so existing code doesn't break.
class BackgroundImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => OnboardingScreen();
}

// ═══════════════════════════════════════════════════════════════════════════
// Design tokens
// ═══════════════════════════════════════════════════════════════════════════

const _kBg = Color(0xFF0D0D0D);
const _kAccent = Color(0xFFF4B625);
const _kWhite = Color(0xFFFFFFFF);
const _kMuted = Color(0xFFAAAAAA);
const _kCardBg = Color(0xFF1A1A1A);
const _kCardBorder = Color(0xFF655017);
const _kProgressBg = Color(0xFF333333);

const _kCdn = 'https://bkp-v1.blr1.cdn.digitaloceanspaces.com/onboarding';
const _kGiftUrl = '$_kCdn/gift.png';
const _kPuppetAvatarUrl = '$_kCdn/puppet_level_zero.png';
const _kComicsBgUrl = '$_kCdn/comics_background.gif';

// ═══════════════════════════════════════════════════════════════════════════
// Main screen
// ═══════════════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  static const routeName = '/onboarding';

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _autoAdvanceTimer;

  // Puppet avatar animation (grows from header → center)
  late AnimationController _puppetScaleCtrl;
  late Animation<double> _puppetScale;

  @override
  void initState() {
    super.initState();
    _puppetScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _puppetScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _puppetScaleCtrl, curve: Curves.easeOutBack),
    );

    // Prefetch all CDN images/GIFs as soon as onboarding starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchImages();
    });
  }

  void _prefetchImages() {
    for (final url in OnboardingProvider.prefetchUrls) {
      precacheImage(CachedNetworkImageProvider(url), context);
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    _puppetScaleCtrl.dispose();
    super.dispose();
  }

  // ───────────────── navigation ─────────────────────────────────────────

  bool get _isConnected {
    try {
      return Provider.of<ConnectivityService>(context, listen: false)
          .isConnected;
    } catch (_) {
      return true; // assume connected if service unavailable
    }
  }

  void _showNoInternetSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No internet connection. Please connect to proceed.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _advance(List<OnboardingSlide> slides, {bool withFeedback = false}) {
    if (!_isConnected) {
      _showNoInternetSnackbar();
      return;
    }
    if (withFeedback) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    }
    if (_currentIndex < slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeLogin();
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setBool('claim_onboarding_reward', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  Future<void> _viewAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(ShortsScreen.routeName);
  }

  void _scheduleAutoAdvance(
      OnboardingSlide slide, List<OnboardingSlide> slides) {
    _autoAdvanceTimer?.cancel();
    if (slide.autoAdvanceMs > 0) {
      _autoAdvanceTimer = Timer(
        Duration(milliseconds: slide.autoAdvanceMs),
        () {
          if (mounted) _advance(slides);
        },
      );
    }
  }

  void _onPageChanged(int index, List<OnboardingSlide> slides) {
    _autoAdvanceTimer?.cancel();
    setState(() => _currentIndex = index);

    final slide = slides[index];

    // Trigger puppet grow animation for puppet_intro slides
    if (slide.slideType == 'puppet_intro') {
      _puppetScaleCtrl.forward(from: 0.0);
    }

    // Schedule auto-advance
    _scheduleAutoAdvance(slide, slides);
  }

  // ───────────────── slide router ───────────────────────────────────────

  Widget _buildSlide(
      OnboardingSlide slide, int index, List<OnboardingSlide> slides) {
    final onContinue = () => _advance(slides, withFeedback: true);
    switch (slide.slideType) {
      case 'selection':
        return _SelectionSlide(
            slide: slide, onContinue: onContinue, onLogin: _completeLogin);
      case 'info':
        return _InfoSlide(slide: slide, onContinue: onContinue);
      case 'fullscreen_image':
        return _FullscreenImageSlide(slide: slide, onContinue: onContinue);
      case 'quiz_prompt':
        return _QuizPromptSlide(slide: slide, onContinue: onContinue);
      case 'quiz':
        return _QuizSlide(slide: slide, onContinue: onContinue);
      case 'reward':
      case 'congratulations':
        return _RewardSlide(slide: slide, onContinue: onContinue);
      case 'puppet_intro':
        return _PuppetIntroSlide(
          slide: slide,
          onContinue: onContinue,
          scaleAnimation: _puppetScale,
        );
      case 'cta':
        return _CtaSlide(
          slide: slide,
          onLogin: _completeLogin,
          onGuest: _viewAsGuest,
        );
      default:
        return _AssetSlide(slide: slide, onContinue: onContinue);
    }
  }

  // ───────────────── build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OnboardingProvider>(context);
    final slides = provider.slides;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => _onPageChanged(i, slides),
            itemBuilder: (ctx, i) => _buildSlide(slides[i], i, slides),
          ),
          // Back arrow (top-left)
          if (_currentIndex > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: GestureDetector(
                onTap: _goBack,
                child: const Icon(Icons.arrow_back, color: _kWhite, size: 24),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _OnboardingStepHeader — progress bar + puppet avatar + gift icon
// ═══════════════════════════════════════════════════════════════════════════

class _OnboardingStepHeader extends StatelessWidget {
  final int? stepNumber;
  final int totalSteps;
  final bool showPuppetAvatar;
  final bool showGiftIcon;
  final Animation<double>? giftJiggleAnim;

  const _OnboardingStepHeader({
    required this.stepNumber,
    required this.totalSteps,
    this.showPuppetAvatar = false,
    this.showGiftIcon = false,
    this.giftJiggleAnim,
  });

  @override
  Widget build(BuildContext context) {
    if (stepNumber == null) return const SizedBox.shrink();
    final progress = stepNumber! / totalSteps;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Puppet avatar
              if (showPuppetAvatar)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kAccent, width: 2),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _kPuppetAvatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: _kCardBg),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.person,
                        color: _kAccent,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              Text(
                'Step $stepNumber of $totalSteps',
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}% Complete',
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Gift icon — shown after claim with jiggle animation
              if (showGiftIcon) ...[
                const SizedBox(width: 8),
                if (giftJiggleAnim != null)
                  AnimatedBuilder(
                    animation: giftJiggleAnim!,
                    builder: (_, child) => Transform.rotate(
                      angle: giftJiggleAnim!.value * 3.14159,
                      child: child,
                    ),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CachedNetworkImage(
                        imageUrl: _kGiftUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Icon(Icons.card_giftcard,
                            color: _kAccent, size: 28),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.card_giftcard,
                            color: _kAccent,
                            size: 28),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CachedNetworkImage(
                      imageUrl: _kGiftUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Icon(Icons.card_giftcard,
                          color: _kAccent, size: 28),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.card_giftcard,
                          color: _kAccent,
                          size: 28),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: _kAccent,
                backgroundColor: _kProgressBg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SelectionSlide — role/time picker cards (no skip button)
// ═══════════════════════════════════════════════════════════════════════════

class _SelectionSlide extends StatefulWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;
  final VoidCallback? onLogin;

  const _SelectionSlide({
    required this.slide,
    required this.onContinue,
    this.onLogin,
  });

  @override
  _SelectionSlideState createState() => _SelectionSlideState();
}

class _SelectionSlideState extends State<_SelectionSlide> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    final opts = widget.slide.options ?? [];
    for (int i = 0; i < opts.length; i++) {
      if (opts[i]['preselected'] == true) {
        _selectedIndex = i;
        break;
      }
    }
  }

  IconData _iconFor(String? iconName) {
    switch (iconName) {
      case 'gamepad':
        return Icons.sports_esports;
      case 'settings':
        return Icons.video_camera_back;
      case 'store':
        return Icons.storefront;
      default:
        return Icons.circle;
    }
  }

  void _saveSelection() {
    if (_selectedIndex == null) return;
    final opts = widget.slide.options ?? [];
    final label = opts[_selectedIndex!]['label'] as String? ?? '';
    final step = widget.slide.stepNumber;
    // Step 1 = role, Step 2 = time engagement
    final key = step == 1 ? 'onboarding_role' : 'onboarding_time_engagement';
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(key, label);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final options = slide.options ?? [];
    final hasIcons = options.any((o) => o['icon'] != null);

    return Container(
      color: _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OnboardingStepHeader(
                stepNumber: slide.stepNumber,
                totalSteps: slide.totalSteps,
              ),
              const SizedBox(height: 32),
              if (slide.title != null)
                Text(
                  slide.title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (slide.subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  slide.subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kMuted, fontSize: 15),
                ),
              ],
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: options.asMap().entries.map((entry) {
                    final i = entry.key;
                    final opt = entry.value;
                    final isSelected = _selectedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _kCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _kAccent : _kCardBorder,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (hasIcons && opt['icon'] != null) ...[
                                Icon(
                                  _iconFor(opt['icon'] as String?),
                                  color: _kAccent,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt['label'] as String? ?? '',
                                      style: const TextStyle(
                                        color: _kWhite,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (opt['subtitle'] != null)
                                      Text(
                                        opt['subtitle'] as String,
                                        style: const TextStyle(
                                          color: _kMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? _kAccent
                                      : Colors.transparent,
                                  border: Border.all(color: _kAccent, width: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Opacity(
                opacity: _selectedIndex != null ? 1.0 : 0.45,
                child: GestureDetector(
                  onTap: _selectedIndex != null
                      ? () {
                          _saveSelection();
                          widget.onContinue();
                        }
                      : null,
                  child: AppButttons(
                    text: slide.ctaText ?? 'Continue',
                    backgroundColor: _kAccent,
                    textColor: Colors.black,
                    borderColor: _kAccent,
                    size: double.infinity,
                  ),
                ),
              ),
              // "Go to login" link for returning users (step 1 only)
              if (slide.stepNumber == 1 && widget.onLogin != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: widget.onLogin,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: _kMuted, fontSize: 14),
                        children: [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Login',
                            style: TextStyle(
                              color: _kAccent,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: _kAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _InfoSlide — coin image + title with accent text + info card
// ═══════════════════════════════════════════════════════════════════════════

class _InfoSlide extends StatelessWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;

  const _InfoSlide({required this.slide, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingStepHeader(
                stepNumber: slide.stepNumber,
                totalSteps: slide.totalSteps,
              ),
              const SizedBox(height: 16),
              if (slide.assetPath != null)
                Center(
                  child: CachedNetworkImage(
                    imageUrl: slide.assetPath!,
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox(
                      width: 160,
                      height: 160,
                      child: Center(
                          child: CircularProgressIndicator(color: _kAccent)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (slide.title != null)
                _RichAccentText(
                  text: slide.title!,
                  accentPhrase: 'engagement has value?',
                  baseStyle: const TextStyle(
                    color: _kWhite,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  accentStyle: const TextStyle(
                    color: _kAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              if (slide.subtitle != null) ...[
                const SizedBox(height: 14),
                Text(
                  slide.subtitle!,
                  style: const TextStyle(
                      color: _kMuted, fontSize: 14, height: 1.4),
                ),
              ],
              const SizedBox(height: 20),
              if (slide.infoCardLabel != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2400),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            slide.infoCardLabel!,
                            style: const TextStyle(
                              color: _kMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const Icon(Icons.north_east,
                              color: _kAccent, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            slide.infoCardValue ?? '',
                            style: const TextStyle(
                              color: _kWhite,
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              slide.infoCardCaption ?? '',
                              style: const TextStyle(
                                color: _kAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: onContinue,
                child: AppButttons(
                  text: slide.ctaText ?? 'Continue',
                  backgroundColor: _kAccent,
                  textColor: Colors.black,
                  borderColor: _kAccent,
                  size: double.infinity,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _FullscreenImageSlide — edge-to-edge bg + GIF-to-static swap
// ═══════════════════════════════════════════════════════════════════════════

class _FullscreenImageSlide extends StatefulWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;

  const _FullscreenImageSlide({
    required this.slide,
    required this.onContinue,
  });

  @override
  _FullscreenImageSlideState createState() => _FullscreenImageSlideState();
}

class _FullscreenImageSlideState extends State<_FullscreenImageSlide> {
  bool _showSecondary = false;
  Timer? _swapTimer;

  @override
  void initState() {
    super.initState();
    if (widget.slide.secondaryAssetPath != null) {
      _swapTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showSecondary = true);
      });
    }
  }

  @override
  void dispose() {
    _swapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final currentUrl = _showSecondary
        ? (slide.secondaryAssetPath ?? slide.assetPath)
        : slide.assetPath;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (currentUrl != null)
          CachedNetworkImage(
            imageUrl: currentUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: _kBg,
              child: const Center(
                  child: CircularProgressIndicator(color: _kAccent)),
            ),
            errorWidget: (_, __, ___) => Container(color: _kBg),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
                Colors.black.withOpacity(0.8),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 24,
          right: 24,
          child: _OnboardingStepHeader(
            stepNumber: slide.stepNumber,
            totalSteps: slide.totalSteps,
          ),
        ),
        if (slide.title != null || slide.subtitle != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (slide.title != null)
                  _RichAccentText(
                    text: slide.title!,
                    accentPhrase: 'puppet...',
                    baseStyle: const TextStyle(
                      color: _kWhite,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    accentStyle: const TextStyle(
                      color: _kAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                if (slide.subtitle != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    slide.subtitle!,
                    style: const TextStyle(
                        color: _kMuted, fontSize: 14, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        if (slide.bodyText != null)
          Positioned(
            bottom: slide.ctaText != null ? 90 : 40,
            left: 24,
            right: 24,
            child: _RichAccentText(
              text: slide.bodyText!,
              accentPhrase: 'Baakhapaa app',
              baseStyle:
                  const TextStyle(color: _kMuted, fontSize: 14, height: 1.4),
              accentStyle: const TextStyle(
                color: _kAccent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (slide.ctaText != null)
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: GestureDetector(
              onTap: widget.onContinue,
              child: AppButttons(
                text: slide.ctaText!,
                backgroundColor: _kAccent,
                textColor: Colors.black,
                borderColor: _kAccent,
                size: double.infinity,
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _QuizPromptSlide — puppet bg + pulsing quiz button (Icons.quiz)
// ═══════════════════════════════════════════════════════════════════════════

class _QuizPromptSlide extends StatefulWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;

  const _QuizPromptSlide({required this.slide, required this.onContinue});

  @override
  _QuizPromptSlideState createState() => _QuizPromptSlideState();
}

class _QuizPromptSlideState extends State<_QuizPromptSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.slide.assetPath != null)
          CachedNetworkImage(
            imageUrl: widget.slide.assetPath!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: _kBg),
            errorWidget: (_, __, ___) => Container(color: _kBg),
          ),
        Container(color: Colors.black.withOpacity(0.3)),
        Positioned(
          top: 0,
          left: 24,
          right: 24,
          child: _OnboardingStepHeader(
            stepNumber: widget.slide.stepNumber,
            totalSteps: widget.slide.totalSteps,
          ),
        ),
        // Pulsing quiz button — Icons.quiz matching shorts section
        Positioned(
          top: MediaQuery.of(context).size.height * 0.42,
          right: 24,
          child: ScaleTransition(
            scale: _pulseAnim,
            child: GestureDetector(
              onTap: widget.onContinue,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/quiz.svg',
                    width: 44,
                    height: 44,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.28,
          right: 50,
          child: CustomPaint(
            size: const Size(40, 200),
            painter: _ArrowPathPainter(),
          ),
        ),
        if (widget.slide.bodyText != null)
          Positioned(
            bottom: 50,
            left: 24,
            right: 24,
            child: Text(
              widget.slide.bodyText!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 16, height: 1.4),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _QuizSlide — timed question with hint + auto-select on timeout
// ═══════════════════════════════════════════════════════════════════════════

class _QuizSlide extends StatefulWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;

  const _QuizSlide({required this.slide, required this.onContinue});

  @override
  _QuizSlideState createState() => _QuizSlideState();
}

class _QuizSlideState extends State<_QuizSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerCtrl;
  int? _selectedIndex;
  bool _confirmed = false;
  bool _hintShown = false;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.slide.quizTimerSeconds ?? 7;
    _timerCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: _remainingSeconds),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _timerCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_confirmed) {
        setState(() {
          _selectedIndex = widget.slide.quizCorrectIndex ?? 0;
        });
        _confirm();
      }
    });

    _timerCtrl.forward();
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    super.dispose();
  }

  int get _displaySeconds => ((_remainingSeconds) * (1.0 - _timerCtrl.value))
      .ceil()
      .clamp(0, _remainingSeconds);

  void _confirm() {
    if (_selectedIndex == null) return;
    setState(() => _confirmed = true);
    _timerCtrl.stop();
    Future.delayed(const Duration(milliseconds: 800), widget.onContinue);
  }

  void _revealHint() {
    setState(() => _hintShown = true);
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final options = slide.options ?? [];

    return Container(
      color: _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OnboardingStepHeader(
                stepNumber: slide.stepNumber,
                totalSteps: slide.totalSteps,
              ),
              // Extra spacing after progress bar
              const SizedBox(height: 40),
              // Timer circle
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: 1.0 - _timerCtrl.value,
                          strokeWidth: 4,
                          color: _kAccent,
                          backgroundColor: _kCardBorder,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_displaySeconds',
                            style: const TextStyle(
                              color: _kWhite,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'SECONDS',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (slide.title != null)
                Text(
                  slide.title!,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              const SizedBox(height: 24),
              ...options.asMap().entries.map((entry) {
                final i = entry.key;
                final opt = entry.value;
                final isSelected = _selectedIndex == i;
                final isCorrect = i == (slide.quizCorrectIndex ?? 0);
                Color borderColor = _kCardBorder;
                if (_confirmed && isSelected) {
                  borderColor = isCorrect ? Colors.green : Colors.red;
                } else if (isSelected) {
                  borderColor = _kAccent;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _confirmed
                        ? null
                        : () => setState(() => _selectedIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: borderColor, width: isSelected ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              opt['label'] as String? ?? '',
                              style:
                                  const TextStyle(color: _kWhite, fontSize: 16),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_confirmed && isCorrect && isSelected)
                                  ? Colors.green
                                  : (isSelected
                                      ? _kAccent
                                      : Colors.transparent),
                              border: Border.all(
                                color: (_confirmed && isCorrect && isSelected)
                                    ? Colors.green
                                    : _kAccent,
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              if (slide.hintText != null)
                GestureDetector(
                  onTap: _hintShown ? null : _revealHint,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2A2400),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lightbulb,
                            color: _kAccent, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hintShown
                              ? 'Hint : Look at the cables wrapped around the puppet!'
                              : 'Hint : ${slide.hintText}',
                          style: TextStyle(
                            color: _hintShown ? _kAccent : _kMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Opacity(
                opacity: _selectedIndex != null ? 1.0 : 0.45,
                child: GestureDetector(
                  onTap: _confirmed ? null : _confirm,
                  child: AppButttons(
                    text: slide.ctaText ?? 'Confirm answer',
                    backgroundColor: _kAccent,
                    textColor: Colors.black,
                    borderColor: _kAccent,
                    size: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _RewardSlide — points animation + congratulations (white title, CDN gift)
// ═══════════════════════════════════════════════════════════════════════════

class _RewardSlide extends StatefulWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;

  const _RewardSlide({required this.slide, required this.onContinue});

  @override
  _RewardSlideState createState() => _RewardSlideState();
}

class _RewardSlideState extends State<_RewardSlide>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _pointsFlyCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _pointsFlyAnim;

  // Gift icon reveal after claim
  bool _giftClaimed = false;
  late AnimationController _giftJiggleCtrl;
  late Animation<double> _giftJiggleAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _pointsFlyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pointsFlyAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(-0.3, -1.5),
    ).animate(CurvedAnimation(parent: _pointsFlyCtrl, curve: Curves.easeInOut));

    // Jiggle animation for the gift icon that appears in header
    _giftJiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Rotate back and forth: 0 → -0.05 → 0.05 → 0 turns (jiggle effect)
    _giftJiggleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _giftJiggleCtrl, curve: Curves.easeInOut));

    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _pointsFlyCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pointsFlyCtrl.dispose();
    _giftJiggleCtrl.dispose();
    super.dispose();
  }

  void _claimGift() {
    if (_giftClaimed) return;
    setState(() => _giftClaimed = true);

    // Play jiggle animation on the newly revealed gift icon
    _giftJiggleCtrl.forward().whenComplete(() {
      // Wait a moment then advance
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onContinue();
      });
    });
  }

  Widget _buildFutureRewardsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.redeem, color: _kAccent, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Future Rewards',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Rewards can be bought from points',
            style: TextStyle(color: _kMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _FutureRewardCard(
                    emoji: '🎁',
                    title: 'Daily Rewards',
                    desc: 'Log in daily for bonus'),
                _FutureRewardCard(
                    emoji: '🏆',
                    title: 'Achievements',
                    desc: 'Complete milestones'),
                _FutureRewardCard(
                    emoji: '⭐',
                    title: 'Level Rewards',
                    desc: 'Level up to unlock'),
                _FutureRewardCard(
                    emoji: '🎯',
                    title: 'Challenges',
                    desc: 'Win special prizes'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final hasFullReward = slide.title != null;
    final isCongratulations = slide.slideType == 'congratulations';

    Widget content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OnboardingStepHeader(
              stepNumber: slide.stepNumber,
              totalSteps: slide.totalSteps,
              showPuppetAvatar: slide.showPuppetAvatar,
              showGiftIcon:
                  slide.showGiftIcon || (isCongratulations && _giftClaimed),
              giftJiggleAnim:
                  (isCongratulations && _giftClaimed) ? _giftJiggleAnim : null,
            ),
            // ── Small reward (step 10): speech bubble → coin visual → spacer ──
            if (!hasFullReward) ...[
              const SizedBox(height: 12),
              // Speech bubble with arrow pointing top-left toward puppet avatar
              Align(
                alignment: Alignment.centerRight,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _SpeechBubbleWithArrow(
                    text: slide.speechBubble ?? '',
                    arrowSide: ArrowSide.topLeft,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Coin visual + points amount + benefits info
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Glow ring + coin image from local assets
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _kAccent.withOpacity(0.25),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/coins.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.monetization_on,
                                color: _kAccent,
                                size: 76,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Points amount with glow
                        if (slide.rewardPoints != null) ...[
                          SlideTransition(
                            position: _pointsFlyAnim,
                            child: FadeTransition(
                              opacity: ReverseAnimation(_pointsFlyCtrl),
                              child: Text(
                                '+${slide.rewardPoints} pts',
                                style: TextStyle(
                                  color: _kAccent,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: _kAccent.withOpacity(0.6),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Earned for your positive engagement',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kMuted, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // What you can do with coins
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _kCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: _kAccent.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'What can you do with points?',
                                style: TextStyle(
                                  color: _kAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 10),
                              _CoinBenefitRow(
                                icon: Icons.lock_open,
                                text: 'Unlock more content & episodes',
                              ),
                              SizedBox(height: 8),
                              _CoinBenefitRow(
                                icon: Icons.card_giftcard,
                                text: 'Redeem exclusive rewards & gifts',
                              ),
                              SizedBox(height: 8),
                              _CoinBenefitRow(
                                icon: Icons.trending_up,
                                text: 'Level up and earn achievements',
                              ),
                              SizedBox(height: 8),
                              _CoinBenefitRow(
                                icon: Icons.storefront,
                                text: 'Shop items from the marketplace',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // ── Full reward (step 13 congratulations): gift + title + body ──
            if (hasFullReward) ...[
              const SizedBox(height: 12),
              // Gift image — static, no fly animation
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: CachedNetworkImage(
                    imageUrl: _kGiftUrl,
                    width: 130,
                    height: 130,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Icon(Icons.card_giftcard,
                        color: _kAccent, size: 130),
                    errorWidget: (_, __, ___) => const Icon(Icons.card_giftcard,
                        color: _kAccent, size: 130),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Title
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  slide.title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (slide.subtitle != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 30, height: 1.5, color: _kAccent),
                    const SizedBox(width: 8),
                    Text(
                      slide.subtitle!,
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 30, height: 1.5, color: _kAccent),
                  ],
                ),
              ],
              if (slide.bodyText != null) ...[
                const SizedBox(height: 10),
                _RichAccentText(
                  text: slide.bodyText!,
                  accentPhrase: '${slide.rewardPoints ?? 40} points',
                  baseStyle: const TextStyle(
                      color: _kMuted, fontSize: 16, height: 1.4),
                  accentStyle: const TextStyle(
                    color: _kAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (!isCongratulations && slide.infoCardValue != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _kAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.info, color: _kAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          slide.infoCardValue!,
                          style: const TextStyle(
                              color: _kMuted, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Future rewards directly below content (no gap)
              if (isCongratulations) ...[
                const SizedBox(height: 40),
                _buildFutureRewardsSection(),
              ],
              const Spacer(),
            ],
            if (slide.ctaText != null) ...[
              GestureDetector(
                onTap: _giftClaimed
                    ? null
                    : (hasFullReward ? _claimGift : widget.onContinue),
                child: AppButttons(
                  text: slide.ctaText!,
                  backgroundColor: _kAccent,
                  textColor: Colors.black,
                  borderColor: _kAccent,
                  size: double.infinity,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );

    return Container(color: _kBg, child: content);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _FutureRewardCard — static gift card for onboarding congratulations
// ═══════════════════════════════════════════════════════════════════════════

class _FutureRewardCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;

  const _FutureRewardCard({
    required this.emoji,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAccent.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kWhite,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kMuted, fontSize: 8),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CoinBenefitRow — single row in "What can you do with points?" card
// ═══════════════════════════════════════════════════════════════════════════

class _CoinBenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CoinBenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _PuppetIntroSlide — puppet in circle, speech bubble with arrow, shifted down
// ═══════════════════════════════════════════════════════════════════════════

class _PuppetIntroSlide extends StatelessWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;
  final Animation<double> scaleAnimation;

  const _PuppetIntroSlide({
    required this.slide,
    required this.onContinue,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isWhiteCircle = slide.accentColor == '#FFFFFF';
    final useComicsBg =
        slide.speechBubble != null && slide.speechBubble!.contains('Feed me');

    Widget content = Container(
      color: useComicsBg ? Colors.transparent : _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _OnboardingStepHeader(
                stepNumber: slide.stepNumber,
                totalSteps: slide.totalSteps,
                showPuppetAvatar: false,
              ),
              // Extra spacing to shift contents down
              const SizedBox(height: 50),
              // Speech bubble with arrow pointing down to puppet
              if (slide.speechBubble != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SpeechBubbleWithArrow(
                      text: slide.speechBubble!,
                      arrowSide: ArrowSide.bottomLeft,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // Puppet image in circle — scale animation
              ScaleTransition(
                scale: scaleAnimation,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isWhiteCircle ? Colors.white : Colors.transparent,
                    border: Border.all(color: _kAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: isWhiteCircle
                            ? Colors.white.withOpacity(0.08)
                            : _kAccent.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: slide.assetPath != null
                        ? CachedNetworkImage(
                            imageUrl: slide.assetPath!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: _kCardBg),
                            errorWidget: (_, __, ___) =>
                                Container(color: _kCardBg),
                          )
                        : Container(color: _kCardBg),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (slide.title != null)
                Text(
                  slide.title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 1,
                  ),
                ),
              if (slide.subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  slide.subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _kMuted, fontSize: 15, height: 1.3),
                ),
              ],
              const Spacer(),
              if (slide.ctaText != null) ...[
                GestureDetector(
                  onTap: onContinue,
                  child: AppButttons(
                    text: slide.ctaText!,
                    backgroundColor: _kAccent,
                    textColor: Colors.black,
                    borderColor: _kAccent,
                    size: double.infinity,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );

    if (useComicsBg) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: _kComicsBgUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => const ColoredBox(color: _kBg),
            errorWidget: (_, __, ___) => const ColoredBox(color: _kBg),
          ),
          Container(color: Colors.black.withOpacity(0.88)),
          content,
        ],
      );
    }

    return content;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CtaSlide — login CTA + view as guest
// ═══════════════════════════════════════════════════════════════════════════

class _CtaSlide extends StatelessWidget {
  final OnboardingSlide slide;
  final VoidCallback onLogin;
  final VoidCallback onGuest;

  const _CtaSlide({
    required this.slide,
    required this.onLogin,
    required this.onGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OnboardingStepHeader(
                stepNumber: slide.stepNumber,
                totalSteps: slide.totalSteps,
                showPuppetAvatar: slide.showPuppetAvatar,
                showGiftIcon: slide.showGiftIcon,
              ),
              const Spacer(),
              if (slide.title != null)
                Text(
                  slide.title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              if (slide.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  slide.subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onLogin,
                child: AppButttons(
                  text: slide.ctaText ?? 'Login to continue',
                  backgroundColor: _kAccent,
                  textColor: Colors.black,
                  borderColor: _kAccent,
                  size: double.infinity,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: onGuest,
                  child: const Text(
                    'View as guest',
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: _kMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _AssetSlide — fallback
// ═══════════════════════════════════════════════════════════════════════════

class _AssetSlide extends StatelessWidget {
  final OnboardingSlide slide;
  final VoidCallback onContinue;

  const _AssetSlide({required this.slide, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OnboardingStepHeader(
                stepNumber: slide.stepNumber,
                totalSteps: slide.totalSteps,
              ),
              const SizedBox(height: 24),
              if (slide.assetPath != null)
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: slide.assetPath!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: _kAccent)),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 64, color: Color(0xFF555555)),
                    ),
                  ),
                ),
              if (slide.assetPath == null) const Spacer(),
              const SizedBox(height: 20),
              if (slide.title != null)
                Text(
                  slide.title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (slide.subtitle != null) ...[
                const SizedBox(height: 10),
                Text(
                  slide.subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kMuted, fontSize: 15),
                ),
              ],
              const SizedBox(height: 28),
              if (slide.ctaText != null)
                GestureDetector(
                  onTap: onContinue,
                  child: AppButttons(
                    text: slide.ctaText!,
                    backgroundColor: _kAccent,
                    textColor: Colors.black,
                    borderColor: _kAccent,
                    size: double.infinity,
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper widgets
// ═══════════════════════════════════════════════════════════════════════════

enum ArrowSide { left, bottomLeft, topRight, topLeft }

/// Speech bubble with arrow tail pointing toward puppet.
class _SpeechBubbleWithArrow extends StatelessWidget {
  final String text;
  final ArrowSide arrowSide;

  const _SpeechBubbleWithArrow({
    required this.text,
    this.arrowSide = ArrowSide.bottomLeft,
  });

  @override
  Widget build(BuildContext context) {
    final isTopRight = arrowSide == ArrowSide.topRight;
    final isLeft = arrowSide == ArrowSide.left;
    final isTopLeft = arrowSide == ArrowSide.topLeft;

    // Left arrow: horizontal layout with arrow ◀ then bubble
    if (isLeft) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(10, 16),
            painter: _BubbleArrowPainterLeft(),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Top-left arrow: arrow at top-left corner pointing up-left toward puppet
    if (isTopLeft) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: CustomPaint(
              size: const Size(16, 10),
              painter: _BubbleArrowPainterUp(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isTopRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Arrow pointing UP toward puppet (top-right)
        if (isTopRight)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CustomPaint(
              size: const Size(16, 10),
              painter: _BubbleArrowPainterUp(),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
        // Arrow pointing down to puppet
        if (arrowSide == ArrowSide.bottomLeft)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: CustomPaint(
              size: const Size(16, 10),
              painter: _BubbleArrowPainter(),
            ),
          ),
      ],
    );
  }
}

/// Paints a small downward triangle (speech bubble arrow).
class _BubbleArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kAccent
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints a small upward triangle (arrow pointing up toward puppet avatar).
class _BubbleArrowPainterUp extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kAccent
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.5, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints a small left-pointing triangle (arrow pointing left toward puppet).
class _BubbleArrowPainterLeft extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kAccent
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height * 0.5)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders text with a specific phrase highlighted in accent color.
class _RichAccentText extends StatelessWidget {
  final String text;
  final String accentPhrase;
  final TextStyle baseStyle;
  final TextStyle accentStyle;
  final TextAlign textAlign;

  const _RichAccentText({
    required this.text,
    required this.accentPhrase,
    required this.baseStyle,
    required this.accentStyle,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final idx = text.toLowerCase().indexOf(accentPhrase.toLowerCase());
    if (idx == -1) {
      return Text(text, style: baseStyle, textAlign: textAlign);
    }
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        children: [
          TextSpan(text: text.substring(0, idx), style: baseStyle),
          TextSpan(
              text: text.substring(idx, idx + accentPhrase.length),
              style: accentStyle),
          TextSpan(
              text: text.substring(idx + accentPhrase.length),
              style: baseStyle),
        ],
      ),
    );
  }
}

/// Draws a curved arrow path (decorative hint for quiz button).
class _ArrowPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kMuted.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..quadraticBezierTo(
        size.width * 1.2,
        size.height * 0.5,
        size.width * 0.5,
        0,
      );
    canvas.drawPath(path, paint);

    final arrowPaint = Paint()
      ..color = _kMuted.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(size.width * 0.5, 0), Offset(size.width * 0.3, 12), arrowPaint);
    canvas.drawLine(
        Offset(size.width * 0.5, 0), Offset(size.width * 0.7, 12), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

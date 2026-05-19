import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/assistive_touch_provider.dart';
import '../providers/puppet_interaction_provider.dart';
import '../providers/auth.dart';
import '../models/url.dart';
import '../navigation/root_navigator_key.dart' show mainNavigatorKey;

// ═══════════════════════════════════════════════════════════════════════
// QuestHintBubble — header-pinned yellow speech bubble pointing to puppet
// ═══════════════════════════════════════════════════════════════════════

/// Renders a yellow-bordered speech bubble just below the AppBar,
/// with a triangular tail pointing up-left toward the header puppet icon.
/// Shown after quest-tap navigation and on first launch.
class QuestHintBubble extends StatelessWidget {
  const QuestHintBubble({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<AssistiveTouchProvider, (bool, String?)>(
      selector: (_, p) => (p.showQuestHint, p.questHint),
      builder: (context, data, _) {
        final showing = data.$1;
        final message = data.$2;
        if (!showing || message == null || message.isEmpty) {
          return const SizedBox.shrink();
        }
        final topPad = MediaQuery.of(context).padding.top;
        // AppBar height is 57 (toolbarHeight in header.dart)
        const appBarH = 57.0;
        return Positioned(
          top: topPad + appBarH,
          left: 8,
          right: 8,
          child: _QuestHintBar(
            key: ValueKey(message),
            message: message,
          ),
        );
      },
    );
  }
}

class _QuestHintBar extends StatefulWidget {
  final String message;

  const _QuestHintBar({Key? key, required this.message}) : super(key: key);

  @override
  State<_QuestHintBar> createState() => _QuestHintBarState();
}

class _QuestHintBarState extends State<_QuestHintBar>
    with SingleTickerProviderStateMixin {
  static const _kAccent = Color(0xFFF4B625);
  static const _kBg = Color(0xFF1A1400);

  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (!mounted) return;
      context.read<AssistiveTouchProvider>().clearQuestHint();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          color: Colors.transparent,
          // Stack: arrow sits above (-8px) the container body to form tail
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Arrow tail pointing UP-LEFT toward header puppet ──
              // Header puppet center ≈ x=29 from screen edge.
              // Bubble starts at left=8, so arrow left offset = 29 - 8 - 8 = 13.
              Positioned(
                left: 13,
                top: -8,
                child: CustomPaint(
                  size: const Size(18, 10),
                  painter: _UpArrowPainter(),
                ),
              ),

              // ── Bubble body ──
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Pulsing star icon
                    _PulsingIcon(),
                    const SizedBox(width: 8),
                    // Message
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Color(0xFFFFE082),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Dismiss
                    GestureDetector(
                      onTap: _dismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arrow tail: filled amber triangle pointing upward.
class _UpArrowPainter extends CustomPainter {
  const _UpArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF4B625)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Pulsing auto_awesome icon shown inside the bubble.
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: const Icon(Icons.auto_awesome_rounded,
          color: Color(0xFFF4B625), size: 18),
    );
  }
}

/// Bottom-of-screen puppet speech overlay.
/// Replaces the old floating cloud bubble with a fixed bottom bar
/// similar to onboarding step 10's speech style.
class PuppetSpeechOverlay extends StatelessWidget {
  const PuppetSpeechOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AssistiveTouchProvider>(
      builder: (context, provider, child) {
        if (!provider.showMessage ||
            provider.messages.isEmpty ||
            provider.currentPuppet == null) {
          return const SizedBox.shrink();
        }

        return _PuppetSpeechBar(
          key: ValueKey(provider.currentPuppet!.id),
          puppet: provider.currentPuppet!,
          message: provider.messages.first,
        );
      },
    );
  }
}

class _PuppetSpeechBar extends StatefulWidget {
  final dynamic puppet;
  final String message;

  const _PuppetSpeechBar({
    Key? key,
    required this.puppet,
    required this.message,
  }) : super(key: key);

  @override
  State<_PuppetSpeechBar> createState() => _PuppetSpeechBarState();
}

class _PuppetSpeechBarState extends State<_PuppetSpeechBar>
    with SingleTickerProviderStateMixin {
  static const _kAccent = Color(0xFFF4B625);
  static const _kCardBg = Color(0xFF1A1A1A);

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _slideCtrl.reverse().then((_) {
      if (!mounted) return;
      context
          .read<PuppetInteractionProvider>()
          .dismissCurrentPuppet(isDismissed: true, context: context);
    });
  }

  void _handleAction() {
    _slideCtrl.reverse().then((_) {
      if (!mounted) return;
      final puppet = widget.puppet;
      if (puppet.goToPage != null && puppet.goToPage!.isNotEmpty) {
        context.read<PuppetInteractionProvider>().completePuppetInteraction(
              context: context,
              navigatorKey: mainNavigatorKey,
            );
      } else {
        context
            .read<PuppetInteractionProvider>()
            .completePuppetInteraction(context: context);
      }
    });
  }

  void _handleSkip() {
    _slideCtrl.reverse().then((_) {
      if (!mounted) return;
      context.read<PuppetInteractionProvider>().skipPuppetInteraction();
    });
  }

  void _showNext() {
    context
        .read<PuppetInteractionProvider>()
        .showNextSuggestion(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final puppet = widget.puppet;
    final hasNavigation =
        puppet.goToPage != null && puppet.goToPage!.isNotEmpty;

    // Get puppet image
    String puppetUrl = '${Url.mediaUrl}/assets/puppetdev.png';
    try {
      final auth = context.read<Auth>();
      final userPuppet = auth.user['current_puppet'];
      if (userPuppet != null && userPuppet['image'] != null) {
        puppetUrl = userPuppet['image'];
      }
    } catch (_) {}

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 200) {
              _dismiss();
            }
          },
          child: Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPad + 10),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Puppet row: avatar + speech bubble
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Puppet avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _kAccent, width: 2),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: puppetUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.smart_toy,
                                color: _kAccent, size: 24),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.smart_toy,
                                color: _kAccent, size: 24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Speech bubble
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Arrow pointing left toward puppet
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: CustomPaint(
                              size: const Size(12, 8),
                              painter: _UpArrowPainter(),
                            ),
                          ),
                          // Bubble body
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _kAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (puppet.title != null &&
                                    puppet.title!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      puppet.title!,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Text(
                                  widget.message,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                // Level progress hint
                                if (puppet.levelHint != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      puppet.levelHint!,
                                      style: TextStyle(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
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

                const SizedBox(height: 10),

                // Action buttons row
                Row(
                  children: [
                    // Counter (1/3)
                    Consumer<PuppetInteractionProvider>(
                      builder: (context, provider, _) {
                        final countText = provider.puppetCountText;
                        if (countText.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            countText,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),

                    // Skip button
                    GestureDetector(
                      onTap: _handleSkip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Next suggestion button (if multiple)
                    Consumer<PuppetInteractionProvider>(
                      builder: (context, provider, _) {
                        if (provider.currentSuggestions.length <= 1) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: _showNext,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.skip_next_rounded,
                                      color: Colors.white70, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Next',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Action button (Got it / Navigate)
                    GestureDetector(
                      onTap: _handleAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: hasNavigation
                              ? const Color(0xFF4CAF50)
                              : _kAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasNavigation
                                  ? (puppet.actionText ?? 'Go')
                                  : (puppet.actionText ?? 'Got it!'),
                              style: TextStyle(
                                color:
                                    hasNavigation ? Colors.white : Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (hasNavigation) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

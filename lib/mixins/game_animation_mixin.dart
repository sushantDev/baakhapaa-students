import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared animation patterns for game screens (crossword, image puzzle).
/// Provides correct/wrong feedback, heart animations, confetti, and sound.
mixin GameAnimationMixin<T extends StatefulWidget>
    on TickerProviderStateMixin<T> {
  late AnimationController heartAnimationController;
  late Animation<double> heartScaleAnimation;

  late AnimationController correctFeedbackController;
  late Animation<double> correctScaleAnimation;
  late Animation<Color?> correctColorAnimation;

  late AnimationController wrongFeedbackController;
  late Animation<double> wrongShakeAnimation;

  final AudioPlayer _gameAudioPlayer = AudioPlayer();

  void initGameAnimations() {
    heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: heartAnimationController,
      curve: Curves.elasticOut,
    ));

    correctFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    correctScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: correctFeedbackController,
      curve: Curves.elasticOut,
    ));
    correctColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: const Color(0xFF4CAF50),
    ).animate(CurvedAnimation(
      parent: correctFeedbackController,
      curve: Curves.easeOut,
    ));

    wrongFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    wrongShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: wrongFeedbackController,
      curve: Curves.easeOut,
    ));
  }

  void disposeGameAnimations() {
    heartAnimationController.dispose();
    correctFeedbackController.dispose();
    wrongFeedbackController.dispose();
    _gameAudioPlayer.dispose();
  }

  Future<void> playCorrectFeedback() async {
    correctFeedbackController.forward(from: 0);
    HapticFeedback.mediumImpact();
    await _gameAudioPlayer.play(AssetSource('sounds/correct.wav'));
  }

  Future<void> playWrongFeedback() async {
    wrongFeedbackController.forward(from: 0);
    // 3-burst vibration pattern
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await _gameAudioPlayer.play(AssetSource('sounds/wrong.wav'));
  }

  void playHeartLostAnimation() {
    heartAnimationController.forward(from: 0);
  }

  Future<void> playCompletionFeedback() async {
    HapticFeedback.heavyImpact();
    await _gameAudioPlayer.play(AssetSource('sounds/correct.wav'));
    await Future.delayed(const Duration(milliseconds: 200));
    await _gameAudioPlayer.play(AssetSource('sounds/correct.wav'));
  }

  /// Build a row of heart icons for displaying lives
  Widget buildHeartsRow(int currentLives, int maxLives) {
    return AnimatedBuilder(
      animation: heartAnimationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(maxLives, (index) {
            final isFilled = index < currentLives;
            final isLastHeart = currentLives == 1 && index == 0;
            double scale = 1.0;
            if (isFilled && heartAnimationController.isAnimating) {
              scale = heartScaleAnimation.value;
            }
            return Transform.scale(
              scale: scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  isFilled ? Icons.favorite : Icons.favorite_border,
                  color: isFilled
                      ? (isLastHeart ? Colors.redAccent : Colors.red)
                      : Colors.grey,
                  size: 22,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Build floating confetti particles
  Widget buildConfetti(AnimationController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isAnimating && controller.value == 0) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: CustomPaint(
            painter: _ConfettiPainter(
              progress: controller.value,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final _random = Random(42);
  static final _particles = List.generate(
      40,
      (i) => _ConfettiParticle(
            x: _random.nextDouble(),
            speed: 0.3 + _random.nextDouble() * 0.7,
            size: 4.0 + _random.nextDouble() * 6,
            color: [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.orange,
            ][_random.nextInt(6)],
            drift: (_random.nextDouble() - 0.5) * 2,
          ));

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final y = -20 + (size.height + 40) * progress * p.speed;
      final x = p.x * size.width + sin(progress * 10 + p.drift) * 30 * p.drift;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - progress).clamp(0, 1))
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 5 * p.drift);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

class _ConfettiParticle {
  final double x;
  final double speed;
  final double size;
  final Color color;
  final double drift;

  _ConfettiParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.drift,
  });
}

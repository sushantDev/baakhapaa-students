import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/tts_service.dart';

class TtsControlBar extends StatefulWidget {
  final String currentText;
  final String language;
  final VoidCallback? onAutoAdvance;
  final VoidCallback? onAutoClose;

  const TtsControlBar({
    Key? key,
    required this.currentText,
    required this.language,
    this.onAutoAdvance,
    this.onAutoClose,
  }) : super(key: key);

  @override
  State<TtsControlBar> createState() => _TtsControlBarState();
}

class _TtsControlBarState extends State<TtsControlBar> {
  final TtsService _tts = TtsService();
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _tts.addListener(_onTtsStateChanged);
    _tts.onComplete = widget.onAutoAdvance;
    _syncLanguage();
  }

  @override
  void didUpdateWidget(TtsControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _syncLanguage();
    }
    if (oldWidget.currentText != widget.currentText) {
      // Text changed (user swipe or auto-advance) — stop any active speech
      if (_tts.isSpeaking || _tts.isPaused) {
        _tts.stop();
      }
      _cancelAutoCloseTimer();
    }
    _tts.onComplete = widget.onAutoAdvance;
  }

  void _syncLanguage() {
    final langCode = widget.language == 'ne' ? 'ne-NP' : 'en-US';
    _tts.setLanguage(langCode);
  }

  void _onTtsStateChanged() {
    if (!mounted) return;
    setState(() {});
    // Start auto-close timer when TTS is paused
    if (_tts.isPaused) {
      _startAutoCloseTimer();
    } else {
      _cancelAutoCloseTimer();
    }
  }

  void _startAutoCloseTimer() {
    _cancelAutoCloseTimer();
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && (_tts.isPaused || (!_tts.isSpeaking && !_tts.isPaused))) {
        _tts.stop();
        widget.onAutoClose?.call();
      }
    });
  }

  void _cancelAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = null;
  }

  @override
  void dispose() {
    _cancelAutoCloseTimer();
    _tts.removeListener(_onTtsStateChanged);
    _tts.onComplete = null;
    _tts.stop();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_tts.isSpeaking) {
      _tts.pause();
    } else if (_tts.isPaused) {
      _tts.speak(widget.currentText);
    } else {
      _tts.speak(widget.currentText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Volume icon
          const Icon(Icons.volume_up_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 8),

          // Speed button
          GestureDetector(
            onTap: () {
              _tts.cycleSpeed();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_tts.speed}x',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _tts.isSpeaking
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Language indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.language == 'ne' ? 'ने' : 'EN',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Stop button
          GestureDetector(
            onTap: () => _tts.stop(),
            child: Icon(
              Icons.stop_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

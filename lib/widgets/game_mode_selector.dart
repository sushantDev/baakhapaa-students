import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_mode.dart';

/// Bottom sheet that presents the 3 game mode options
class GameModeSelector extends StatefulWidget {
  final void Function(GameMode mode) onModeSelected;
  final List<GameMode>? allowedModes;

  const GameModeSelector({
    Key? key,
    required this.onModeSelected,
    this.allowedModes,
  }) : super(key: key);

  static Future<GameMode?> show(
    BuildContext context, {
    List<GameMode>? allowedModes,
  }) {
    return showModalBottomSheet<GameMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GameModeSelector(
        allowedModes: allowedModes,
        onModeSelected: (mode) => Navigator.of(context).pop(mode),
      ),
    );
  }

  @override
  State<GameModeSelector> createState() => _GameModeSelectorState();
}

class _GameModeSelectorState extends State<GameModeSelector>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late List<Animation<double>> _cardSlideAnimations;
  late List<Animation<double>> _cardFadeAnimations;
  GameMode? _selectedMode;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardSlideAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 40, end: 0).animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(i * 0.15, 0.6 + i * 0.15, curve: Curves.easeOutBack),
        ),
      );
    });

    _cardFadeAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(i * 0.15, 0.5 + i * 0.15, curve: Curves.easeOut),
        ),
      );
    });

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _onModeTapped(GameMode mode) async {
    if (_isSelecting) return;
    setState(() {
      _isSelecting = true;
      _selectedMode = mode;
    });
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    widget.onModeSelected(mode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Your Challenge',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a game mode to earn points',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 24),
              ..._buildModeCards(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeCard({
    required int index,
    required GameMode mode,
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradient,
  }) {
    final isSelected = _selectedMode == mode;
    final isOther = _selectedMode != null && !isSelected;

    return Transform.translate(
      offset: Offset(0, _cardSlideAnimations[index].value),
      child: Opacity(
        opacity: isOther ? 0.3 : _cardFadeAnimations[index].value,
        child: AnimatedScale(
          scale: isSelected ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.elasticOut,
          child: GestureDetector(
            onTap: () => _onModeTapped(mode),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isSelected
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildModeCards(bool isDark) {
    final allModes = <Map<String, dynamic>>[
      {
        'mode': GameMode.quiz,
        'icon': Icons.quiz_outlined,
        'title': 'Quiz',
        'description': 'Answer multiple choice questions',
        'gradient': const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
      },
      {
        'mode': GameMode.crossword,
        'icon': Icons.grid_on_rounded,
        'title': 'Crossword',
        'description': 'Fill in the crossword grid with answers',
        'gradient': const [Color(0xFF2196F3), Color(0xFF1565C0)],
      },
      {
        'mode': GameMode.imagePuzzle,
        'icon': Icons.extension_rounded,
        'title': 'Image Puzzle',
        'description': 'Reassemble the scrambled image',
        'gradient': const [Color(0xFFFF9800), Color(0xFFE65100)],
      },
    ];

    final modes = widget.allowedModes == null
        ? allModes
        : allModes
            .where((entry) => widget.allowedModes!.contains(entry['mode']))
            .toList();

    if (modes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No challenges are currently available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ];
    }

    return List<Widget>.generate(modes.length * 2 - 1, (index) {
      if (index.isOdd) {
        return const SizedBox(height: 12);
      }
      final item = modes[index ~/ 2];
      return _buildModeCard(
        index: index ~/ 2,
        mode: item['mode'] as GameMode,
        icon: item['icon'] as IconData,
        title: item['title'] as String,
        description: item['description'] as String,
        gradient: item['gradient'] as List<Color>,
      );
    });
  }
}

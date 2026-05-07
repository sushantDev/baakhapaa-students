import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/puppet_interaction_provider.dart';
import '../models/puppet_interaction.dart';
import '../models/url.dart';
import '../utils/puppet_navigation_helper.dart';
import '../utils/debug_logger.dart';

class PuppetDialog extends StatefulWidget {
  final PuppetInteraction puppet;
  final VoidCallback? onClose;
  final VoidCallback? onComplete;

  const PuppetDialog({
    Key? key,
    required this.puppet,
    this.onClose,
    this.onComplete,
  }) : super(key: key);

  @override
  State<PuppetDialog> createState() => _PuppetDialogState();
}

class _PuppetDialogState extends State<PuppetDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        context
            .read<PuppetInteractionProvider>()
            .dismissCurrentPuppet(isDismissed: true);
      }
    });
  }

  void _handleComplete() {
    _animationController.reverse().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        context.read<PuppetInteractionProvider>().completePuppetInteraction();
      }
    });
  }

  void _handleSkip() {
    _animationController.reverse().then((_) {
      context.read<PuppetInteractionProvider>().skipPuppetInteraction();
    });
  }

  void _handleNext() {
    final goToPage = widget.puppet.goToPage;
    if (goToPage != null && goToPage.isNotEmpty) {
      DebugLogger.puppet('🧭 Puppet dialog: Navigating to $goToPage');
      DebugLogger.puppet(
          '🎭 Puppet interaction: "${widget.puppet.message}" → Next: $goToPage');

      // First dismiss the dialog
      _animationController.reverse().then((_) {
        // Then navigate to the specified screen
        PuppetNavigationHelper.navigateToScreen(context, goToPage).then((_) {
          DebugLogger.success(
              '🧭 Successfully navigated to $goToPage via puppet interaction');
        }).catchError((error) {
          DebugLogger.error('🧭 Failed to navigate to $goToPage: $error');
        });

        // Mark the interaction as completed
        context.read<PuppetInteractionProvider>().completePuppetInteraction();
      });
    } else {
      DebugLogger.warning('🧭 Puppet dialog: No goToPage specified');
      _handleComplete(); // Fallback to complete action
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Material(
            color: Colors.black54,
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(
                    maxWidth: 350,
                    maxHeight: 500,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      Flexible(child: _buildContent()),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2196F3),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Puppet Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Color(0xFF2196F3),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.puppet.title ?? 'Assistant',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Consumer<PuppetInteractionProvider>(
                  builder: (context, provider, child) {
                    final countText = provider.puppetCountText;
                    if (countText.isNotEmpty) {
                      return Text(
                        countText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleClose,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image/Video if available
          if (widget.puppet.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: _getFullImageUrl(widget.puppet.imageUrl!),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 120,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  color: Colors.grey[200],
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Message
          Text(
            widget.puppet.message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    // Debug logging to check goToPage value
    DebugLogger.puppet('🎭 Puppet Dialog Debug:');
    DebugLogger.puppet('   - goToPage: ${widget.puppet.goToPage}');
    DebugLogger.puppet(
        '   - goToPage is null: ${widget.puppet.goToPage == null}');
    DebugLogger.puppet(
        '   - goToPage is empty: ${widget.puppet.goToPage?.isEmpty}');
    DebugLogger.puppet(
        '   - Will show Next button: ${widget.puppet.goToPage != null && widget.puppet.goToPage!.isNotEmpty}');

    return Container(
      padding: const EdgeInsets.all(16),
      child: Consumer<PuppetInteractionProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Navigation buttons if multiple suggestions
              if (provider.currentSuggestions.length > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: provider.showPreviousSuggestion,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                    TextButton.icon(
                      onPressed: provider.showNextSuggestion,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Main action buttons
              widget.puppet.goToPage != null &&
                      widget.puppet.goToPage!.isNotEmpty
                  ? _buildActionsWithNext()
                  : _buildDefaultActions(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDefaultActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _handleSkip,
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _handleComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(widget.puppet.actionText ?? 'Got it!'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsWithNext() {
    return Column(
      children: [
        // Only show Skip and Next buttons (no "Got it" button)
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _handleSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text(
                  'Next',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getFullImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    return '${Url.mediaUrl}/$imageUrl';
  }
}

// Widget to show puppet dialog overlay
class PuppetDialogOverlay extends StatelessWidget {
  const PuppetDialogOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PuppetInteractionProvider>(
      builder: (context, provider, child) {
        if (!provider.showPuppetDialog || provider.currentPuppet == null) {
          return const SizedBox.shrink();
        }

        return PuppetDialog(
          puppet: provider.currentPuppet!,
        );
      },
    );
  }
}

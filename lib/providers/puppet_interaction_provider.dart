import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/puppet_interaction.dart';
import '../services/puppet_interaction_service.dart';
import '../providers/assistive_touch_provider.dart';
import '../providers/cart.dart';
import '../providers/shop.dart';
import '../providers/levels.dart';
import '../utils/debug_logger.dart';
import '../utils/puppet_navigation_helper.dart';

class PuppetInteractionProvider with ChangeNotifier {
  // ID-based screens mapping as per backend configuration
  static const Map<String, String> _idBasedScreens = {
    'single_product_screen': 'product',
    'single_gift_screen': 'gift',
    'video_screen': 'video',
    'episode_screen': 'episode',
    'question_screen': 'question',
    'single_shorts_screen': 'shorts',
    'shorts_challenge_screen': 'challenge',
  };

  bool _isEnabled = false;
  List<PuppetInteraction> _currentSuggestions = [];
  PuppetInteraction? _currentPuppet;
  String _currentScreenName = '';
  bool _isLoading = false;
  DateTime? _interactionStartTime;

  // Context for filtering puppet interactions
  String? _contextActionType;
  int? _contextActionId;

  // Getters
  bool get isEnabled => _isEnabled;
  List<PuppetInteraction> get currentSuggestions => _currentSuggestions;
  PuppetInteraction? get currentPuppet => _currentPuppet;
  String get currentScreenName => _currentScreenName;
  bool get isLoading => _isLoading;
  String? get contextActionType => _contextActionType;
  int? get contextActionId => _contextActionId;

  // Remove the showPuppetDialog getter since we're using AssistiveTouch now
  bool get showPuppetDialog =>
      false; // Deprecated - using AssistiveTouch instead

  Future<void> initState() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('puppet_interaction_enabled') ?? false;
    notifyListeners();
  }

  Future<void> toggleEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('puppet_interaction_enabled', enabled);

    if (!enabled) {
      await dismissCurrentPuppet();
    }

    notifyListeners();
  }

  // Reset puppet display limits when user wants to see more puppets
  Future<void> resetPuppetLimits(BuildContext? context) async {
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        await assistiveProvider.resetPuppetLimits();
        DebugLogger.puppet('Puppet Provider: Reset puppet display limits');
      } catch (e) {
        DebugLogger.puppet(
            'Puppet Provider: Could not reset puppet limits: $e');
      }
    }
  }

  // Force reset for immediate testing
  Future<void> forceResetForTesting(BuildContext? context) async {
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        await assistiveProvider.forceResetForTesting();
        DebugLogger.puppet(
            'Puppet Provider: Force reset completed for testing');
      } catch (e) {
        DebugLogger.puppet('Puppet Provider: Could not force reset: $e');
      }
    }
  }

  Future<void> loadScreenSuggestions(
    String screenName,
    BuildContext? context, {
    String? contextActionType,
    int? contextActionId,
  }) async {
    DebugLogger.puppet(
        '🎭 🎭 PUPPET PROVIDER: Loading suggestions for screen: $screenName');
    DebugLogger.puppet(
        '🎭 🎭 PUPPET PROVIDER: Context - actionType: $contextActionType, actionId: $contextActionId');

    if (!_isEnabled || screenName.isEmpty) {
      DebugLogger.puppet(
          '🎭 Puppet Provider: Skipping load - enabled: $_isEnabled, screenName: $screenName');
      return;
    }

    DebugLogger.puppet(
        'Puppet Provider: Loading suggestions for screen: $screenName (actionType: $contextActionType, actionId: $contextActionId)');

    // Clear any existing puppet message when changing screens
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        assistiveProvider.clearPuppetMessage();
        DebugLogger.puppet(
            '🎭 Puppet Provider: Cleared existing puppet message for screen change');
      } catch (e) {
        DebugLogger.puppet(
            '🎭 Puppet Provider: Could not access AssistiveTouch provider: $e');
      }
    }

    _isLoading = true;
    _currentScreenName = screenName;

    // Store context for filtering
    _contextActionType = contextActionType;
    _contextActionId = contextActionId;

    notifyListeners();

    try {
      // Determine if this is an ID-based screen and prepare parameters
      final itemType = _idBasedScreens[screenName];
      final itemId = (itemType != null) ? contextActionId : null;

      if (itemType != null && itemId != null) {
        DebugLogger.puppet(
            '🎭 🎭 PROVIDER: ID-based screen detected - $screenName requires $itemType ID: $itemId');
      }

      List<PuppetInteraction>? suggestions =
          await PuppetInteractionService.getScreenSuggestions(
        screenName,
        itemId: itemId,
        itemType: itemType,
      );

      DebugLogger.puppet(
          '🎭 Puppet Provider: Received ${suggestions?.length ?? 0} suggestions for $screenName');

      // If no suggestions found for guest screen, try the base screen
      if ((suggestions == null || suggestions.isEmpty) &&
          screenName.endsWith('_guest')) {
        final baseScreenName = screenName.replaceAll('_guest', '');
        DebugLogger.puppet(
            '🎭 Puppet Provider: No suggestions for $screenName, trying base screen: $baseScreenName');

        suggestions = await PuppetInteractionService.getScreenSuggestions(
          baseScreenName,
          itemId: itemId,
          itemType: itemType,
        );
        DebugLogger.puppet(
            '🎭 Puppet Provider: Received ${suggestions?.length ?? 0} suggestions for base screen: $baseScreenName');
      }

      if (suggestions != null && suggestions.isNotEmpty) {
        _currentSuggestions = suggestions;

        // Filter suggestions using shouldShowPuppet method (includes action type/id matching)
        final validSuggestions =
            suggestions.where((s) => shouldShowPuppet(s)).toList();
        DebugLogger.puppet(
            '🎭 Puppet Provider: Found ${validSuggestions.length} valid suggestions after filtering');

        if (validSuggestions.isNotEmpty) {
          validSuggestions.sort((a, b) => b.priority.compareTo(a.priority));
          DebugLogger.puppet(
              '🎭 Puppet Provider: Showing puppet - Title: "${validSuggestions.first.title}", Message: "${validSuggestions.first.message}"');
          await showPuppet(validSuggestions.first, context);
        }
      } else {
        _currentSuggestions = [];
        DebugLogger.puppet(
            'Puppet Provider: No suggestions received for $screenName');
      }
    } catch (e) {
      DebugLogger.puppet(
          'Puppet Provider Error loading screen suggestions: $e');
      _currentSuggestions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> showPuppet(
      PuppetInteraction puppet, BuildContext? context) async {
    if (!_isEnabled) {
      DebugLogger.puppet(
          'Puppet Provider: Cannot show puppet - system disabled');
      await trackPuppetInaccessible(puppet.id, 'system_disabled',
          context: context);
      return;
    }

    // Check if user has reached puppet display limits
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        if (!assistiveProvider.canShowPuppet) {
          DebugLogger.puppet(
              '🎭 Puppet Provider: User has reached puppet display limit for this session');
          await trackPuppetInaccessible(puppet.id, 'display_limit_reached',
              context: context);
          return;
        }
      } catch (e) {
        DebugLogger.puppet(
            'Puppet Provider: Could not check puppet limits: $e');
      }
    }

    DebugLogger.puppet(
        '🎭 Puppet Provider: Showing puppet message via AssistiveTouch - Title: ${puppet.title}, Message: ${puppet.message}');

    // Fetch level progress and enrich puppet data
    PuppetInteraction enrichedPuppet = puppet;
    if (context != null) {
      try {
        final levelsProvider = context.read<Levels>();
        final levelProgress =
            levelsProvider.getLevelProgressForAssistiveTouch();

        if (levelProgress != null) {
          // Create enriched puppet with level progress data
          enrichedPuppet = PuppetInteraction(
            id: puppet.id,
            screenName: puppet.screenName,
            title: puppet.title,
            message: puppet.message,
            actionText: puppet.actionText,
            elementSelector: puppet.elementSelector,
            priority: puppet.priority,
            isActive: puppet.isActive,
            imageUrl: puppet.imageUrl,
            videoUrl: puppet.videoUrl,
            audioUrl: puppet.audioUrl,
            triggerType: puppet.triggerType,
            goToPage: puppet.goToPage,
            actionType: puppet.actionType,
            actionId: puppet.actionId,
            itemType: puppet.itemType,
            itemId: puppet.itemId,
            actionData: puppet.actionData,
            createdAt: puppet.createdAt,
            updatedAt: puppet.updatedAt,
            levelProgress: levelProgress,
            levelHint: levelProgress['hint'],
          );
          DebugLogger.puppet(
              '🎭 Puppet enriched with level progress: ${levelProgress["next_level"]?["name"] ?? "Unknown"}');
        }
      } catch (e) {
        DebugLogger.puppet(
            '🎭 Puppet Provider: Could not fetch level progress: $e');
        // Continue with original puppet if level progress unavailable
      }
    }

    _currentPuppet = enrichedPuppet;
    _interactionStartTime = DateTime.now();

    // Track the view with comprehensive data
    await _trackPuppetProgress(enrichedPuppet.id, 'viewed',
        completionPercentage: 0,
        timeSpent: 0,
        notes: 'User first viewed the interaction');

    // Also keep the existing simple tracking for backward compatibility
    await PuppetInteractionService.trackInteractionView(enrichedPuppet.id);

    // Show puppet message through AssistiveTouch
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        assistiveProvider.showPuppetMessage(enrichedPuppet);
        DebugLogger.puppet(
            'Puppet Provider: Puppet message sent to AssistiveTouch');
      } catch (e) {
        DebugLogger.puppet(
            '🎭 Puppet Provider: Could not access AssistiveTouch provider: $e');
      }
    }

    notifyListeners();
  }

  Future<void> dismissCurrentPuppet(
      {bool isDismissed = false, BuildContext? context}) async {
    if (_currentPuppet != null) {
      final timeSpent = _interactionStartTime != null
          ? DateTime.now().difference(_interactionStartTime!).inSeconds
          : null;

      // Comprehensive tracking
      await _trackPuppetProgress(_currentPuppet!.id, 'dismissed',
          completionPercentage: 0,
          timeSpent: timeSpent,
          notes: isDismissed
              ? 'User dismissed the interaction'
              : 'Interaction cleared programmatically',
          additionalData: {
            'dismissal_type': isDismissed ? 'user_action' : 'system_action',
          });

      // Keep existing tracking for backward compatibility
      await PuppetInteractionService.trackInteractionCompletion(
        _currentPuppet!.id,
        isDismissed: isDismissed,
        timeSpentSeconds: timeSpent,
      );
    }

    // Clear puppet message from AssistiveTouch
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        assistiveProvider.clearPuppetMessage();
      } catch (e) {
        DebugLogger.puppet(
            '🎭 Puppet Provider: Could not access AssistiveTouch provider: $e');
      }
    }

    _currentPuppet = null;
    _interactionStartTime = null;
    notifyListeners();
  }

  Future<void> completePuppetInteraction({
    BuildContext? context,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    DebugLogger.info('🎭 COMPLETE PUPPET INTERACTION START');
    DebugLogger.info('🎭 Current puppet: $_currentPuppet');
    DebugLogger.info('🎭 Current puppet ID: ${_currentPuppet?.id}');
    DebugLogger.info('🎭 Interaction start time: $_interactionStartTime');

    if (_currentPuppet != null && context != null) {
      final timeSpent = _interactionStartTime != null
          ? DateTime.now().difference(_interactionStartTime!).inSeconds
          : null;
      DebugLogger.info('🎭 Time spent calculated: $timeSpent seconds');

      // Execute the appropriate action based on puppet data
      await _executePuppetAction(_currentPuppet!, context, navigatorKey);

      // Comprehensive tracking
      DebugLogger.info('🎭 Calling _trackPuppetProgress for completed...');
      await _trackPuppetProgress(_currentPuppet!.id, 'completed',
          completionPercentage: 100,
          timeSpent: timeSpent,
          notes: 'User completed the interaction successfully',
          additionalData: {
            'completion_method': _currentPuppet!.goToPage?.isNotEmpty == true
                ? 'navigation'
                : 'acknowledgment',
            'target_page': _currentPuppet!.goToPage,
            'action_executed': _currentPuppet!.actionType != null,
            'action_type': _currentPuppet!.actionType,
            'action_id': _currentPuppet!.actionId,
          });
      DebugLogger.info('🎭 _trackPuppetProgress for completed finished');

      // Keep existing tracking for backward compatibility
      DebugLogger.info('🎭 Calling legacy trackInteractionCompletion...');
      await PuppetInteractionService.trackInteractionCompletion(
        _currentPuppet!.id,
        isCompleted: true,
        timeSpentSeconds: timeSpent,
      );
      DebugLogger.info('🎭 Legacy trackInteractionCompletion finished');
    } else {
      DebugLogger.info('🎭 WARNING: No current puppet or context to complete!');
    }

    // Clear puppet message from AssistiveTouch
    DebugLogger.info('🎭 Clearing puppet message from AssistiveTouch...');
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        assistiveProvider.clearPuppetMessage();
        DebugLogger.info('🎭 AssistiveTouch cleared successfully');
      } catch (e) {
        DebugLogger.info('🎭 ERROR clearing AssistiveTouch: $e');
        DebugLogger.puppet(
            '🎭 Puppet Provider: Could not access AssistiveTouch provider: $e');
      }
    } else {
      DebugLogger.info(
          '🎭 WARNING: No context provided to clear AssistiveTouch');
    }

    DebugLogger.info('🎭 Clearing current puppet and notifying listeners...');
    _currentPuppet = null;
    _interactionStartTime = null;
    notifyListeners();
    DebugLogger.info('🎭 COMPLETE PUPPET INTERACTION END');
  }

  // Execute the appropriate action based on puppet data
  Future<void> _executePuppetAction(
    PuppetInteraction puppet,
    BuildContext context, [
    GlobalKey<NavigatorState>? navigatorKey,
  ]) async {
    try {
      DebugLogger.puppet(
          '🎭 🎯 Executing puppet action - ActionType: ${puppet.actionType}, ActionID: ${puppet.actionId}, ItemType: ${puppet.itemType}, ItemID: ${puppet.itemId}');

      // PRIORITY 1: Check if this is an ITEM ACTION (item_id + item_type = perform action like add to cart)
      // This should only happen when user is already on the appropriate screen (e.g., single_product_screen)
      if (puppet.itemId != null && puppet.itemType != null) {
        DebugLogger.puppet(
            '🎭 🎯 Item action detected - Type: ${puppet.itemType}, ID: ${puppet.itemId}');
        DebugLogger.puppet('🎭 🎯 Current screen: $_currentScreenName');

        // Only execute item actions if user is on the appropriate screen
        // This prevents adding to cart from shop screen - navigation should happen first
        bool canExecuteItemAction = false;
        switch (puppet.itemType) {
          case 'Product':
            canExecuteItemAction =
                _currentScreenName == 'single_product_screen';
            break;
          case 'Gift':
            canExecuteItemAction = _currentScreenName == 'single_gift_screen';
            break;
          case 'Video':
          case 'Episode':
            canExecuteItemAction = _currentScreenName == 'video_screen';
            break;
          case 'Shorts':
            canExecuteItemAction = _currentScreenName == 'single_shorts_screen';
            break;
          case 'Challenge':
            canExecuteItemAction =
                _currentScreenName == 'all_challenges_screen';
            break;
          case 'Question':
            canExecuteItemAction = _currentScreenName == 'question_screen';
            break;
        }

        if (canExecuteItemAction) {
          DebugLogger.puppet(
              '🎭 🎯 ✅ Executing item action - user is on correct screen ($_currentScreenName)');

          // Execute the action based on item type
          switch (puppet.itemType) {
            case 'Product':
              await _executeProductAction(
                  puppet.itemId!, context, navigatorKey);
              break;
            case 'Gift':
              await _executeGiftAction(puppet.itemId!, context);
              break;
            case 'Video':
              await _executeVideoAction(puppet.itemId!, context);
              break;
            case 'Episode':
              await _executeEpisodeAction(puppet.itemId!, context);
              break;
            case 'Shorts':
              await _executeShortsAction(puppet.itemId!, context);
              break;
            case 'Challenge':
              await _executeChallengeAction(puppet.itemId!, context);
              break;
            case 'Question':
              await _executeQuestionAction(puppet.itemId!, context);
              break;
            default:
              DebugLogger.puppet(
                  '🎭 🎯 Unknown item type: ${puppet.itemType}, falling back to navigation');
              await _performNavigation(puppet, context, navigatorKey);
          }
          return;
        } else {
          DebugLogger.puppet(
              '🎭 🎯 ❌ Cannot execute item action from current screen ($_currentScreenName). Need to navigate first.');
          DebugLogger.puppet(
              '🎭 🎯 🧭 Will perform navigation instead of item action');
          // Fall through to navigation logic
        }
      }

      // PRIORITY 2: Check if this is a NAVIGATION ACTION (action_type + action_id = navigate to screen)
      if (puppet.actionType != null && puppet.actionId != null) {
        DebugLogger.puppet(
            '🎭 🎯 Navigation action detected - Type: ${puppet.actionType}, ID: ${puppet.actionId}');

        // Navigate to appropriate screen with action data
        await _performNavigationWithAction(puppet, context, navigatorKey);
        return;
      }

      // PRIORITY 3: Default to basic navigation if no specific actions
      DebugLogger.puppet(
          '🎭 🎯 No specific action or navigation target, performing basic navigation');
      await _performNavigation(puppet, context, navigatorKey);
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Error executing puppet action: $e');
      // Fallback to navigation if action fails
      await _performNavigation(puppet, context, navigatorKey);
    }
  }

  // Product action: Add to cart
  Future<void> _executeProductAction(
    int productId,
    BuildContext context, [
    GlobalKey<NavigatorState>? navigatorKey,
  ]) async {
    DebugLogger.puppet('🎭 🛒 Adding product $productId to cart');
    DebugLogger.puppet('🎭 🛒 Current screen: $_currentScreenName');

    try {
      // Ensure we're on the single_product_screen before adding to cart
      if (_currentScreenName != 'single_product_screen') {
        DebugLogger.puppet(
            '🎭 🛒 ERROR: Cannot add to cart from $_currentScreenName. Must be on single_product_screen');
        throw Exception('Add to cart only allowed from single_product_screen');
      }

      // Get the shop and cart providers
      final shopProvider = context.read<Shop>();
      final cartProvider = context.read<Cart>();

      DebugLogger.puppet(
          '🎭 🛒 Current singleProduct ID: ${shopProvider.singleProduct['id']}');
      DebugLogger.puppet('🎭 🛒 Target product ID: $productId');

      // Check if we're already viewing this product on the screen
      final isCurrentProduct = shopProvider.singleProduct['id'] == productId &&
          shopProvider.singleProduct.isNotEmpty;

      if (!isCurrentProduct) {
        DebugLogger.puppet('🎭 🛒 Fetching product details for $productId');
        await shopProvider.getSingleProduct(productId);
        DebugLogger.puppet(
            '🎭 🛒 After fetch - singleProduct ID: ${shopProvider.singleProduct['id']}');
      } else {
        DebugLogger.puppet('🎭 🛒 Using already loaded product data');
      }

      final product = shopProvider.singleProduct;
      DebugLogger.puppet('🎭 🛒 Raw product data: $product');
      DebugLogger.puppet('🎭 🛒 Product keys: ${product.keys.toList()}');
      DebugLogger.puppet('🎭 🛒 Product name field: ${product['name']}');
      DebugLogger.puppet(
          '🎭 🛒 Product name type: ${product['name'].runtimeType}');

      if (product.isNotEmpty && product['id'] == productId) {
        // Extract product details with proper null handling
        final productName = _extractProductName(product);
        final productPrice = _extractProductPrice(product);
        final productQuantity = _extractProductQuantity(product);
        final productImageUrl = _extractProductImageUrl(product);

        DebugLogger.puppet('🎭 🛒 Extracted details:');
        DebugLogger.puppet('🎭 🛒   Name: "$productName"');
        DebugLogger.puppet('🎭 🛒   Price: $productPrice');
        DebugLogger.puppet('🎭 🛒   Quantity: $productQuantity');
        DebugLogger.puppet('🎭 🛒   Image: "$productImageUrl"');

        // Add product to cart using the cart provider
        cartProvider.addItem(
          productId.toString(),
          productPrice,
          productName,
          productImageUrl,
          productQuantity,
          attributes: null, // No attributes for puppet interaction
        );

        DebugLogger.puppet(
            '🎭 ✅ Product $productId added to cart successfully');

        // Show success message with proper product name
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName added to cart!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to cart screen
                PuppetNavigationHelper.navigateToScreen(
                  context,
                  'cart_screen',
                  navigatorKey: navigatorKey,
                );
              },
            ),
          ),
        );
      } else {
        DebugLogger.puppet(
            '🎭 ❌ Product validation failed - isEmpty: ${product.isEmpty}, ID match: ${product['id'] == productId}');
        throw Exception('Product not found or ID mismatch');
      }
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Failed to add product to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product to cart: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper method to extract product name with multiple fallbacks
  String _extractProductName(Map<String, dynamic> product) {
    // Try various possible name fields
    final candidates = [
      product['name'],
      product['title'],
      product['product_name'],
      product['productName'],
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.toString().trim().isNotEmpty) {
        return candidate.toString().trim();
      }
    }

    return 'Unknown Product';
  }

  // Helper method to extract product price
  double _extractProductPrice(Map<String, dynamic> product) {
    final candidates = [
      product['price'],
      product['selling_price'],
      product['cost'],
    ];

    for (final candidate in candidates) {
      if (candidate != null) {
        try {
          return (candidate as num).toDouble();
        } catch (e) {
          continue;
        }
      }
    }

    return 0.0;
  }

  // Helper method to extract product quantity
  int _extractProductQuantity(Map<String, dynamic> product) {
    final candidates = [
      product['quantity'],
      product['stock'],
      product['available_quantity'],
    ];

    for (final candidate in candidates) {
      if (candidate != null) {
        try {
          return (candidate as num).toInt();
        } catch (e) {
          continue;
        }
      }
    }

    return 1; // Default quantity
  }

  // Helper method to extract product image URL
  String _extractProductImageUrl(Map<String, dynamic> product) {
    try {
      // Use the same image structure as the single_product_screen
      if (product['images'] != null && product['images'] is List) {
        final images = product['images'] as List;
        if (images.isNotEmpty) {
          final firstImage = images[0] as Map<String, dynamic>;
          // Use the 'full' field like single_product_screen does
          final fullPath = firstImage['full'];
          if (fullPath != null) {
            String path = fullPath.toString();
            // The full path might already include 'storage/', so handle both cases
            if (path.startsWith('storage/')) {
              return 'https://app.baakhapaa.com/$path';
            } else {
              return 'https://app.baakhapaa.com/storage/$path';
            }
          }
        }
      }
    } catch (e) {
      DebugLogger.puppet('🎭 ⚠️ Could not extract image URL: $e');
    }

    return ''; // Return empty string if no image found
  }

  // Video action: Start quiz
  Future<void> _executeVideoAction(int videoId, BuildContext context) async {
    DebugLogger.puppet('🎭 🎬 Starting quiz for video $videoId');

    try {
      // TODO: Implement actual start quiz API call
      // Example: await VideoService.startQuiz(videoId);

      DebugLogger.puppet('🎭 ✅ Quiz started for video $videoId');

      // Navigate to quiz screen
      // TODO: Replace with actual quiz navigation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz started!'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Failed to start quiz: $e');
    }
  }

  // Gift action: Claim gift
  Future<void> _executeGiftAction(int giftId, BuildContext context) async {
    DebugLogger.puppet('🎭 🎁 Claiming gift $giftId');

    try {
      // TODO: Implement actual claim gift API call
      // Example: await GiftService.claimGift(giftId);

      DebugLogger.puppet('🎭 ✅ Gift $giftId claimed successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gift claimed!'),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Failed to claim gift: $e');
    }
  }

  // Episode action: Mark as watched or play next
  Future<void> _executeEpisodeAction(
      int episodeId, BuildContext context) async {
    DebugLogger.puppet('🎭 📺 Processing episode $episodeId');

    try {
      // TODO: Implement actual episode action
      // Example: await EpisodeService.markAsWatched(episodeId);

      DebugLogger.puppet('🎭 ✅ Episode $episodeId processed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Episode updated!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Failed to process episode: $e');
    }
  }

  // Shorts action: Like or interact
  Future<void> _executeShortsAction(int shortsId, BuildContext context) async {
    DebugLogger.puppet('🎭 📱 Interacting with shorts $shortsId');

    try {
      // TODO: Implement actual shorts interaction
      // Example: await ShortsService.likeShorts(shortsId);

      DebugLogger.puppet('🎭 ✅ Shorts $shortsId interaction completed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shorts liked!'),
          backgroundColor: Colors.pink,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Failed to interact with shorts: $e');
    }
  }

  // Challenge action: Join challenge
  Future<void> _executeChallengeAction(
      int challengeId, BuildContext context) async {
    DebugLogger.puppet('🎭 🏆 Joining challenge $challengeId');

    try {
      // TODO: Implement actual join challenge API call
      // Example: await ChallengeService.joinChallenge(challengeId);

      DebugLogger.puppet('🎭 ✅ Challenge $challengeId joined successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge joined!'),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Failed to join challenge: $e');
    }
  }

  // Question action: Answer or skip
  Future<void> _executeQuestionAction(
      int questionId, BuildContext context) async {
    DebugLogger.puppet('🎭 ❓ Processing question $questionId');

    try {
      // TODO: Implement actual question action
      // Example: await QuestionService.processQuestion(questionId);

      DebugLogger.puppet('🎭 ✅ Question $questionId processed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Question processed!'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Failed to process question: $e');
    }
  }

  // Fallback navigation if no specific action
  Future<void> _performNavigation(
    PuppetInteraction puppet,
    BuildContext context, [
    GlobalKey<NavigatorState>? navigatorKey,
  ]) async {
    if (puppet.goToPage?.isNotEmpty == true) {
      DebugLogger.puppet('🎭 🧭 Navigating to: ${puppet.goToPage}');

      try {
        // Use the puppet navigation helper for proper navigation
        // If we have actionType and actionId, pass them for context
        await PuppetNavigationHelper.navigateToScreenWithAction(
          context,
          puppet.goToPage!,
          actionType: puppet.actionType,
          actionId: puppet.actionId,
          navigatorKey: navigatorKey,
        );

        DebugLogger.puppet('🎭 ✅ Navigation to ${puppet.goToPage} successful');
      } catch (e) {
        DebugLogger.puppet('🎭 ❌ Navigation failed: $e');

        // Fallback message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigating to ${puppet.goToPage}'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      DebugLogger.puppet('🎭 🧭 No navigation target specified');

      // If no goToPage but we have actionType and actionId, try navigation with action
      if (puppet.actionType != null && puppet.actionId != null) {
        DebugLogger.puppet('🎭 🧭 Fallback: Using action-based navigation');
        await _performNavigationWithAction(puppet, context, navigatorKey);
      }
    }
  }

  // Navigate to a screen with action type and ID (for navigation actions)
  Future<void> _performNavigationWithAction(
    PuppetInteraction puppet,
    BuildContext context, [
    GlobalKey<NavigatorState>? navigatorKey,
  ]) async {
    DebugLogger.puppet(
        '🎭 🧭 Performing navigation with action - Type: ${puppet.actionType}, ID: ${puppet.actionId}');

    try {
      // Determine target screen based on action type
      String? targetScreen;
      Object? arguments;

      switch (puppet.actionType) {
        case 'Product':
          targetScreen = 'single_product_screen';
          arguments = puppet.actionId;
          DebugLogger.puppet(
              '🎭 🧭 Product navigation: screen=$targetScreen, productId=${puppet.actionId}');
          break;
        case 'Gift':
          targetScreen = 'single_gift_screen';
          arguments = puppet.actionId;
          DebugLogger.puppet(
              '🎭 🧭 Gift navigation: screen=$targetScreen, giftId=${puppet.actionId}');
          break;
        case 'Video':
        case 'Episode':
          targetScreen = 'video_screen';
          arguments = puppet.actionId;
          DebugLogger.puppet(
              '🎭 🧭 Video navigation: screen=$targetScreen, videoId=${puppet.actionId}');
          break;
        case 'Shorts':
          targetScreen = 'single_shorts_screen';
          arguments = puppet.actionId;
          DebugLogger.puppet(
              '🎭 🧭 Shorts navigation: screen=$targetScreen, shortsId=${puppet.actionId}');
          break;
        case 'Challenge':
          targetScreen = 'all_challenges_screen';
          arguments = puppet.actionId;
          DebugLogger.puppet(
              '🎭 🧭 Challenge navigation: screen=$targetScreen, challengeId=${puppet.actionId}');
          break;
        default:
          // Fallback to goToPage if action type is unknown
          if (puppet.goToPage?.isNotEmpty == true) {
            targetScreen = puppet.goToPage;
            DebugLogger.puppet(
                '🎭 🧭 Fallback navigation: screen=$targetScreen');
          } else {
            throw Exception('Unknown action type: ${puppet.actionType}');
          }
      }

      if (targetScreen != null) {
        // Use the puppet navigation helper for proper navigation
        await PuppetNavigationHelper.navigateToScreenWithAction(
          context,
          targetScreen,
          actionType: puppet.actionType,
          actionId: puppet.actionId,
          fallbackArguments: arguments,
          navigatorKey: navigatorKey,
        );

        DebugLogger.puppet(
            '🎭 ✅ Navigation with action to $targetScreen successful');
      } else {
        throw Exception('No target screen determined');
      }
    } catch (e) {
      DebugLogger.puppet('🎭 ❌ Navigation with action failed: $e');

      // Fallback to basic navigation if available
      if (puppet.goToPage?.isNotEmpty == true) {
        DebugLogger.puppet('🎭 🧭 Falling back to basic navigation');
        await _performNavigation(puppet, context);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation failed: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> skipPuppetInteraction({BuildContext? context}) async {
    if (_currentPuppet != null) {
      final timeSpent = _interactionStartTime != null
          ? DateTime.now().difference(_interactionStartTime!).inSeconds
          : null;

      // Comprehensive tracking
      await _trackPuppetProgress(_currentPuppet!.id, 'skipped',
          completionPercentage: 0,
          timeSpent: timeSpent,
          notes: 'User skipped the interaction',
          additionalData: {
            'skip_reason': 'user_choice',
            'interaction_duration': timeSpent,
          });

      // Keep existing tracking for backward compatibility
      await PuppetInteractionService.trackInteractionCompletion(
        _currentPuppet!.id,
        isSkipped: true,
        timeSpentSeconds: timeSpent,
      );
    }

    // Clear puppet message from AssistiveTouch
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        assistiveProvider.clearPuppetMessage();
      } catch (e) {
        DebugLogger.puppet(
            '🎭 Puppet Provider: Could not access AssistiveTouch provider: $e');
      }
    }

    _currentPuppet = null;
    _interactionStartTime = null;
    notifyListeners();
  }

  Future<void> showNextSuggestion({BuildContext? context}) async {
    if (_currentSuggestions.isEmpty) return;

    // Find current puppet index
    final currentIndex = _currentPuppet != null
        ? _currentSuggestions.indexWhere((s) => s.id == _currentPuppet!.id)
        : -1;

    // Get next suggestion
    final nextIndex = (currentIndex + 1) % _currentSuggestions.length;
    final nextPuppet = _currentSuggestions[nextIndex];

    await showPuppet(nextPuppet, context);
  }

  Future<void> showPreviousSuggestion({BuildContext? context}) async {
    if (_currentSuggestions.isEmpty) return;

    // Find current puppet index
    final currentIndex = _currentPuppet != null
        ? _currentSuggestions.indexWhere((s) => s.id == _currentPuppet!.id)
        : 0;

    // Get previous suggestion
    final previousIndex =
        currentIndex > 0 ? currentIndex - 1 : _currentSuggestions.length - 1;
    final previousPuppet = _currentSuggestions[previousIndex];

    await showPuppet(previousPuppet, context);
  }

  // Method to track when user starts actively interacting with a puppet
  Future<void> trackPuppetStarted({BuildContext? context}) async {
    if (_currentPuppet != null) {
      await _trackPuppetProgress(_currentPuppet!.id, 'started',
          completionPercentage: 25,
          notes: 'User started actively interacting with the puppet',
          additionalData: {
            'interaction_method': 'assistive_touch_tap',
            'puppet_visible_duration': _interactionStartTime != null
                ? DateTime.now().difference(_interactionStartTime!).inSeconds
                : 0,
          });
    }
  }

  // Method to track inaccessible puppets (when user can't access due to limits, etc.)
  Future<void> trackPuppetInaccessible(int puppetId, String reason,
      {BuildContext? context}) async {
    await _trackPuppetProgress(puppetId, 'inaccessible',
        completionPercentage: 0,
        timeSpent: 0,
        notes: 'Puppet was inaccessible to user: $reason',
        additionalData: {
          'inaccessible_reason': reason,
          'screen_context': _currentScreenName,
        });
  }

  // DEBUG/TEST METHOD: Manual tracking for testing purposes
  Future<void> testTrackProgress(String action) async {
    if (_currentPuppet != null) {
      await _trackPuppetProgress(_currentPuppet!.id, action,
          completionPercentage: action == 'completed' ? 100 : 50,
          notes: 'Manual test tracking for action: $action',
          additionalData: {
            'test_mode': true,
            'manual_trigger': true,
          });
      DebugLogger.puppet(
          '🧪 TEST: Manually tracked "$action" for puppet ${_currentPuppet!.id}');
    } else {
      DebugLogger.puppet('🧪 TEST: No current puppet to track');
    }
  }

  void clearCurrentScreen({BuildContext? context}) {
    // Clear puppet message from AssistiveTouch
    if (context != null) {
      try {
        final assistiveProvider = context.read<AssistiveTouchProvider>();
        assistiveProvider.clearPuppetMessage();
      } catch (e) {
        DebugLogger.puppet(
            '🎭 Puppet Provider: Could not access AssistiveTouch provider: $e');
      }
    }

    _currentScreenName = '';
    _currentSuggestions = [];
    _currentPuppet = null;
    _interactionStartTime = null;

    // Only notify listeners if not during widget disposal
    try {
      notifyListeners();
    } catch (e) {
      DebugLogger.puppet(
          '🎭 Puppet Provider: Skipped notifyListeners during disposal: $e');
    }
  }

  // Method to set context for puppet filtering
  void setContext({String? actionType, String? actionId}) {
    final oldActionType = _contextActionType;
    final oldActionId = _contextActionId;

    DebugLogger.info(
        '🎭 🎭 setContext called - actionType: $actionType, actionId: $actionId');
    DebugLogger.info(
        '🎭 🎭 Previous context - actionType: $oldActionType, actionId: $oldActionId');
    DebugLogger.info('🎭 🎭 Current screen: $_currentScreenName');

    _contextActionType = actionType;
    _contextActionId = actionId != null ? int.tryParse(actionId) : null;
    DebugLogger.puppet(
        'Provider: Context updated - actionType: $actionType, actionId: $actionId');

    // If context changed and we have a current screen, reload suggestions with new context
    if (_currentScreenName.isNotEmpty &&
        (oldActionType != _contextActionType ||
            oldActionId != _contextActionId)) {
      DebugLogger.info(
          '🎭 🎭 Context changed, scheduling reload for screen: $_currentScreenName');
      DebugLogger.puppet(
          'Provider: Context changed, reloading suggestions for screen: $_currentScreenName');
      // Use post-frame callback to avoid state changes during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DebugLogger.info(
            '🎭 🎭 Post-frame callback: reloading suggestions with new context');
        loadScreenSuggestions(
          _currentScreenName,
          null,
          contextActionType: _contextActionType,
          contextActionId: _contextActionId,
        );
      });
    } else {
      DebugLogger.info(
          '🎭 🎭 No reload needed - screenName: $_currentScreenName, contextChanged: ${oldActionType != _contextActionType || oldActionId != _contextActionId}');
      // Just notify listeners if suggestions are already loaded
      if (_currentScreenName.isNotEmpty && _currentSuggestions.isNotEmpty) {
        notifyListeners();
      }
    }
  }

  Future<void> refreshSuggestions({BuildContext? context}) async {
    if (_currentScreenName.isNotEmpty) {
      await PuppetInteractionService.clearCache();
      await loadScreenSuggestions(_currentScreenName, context);
    }
  }

  // Helper method to check if a puppet should be shown based on its conditions
  bool shouldShowPuppet(PuppetInteraction puppet) {
    DebugLogger.puppet(
        '🎭 🎭 FILTERING: Checking puppet ID ${puppet.id} - isActive: ${puppet.isActive}, systemEnabled: $_isEnabled');

    if (!puppet.isActive || !_isEnabled) {
      DebugLogger.puppet(
          '🎭 ❌ FILTERING: Puppet ${puppet.id} rejected - isActive: ${puppet.isActive}, systemEnabled: $_isEnabled');
      return false;
    }

    // Enhanced logic: Check for item-specific targeting first

    // Case 1: Puppet has item-specific targeting (item_id)
    if (puppet.itemId != null) {
      // This puppet is meant for a specific item (e.g., product, gift, etc.)
      if (_contextActionId != null) {
        // Current screen has a specific item context
        bool itemMatches = puppet.itemId == _contextActionId;
        bool typeMatches = puppet.itemType == _contextActionType ||
            puppet.actionType == _contextActionType;

        DebugLogger.puppet(
            '🎭 🎯 Item-specific filtering: puppet itemId ${puppet.itemId} == context ${_contextActionId} ($itemMatches), '
            'puppet itemType "${puppet.itemType}" or actionType "${puppet.actionType}" == context "${_contextActionType}" ($typeMatches)');

        if (itemMatches && typeMatches) {
          DebugLogger.puppet(
              '🎭 ✅ FILTERING: Puppet ${puppet.id} matches current item ${_contextActionId}');
          return true;
        } else {
          DebugLogger.puppet(
              '🎭 ❌ FILTERING: Puppet ${puppet.id} is for different item (puppet: ${puppet.itemId}, current: ${_contextActionId})');
          return false;
        }
      } else {
        // Screen has no specific item context - this puppet is not relevant
        DebugLogger.puppet(
            '🎭 ❌ FILTERING: Puppet ${puppet.id} requires item ${puppet.itemId} but current screen has no item context');
        return false;
      }
    }

    // Case 2: Puppet has action targeting but no item-specific targeting
    if (puppet.actionType != null && puppet.actionId != null) {
      // If current screen also has matching context, show only if both match
      if (_contextActionType != null && _contextActionId != null) {
        bool typeMatches = puppet.actionType == _contextActionType;
        bool idMatches = puppet.actionId == _contextActionId;

        DebugLogger.puppet(
            '🎭 🎯 Action-specific filtering: actionType "${puppet.actionType}" == "${_contextActionType}" ($typeMatches), '
            'actionId ${puppet.actionId} == ${_contextActionId} ($idMatches)');

        return typeMatches && idMatches;
      } else {
        // Screen has no context - this is a promotional/navigation puppet
        // Show it on the current page (e.g., promoting product 190 on shop screen)
        DebugLogger.puppet(
            '🎭 🎯 Promotional puppet: Showing "${puppet.actionType}:${puppet.actionId}" targeting on current screen');
        return true;
      }
    }

    // Case 3: Universal puppet (no specific targeting) - show everywhere
    DebugLogger.puppet(
        '🎭 ✅ FILTERING: Universal puppet ${puppet.id} - No specific targeting, showing for all screens');
    return true;
  }

  // Helper method for comprehensive progress tracking
  Future<void> _trackPuppetProgress(
    int interactionId,
    String action, {
    double? completionPercentage,
    int? timeSpent,
    String? notes,
    Map<String, dynamic>? additionalData,
  }) async {
    DebugLogger.info('🎭 PROVIDER _trackPuppetProgress START');
    DebugLogger.info('🎭 Provider interactionId: $interactionId');
    DebugLogger.info('🎭 Provider action: $action');
    DebugLogger.info('🎭 Provider completionPercentage: $completionPercentage');
    DebugLogger.info('🎭 Provider timeSpent: $timeSpent');
    DebugLogger.info('🎭 Provider notes: $notes');
    DebugLogger.info('🎭 Provider additionalData: $additionalData');

    try {
      // Calculate actual time spent if not provided
      final actualTimeSpent = timeSpent ??
          (_interactionStartTime != null
              ? DateTime.now().difference(_interactionStartTime!).inSeconds
              : 0);
      DebugLogger.info('🎭 Provider actualTimeSpent: $actualTimeSpent');
      DebugLogger.info(
          '🎭 Provider _interactionStartTime: $_interactionStartTime');

      // Prepare interaction data with puppet-specific context
      final interactionData = {
        'puppet_id': interactionId,
        'screen_name': _currentScreenName,
        'context_action_type': _contextActionType,
        'context_action_id': _contextActionId,
        'suggestions_count': _currentSuggestions.length,
        'puppet_priority': _currentPuppet?.priority,
        'puppet_trigger_type': _currentPuppet?.triggerType,
        'has_navigation': _currentPuppet?.goToPage?.isNotEmpty ?? false,
        'action_type': _currentPuppet?.actionType,
        'action_id': _currentPuppet?.actionId,
        'puppet_title': _currentPuppet?.title,
        'has_media': (_currentPuppet?.imageUrl?.isNotEmpty ?? false) ||
            (_currentPuppet?.videoUrl?.isNotEmpty ?? false) ||
            (_currentPuppet?.audioUrl?.isNotEmpty ?? false),
        ...?additionalData,
      };
      DebugLogger.info('🎭 Provider final interactionData: $interactionData');

      DebugLogger.info(
          '🎭 Provider calling PuppetInteractionService.trackProgress...');
      final result = await PuppetInteractionService.trackProgress(
        interactionId,
        action,
        completionPercentage: completionPercentage,
        timeSpent: actualTimeSpent,
        screenName: _currentScreenName,
        interactionData: interactionData,
        notes: notes,
      );
      DebugLogger.info('🎭 Provider trackProgress result: $result');
    } catch (e, stackTrace) {
      DebugLogger.info('🎭 PROVIDER EXCEPTION in _trackPuppetProgress: $e');
      DebugLogger.info('🎭 Provider stack trace: $stackTrace');
      DebugLogger.puppet('Error in comprehensive puppet progress tracking: $e');
    } finally {
      DebugLogger.info('🎭 PROVIDER _trackPuppetProgress END');
    }
  }

  // Get formatted puppet count for UI
  String get puppetCountText {
    if (_currentSuggestions.isEmpty) return '';

    final currentIndex = _currentPuppet != null
        ? _currentSuggestions.indexWhere((s) => s.id == _currentPuppet!.id) + 1
        : 1;

    return '$currentIndex / ${_currentSuggestions.length}';
  }
}

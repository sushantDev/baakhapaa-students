import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/challenge.dart';
import '../shop/create/create_product_screen.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription.dart';
// TODO: Import Product provider when available
// import 'package:baakhapaa/providers/product.dart';
import 'package:baakhapaa/widgets/footer.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/loading.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import 'challenge_detail_widgets.dart';
import 'challenge_detail_screens_shared.dart';

/// Product Challenge Detail Screen
/// Similar to Shorts and Season challenges but for product-based competitions
/// Users create/submit products instead of videos or seasons
class ChallengeDetailProductScreen extends StatefulWidget {
  static const routeName = '/challenge-detail-product';

  final Map<String, dynamic>? challenge;

  const ChallengeDetailProductScreen({
    Key? key,
    this.challenge,
  }) : super(key: key);

  @override
  State<ChallengeDetailProductScreen> createState() =>
      _ChallengeDetailProductScreenState();
}

class _ChallengeDetailProductScreenState
    extends State<ChallengeDetailProductScreen> with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  List<dynamic> challengeProducts = [];
  Map<String, dynamic>? challenge;
  Map<String, dynamic>? myProductDetails;
  bool _isDescriptionExpanded = false;
  UserBenefitUsage? _unlockChallengeBenefit;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _checkChallengeBenefit();
      _fetchData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  // -----------------------------
  // Participation Lock Helpers
  // -----------------------------
  Future<void> _setChallengeLocked(int challengeId, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('challenge_${challengeId}_user_$userId', true);
    DebugLogger.info(
        '🔒 Locked participation for challenge $challengeId, user $userId');
  }

  // Future<bool> _isChallengeLockedForUser(int challengeId, int userId) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final isLocked =
  //       prefs.getBool('challenge_${challengeId}_user_$userId') ?? false;
  //   DebugLogger.info(
  //       '🔍 Check participation lock for challenge $challengeId, user $userId: $isLocked');
  //   return isLocked;
  // }

  Future<void> _checkChallengeBenefit() async {
    if (!mounted) return;
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.isSubscribed) return;

    try {
      final subService = SubscriptionService(context: context);
      final response = await subService.getUserBenefitStatus();
      if (mounted && response.success && response.items.isNotEmpty) {
        setState(() {
          try {
            _unlockChallengeBenefit = response.items.first.benefits.firstWhere(
              (b) => b.benefitType.id == 7,
            );
          } catch (_) {
            _unlockChallengeBenefit = null;
          }
        });
      }
    } catch (e) {
      DebugLogger.error('❌ Error checking challenge unlock benefit: $e');
    }
  }

  // ignore: unused_element
  Future<void> _useUnlockChallengeBenefit() async {
    if (_unlockChallengeBenefit == null || challenge == null) return;

    final challengeId = challenge!['id'] as int;
    final challengeTitle = challenge!['title'] ?? 'this challenge';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.amber, size: 24),
            SizedBox(width: 10),
            Text('Unlock Challenge',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Use 1 benefit to unlock "$challengeTitle"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC83E),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlock Now',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFC83E))),
      );

      final auth = Provider.of<Auth>(context, listen: false);
      final challengeProvider = Provider.of<Challenge>(context, listen: false);
      final subService =
          SubscriptionService(context: context, authToken: auth.token);

      await challengeProvider.unlockChallenge(challengeId);
      await subService.updateUserBenefitUsage(
        userBenefitUsageId: _unlockChallengeBenefit!.id,
        challengeId: challengeId,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          challenge!['unlocked'] = true;
          challenge!['is_locked'] = 0;
        });
        await _checkChallengeBenefit();
        showScaffoldMessenger(context, '🎉 Challenge unlocked successfully!');
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldMessenger(context, 'Failed to unlock: $e');
      }
    }
  }

  // -----------------------------
  // Data Loading
  // -----------------------------
  Future<void> _fetchData() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Use passed challenge or fetch from route arguments
      Map<String, dynamic>? challengeData = widget.challenge;

      if (challengeData == null) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        int challengeId;
        if (arguments is Map) {
          challengeId = arguments['id'] ?? arguments['challengeId'] ?? 0;
        } else if (arguments is int) {
          challengeId = arguments;
        } else if (arguments is String) {
          challengeId = int.tryParse(arguments) ?? 0;
        } else {
          challengeId = 0;
        }

        DebugLogger.info('🎁 Loading Product challenge ID: $challengeId');

        final challengeProvider =
            Provider.of<Challenge>(context, listen: false);
        await challengeProvider.fetchChallenges();
        if (!mounted) return;

        challengeData = challengeProvider.challenges.firstWhere(
          (c) => c['id'] == challengeId,
          orElse: () => <String, dynamic>{
            'id': challengeId,
            'title': 'Unknown Challenge',
            'deadline': 'Unknown',
            'points_required': 0,
            'unlock_points': 0,
            'is_locked': 0,
            'platform': 'Products',
          },
        );
      }

      final auth = Provider.of<Auth>(context, listen: false);
      final int myUserId = auth.userId;

      setState(() {
        challenge = challengeData;
        if (challenge != null) {
          normalizeChallenge(challenge!);
        }
      });

      // TODO: Fetch products for this challenge from API
      // Expected API endpoint: GET /api/challenges/{challengeId}/products
      // Expected response format:
      // {
      //   "data": [
      //     {
      //       "id": 1,
      //       "user_id": 123,
      //       "product_name": "Product Title",
      //       "description": "Product description",
      //       "image_url": "https://...",
      //       "price": 99.99,
      //       "category": "Electronics",
      //       "stock": 10,
      //       "ratings": 4.5,
      //       "total_sales": 50,
      //       "challenge_details": [
      //         {
      //           "rank": 1,
      //           "is_winner": 1,
      //           "total_points": 1500
      //         }
      //       ],
      //       "created_at": "2025-01-01T00:00:00Z"
      //     }
      //   ]
      // }
      try {
        final challengeProvider =
            Provider.of<Challenge>(context, listen: false);

        // Fetch user's own products to check participation
        await challengeProvider.fetchUserProducts(myUserId);

        // Fetch all challenge products for leaderboard/gallery
        await challengeProvider
            .fetchChallengeProductsForChallenge(challenge!['id']);

        if (!mounted) return;

        final userProducts = challengeProvider.userProducts;
        final allChallengeProducts = challengeProvider.challengeProducts;

        DebugLogger.success(
            '🎁 Loaded ${userProducts.length} user products and ${allChallengeProducts.length} challenge products');

        // Find user's product for THIS challenge from their own products
        final myProductEntry = userProducts.firstWhere(
          (p) {
            final productChallengeId = p['challenge_id'];
            final matches = productChallengeId != null &&
                productChallengeId.toString() == challenge!['id'].toString();
            if (matches) {
              DebugLogger.success(
                  '✅ Found user product for challenge: ${p['id']} - ${p['title']}');
            }
            return matches;
          },
          orElse: () => null,
        );

        if (myProductEntry != null) {
          DebugLogger.info(
              '📦 User product data: ${myProductEntry.keys.toList()}');
        } else {
          DebugLogger.warning(
              '⚠️ No product found for user $myUserId in challenge ${challenge!['id']}');
        }

        setState(() {
          challengeProducts = allChallengeProducts;
          myProductDetails = myProductEntry;
          _isLoading = false;
        });
      } catch (error) {
        DebugLogger.error('❌ Failed to fetch products: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      DebugLogger.error('❌ Error fetching product challenge data: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load challenge: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // -----------------------------
  // Helper Methods
  // -----------------------------
  void normalizeChallenge(Map<String, dynamic> c) {
    // Handle both boolean (true/false) and integer (0/1) values from backend
    final bool backendUnlocked =
        c['has_unlocked'] == true || c['has_unlocked'] == 1;
    final bool localUnlocked = c['unlocked'] == true || c['unlocked'] == 1;
    final bool isUnlocked = backendUnlocked || localUnlocked;
    c['unlocked'] = isUnlocked;
    c['is_locked'] = isUnlocked ? 0 : 1;

    // Ensure category ID is captured for pre-filling product creation
    if (c['product_category_id'] == null && c['category_id'] != null) {
      c['product_category_id'] = c['category_id'];
    }

    DebugLogger.info(
        '🔓 Challenge normalization: id=${c['id']}, unlocked=${c['unlocked']}, cat_id=${c['product_category_id']}');
  }

  bool isChallengeLocked(Map<String, dynamic>? challenge) {
    if (challenge == null) return true;
    return challenge['unlocked'] != true;
  }

  // Product-specific progress state logic
  Map<String, dynamic> getProductProgressState() {
    // STEP DEFINITIONS (Product Challenge)
    // Step 1 → Unlock Challenge
    // Step 2 → Create Product
    // Step 3 → Result (Ranking / Winner)

    final auth = Provider.of<Auth>(context, listen: false);
    final int myUserId = auth.userId;

    // Check if current user has participated (created a product)
    // Check if myProductDetails exists (set from user's own products API)
    DebugLogger.info(
        '👤 Current User ID: $myUserId (type: ${myUserId.runtimeType})');

    final bool hasParticipated = myProductDetails != null;

    if (hasParticipated) {
      DebugLogger.success(
          '✅ PARTICIPATION CONFIRMED: User has product ${myProductDetails!['id']} in challenge ${challenge?['id']}');
    } else {
      DebugLogger.warning(
          '⚠️ User has not participated in challenge ${challenge?['id']}');
    }

    DebugLogger.info(
        '🎁 Total Challenge Participants: ${challengeProducts.length} | User Participated: $hasParticipated');

    // Check if deadline has passed (expired)
    final String? deadlineStr = challenge?['deadline'];
    bool isExpired = false;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      String dateTimeStr = deadlineStr;
      if (!deadlineStr.contains('T')) {
        dateTimeStr = '$deadlineStr 23:59:59';
      }
      final DateTime? deadline = DateTime.tryParse(dateTimeStr);
      final DateTime now = DateTime.now();
      if (deadline != null && deadline.isBefore(now)) {
        isExpired = true;
      }
      DebugLogger.info(
          '⏰ Product Challenge deadline: $deadlineStr | Expired: $isExpired');
    }

    // Check if there's a winner declared
    bool hasWinnerDeclared = challengeProducts.any((product) =>
        product['challenge_details'] != null &&
        product['challenge_details'].isNotEmpty &&
        product['challenge_details'][0]['is_winner'] == 1);

    DebugLogger.info(
        '🏆 Product Challenge - Checking ${challengeProducts.length} products for winner');

    final bool resultDeclared = hasWinnerDeclared || isExpired;
    // final bool canShowResult = hasParticipated && resultDeclared;

    DebugLogger.success(
        '📊 Product Challenge State: hasParticipated=$hasParticipated | isExpired=$isExpired | resultDeclared=$resultDeclared');

    ChallengeStepStatus step1Status;
    ChallengeStepStatus step2Status;
    ChallengeStepStatus step3Status;
    String buttonText;
    Color buttonColor;
    IconData buttonIcon;
    VoidCallback? buttonAction;
    bool shouldShow = true;

    if (isExpired && !hasParticipated) {
      shouldShow = false;

      step1Status = ChallengeStepStatus.locked;
      step2Status = ChallengeStepStatus.locked;
      step3Status = ChallengeStepStatus.locked;

      buttonText = 'Challenge Expired';
      buttonColor = Colors.grey.shade700;
      buttonIcon = Icons.block;
      buttonAction = null;
    }

    // Rule 2: Not Expired + Not Participated → Show Unlock/Create option
    else if (!isExpired && !hasParticipated) {
      final bool locked = isChallengeLocked(challenge);

      if (locked) {
        // Step 1 active (unlock)
        step1Status = ChallengeStepStatus.active;
        step2Status = ChallengeStepStatus.locked;
        step3Status = ChallengeStepStatus.locked;

        buttonText = '';
        buttonColor = const Color(0xFFE50914);
        buttonIcon = Icons.lock_open;
        buttonAction = null;
      } else {
        // Step 2 active (create product)
        step1Status = ChallengeStepStatus.completed;
        step2Status = ChallengeStepStatus.active;
        step3Status = ChallengeStepStatus.locked;

        buttonText = 'Create Product';
        buttonColor = const Color(0xFF3DDC84);
        buttonIcon = Icons.add_shopping_cart;
        buttonAction = () => navigateToCreateProductScreen(context);
      }
    }

    // Rule 3: Participated + Not Expired → Waiting for Result
    else if (hasParticipated && !resultDeclared) {
      step1Status = ChallengeStepStatus.completed;
      step2Status = ChallengeStepStatus.completed;
      step3Status = ChallengeStepStatus.waiting;

      buttonText = 'Waiting for Result';
      buttonColor = Colors.grey.shade600;
      buttonIcon = Icons.hourglass_top;
      buttonAction = null;
    }

    // Rule 4: Participated + Expired → All Completed ✅
    else {
      step1Status = ChallengeStepStatus.completed;
      step2Status = ChallengeStepStatus.completed;
      step3Status = ChallengeStepStatus.completed;

      buttonText = 'View Results';
      buttonColor = const Color(0xFF4CAF50);
      buttonIcon = Icons.emoji_events;
      buttonAction = null;
    }

    return {
      'step1': step1Status,
      'step2': step2Status,
      'step3': step3Status,
      'buttonText': buttonText,
      'buttonColor': buttonColor,
      'buttonIcon': buttonIcon,
      'buttonAction': buttonAction,
      'shouldShow': shouldShow,
      'isExpired': isExpired,
      'hasParticipated': hasParticipated,
    };
  }

  // -----------------------------
  // Challenge Interaction
  // -----------------------------
  void handleChallengeTap(
      BuildContext context, Map<String, dynamic>? challenge) {
    if (!mounted) return;

    final authProvider = Provider.of<Auth>(context, listen: false);

    // ⚠️ VENDOR ROLE CHECK - Only vendors can unlock/participate in product challenges
    if (authProvider.role != 'vendor') {
      showScaffoldMessenger(
        context,
        'Only vendors can participate in product challenges. .',
      );
      return;
    }

    // Check if challenge is expired
    final String? deadlineStr = challenge?['deadline'];
    bool isExpired = false;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      String dateTimeStr = deadlineStr;
      if (!deadlineStr.contains('T')) {
        dateTimeStr = '$deadlineStr 23:59:59';
      }
      final DateTime? deadline = DateTime.tryParse(dateTimeStr);
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        isExpired = true;
      }
    }

    if (isExpired) {
      showScaffoldMessenger(
        context,
        'This challenge has expired. You can no longer participate.',
      );
      return;
    }

    // final authProvider = Provider.of<Auth>(context, listen: false);

    if (authProvider.userAvailableCoins >=
        (challenge?['points_required'] ?? 0)) {
      if (challenge?['unlocked'] == true) {
        navigateToCreateProductScreen(context);
      } else if (challenge?['achievement_id'] != null &&
          !(challenge?['has_obtained_achievement'] ?? false)) {
        if (!mounted) return;
        showScaffoldMessenger(
          context,
          'You need to obtain the achievement "${challenge?['achievement_title']}" to unlock this challenge.',
        );
      } else if (challenge?['product_id'] != null &&
          !(challenge?['has_purchased_product'] ?? false)) {
        if (!mounted) return;
        showScaffoldMessenger(
          context,
          'You need to purchase the required product "${challenge?['product_title']}" to unlock this challenge.',
        );
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            String unlockMessage;

            if (challenge?['unlock_points'] != null) {
              unlockMessage =
                  'This challenge is locked. Do you want to unlock it using ${challenge?['unlock_points']} points?';
            } else if (challenge?['achievement_id'] != null &&
                (challenge?['has_obtained_achievement'] ?? false)) {
              unlockMessage =
                  'You have the achievement "${challenge?['achievement_title']}". Do you want to use it to unlock this challenge?';
            } else if (challenge?['product_id'] != null &&
                (challenge?['has_purchased_product'] ?? false)) {
              unlockMessage =
                  'You have purchased the product "${challenge?['product_title']}". Do you want to use it to unlock this challenge?';
            } else {
              unlockMessage =
                  'This challenge is locked. Do you want to unlock it?';
            }

            return AlertDialog(
              title: Text('Unlock Challenge'),
              content: Text(unlockMessage),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    try {
                      var challengeProvider =
                          Provider.of<Challenge>(context, listen: false);
                      await challengeProvider.unlockChallenge(challenge?['id']);

                      if (!mounted) return;

                      setState(() {
                        challenge?['is_locked'] = 0;
                        challenge?['unlocked'] = true;
                        challenge?['has_unlocked'] = true;
                      });

                      nav.pop();
                      showScaffoldMessenger(
                          context, 'Challenge has been unlocked successfully!');
                      navigateToCreateProductScreen(context);
                    } catch (e) {
                      if (!mounted) return;
                      nav.pop();
                      showScaffoldMessenger(
                          context, 'Failed to unlock challenge: $e');
                    }
                  },
                  child: Text('Yes, Unlock Now'),
                ),
              ],
            );
          },
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You need ${challenge?['points_required']} coins to enter this challenge'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // -----------------------------
  // Navigation
  // -----------------------------
  void navigateToCreateProductScreen(BuildContext context) async {
    final auth = Provider.of<Auth>(context, listen: false);

    // ⚠️ VENDOR ROLE CHECK - Only vendors can participate in product challenges
    if (auth.role != 'vendor') {
      showScaffoldMessenger(
        context,
        'Only vendors can participate in product challenges.',
      );
      return;
    }

    // Check if challenge is expired
    final String? deadlineStr = challenge?['deadline'];
    bool isExpired = false;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      String dateTimeStr = deadlineStr;
      if (!deadlineStr.contains('T')) {
        dateTimeStr = '$deadlineStr 23:59:59';
      }
      final DateTime? deadline = DateTime.tryParse(dateTimeStr);
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        isExpired = true;
      }
    }

    if (isExpired) {
      showScaffoldMessenger(
        context,
        'This challenge has expired. You can no longer create products.',
      );
      return;
    }

    // TODO: Check if user is a creator/seller (role verification)
    // if (auth.role != 'creator' && auth.role != 'seller') {
    //   Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
    //   return;
    // }

    // Set local participation lock before navigating
    final int challengeId = challenge?['id'] ?? 0;
    final int myUserId = auth.userId;
    await _setChallengeLocked(challengeId, myUserId);

    // Navigate to Create Product screen with challenge context
    if (mounted) {
      await Navigator.of(context).pushNamed(
        CreateProductScreen.routeName,
        arguments: {
          'isChallenge': true,
          'challengeId': challenge?['id'],
          'categoryId': challenge?['product_category_id'],
          'points': challenge?['reward_details']?['reward_points'],
          'minParticipation':
              challenge?['min_number_of_challenge_participation'],
          'winnerCriteria': challenge?['winner_as'],
        },
      );

      // Refresh data after returning from product creation
      _fetchData();
    }
  }

  // -----------------------------
  // Build Method
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUserId = Provider.of<Auth>(context, listen: false).userId;

    return Scaffold(
      backgroundColor: isDark ? Color.fromARGB(255, 9, 9, 9) : Colors.white,
      appBar: header(context: context, titleText: 'Product Challenge'),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF090909), const Color(0xFF082032)]
                  : [Colors.white, Colors.grey.shade300],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _isLoading
              ? const Loading()
              : challenge == null
                  ? const ErrorState()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      child: Column(
                        children: [
                          // Challenge Header
                          ChallengeHeader(
                            challenge: challenge!,
                            isDescriptionExpanded: _isDescriptionExpanded,
                            onToggleDescription: () {
                              setState(() {
                                _isDescriptionExpanded =
                                    !_isDescriptionExpanded;
                              });
                            },
                          ),

                          // Unlock/Rewards Tabs
                          UnlockRewardsTabs(challengeData: challenge),

                          // Challenge Progress Card (3-step UI)
                          Builder(
                            builder: (context) {
                              final progressState = getProductProgressState();
                              final shouldShow =
                                  progressState['shouldShow'] as bool;
                              if (!shouldShow) {
                                return const SizedBox.shrink();
                              }
                              return ChallengeProgressCard(
                                step1: progressState['step1']
                                    as ChallengeStepStatus,
                                step2: progressState['step2']
                                    as ChallengeStepStatus,
                                step3: progressState['step3']
                                    as ChallengeStepStatus,
                                step2Title: 'Upload Product',
                                primaryButtonText:
                                    progressState['buttonText'] as String,
                                primaryButtonColor:
                                    progressState['buttonColor'] as Color,
                                primaryIcon:
                                    progressState['buttonIcon'] as IconData,
                                primaryAction: progressState['buttonAction']
                                    as VoidCallback?,
                              );
                            },
                          ),

                          // My Product Report Card
                          Builder(
                            builder: (context) {
                              if (myProductDetails == null) {
                                return const SizedBox.shrink();
                              }

                              return MyProductReportCard(
                                productData: myProductDetails,
                              );
                            },
                          ),

                          // Product Challenge Leaderboard
                          if (challengeProducts.isNotEmpty)
                            ProductChallengeLeaderboard(
                              challengeProducts: challengeProducts,
                              currentUserId: myUserId,
                            ),

                          // Participated Products Gallery
                          if (challengeProducts.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1C1C1C)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined,
                                          color: Colors.white70),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'All Participated Products:',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '${challengeProducts.length} Products',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.75,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: challengeProducts.length,
                                    itemBuilder: (context, index) {
                                      return ProductGalleryCard(
                                        product: challengeProducts[index],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                          ChallengeBottomUnlockButton(
                            challenge: challenge,
                            onUnlock: () =>
                                handleChallengeTap(context, challenge),
                          ),
                          Footer.scrollBottomSpacer(context),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

// ==================== HELPER WIDGETS ====================

class MyProductReportCard extends StatelessWidget {
  final Map<String, dynamic>? productData;

  const MyProductReportCard({super.key, this.productData});

  @override
  Widget build(BuildContext context) {
    if (productData == null) return const SizedBox.shrink();

    final productName = productData!['product_name'] ??
        productData!['title'] ??
        'Untitled Product';
    final imageUrl = _extractImageUrl(productData!);
    final price = productData!['price']?.toString() ?? '0.00';
    final sales = productData!['total_sales'] ?? 0;
    final rating = productData!['ratings'] ?? 0.0;
    // final stock = productData!['stock'] ?? 0;

    int rank = 0;
    if (productData!['challenge_details'] != null &&
        productData!['challenge_details'] is List &&
        productData!['challenge_details'].isNotEmpty) {
      rank = productData!['challenge_details'][0]['rank'] ?? 0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Product Report',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (rank > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC83E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Rank #$rank',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.white10),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.white10,
                    child:
                        const Icon(Icons.shopping_bag, color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. $price',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFFFFC83E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ReportStat(
                          icon: Icons.trending_up,
                          label: 'Sales',
                          value: sales.toString(),
                        ),
                        const SizedBox(width: 16),
                        _ReportStat(
                          icon: Icons.star,
                          label: 'Rating',
                          value: rating.toString(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReportStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class ProductChallengeLeaderboard extends StatelessWidget {
  final List<dynamic> challengeProducts;
  final int? currentUserId;

  const ProductChallengeLeaderboard({
    super.key,
    required this.challengeProducts,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final sortedProducts = [
      ...challengeProducts
    ]..sort((a, b) => (b['total_sales'] ?? 0).compareTo(a['total_sales'] ?? 0));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Leaderboard',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _LeaderboardHeaders(),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedProducts.length > 5 ? 5 : sortedProducts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final product = sortedProducts[index];
              return _LeaderboardItem(
                rank: index + 1,
                product: product,
                isCurrentUser: product['user_id'] == currentUserId,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardHeaders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.white38,
    );

    return Row(
      children: const [
        SizedBox(width: 30, child: Text('Rank', style: headerStyle)),
        Expanded(flex: 3, child: Text('Product', style: headerStyle)),
        Expanded(
            child:
                Text('Sales', style: headerStyle, textAlign: TextAlign.center)),
        Expanded(
            child: Text('Rating',
                style: headerStyle, textAlign: TextAlign.center)),
      ],
    );
  }
}

class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> product;
  final bool isCurrentUser;

  const _LeaderboardItem({
    required this.rank,
    required this.product,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:
            isCurrentUser ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                color: rank == 1
                    ? const Color(0xFFFFC83E)
                    : rank == 2
                        ? Colors.grey[400]
                        : rank == 3
                            ? const Color(0xFFCD7F32)
                            : Colors.white70,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: _extractImageUrl(product),
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 24,
                      height: 24,
                      color: Colors.grey,
                      child: const Icon(Icons.image, size: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product['product_name'] ?? product['title'] ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight:
                          isCurrentUser ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${product['total_sales'] ?? product['sales_count'] ?? 0}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 10, color: Color(0xFFFFC83E)),
                const SizedBox(width: 2),
                Text(
                  '${product['ratings'] ?? 0.0}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to extract image URL from product data
String _extractImageUrl(Map<String, dynamic> product) {
  // Try image_url first
  if (product['image_url'] != null &&
      product['image_url'].toString().isNotEmpty) {
    return product['image_url'];
  }

  // Try images array
  if (product['images'] != null && product['images'].isNotEmpty) {
    final firstImage = product['images'][0];
    if (firstImage is Map && firstImage['full'] != null) {
      final path = firstImage['full'].toString();
      // Add storage prefix if not already present
      if (path.startsWith('http')) {
        return path;
      }
      return 'https://student.baakhapaa.com/storage/$path';
    } else if (firstImage is String) {
      if (firstImage.startsWith('http')) {
        return firstImage;
      }
      return 'https://student.baakhapaa.com/storage/$firstImage';
    }
  }

  return '';
}

class ProductGalleryCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductGalleryCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: CachedNetworkImage(
                imageUrl: _extractImageUrl(product),
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.white10),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.shopping_bag),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['product_name'] ??
                      product['title'] ??
                      'Product Title',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs. ${product['price']}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFC83E),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up,
                            size: 10, color: Colors.white54),
                        const SizedBox(width: 2),
                        Text(
                          '${product['total_sales'] ?? product['sales_count'] ?? 0}',
                          style: GoogleFonts.poppins(
                              fontSize: 9, color: Colors.white54),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 10, color: Color(0xFFFFC83E)),
                        const SizedBox(width: 2),
                        Text(
                          '${product['ratings'] ?? 0.0}',
                          style: GoogleFonts.poppins(
                              fontSize: 9, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

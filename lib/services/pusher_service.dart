import 'dart:async';
import 'dart:convert';
import 'package:baakhapaa/config/pusher_config.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../utils/debug_logger.dart';

/// Service to handle Pusher real-time events
class PusherService {
  static final PusherService _instance = PusherService._internal();

  late PusherChannelsFlutter _pusher;
  String? _currentUserId;
  bool _isInitialized = false;
  bool _isConnected = false;

  // Event stream for broadcasting to providers
  final _eventStreamController = StreamController<PusherEventData>.broadcast();
  Stream<PusherEventData> get eventStream => _eventStreamController.stream;

  factory PusherService() {
    return _instance;
  }

  PusherService._internal();

  /// Convenient setup method using config
  /// Call this once when user logs in
  static Future<void> setupAndConnect(int userId, {String? authToken}) async {
    final service = PusherService();

    try {
      DebugLogger.info('🔌 Pusher: Setting up for user $userId...');

      // Initialize with config values
      await service.init(
        apiKey: PusherConfig.appKey,
        cluster: PusherConfig.cluster,
        userId: userId.toString(),
        authToken: authToken,
      );

      // Connect to Pusher
      await service.connect();

      // Subscribe to user's private channel
      await service.subscribeToUserChannel();

      // Set up event listener in provider
      service._setupEventListener();

      DebugLogger.info('✅ Pusher: Setup complete and connected!');
    } catch (e) {
      DebugLogger.info('❌ Pusher: Setup error: $e');
      rethrow;
    }
  }

  /// Initialize Pusher with credentials
  Future<void> init({
    required String apiKey,
    required String cluster,
    required String userId,
    String? authToken,
  }) async {
    if (_isInitialized) {
      DebugLogger.info('🔌 Pusher: Already initialized');
      return;
    }

    try {
      _currentUserId = userId;
      _pusher = PusherChannelsFlutter.getInstance();

      DebugLogger.info(
          '🔌 Pusher: Initializing with key: $apiKey, cluster: $cluster, userId: $userId');

      await _pusher.init(
        apiKey: apiKey,
        cluster: cluster,
        onConnectionStateChange: (previousState, currentState) {
          _handleConnectionStateChange(
              previousState.toString(), currentState.toString());
        },
        onError: _handleError,
        onSubscriptionSucceeded: _handleSubscriptionSucceeded,
        onEvent: _handleEvent,
        onSubscriptionError: _handleSubscriptionError,
        onAuthorizer: (channelName, socketId, options) async {
          // Call Laravel backend for channel authorization
          DebugLogger.info(
              '🔐 Pusher: Authorizing channel $channelName with socket $socketId');

          try {
            final response = await _authorizeChannel(
              channelName: channelName,
              socketId: socketId,
              authToken: authToken,
            );

            DebugLogger.info(
                '✅ Pusher: Authorization successful for $channelName');
            return response;
          } catch (e) {
            DebugLogger.info('❌ Pusher: Authorization failed: $e');
            rethrow;
          }
        },
      );

      _isInitialized = true;
      DebugLogger.info('🔌 Pusher: Initialization complete');
    } catch (e) {
      DebugLogger.info('❌ Pusher: Initialization error: $e');
      rethrow;
    }
  }

  /// Authorize private channel with Laravel backend
  Future<dynamic> _authorizeChannel({
    required String channelName,
    required String socketId,
    String? authToken,
  }) async {
    final url = Uri.parse(PusherConfig.authEndpoint);
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    // Add authorization header if token available
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final body = {
      'socket_id': socketId,
      'channel_name': channelName,
    };

    DebugLogger.info('🔐 Pusher: POST ${url.toString()}');
    DebugLogger.info('   Headers: $headers');
    DebugLogger.info('   Body: $body');

    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );

    DebugLogger.info('🔐 Pusher: Response status: ${response.statusCode}');
    DebugLogger.info('   Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception(
          'Authorization failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Connect to Pusher
  Future<void> connect() async {
    if (!_isInitialized) {
      throw Exception('Pusher not initialized. Call init() first.');
    }

    try {
      DebugLogger.info('🔌 Pusher: Connecting...');
      await _pusher.connect();
      DebugLogger.info('🔌 Pusher: Connected');
    } catch (e) {
      DebugLogger.info('❌ Pusher: Connection error: $e');
      rethrow;
    }
  }

  /// Subscribe to user's private channel
  Future<void> subscribeToUserChannel() async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Pusher not initialized or userId not set');
    }

    try {
      final channelName = 'private-user.$_currentUserId';
      DebugLogger.info('🔌 Pusher: Subscribing to channel: $channelName');

      // Subscribe to channel - stored for reference but events handled via callback
      await _pusher.subscribe(
        channelName: channelName,
        onSubscriptionSucceeded: (data) {
          DebugLogger.info('✅ Pusher: Subscribed to $channelName');
          _handleSubscriptionSucceeded(channelName, data);
        },
        onSubscriptionError: (error) {
          DebugLogger.info('❌ Pusher: Subscription error to $channelName');
          _handleSubscriptionError(error?.toString() ?? 'Unknown error', error);
        },
        onEvent: _handleEvent,
      );

      // Events are automatically handled through onEvent callback
      DebugLogger.info('✅ Pusher: Channel ready to receive events');
    } catch (e) {
      DebugLogger.info('❌ Pusher: Channel subscription error: $e');
      rethrow;
    }
  }

  /// Handle connection state changes
  void _handleConnectionStateChange(String previousState, String currentState) {
    DebugLogger.info(
        '🔌 Pusher: Connection state changed: $previousState → $currentState');
    _isConnected = currentState == 'CONNECTED';

    if (_isConnected) {
      DebugLogger.info('✅ Pusher: Connected and ready');
    }
  }

  /// Handle Pusher errors
  void _handleError(String message, int? code, dynamic error) {
    DebugLogger.info('❌ Pusher Error [$code]: $message');
    if (error != null) {
      DebugLogger.info('   Details: $error');
    }
  }

  /// Handle subscription success
  void _handleSubscriptionSucceeded(String channelName, dynamic data) {
    DebugLogger.info('✅ Pusher: Subscription succeeded for $channelName');
  }

  /// Handle subscription errors
  void _handleSubscriptionError(String message, dynamic error) {
    DebugLogger.info('❌ Pusher Subscription Error: $message');
    if (error != null) {
      DebugLogger.info('   Details: $error');
    }
  }

  /// Handle incoming events
  void _handleEvent(dynamic event) {
    try {
      // Cast to PusherEvent if it's not already
      final pusherEvent = event as PusherEvent;

      DebugLogger.info(
          '📨 Pusher: Raw event - Channel: ${pusherEvent.channelName}, Event: ${pusherEvent.eventName}');
      DebugLogger.info('   Data: ${pusherEvent.data}');

      // Parse the event data
      final eventData = _parseEventData(
        eventName: pusherEvent.eventName,
        rawData: pusherEvent.data,
      );

      if (eventData != null) {
        DebugLogger.info('✅ Pusher: Broadcasting event: ${eventData.type}');
        _eventStreamController.add(eventData);
      }
    } catch (e) {
      DebugLogger.info('❌ Pusher: Error handling event: $e');
    }
  }

  /// Set up event listener (called after initialization)
  void _setupEventListener() {
    DebugLogger.info('🔌 Pusher: Event listener setup complete');
  }

  /// Parse event data based on event type
  PusherEventData? _parseEventData({
    required String eventName,
    required String? rawData,
  }) {
    try {
      // Ignore Pusher internal events (they start with 'pusher:')
      if (eventName.startsWith('pusher:')) {
        // These are handled by the SDK callbacks, not application events
        return null;
      }

      // Parse JSON if available
      Map<String, dynamic> data = {};
      if (rawData != null && rawData.isNotEmpty) {
        data = jsonDecode(rawData);
      }

      switch (eventName) {
        case 'reward.earned':
          return PusherEventData(
            type: 'reward_earned',
            eventName: eventName,
            data: data,
            source: data['source'] ?? 'unknown',
            amount: data['amount'] ?? data['coins'] ?? 0,
            availableCoins: data['available_coins'] ??
                data['updated_balances']?['available'] ??
                0,
          );

        case 'progress.updated':
          return PusherEventData(
            type: 'progress_updated',
            eventName: eventName,
            data: data,
            progressType: data['progress_type'] ?? 'unknown',
            progressData: data['progress_data'],
          );

        case 'gift.available':
          return PusherEventData(
            type: 'gift_available',
            eventName: eventName,
            data: data,
            giftType: data['gift_type'] ?? 'unknown',
            giftDetails: data['gift_details'] ?? {},
          );

        case 'level.upgraded':
          // Extract level ID from new_level object or use as int
          final newLevelData = data['new_level'];
          final levelId =
              newLevelData is Map ? newLevelData['id'] : newLevelData;

          return PusherEventData(
            type: 'level_upgraded',
            eventName: eventName,
            data: data,
            newLevel: levelId ?? 0,
            reward: data['rewards'] ?? data['reward'],
          );

        // Low-priority engagement notifications
        case 'shorts.liked':
          return PusherEventData(
            type: 'shorts_liked',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            actorId: data['liker_id'],
            actorUsername: data['liker_username'],
            actorName:
                data['liker_username'], // Use username if name not provided
            contentId: data['shorts_id'],
            contentTitle: data['shorts_title'],
            contentType: 'shorts',
            message:
                '👍 ${data['liker_username']} liked your shorts: ${data['shorts_title']}',
          );

        case 'shorts.commented':
          return PusherEventData(
            type: 'shorts_commented',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            actorId: data['commenter_id'],
            actorUsername: data['commenter_username'],
            actorName: data['commenter_username'],
            contentId: data['shorts_id'],
            contentTitle: data['shorts_title'],
            contentType: 'shorts',
            message:
                '💬 ${data['commenter_username']} commented on your shorts: ${data['shorts_title']}',
          );

        case 'shorts.donation.received':
          return PusherEventData(
            type: 'shorts_donation_received',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            actorId: data['donor_id'],
            actorUsername: data['donor_username'],
            actorName: data['donor_username'],
            contentId: data['shorts_id'],
            contentTitle: data['shorts_title'],
            contentType: 'shorts',
            amount: data['coins'],
            message:
                '💰 ${data['donor_username']} donated ${data['coins']} coins to your shorts!',
          );

        case 'season.commented':
          return PusherEventData(
            type: 'season_commented',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            actorId: data['commenter_id'],
            actorUsername: data['commenter_username'],
            actorName: data['commenter_username'],
            contentId: data['episode_id'],
            contentTitle: data['episode_title'],
            contentType: 'season',
            message:
                '💬 ${data['commenter_username']} commented on your episode: ${data['episode_title']}',
          );

        case 'season.donation.received':
          return PusherEventData(
            type: 'season_donation_received',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            actorId: data['donor_id'],
            actorUsername: data['donor_username'],
            actorName: data['donor_username'],
            contentId: data['episode_id'],
            contentTitle: data['episode_title'],
            contentType: 'season',
            amount: data['coins'],
            message:
                '💰 ${data['donor_username']} donated ${data['coins']} coins to your episode!',
          );

        case 'content.view.milestone':
          final contentType = data['content_type'] ?? 'content';
          final contentTitle = data['content_title'] ?? 'your content';
          return PusherEventData(
            type: 'content_view_milestone',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            contentId: data['content_id'],
            contentTitle: contentTitle,
            contentType: contentType,
            message:
                '🎉 Your $contentType "$contentTitle" reached ${data['milestone']} views!',
          );

        case 'user.followed':
          return PusherEventData(
            type: 'user_followed',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            actorId: data['follower_id'] ?? data['actor_id'],
            actorUsername: data['follower_username'] ?? data['actor_username'],
            actorName: data['follower_name'] ?? data['actor_name'],
            message:
                '👤 ${data['follower_name'] ?? data['actor_name'] ?? data['follower_username'] ?? data['actor_username']} started following you!',
          );

        case 'badge.earned':
          return PusherEventData(
            type: 'badge_earned',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            contentId: data['badge_id'],
            contentTitle: data['badge_title'],
            message: '🏆 You unlocked the badge: ${data['badge_title']}!',
          );

        case 'referral.joined':
          return PusherEventData(
            type: 'referral_joined',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            actorId: data['referred_user_id'],
            actorUsername: data['referred_user_username'],
            actorName: data['referred_user_name'],
            amount: data['coins_earned'],
            message:
                '🎁 ${data['referred_user_name'] ?? data['referred_user_username']} joined using your referral code! You earned ${data['coins_earned']} coins.',
          );

        case 'challenge.won':
          return PusherEventData(
            type: 'challenge_won',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            contentId: data['challenge_id'],
            contentTitle: data['challenge_title'],
            amount: data['coins_earned'],
            message:
                '🏅 Congratulations! You won the challenge "${data['challenge_title']}" and earned ${data['coins_earned']} coins!',
          );

        case 'subscription.order.created':
          return PusherEventData(
            type: 'subscription_order_created',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            orderId: data['order_id'],
            subscriptionId: data['subscription_id'],
            subscriptionName: data['subscription_name'],
            durationDays: data['duration_days'],
            totalAmount: data['total_amount'],
            paymentMethod: data['payment_method'],
            status: data['status'],
            timestamp: data['timestamp'],
            message:
                '📋 Your ${data['subscription_name']} order has been placed via ${data['payment_method']}!',
          );

        case 'subscription.order.completed':
          return PusherEventData(
            type: 'subscription_order_completed',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            orderId: data['order_id'],
            subscriptionId: data['subscription_id'],
            subscriptionName: data['subscription_name'],
            startedAt: data['started_at'],
            expiresAt: data['expires_at'],
            durationDays: data['duration_days'],
            totalAmount: data['total_amount'],
            pointsAwarded: data['points_awarded'],
            isRepurchase: data['is_repurchase'],
            status: data['status'],
            timestamp: data['timestamp'],
            message:
                '🎉 ${data['is_repurchase'] == true ? 'Welcome back! ' : ''}Your ${data['subscription_name']} is now active! ${data['points_awarded'] != null && data['points_awarded'] > 0 ? '+${data['points_awarded']} points' : ''}',
          );

        case 'product.purchased':
          return PusherEventData(
            type: 'product_purchased',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            productId: data['product_id'],
            productName: data['product_name'],
            orderId: data['order_id'],
            amountPaid: data['amount_paid'],
            purchasedAt: data['purchased_at'],
            timestamp: data['timestamp'],
            message:
                '🛍️ Successfully purchased ${data['product_name']} for NPR ${data['amount_paid']}!',
          );

        case 'order.confirmed':
          return PusherEventData(
            type: 'order_confirmed',
            eventName: eventName,
            data: data,
            priority: data['priority'] ?? 'low',
            productId: data['product_id'],
            productName: data['product_name'],
            orderId: data['order_id'],
            totalAmount: data['total'],
            purchasedAt: data['created_at'],
            timestamp: data['timestamp'],
            message:
                '✅ Order confirmed! ${data['product_name']} - NPR ${data['total']}',
          );

        // ── Collaboration events ───────────────────────────────────────
        case 'collaboration.invitation':
          return PusherEventData(
            type: 'collaboration_invitation',
            eventName: eventName,
            data: data,
            contentId: data['collaboration_id'],
            contentTitle: data['title'],
            contentType: data['content_type'],
            actorId: data['initiator']?['id'],
            actorUsername: data['initiator']?['username'],
            actorName: data['initiator']?['username'],
            message:
                '🤝 ${data['initiator']?['username'] ?? 'Someone'} invited you to collaborate on "${data['title']}"',
          );

        case 'collaboration.response':
          final action = data['action'] ?? 'responded';
          final emoji = action == 'accepted' ? '✅' : '❌';
          return PusherEventData(
            type: 'collaboration_response',
            eventName: eventName,
            data: data,
            contentId: data['collaboration_id'],
            contentTitle: data['title'],
            actorId: data['responder']?['id'],
            actorUsername: data['responder']?['username'],
            actorName: data['responder']?['username'],
            status: action,
            message:
                '$emoji ${data['responder']?['username'] ?? 'Someone'} $action your collaboration "${data['title']}"',
          );

        case 'collaboration.ready':
          return PusherEventData(
            type: 'collaboration_ready',
            eventName: eventName,
            data: data,
            contentId: data['collaboration_id'],
            contentTitle: data['title'],
            contentType: data['content_type'],
            message:
                '🎉 Collaboration "${data['title']}" is ready! All collaborators have accepted.',
          );

        case 'collaboration.cancelled':
          return PusherEventData(
            type: 'collaboration_cancelled',
            eventName: eventName,
            data: data,
            contentId: data['collaboration_id'],
            contentTitle: data['title'],
            contentType: data['content_type'],
            actorId: data['cancelled_by']?['id'],
            actorUsername: data['cancelled_by']?['username'],
            actorName: data['cancelled_by']?['username'],
            message:
                '🚫 ${data['cancelled_by']?['username'] ?? 'Someone'} cancelled the collaboration "${data['title']}"',
          );

        default:
          DebugLogger.info('⚠️  Pusher: Unknown event type: $eventName');
          return null;
      }
    } catch (e) {
      DebugLogger.info('❌ Pusher: Error parsing event data: $e');
      return null;
    }
  }

  /// Disconnect from Pusher
  Future<void> disconnect() async {
    try {
      if (_isInitialized) {
        await _pusher.disconnect();
        DebugLogger.info('🔌 Pusher: Disconnected');
        _isConnected = false;
      }
    } catch (e) {
      DebugLogger.info('❌ Pusher: Disconnect error: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await disconnect();
    await _eventStreamController.close();
    _isInitialized = false;
    _currentUserId = null;
    DebugLogger.info('🗑️  Pusher: Service disposed');
  }

  /// Check if connected
  bool get isConnected => _isConnected;
}

/// Data model for Pusher events
class PusherEventData {
  final String
      type; // reward_earned, progress_updated, gift_available, level_upgraded, engagement notifications
  final String eventName; // reward.earned, progress.updated, shorts.liked, etc.
  final Map<String, dynamic> data; // Full raw data from backend

  // Reward fields
  final String? source;
  final dynamic amount;
  final dynamic availableCoins;

  // Progress fields
  final String? progressType;
  final dynamic progressData;

  // Gift fields
  final String? giftType;
  final Map<String, dynamic>? giftDetails;

  // Level fields
  final int? newLevel;
  final dynamic reward;

  // Engagement notification fields (low priority)
  final String? priority; // 'low' for engagement notifications
  final String? actorName;
  final String? actorUsername;
  final int? actorId;
  final String? contentTitle;
  final int? contentId;
  final String? contentType; // 'shorts', 'season', etc.
  final String? message; // Formatted message

  // Subscription fields
  final int? orderId;
  final int? subscriptionId;
  final String? subscriptionName;
  final int? durationDays;
  final int? totalAmount;
  final String? paymentMethod;
  final String? status;
  final String? startedAt;
  final String? expiresAt;
  final int? pointsAwarded;
  final bool? isRepurchase;
  final String? timestamp;

  // Product purchase fields
  final int? productId;
  final String? productName;
  final int? amountPaid;
  final String? purchasedAt;

  PusherEventData({
    required this.type,
    required this.eventName,
    required this.data,
    this.source,
    this.amount,
    this.availableCoins,
    this.progressType,
    this.progressData,
    this.giftType,
    this.giftDetails,
    this.newLevel,
    this.reward,
    this.priority,
    this.actorName,
    this.actorUsername,
    this.actorId,
    this.contentTitle,
    this.contentId,
    this.contentType,
    this.message,
    // Subscription parameters
    this.orderId,
    this.subscriptionId,
    this.subscriptionName,
    this.durationDays,
    this.totalAmount,
    this.paymentMethod,
    this.status,
    this.startedAt,
    this.expiresAt,
    this.pointsAwarded,
    this.isRepurchase,
    this.timestamp,
    // Product purchase parameters
    this.productId,
    this.productName,
    this.amountPaid,
    this.purchasedAt,
  });

  @override
  String toString() {
    return 'PusherEventData(type: $type, eventName: $eventName, data: $data)';
  }
}

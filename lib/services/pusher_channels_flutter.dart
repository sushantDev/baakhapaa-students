/// Complete mock implementation of pusher_channels_flutter for iOS testing
/// This file replaces the entire pusher_channels_flutter package functionality
/// with no-op implementations that allow iOS builds to succeed

import 'dart:async';
import '../../../utils/debug_logger.dart';

/// Mock PusherChannelsFlutter class
class PusherChannelsFlutter {
  static PusherChannelsFlutter? _instance;

  static PusherChannelsFlutter getInstance() {
    _instance ??= PusherChannelsFlutter._();
    return _instance!;
  }

  PusherChannelsFlutter._();

  /// Initialize Pusher
  Future<void> init({
    required String apiKey,
    required String cluster,
    Function(String, dynamic)? onConnectionStateChange,
    Function(String, String?, dynamic)? onError,
    Function(String, dynamic)? onSubscriptionSucceeded,
    Function(PusherEvent)? onEvent,
    Function(String, String?, dynamic)? onSubscriptionError,
    Function(String, String?, dynamic)? onDecryptionFailure,
    Function(String)? onMemberAdded,
    Function(String)? onMemberRemoved,
  }) async {
    DebugLogger.info(
        'Mock Pusher: Initialized with API key $apiKey, cluster $cluster');
  }

  /// Connect to Pusher
  Future<void> connect() async {
    DebugLogger.info('Mock Pusher: Connected');
  }

  /// Disconnect from Pusher
  Future<void> disconnect() async {
    DebugLogger.info('Mock Pusher: Disconnected');
  }

  /// Subscribe to a channel
  Future<PusherChannel> subscribe({
    required String channelName,
    Function(PusherEvent)? onEvent,
    Function(String, dynamic)? onSubscriptionSucceeded,
    Function(String, String?, dynamic)? onSubscriptionError,
    Function(String)? onMemberAdded,
    Function(String)? onMemberRemoved,
  }) async {
    DebugLogger.info('Mock Pusher: Subscribed to channel $channelName');
    return PusherChannel(channelName);
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe({required String channelName}) async {
    DebugLogger.info('Mock Pusher: Unsubscribed from channel $channelName');
  }

  /// Trigger an event
  Future<void> trigger({
    required String channelName,
    required String eventName,
    required String data,
  }) async {
    DebugLogger.info(
        'Mock Pusher: Triggered event $eventName on channel $channelName');
  }
}

/// Mock PusherChannel class
class PusherChannel {
  final String name;

  PusherChannel(this.name);

  /// Bind to an event
  Future<void> bind({
    required String eventName,
    required Function(PusherEvent) callback,
  }) async {
    DebugLogger.info('Mock Pusher: Bound to event $eventName on channel $name');
  }

  /// Unbind from an event
  Future<void> unbind({required String eventName}) async {
    DebugLogger.info(
        'Mock Pusher: Unbound from event $eventName on channel $name');
  }

  /// Trigger an event on this channel
  Future<void> trigger({
    required String eventName,
    required String data,
  }) async {
    DebugLogger.info(
        'Mock Pusher: Triggered event $eventName on channel $name');
  }
}

/// Mock PusherEvent class
class PusherEvent {
  final String? channelName;
  final String? eventName;
  final String? data;
  final String? userId;

  const PusherEvent({
    this.channelName,
    this.eventName,
    this.data,
    this.userId,
  });
}

/// Mock PusherEventStreamChannel class
class PusherEventStreamChannel {
  final String name;

  PusherEventStreamChannel(this.name);

  Stream<PusherEvent> get stream => const Stream.empty();
}

/// Mock connection states
class PusherConnectionState {
  static const String connecting = 'CONNECTING';
  static const String connected = 'CONNECTED';
  static const String disconnecting = 'DISCONNECTING';
  static const String disconnected = 'DISCONNECTED';
  static const String reconnecting = 'RECONNECTING';
}

/// Mock error codes
class PusherError {
  final String? message;
  final String? code;
  final dynamic exception;

  const PusherError({
    this.message,
    this.code,
    this.exception,
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
// import '../../main.dart';

import 'package:app_links/app_links.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:bubble/bubble.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:baakhapaa/widgets/messages_bubble.dart';
import '../../models/url.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class MessagesScreen extends StatefulWidget {
  static const routeName = '/messages-screen';

  // static void navigateToMessage(String conversationId, String senderName) {
  //   mainNavigatorKey.currentState?.pushNamed(
  //     MessagesScreen.routeName,
  //     arguments: {
  //       'conversation_id': conversationId,
  //       'sender_name': senderName,
  //     },
  //   );
  // }

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  Map<String, dynamic> args = {};
  List<types.Message> _messages = [];
  types.User _user = types.User(id: '');
  final GlobalKey<ChatState> _chatKey = GlobalKey();
  late PusherChannelsFlutter pusher;
  late PusherChannel myChannel;
  Set<int> _processedMessageIds = {};
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;
  // Define valid Baakhapaa URL patterns
  final List<String> validPaths = [
    'shorts',
    'episode',
    'gift',
    'product',
    'redeem gift',
  ];

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is Map<String, dynamic>) {
        setState(() {
          args = Map<String, dynamic>.from(routeArgs);
        });

        // Initialize chat after getting args
        _initializeChat();
      } else {
        // Show error and pop if args are invalid
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Invalid message data')));
          Navigator.of(context).pop();
        });
        return;
      }

      final authProvider = Provider.of<Auth>(context, listen: false);
      authProvider.markMessagesAsRead(args['conversation_id'] as int);
      authProvider.clearUnreadMessageCount();
      authProvider.getUnreadMessageCount();

      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _initializeChat() async {
    if (!mounted) return;

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      _user = types.User(id: auth.userId.toString());

      // Fetch messages first
      await auth.fetchMessages(args['conversation_id'] as int);

      if (!mounted) return;

      setState(() {
        _messages = _convertMessages(auth.messages);
        _isLoading = false;
      });

      // Initialize Pusher after messages are loaded
      await _connectPusher();
      _setupDeepLinkHandling();
    } catch (e) {
      DebugLogger.error('Error initializing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load messages')));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    pusher.unsubscribe(channelName: 'conversations.${args['conversation_id']}');
    pusher.disconnect();
    super.dispose();
  }

  void _setupDeepLinkHandling() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? link) {
        if (link != null && link.toString().isNotEmpty) {
          DebugLogger.info("Deep Link received: ${link.toString()}");
          // You can add any specific handling here if needed
        }
      },
      onError: (err) {
        DebugLogger.error("Failed to receive deep link: $err");
      },
    );
  }

  Future<void> _connectPusher() async {
    pusher = PusherChannelsFlutter.getInstance();
    try {
      await pusher.init(
        apiKey: '09f62fb26d288c955778',
        cluster: 'ap2',
        onConnectionStateChange: _onConnectionStateChange,
        onError: _onError,
        onSubscriptionSucceeded: _onSubscriptionSucceeded,
        onEvent: _onEvent,
        onSubscriptionError: _onSubscriptionError,
        // onDecryptionFailure: _onDecryptionFailure,
        // onMemberAdded: _onMemberAdded,
        // onMemberRemoved: _onMemberRemoved,
      );

      myChannel = await pusher.subscribe(
        channelName: 'conversations.${args['conversation_id']}',
        // onMemberAdded: _onMemberAdded,
        // onMemberRemoved: _onMemberRemoved,
        onEvent: _onEvent,
      );

      await pusher.connect();
    } catch (e) {
      DebugLogger.error("ERROR: $e");
    }
  }

  void _onConnectionStateChange(dynamic currentState, dynamic previousState) {
    DebugLogger.info("Connection state changed: $currentState");
  }

  void _onError(String message, int? code, dynamic e) {
    DebugLogger.error("Error: $message (code: $code); exception: $e");
  }

  void _onSubscriptionSucceeded(String channelName, dynamic data) {
    DebugLogger.info("Subscribed to $channelName with data: $data");
  }

  void _onEvent(dynamic event) {
    DebugLogger.info(
      "Received event on channel ${event.channelName}: ${event.eventName} with data: ${event.data}",
    );
    if (event.eventName == 'message.sent') {
      final Map<String, dynamic> messageData = jsonDecode(
        event.data,
      ); // Decode JSON

      // Check if this message ID has already been processed
      if (_processedMessageIds.contains(messageData['id'])) {
        return; // Ignore this event as it's a duplicate
      }

      // Mark this message as processed
      _processedMessageIds.add(messageData['id']);

      // Check if the message is sent by the current user
      if (messageData['user_id'].toString() ==
          Provider.of<Auth>(context, listen: false).userId.toString()) {
        return; // Do not add this message to the chat
      }

      // Retrieve user information
      Map<String, dynamic> userInfo = {
        "id": messageData['user_id'],
        "username": args['user_name'],
        "name": args['user_name'],
        "user_image": "",
      };

      final message = createMessage(addUserInfo(userInfo, messageData));
      _addMessage(message);
    }
  }

  void _onSubscriptionError(String message, dynamic e) {
    DebugLogger.error("Subscription error: $message. Exception: $e");
  }

  Map<String, dynamic> addUserInfo(
    Map<String, dynamic> userInfo,
    Map<String, dynamic> incomingMessage,
  ) {
    incomingMessage['user'] = userInfo;
    return incomingMessage;
  }

  types.Message createMessage(Map<String, dynamic> incomingMessage) {
    final user = types.User(
      id: incomingMessage['user']['id'].toString(),
      firstName: incomingMessage['user']['name'],
      imageUrl: incomingMessage['user']['user_image'],
    );

    // Check the type of the message ('text' or 'image')
    if (incomingMessage['type'] == 'image') {
      return types.ImageMessage(
        author: user,
        createdAt: DateTime.parse(
          incomingMessage['created_at'],
        ).millisecondsSinceEpoch,
        id: incomingMessage['id'].toString(),
        name: incomingMessage['media_url'] != null
            ? incomingMessage['media_url'].split('/').last
            : 'Image',
        uri: incomingMessage['media_url'] ?? '',
        size: 100,
      );
    } else {
      return types.TextMessage(
        author: user,
        createdAt: DateTime.parse(
          incomingMessage['created_at'],
        ).millisecondsSinceEpoch,
        id: incomingMessage['id'].toString(),
        text: incomingMessage['content'] ?? '',
      );
    }
  }

  // void _connectWebSocket() async {
  //   try {
  //     channel = WebSocketChannel.connect(
  //       Uri.parse(
  //           'ws://student.baakhapaa.com:6001/socket.io/?EIO=4&transport=websocket'),
  //     );
  //     await channel.ready;
  //     DebugLogger.info('WebSocket connection established');

  //     // Subscribe to the channel
  //     final conversationId = args['conversation_id'].toString();
  //     final channelId =
  //         '{"event": "subscribe", "channel": "conversations.$conversationId"}';
  //     channel.sink.add(channelId);
  //     DebugLogger.info('Subscribed to channel: $channelId');

  //     // Listen for incoming messages
  //     channel.stream.listen((message) {
  //       DebugLogger.info('Received message: $message');
  //     }, onError: (error) {
  //       DebugLogger.error('WebSocket error: $error');
  //     }, onDone: () {
  //       DebugLogger.info('WebSocket connection closed');
  //     });
  //   } catch (error) {
  //     DebugLogger.error('Error connecting to WebSocket: $error');
  //   }
  // }

  // void _connectWebSocket() {
  //   try {
  //     // Create a Socket.IO connection
  //     IO.Socket socket = IO.io(
  //         'http://student.baakhapaa.com:6001',
  //         IO.OptionBuilder()
  //             .setTransports(['websocket']) // Use WebSocket transport
  //             .enableAutoConnect() // Enable auto-connect
  //             .setQuery({
  //               'EIO': '4', // Specify Engine.IO protocol version
  //               'transport': 'websocket',
  //             })
  //             .build());

  //     // Connect to the WebSocket
  //     socket.connect();

  //     socket.onConnect((_) {
  //       DebugLogger.info('WebSocket connection established');

  //       // Subscribe to the channel
  //       final conversationId = args['conversation_id'].toString();
  //       final channelId = 'conversations.$conversationId';
  //       socket.emit('subscribe', {'event': 'subscribe', 'channel': channelId});
  //       DebugLogger.info('Subscribed to channel: $channelId');
  //     });

  //     // Listen for incoming messages
  //     socket.on('message', (data) {
  //       DebugLogger.info('Received message: $data');
  //     });

  //     // Handle connection errors
  //     socket.onConnectError((error) {
  //       DebugLogger.error('WebSocket connection error: $error');
  //     });

  //     socket.onDisconnect((_) {
  //       DebugLogger.info('WebSocket connection closed');
  //     });
  //   } catch (error) {
  //     DebugLogger.error('Error connecting to WebSocket: $error');
  //   }
  // }

  // Function to convert API messages to types.Message
  List<types.Message> _convertMessages(List<dynamic> apiMessages) {
    return apiMessages
        .map((message) {
          final user = types.User(
            id: message['user']['id'].toString(),
            firstName: message['user']['name'],
            imageUrl: message['user']['user_image'],
          );

          if (message['type'] == 'text') {
            final text = message['content'];
            // Check if message starts with any valid Baakhapaa URL pattern
            final isValidBaakhapaaUrl = validPaths.any((path) {
              final pattern = path == 'redeem gift'
                  ? 'Baakhapaa Redeem Gift ${Url.deepLink('/gift/')}'
                  : 'Baakhapaa ${path.capitalize()} ${Url.deepLink('/$path/')}';
              return text.startsWith(pattern);
            });
            // Use isValidBaakhapaaUrl to set metadata
            final Map<String, dynamic>? metadata =
                isValidBaakhapaaUrl ? {'clickable': true} : null;

            return types.TextMessage(
              author: user,
              createdAt: DateTime.parse(
                message['created_at'],
              ).millisecondsSinceEpoch,
              id: message['id'].toString(),
              text: text,
              metadata: metadata,
            );
          } else if (message['type'] == 'image') {
            return types.ImageMessage(
              author: user,
              createdAt: DateTime.parse(
                message['created_at'],
              ).millisecondsSinceEpoch,
              id: message['id'].toString(),
              name: randomString(),
              uri: message['media_url'],
              size: 100,
            );
          }

          // Fallback to a generic message if needed
          return types.TextMessage(
            author: user,
            createdAt: DateTime.parse(
              message['created_at'],
            ).millisecondsSinceEpoch,
            id: message['id'].toString(),
            text: "Unsupported message type",
          );
        })
        .toList()
        .reversed
        .toList();
  }

  // For the testing purposes, you should probably use https://pub.dev/packages/uuid.
  String randomString() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );

    var authProvider = Provider.of<Auth>(context, listen: false);

    authProvider
        .sendMessages(
      args['conversation_id'] as int,
      message.text,
      'text',
      null,
      null,
    )
        .then((_) {
      _addMessage(textMessage);
    }).catchError((error) {
      // Show user-friendly error message
      if (mounted) {
        String errorMessage = 'Failed to send message. Please try again.';

        if (error is Exception) {
          final errorString = error.toString();
          if (errorString.contains('Exception:')) {
            errorMessage = errorString.replaceFirst('Exception:', '').trim();
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleSendPressed(message),
            ),
          ),
        );
      }

      // Log the error for debugging
      DebugLogger.info('❌ Error sending message: $error');
    });
  }

  void _handleImageSelection() async {
    try {
      final result = await ImagePicker().pickImage(
        imageQuality: 70,
        maxWidth: 1440,
        source: ImageSource.gallery,
      );

      if (result != null) {
        // Check the file size in bytes
        final fileSize = await result.length();

        // Convert bytes to megabytes (1 MB = 1,048,576 bytes)
        const maxFileSizeInBytes = 2 * 1024 * 1024; // 2 MB in bytes

        if (fileSize > maxFileSizeInBytes) {
          // Reject the image if it's larger than 2 MB
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Image size exceeds 2 MB. Please select a smaller image.',
              ),
            ),
          );
          return;
        }

        // Display image in the chat immediately
        final bytes = await result.readAsBytes();
        final image = await decodeImageFromList(bytes);

        // Create a temporary message for the chat UI
        final message = types.ImageMessage(
          author: _user,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          height: image.height.toDouble(),
          id: randomString(),
          name: result.name,
          size: bytes.length,
          uri: result.path, // This is the local path for display
          width: image.width.toDouble(),
        );

        // Add the message to the chat
        _addMessage(message);

        // Convert the image file into a File object
        final imageFile = File(result.path);

        var authProvider = Provider.of<Auth>(context, listen: false);

        // Send the image to the server using your sendMessages function
        await authProvider.sendMessages(
          args['conversation_id'] as int,
          '',
          'image',
          null,
          imageFile,
        );
      }
    } catch (error) {
      // Handle any errors that occur during image picking or sending
      DebugLogger.error('Image selection/upload failed: $error');

      if (mounted) {
        String errorMessage = 'Failed to send image. Please try again.';

        if (error is Exception) {
          final errorString = error.toString();
          if (errorString.contains('Exception:')) {
            errorMessage = errorString.replaceFirst('Exception:', '').trim();
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }

  Widget _bubbleBuilder(
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) {
    if (message is types.TextMessage) {
      // Check if message starts with any valid Baakhapaa URL pattern
      final isValidBaakhapaaUrl = validPaths.any((path) {
        final pattern = path == 'redeem gift'
            ? 'Baakhapaa Redeem Gift ${Url.deepLink('/gift/')}'
            : 'Baakhapaa ${path.capitalize()} ${Url.deepLink('/$path/')}';
        return message.text.startsWith(pattern);
      });

      if (isValidBaakhapaaUrl) {
        return MessagesBubble(
          message: message,
          currentUser: _user,
          nextMessageInGroup: nextMessageInGroup,
        );
      }
    }

    // Default bubble for other messages
    return Bubble(
      child: child,
      color: _user.id != message.author.id ||
              message.type == types.MessageType.image
          ? const Color(0xfff5f5f7)
          : const Color(0xff6f61e8),
      margin: nextMessageInGroup
          ? const BubbleEdges.symmetric(horizontal: 6)
          : null,
      nip: nextMessageInGroup
          ? BubbleNip.no
          : _user.id != message.author.id
              ? BubbleNip.leftBottom
              : BubbleNip.rightBottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildModernAppBar(),
      body: _isLoading
          ? Loading()
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E1E1E)
                        : Colors.grey.shade50,
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.black87
                        : Colors.white,
                  ],
                ),
              ),
              child: Chat(
                key: _chatKey,
                messages: _messages,
                onSendPressed: _handleSendPressed,
                user: _user,
                onAttachmentPressed: _handleImageSelection,
                onPreviewDataFetched: _handlePreviewDataFetched,
                bubbleBuilder: _bubbleBuilder,
                showUserAvatars: true,
                showUserNames: true,
                theme: _buildModernChatTheme(),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(80),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF2A2A2A)
                  : Colors.white,
              Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF1E1E1E)
                  : Colors.grey.shade50,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Back button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios, color: Colors.amber),
                  ),
                ),
                SizedBox(width: 12),

                // User avatar
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.amber, Colors.orange],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        args['user_name'] ?? 'Chat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Active now', // You can make this dynamic based on user status
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Add video call functionality here if needed
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Video call feature coming soon!'),
                        ),
                      );
                    },
                    icon: Icon(Icons.videocam, color: Colors.amber),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Add voice call functionality here if needed
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Voice call feature coming soon!'),
                        ),
                      );
                    },
                    icon: Icon(Icons.call, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DefaultChatTheme _buildModernChatTheme() {
    return DefaultChatTheme(
      inputBackgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF2A2A2A)
          : Colors.white,
      inputTextColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87,
      inputTextStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87,
        fontSize: 16,
      ),
      sendButtonIcon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.amber, Colors.orange],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(Icons.send, color: Colors.white, size: 18),
      ),
      primaryColor: Colors.amber,
      secondaryColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF2A2A2A)
          : Colors.grey.shade100,
      backgroundColor: Colors.transparent,
      inputBorderRadius: const BorderRadius.all(Radius.circular(24)),
      messageInsetsHorizontal: 12,
      messageInsetsVertical: 8,
      inputTextDecoration: InputDecoration(
        hintText: 'Type a message...',
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.amber, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 20,
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
      ),
      inputElevation: 2.0,
      inputMargin: EdgeInsets.all(16),
      inputPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      attachmentButtonIcon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.attach_file, color: Colors.grey[600], size: 20),
      ),
    );
  }
}

import 'package:baakhapaa/screens/messages/messages_screen.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:bubble/bubble.dart';
import 'package:provider/provider.dart';
import '../../providers/auth.dart';
import '../../providers/chatbot_provider.dart';

class ChatbotScreen extends StatefulWidget {
  static const routeName = '/chatbot-screen';

  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with PuppetInteractionMixin {
  List<types.Message> _messages = [];
  late types.User _user;
  late types.User _bot;
  bool _isLoading = false;
  final GlobalKey<ChatState> _chatKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeUsers();
    _addWelcomeMessage();
  }

  void _initializeUsers() {
    final auth = Provider.of<Auth>(context, listen: false);
    _user = types.User(
      id: auth.userId.toString(),
      firstName: auth.username,
    );

    _bot = const types.User(
      id: 'baakhapaa_bot',
      firstName: 'Baakhapaa Assistant',
      imageUrl: 'https://baakhapaa.com/assets/img/logo/logo3.png',
    );
  }

  void _addWelcomeMessage() {
    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);
    final welcomeMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: chatbotProvider.getWelcomeMessage(),
    );

    setState(() {
      _messages.insert(0, welcomeMessage);
    });
  } // Modern bubble builder with proper text contrast

  Widget _bubbleBuilder(
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) {
    final isUserMessage = _user.id == message.author.id;

    // Override text style for better readability
    Widget styledChild = child;
    if (child is Text && !isUserMessage) {
      // Bot messages need better text color
      styledChild = DefaultTextStyle(
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white // White text in dark mode
              : Colors.black87, // Dark text in light mode
          fontSize: 16,
          height: 1.4,
        ),
        child: child,
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: nextMessageInGroup ? 2 : 8,
      ),
      child: Bubble(
        child: styledChild,
        color: isUserMessage
            ? Colors.purple // User messages in purple
            : Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A) // Bot messages in dark mode
                : Color(0xfff5f5f7), // Bot messages in light mode
        margin: nextMessageInGroup
            ? const BubbleEdges.symmetric(horizontal: 6)
            : null,
        nip: nextMessageInGroup
            ? BubbleNip.no
            : isUserMessage
                ? BubbleNip.rightBottom
                : BubbleNip.leftBottom,
        elevation: 2,
        shadowColor: Colors.grey.withValues(alpha: 0.2),
      ),
    );
  }

  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message.text,
    );

    setState(() {
      _messages.insert(0, textMessage);
      _isLoading = true;
    });

    // Check if user is asking for human support
    if (_isHumanSupportRequest(message.text)) {
      _handleSupportCenter();
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Get bot response
    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);
    final response = await chatbotProvider.getBotResponse(message.text);

    final botMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: response,
    );

    setState(() {
      _messages.insert(0, botMessage);
      _isLoading = false;
    });

    // Check if we should add a human support button after bot response
    if (chatbotProvider.shouldOfferHumanSupport()) {
      _addHumanSupportButton();
    }
  }

  bool _isHumanSupportRequest(String message) {
    final supportKeywords = [
      'human support',
      'contact support',
      'support team',
      'talk to human',
      'speak to person',
      'customer service',
      'live chat',
      'real person'
    ];
    final lowercaseMessage = message.toLowerCase();
    return supportKeywords.any((keyword) => lowercaseMessage.contains(keyword));
  }

  void _handleSupportCenter() {
    final _authProvider = Provider.of<Auth>(context, listen: false);
    List<int> userIds = [
      _authProvider.userId,
      37,
    ];

    _authProvider.startConversations(userIds).then((_) {
      Navigator.of(context).pushNamed(
        MessagesScreen.routeName,
        arguments: {
          'conversation_id': _authProvider.selectedConversationId,
          'user_name': 'Baakhapaa Support',
        },
      );
    }).catchError((error) {
      // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to support. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _addHumanSupportButton() {
    final supportMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: 'support_button_${DateTime.now().millisecondsSinceEpoch}',
      text: '''🤝 **Need More Personalized Help?**

I've done my best to assist you! For complex issues or personalized support, our amazing human support team is ready to help.

💬 **Our Support Team Offers:**
• Detailed troubleshooting
• Account-specific assistance  
• Advanced feature guidance
• Priority issue resolution

🚀 **Get Connected:** Type "human support" or use the support button in the header to start chatting with our team right away!

*Average response time: Under 2 minutes during business hours*''',
    );

    setState(() {
      _messages.insert(0, supportMessage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildModernAppBar(),
      body: Container(
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
        child: Stack(
          children: [
            Chat(
              key: _chatKey,
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _user,
              bubbleBuilder: _bubbleBuilder,
              showUserAvatars: true,
              showUserNames: true,
              theme: _buildModernChatTheme(),
            ),
            // Modern typing indicator
            if (_isLoading && _messages.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Assistant is thinking...',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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

                // Bot avatar
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.purple, Colors.purple.shade300],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),

                // Bot info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Baakhapaa Assistant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Always online',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Support button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _handleSupportCenter,
                    icon: Icon(Icons.support_agent, color: Colors.amber),
                    tooltip: 'Contact Human Support',
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
      // Enhanced text styles for better readability
      receivedMessageBodyTextStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white // White text for bot messages in dark mode
            : Colors.black87, // Dark text for bot messages in light mode
        fontSize: 16,
        height: 1.4,
      ),
      sentMessageBodyTextStyle: TextStyle(
        color: Colors.white, // White text for user messages (purple background)
        fontSize: 16,
        height: 1.4,
      ),
      receivedMessageLinkTitleTextStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.blue.shade300
            : Colors.blue.shade700,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      sentMessageLinkTitleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      sendButtonIcon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple, Colors.purple.shade300],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.send,
          color: Colors.white,
          size: 18,
        ),
      ),
      primaryColor: Colors.purple,
      secondaryColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF2A2A2A)
          : Colors.grey.shade100,
      backgroundColor: Colors.transparent,
      inputBorderRadius: const BorderRadius.all(Radius.circular(24)),
      messageInsetsHorizontal: 12,
      messageInsetsVertical: 8,
      inputTextDecoration: InputDecoration(
        hintText: 'Ask me anything about Baakhapaa...',
        hintStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 16,
        ),
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
          borderSide: BorderSide(
            color: Colors.purple,
            width: 2,
          ),
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
    );
  }
}

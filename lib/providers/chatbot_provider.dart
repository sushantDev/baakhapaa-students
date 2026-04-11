import 'package:flutter/foundation.dart';

class ChatbotProvider extends ChangeNotifier {
  final Map<String, List<String>> _appContent = {
    'navigation': [
      'The app has several main sections:',
      '• 🏠 Home - View stories and episodes',
      '• 🎬 Shorts - Watch and create short videos',
      '• 🛍️ Shop - Browse and purchase products',
      '• 👤 Profile - Manage your account',
      '• 💬 Messages - Chat with other users',
      '• 🏆 Leaderboard - See top users',
    ],
    'points': [
      'Baakhapaa Points System:',
      '• Earn points by watching stories and episodes',
      '• Complete quizzes to get bonus points',
      '• Refer friends to earn 20 points each',
      '• Use points to purchase products in the shop',
      '• Support creators by donating points',
      '• Watch ads to earn points',
      '• Post content as a creator',
      '• Participate in challenges',
    ],
    'points_earning': [
      'How to earn points inside the app:',
      '• 📺 Watch stories/episodes and answer quiz questions',
      '• 🎬 Watch shorts and play quiz',
      '• 👥 Use referral codes (both referrer and referee get points)',
      '• 🎯 Post videos as a creator and engage players',
      '• 🏆 Participate in various Baakhapaa challenges',
      '• 📱 Watch ads',
      '',
      '💡 Note: For referral points, the referred person must earn their first 25 points for both parties to receive points.',
    ],
    'points_conversion': [
      'Convert Points to Cash:',
      '• You must achieve the "Point Conversion Badge" first',
      '• After getting the conversion badge, withdraw from Baakhapaa wallet',
      '• Complete all required tasks for the specific achievement',
      '',
      '💰 The point conversion feature requires specific achievements to unlock.',
    ],
    'stories': [
      'Stories & Episodes:',
      '• Watch engaging video content',
      '• Answer quiz questions to earn points',
      '• Comment on episodes (costs points)',
      '• Support creators with donations',
      '• Track your progress and achievements',
      '• Unlock locked seasons with points or achievements',
      '',
      '🏆 You\'ll be rewarded for answering all quiz questions correctly!',
    ],
    'shop': [
      'Shop Features:',
      '• Browse products using your earned points',
      '• Add items to cart',
      '• Place orders with delivery info',
      '• View order history',
      '• Share products with friends',
      '• Use achievement badges as discount vouchers',
      '',
      '📅 Purchased products/gifts are distributed every Monday.',
      '💡 Need sufficient points to redeem products.',
    ],
    'shorts': [
      'Shorts Features:',
      '• Watch short video content',
      '• Create your own shorts (creator role required)',
      '• Participate in challenges',
      '• Answer quiz questions',
      '• Like and share content',
      '',
      '🎬 If your video isn\'t showing, check: format/size, internet connection, app version, or try re-uploading.',
    ],
    'creator': [
      'Become a Creator:',
      '• Click the + icon at the bottom',
      '• Requirements: Minimum 10 Baakhapaa points',
      '• Watch and complete required episodes',
      '• Submit creator request',
      '• Create stories and shorts',
      '• Earn from user donations',
      '• Earn from challenges participation',
      '• Access creator tools and portal',
    ],
    'creator_posting': [
      'How to Post Content as Creator:',
      '• Must be a creator first',
      '• Click the 3-line icon at bottom middle',
      '• Choose "Create Shorts" for short videos',
      '• Use "Creator Portal" for long/short format videos',
      '• Log into creator portal first',
      '• Post directly from create shorts section',
      '',
      '🎯 Engage players to watch and answer your quiz questions to earn points!',
    ],
    'challenges': [
      'Baakhapaa Challenges:',
      '• Script writing challenges',
      '• Film making challenges',
      '• Reels challenges',
      '• Find available challenges in the home section',
      '• Participate in showcased challenges',
      '• Earn points by participating',
      '',
      '🏆 Various challenge types are regularly organized!',
    ],
    'referral': [
      'Referral System:',
      '• Click user icon (bottom right)',
      '• Find "Referral Code" option',
      '• Create your own referral code',
      '• Share with friends',
      '• Both parties earn points when referee earns their first 25 points',
      '',
      '💡 May also be found in settings in future updates.',
    ],
    'achievements': [
      'Achievement Badges:',
      '• Complete all required tasks for specific achievements',
      '• Use badges to unlock seasons',
      '• Redeem gifts and rewards',
      '• Get discounts on products',
      '• Point conversion badge enables cash withdrawal',
      '',
      '🏆 Each achievement has specific requirements to complete.',
    ],
    'gifts_delivery': [
      'Gift Delivery Information:',
      '• All purchased products/gifts distributed every Monday',
      '• Money refunds processed every Monday',
      '• Check if you have sufficient points for redemption',
      '• Verify item is not out of stock',
      '',
      '📅 Weekly distribution schedule ensures organized delivery.',
    ],
    'app_info': [
      'About Baakhapaa App:',
      '• Mindful, purpose-driven storytelling space',
      '• Content creation is intentional and community-driven',
      '• Rooted in emotional depth',
      '• Clear structure and guidance provided',
      '• Turn ideas into films and life experiences into stories',
      '• Community-focused platform',
      '',
      '🎬 A platform designed for meaningful content creation!',
    ],
    'updates': [
      'App Updates:',
      '• Notifications sent for new updates',
      '• Viber community announcements',
      '• Mostly bug fixes and new feature additions',
      '• Regular improvements and enhancements',
      '',
      '📱 Stay connected through notifications for latest updates!',
    ],
    'support': [
      'Human Support Available:',
      '• Get personalized help from our support team',
      '• Report technical issues',
      '• Account-specific questions',
      '• Payment and transaction support',
      '• Content moderation concerns',
      '• Episode-specific problems',
      '• Donation issues',
    ],
  };

  // Enhanced keyword patterns with FAQ content
  final Map<String, List<List<String>>> _intentPatterns = {
    'points': [
      ['earn', 'points'],
      ['get', 'points'],
      ['how', 'points'],
      ['baakhapaa', 'points'],
      ['point', 'system'],
      ['make', 'points'],
      ['collect', 'points'],
      ['gain', 'points'],
      ['points', 'work'],
      ['use', 'points'],
      ['spend', 'points'],
    ],
    'points_earning': [
      ['how', 'earn', 'inside'],
      ['earn', 'inside', 'app'],
      ['ways', 'earn'],
      ['how', 'make', 'money'],
      ['earn', 'points', 'creator'],
      ['earn', 'points', 'player'],
    ],
    'points_conversion': [
      ['convert', 'points', 'cash'],
      ['points', 'to', 'cash'],
      ['cash', 'conversion'],
      ['withdraw', 'points'],
      ['money', 'from', 'points'],
    ],
    'creator': [
      ['become', 'creator'],
      ['how', 'creator'],
      ['creator', 'role'],
      ['be', 'creator'],
      ['create', 'content'],
      ['creator', 'requirements'],
      ['apply', 'creator'],
      ['join', 'creator'],
      ['creator', 'baakhapaa'],
    ],
    'creator_posting': [
      ['post', 'content'],
      ['upload', 'video'],
      ['how', 'post'],
      ['add', 'story'],
      ['create', 'shorts'],
      ['upload', 'shorts'],
      ['post', 'video'],
    ],
    'challenges': [
      ['challenge', 'about'],
      ['participate', 'challenge'],
      ['what', 'challenge'],
      ['join', 'challenge'],
      ['challenge', 'participation'],
      ['script', 'challenge'],
      ['film', 'challenge'],
      ['reel', 'challenge'],
    ],
    'stories': [
      ['how', 'stories', 'work'],
      ['what', 'are', 'stories'],
      ['stories', 'feature'],
      ['watch', 'stories'],
      ['about', 'stories'],
      ['quiz', 'questions', 'general'],
      ['unlock', 'season'],
      ['locked', 'season'],
      ['quiz', 'reward'],
      ['stories', 'episodes', 'general'],
    ],
    'shop': [
      ['buy', 'products'],
      ['shop', 'work'],
      ['purchase', 'items'],
      ['redeem', 'rewards'],
      ['redeem', 'gifts'],
      ['discount', 'product'],
      ['can\'t', 'purchase'],
      ['can\'t', 'redeem'],
    ],
    'shorts': [
      ['watch', 'shorts'],
      ['short', 'videos'],
      ['create', 'shorts'],
      ['video', 'not', 'uploaded'],
      ['video', 'not', 'showing'],
      ['upload', 'problem'],
    ],
    'referral': [
      ['referral', 'code'],
      ['didn\'t', 'receive', 'referral'],
      ['referral', 'points'],
      ['own', 'referral'],
      ['make', 'referral'],
      ['create', 'referral'],
    ],
    'achievements': [
      ['achievement', 'badge'],
      ['use', 'badge'],
      ['not', 'getting', 'badge'],
      ['receive', 'achievement'],
      ['badge', 'discount'],
      ['achievement', 'unlock'],
    ],
    'gifts_delivery': [
      ['didn\'t', 'receive', 'gift'],
      ['haven\'t', 'received', 'gift'],
      ['money', 'not', 'refunded'],
      ['when', 'delivery'],
      ['gift', 'delivery'],
    ],
    'app_info': [
      ['about', 'app'],
      ['tell', 'about', 'app'],
      ['what', 'is', 'baakhapaa'],
      ['app', 'purpose'],
      ['help', 'use', 'app'],
    ],
    'updates': [
      ['new', 'update'],
      ['when', 'update'],
      ['update', 'about'],
      ['app', 'update'],
    ],
    'navigation': [
      ['app', 'features'],
      ['how', 'navigate'],
      ['what', 'can', 'do'],
      ['app', 'sections'],
      ['main', 'features'],
      ['how', 'use', 'app'],
      ['getting', 'started'],
    ],
    'profile': [
      ['edit', 'profile'],
      ['my', 'account'],
      ['account', 'settings'],
      ['profile', 'settings'],
      ['manage', 'account'],
    ],
  };

  // Track failed queries
  int _failedQueries = 0;
  List<String> _recentFailedQueries = [];

  // Get initial welcome message
  String getWelcomeMessage() {
    return '''Hello! 👋 I'm your Baakhapaa Assistant.

I can help you learn about:
• How to earn and use points
• App navigation and features  
• Stories, episodes, and shorts
• Shopping and products
• Becoming a creator
• Challenges and achievements
• Referral system
• Gift delivery and updates

What would you like to know about?

💡 If you need personalized help, I can connect you with our human support team!''';
  }

  Future<String> getBotResponse(String userMessage) async {
    await Future.delayed(Duration(milliseconds: 500));

    final message = userMessage.toLowerCase().trim();

    // Check for specific technical issues first - these should go to human support
    if (_isSpecificTechnicalIssue(message)) {
      return '''I understand you're experiencing a specific technical issue. 🔧

For problems like:
• Specific episodes not working
• Missing quiz questions in particular content
• Individual video playback issues
• Content-specific errors

Our human support team needs to investigate these issues directly.

**Please contact human support for immediate assistance:**

Say "human support" and I'll connect you with our technical team who can look into this specific problem right away! 

They'll be able to check the exact episode/content you mentioned and resolve the issue for you.''';
    }

    // Clean and tokenize the message
    final words = _tokenizeMessage(message);

    // Apply typo correction to words
    final correctedWords = _correctTypos(words);

    // Try to match intent using enhanced pattern matching with corrected words
    final intent = _matchIntent(correctedWords);

    if (intent != null) {
      _resetFailedQueries();
      return _appContent[intent]!.join('\n');
    }

    // Handle greetings
    if (_isGreeting(message)) {
      _resetFailedQueries();
      return '''Hello! 👋 I'm your Baakhapaa Assistant.

I can help you learn about:
• How to earn and use points
• App navigation and features  
• Stories, episodes, and shorts
• Shopping and products
• Becoming a creator
• Challenges and achievements
• Referral system
• Gift delivery and updates

What would you like to know about?

💡 If you need personalized help, I can connect you with our human support team!''';
    }

    // Handle thanks
    if (_isThanking(message)) {
      _resetFailedQueries();
      return '''You're welcome! 😊 

Feel free to ask me anything else about the Baakhapaa app. If you need more detailed help, I can connect you with our support team!''';
    }

    // Handle help requests
    if (_isAskingForHelp(message)) {
      return '''I can help you with:

🎯 **Points & Rewards**
"How to earn points", "Convert points to cash"

📱 **App Features** 
"App navigation", "What can I do"

🎬 **Content**
"Stories", "Shorts", "How to post content"

🛍️ **Shopping**
"Shop", "Redeem rewards", "Gift delivery"

👤 **Account**
"Profile", "Become creator", "Referral code"

🏆 **Challenges & Achievements**
"Challenges", "Achievement badges"

💬 **Need More Help?**
Say "human support" to chat with our team!

Just ask me about any of these topics!''';
    }

    // Check for support-related keywords
    if (_isSupportRequest(message)) {
      return _appContent['support']!.join('\n');
    }

    // Try fuzzy matching for common variations with original and corrected words
    final fuzzyIntent = _fuzzyMatchIntent(correctedWords, message);
    if (fuzzyIntent != null) {
      _resetFailedQueries();
      return _appContent[fuzzyIntent]!.join('\n');
    }

    // Try typo-tolerant matching before giving up
    final typoIntent = _matchWithTypoTolerance(words, message);
    if (typoIntent != null) {
      _resetFailedQueries();
      return _appContent[typoIntent]!.join('\n');
    }

    // Increment failed queries
    _failedQueries++;
    _recentFailedQueries.add(userMessage);
    if (_recentFailedQueries.length > 3) {
      _recentFailedQueries.removeAt(0);
    }

    // Offer suggestions based on partial matches
    final suggestions = _getSuggestions(correctedWords);

    if (_failedQueries >= 2) {
      return '''I'm having trouble understanding your question. 🤔

${suggestions.isNotEmpty ? 'Did you mean:\n${suggestions.join('\n')}\n\n' : ''}It seems like you might need more specific help than I can provide. Our human support team would be better equipped to assist you.

**Would you like to chat with our human support team?**

Just say "human support" and I'll help you connect with them for personalized assistance!''';
    }

    return '''I'm not sure about that specific question. 🤔

${suggestions.isNotEmpty ? 'Did you mean:\n${suggestions.join('\n')}\n\n' : ''}Here are some things I can help with:
• "How to earn points"
• "How to become a creator"
• "What are challenges about"
• "How to redeem rewards"
• "App features and navigation"

💡 **Need personalized help?** Say "human support" to chat with our team!''';
  }

  bool _isSpecificTechnicalIssue(String message) {
    // Patterns that indicate specific technical problems
    final technicalIssuePatterns = [
      // Specific episode/content issues
      RegExp(r'episode .+ (not working|does not work|is not working|broken)',
          caseSensitive: false),
      RegExp(
          r'the .+ episode (not working|does not work|is not working|broken)',
          caseSensitive: false),
      RegExp(r'.+ episode (not working|does not work|is not working|broken)',
          caseSensitive: false),

      // Missing quiz issues
      RegExp(
          r'episode .+ (no quiz|does not have quiz|missing quiz|quiz missing)',
          caseSensitive: false),
      RegExp(
          r'the .+ episode (no quiz|does not have quiz|missing quiz|quiz missing)',
          caseSensitive: false),
      RegExp(
          r'.+ episode (no quiz|does not have quiz|missing quiz|quiz missing)',
          caseSensitive: false),
      RegExp(r'quiz (not showing|missing|not there) in .+',
          caseSensitive: false),

      // Specific video/content issues
      RegExp(r'video .+ (not working|not playing|broken)',
          caseSensitive: false),
      RegExp(r'story .+ (not working|not playing|broken)',
          caseSensitive: false),
      RegExp(r'short .+ (not working|not playing|broken)',
          caseSensitive: false),

      // Named content issues (like "The Walking Dead")
      RegExp(
          r'"[^"]+" (not working|does not work|is not working|broken|no quiz|missing quiz)',
          caseSensitive: false),
      RegExp(
          r"'[^']+' (not working|does not work|is not working|broken|no quiz|missing quiz)",
          caseSensitive: false),

      // Other specific issues
      RegExp(r'specific .+ (not working|broken|missing)', caseSensitive: false),
      RegExp(r'particular .+ (not working|broken|missing)',
          caseSensitive: false),
      RegExp(r'this .+ (not working|broken|missing)', caseSensitive: false),
    ];

    // Check if message matches any technical issue pattern
    for (RegExp pattern in technicalIssuePatterns) {
      if (pattern.hasMatch(message)) {
        return true;
      }
    }

    // Additional keyword-based detection
    final hasSpecificName = _mentionsSpecificContent(message);
    final hasTechnicalIssue = _containsTechnicalKeywords(message);

    return hasSpecificName && hasTechnicalIssue;
  }

  List<String> _correctTypos(List<String> words) {
    final typoCorrections = {
      // Common point-related typos
      'pointd': 'points',
      'poitns': 'points',
      'ponts': 'points',
      'pints': 'points',
      'pointss': 'points',
      'point': 'points',

      // Creator-related typos
      'creater': 'creator',
      'craetor': 'creator',
      'createor': 'creator',
      'cretor': 'creator',

      // Shop-related typos
      'shpo': 'shop',
      'shopp': 'shop',
      'sohp': 'shop',

      // Episode-related typos
      'episod': 'episode',
      'epsiode': 'episode',
      'eposide': 'episode',
      'episods': 'episodes',

      // Story-related typos
      'strory': 'story',
      'storis': 'stories',
      'storie': 'story',

      // Challenge-related typos
      'challange': 'challenge',
      'chalenage': 'challenge',
      'challengs': 'challenges',

      // Referral-related typos
      'referal': 'referral',
      'refferal': 'referral',
      'referel': 'referral',

      // Common action typos
      'earnig': 'earning',
      'earrn': 'earn',
      'eran': 'earn',
      'becoe': 'become',
      'becom': 'become',
      'recieve': 'receive',
      'recive': 'receive',

      // App-related typos
      'baakhapa': 'baakhapaa',
      'bakhaapa': 'baakhapaa',
      'bakhapa': 'baakhapaa',
    };

    return words.map((word) {
      return typoCorrections[word] ?? word;
    }).toList();
  }

  // Add fuzzy matching with edit distance
  String? _matchWithTypoTolerance(
      List<String> originalWords, String originalMessage) {
    final keywordMap = {
      'points': ['points', 'point', 'coin', 'coins', 'credit', 'credits'],
      'creator': ['creator', 'create', 'maker', 'content'],
      'shop': ['shop', 'store', 'buy', 'purchase'],
      'stories': ['story', 'stories', 'episode', 'episodes', 'video'],
      'shorts': ['short', 'shorts', 'reel', 'reels'],
      'challenges': ['challenge', 'challenges', 'contest', 'competition'],
      'referral': ['referral', 'refer', 'code', 'invite'],
      'achievements': ['achievement', 'achievements', 'badge', 'badges'],
      'navigation': ['navigate', 'navigation', 'feature', 'features'],
    };

    // Check each word against keywords with edit distance tolerance
    for (String word in originalWords) {
      for (String intent in keywordMap.keys) {
        for (String keyword in keywordMap[intent]!) {
          if (_calculateEditDistance(word, keyword) <= 2 && word.length >= 3) {
            return intent;
          }
        }
      }
    }

    return null;
  }

  // Calculate edit distance (Levenshtein distance)
  int _calculateEditDistance(String s1, String s2) {
    if (s1.length < s2.length) {
      return _calculateEditDistance(s2, s1);
    }

    if (s2.isEmpty) {
      return s1.length;
    }

    List<int> previousRow = List.generate(s2.length + 1, (i) => i);

    for (int i = 0; i < s1.length; i++) {
      List<int> currentRow = [i + 1];

      for (int j = 0; j < s2.length; j++) {
        int insertions = previousRow[j + 1] + 1;
        int deletions = currentRow[j] + 1;
        int substitutions = previousRow[j] + (s1[i] != s2[j] ? 1 : 0);

        currentRow.add([insertions, deletions, substitutions]
            .reduce((a, b) => a < b ? a : b));
      }

      previousRow = currentRow;
    }

    return previousRow.last;
  }

  // Enhanced fuzzy matching
  String? _fuzzyMatchIntent(List<String> words, String originalMessage) {
    final synonyms = {
      'creator': ['content maker', 'video maker', 'youtuber', 'influencer'],
      'points': ['coins', 'credits', 'rewards', 'currency'],
      'stories': ['videos', 'content', 'episodes', 'shows'],
      'shop': ['store', 'market', 'buy', 'purchase'],
      'profile': ['account', 'user'],
      'challenges': ['contest', 'competition', 'event'],
      'gifts_delivery': ['gift', 'product', 'delivery', 'distribution'],
      'achievements': ['badges', 'rewards', 'accomplishments'],
    };

    for (String intent in synonyms.keys) {
      for (String synonym in synonyms[intent]!) {
        if (originalMessage.contains(synonym)) {
          return intent;
        }
      }
    }

    // Check for partial word matches with better tolerance
    for (String intent in _intentPatterns.keys) {
      String intentPrefix = intent.substring(0, intent.length.clamp(0, 4));
      for (String word in words) {
        if (word.length >= 3) {
          // Check if word starts with intent prefix or has small edit distance
          if (word.startsWith(intentPrefix) ||
              _calculateEditDistance(word, intent) <= 2) {
            return intent;
          }
        }
      }
    }

    return null;
  }

  // Enhanced suggestions with typo tolerance
  List<String> _getSuggestions(List<String> words) {
    final suggestions = <String>[];

    // Use typo-tolerant matching for suggestions
    for (String word in words) {
      if (_isTypoOfWord(word, ['point', 'points', 'earn', 'coin'])) {
        suggestions.add('• "How to earn points"');
        break;
      }
    }

    for (String word in words) {
      if (_isTypoOfWord(word, ['creat', 'creator', 'make', 'upload'])) {
        suggestions.add('• "How to become a creator"');
        break;
      }
    }

    for (String word in words) {
      if (_isTypoOfWord(word, ['challeng', 'contest', 'competition'])) {
        suggestions.add('• "What are challenges about"');
        break;
      }
    }

    for (String word in words) {
      if (_isTypoOfWord(word, ['gift', 'deliver', 'receive'])) {
        suggestions.add('• "Gift delivery information"');
        break;
      }
    }

    for (String word in words) {
      if (_isTypoOfWord(word, ['refer', 'code', 'invite'])) {
        suggestions.add('• "How to get referral code"');
        break;
      }
    }

    for (String word in words) {
      if (_isTypoOfWord(word, ['badge', 'achieve', 'reward'])) {
        suggestions.add('• "How to use achievement badges"');
        break;
      }
    }

    for (String word in words) {
      if (_isTypoOfWord(word, ['shop', 'buy', 'redeem', 'purchase'])) {
        suggestions.add('• "How to redeem rewards"');
        break;
      }
    }

    return suggestions.toSet().toList(); // Remove duplicates
  }

  // Helper method to check if a word is a typo of target words
  bool _isTypoOfWord(String word, List<String> targetWords) {
    if (word.length < 3) return false;

    for (String target in targetWords) {
      if (word.contains(target.substring(0, target.length.clamp(0, 3))) ||
          _calculateEditDistance(word, target) <= 2) {
        return true;
      }
    }
    return false;
  }

  bool _containsTechnicalKeywords(String message) {
    final technicalKeywords = [
      'not working',
      'doesn\'t work',
      'does not work',
      'isn\'t working',
      'is not working',
      'won\'t play',
      'will not play',
      'won\'t work',
      'will not work',
      'not playing',
      'not showing',
      'not loading',
      'video not playing',
      'video not showing',
      'video not loading',
      'video not working',
      'episode not playing',
      'episode not showing',
      'episode not loading',
      'episode not working',
      'short not playing',
      'short not showing',
      'short not loading',
      'short not working',
      'content not playing',
      'content not showing',
      'content not loading',
      'content not working',
      'broken',
      'no quiz',
      'doesn\'t have quiz',
      'does not have quiz',
      'missing quiz',
      'quiz missing',
      'error',
      'can\'t watch',
      'cannot watch',
      'stuck',
      'frozen'
    ];

    return technicalKeywords.any((keyword) => message.contains(keyword));
  }

  String? _matchIntent(List<String> words) {
    int bestMatchScore = 0;
    String? bestIntent;

    for (String intent in _intentPatterns.keys) {
      for (List<String> pattern in _intentPatterns[intent]!) {
        int score = _calculatePatternScore(words, pattern);
        if (score > bestMatchScore && score >= pattern.length) {
          bestMatchScore = score;
          bestIntent = intent;
        }
      }
    }

    return bestIntent;
  }

  List<String> _tokenizeMessage(String message) {
    final cleaned = message.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase())
        .toList();
  }

  int _calculatePatternScore(List<String> words, List<String> pattern) {
    int score = 0;
    for (String patternWord in pattern) {
      if (words.contains(patternWord)) {
        score++;
      }
    }
    return score;
  }

  void _resetFailedQueries() {
    _failedQueries = 0;
    _recentFailedQueries.clear();
  }

  bool _isGreeting(String message) {
    final greetings = [
      'hello',
      'hi',
      'hey',
      'good morning',
      'good afternoon',
      'good evening'
    ];
    return greetings.any((greeting) => message.contains(greeting));
  }

  bool _isThanking(String message) {
    final thanks = ['thank', 'thanks', 'thx', 'appreciate'];
    return thanks.any((thank) => message.contains(thank));
  }

  bool _isAskingForHelp(String message) {
    final helpWords = [
      'help',
      'assist',
      'guide',
      'what can you do',
      'commands'
    ];
    return helpWords.any((word) => message.contains(word));
  }

  bool _isSupportRequest(String message) {
    final supportWords = [
      'human support',
      'contact support',
      'support team',
      'talk to human',
      'speak to person',
      'customer service',
      'live chat',
      'real person'
    ];
    return supportWords.any((word) => message.contains(word));
  }

  bool shouldOfferHumanSupport() {
    return _failedQueries >= 2;
  }

  List<String> getRecentFailedQueries() {
    return List.from(_recentFailedQueries);
  }

  // Helper method to detect if message mentions specific content
  bool _mentionsSpecificContent(String message) {
    // Check for quoted content
    if (message.contains('"') || message.contains("'")) {
      return true;
    }

    // Check for capitalized phrases (likely titles)
    final capitalizedPattern = RegExp(r'[A-Z][a-z]+ [A-Z][a-z]+');
    if (capitalizedPattern.hasMatch(message)) {
      return true;
    }

    // Check for specific episode/content indicators
    // ignore: deprecated_member_use
    final specificIndicators = [
      RegExp(r'episode \d+', caseSensitive: false),
      RegExp(r'season \d+', caseSensitive: false),
      RegExp(r'chapter \d+', caseSensitive: false),
      RegExp(r'part \d+', caseSensitive: false),
      RegExp(r'the .+ episode', caseSensitive: false),
      RegExp(r'this episode', caseSensitive: false),
      RegExp(r'that episode', caseSensitive: false),
      RegExp(r'this video', caseSensitive: false),
      RegExp(r'that video', caseSensitive: false),
      RegExp(r'this story', caseSensitive: false),
      RegExp(r'that story', caseSensitive: false),
    ];

    return specificIndicators.any((pattern) => pattern.hasMatch(message));
  }
}

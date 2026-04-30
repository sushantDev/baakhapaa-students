import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/header.dart';
import '../../providers/auth.dart';
import '../../widgets/loading.dart';
import '../../models/url.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';

class ReferralsScreen extends StatefulWidget {
  static const routeName = '/referrals-screen';
  const ReferralsScreen({Key? key}) : super(key: key);

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen>
    with PuppetInteractionMixin {
  var _isInit = false;
  var _isLoadingReferredUsers = false;
  List<Map<String, dynamic>> _referredUsers = [];
  Map<String, dynamic> _pagination = {};
  Map<String, dynamic> _summary = {};
  int _currentPage = 1;
  bool _hasMorePages = false;
  final referralController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _errorMessage = '';
  bool _isSubmittingReferral = false;

  @override
  void initState() {
    super.initState();

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    referralController.dispose();
    _scrollController.dispose();

    // Clear puppet interactions when leaving screen
    clearPuppetInteractions();

    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_hasMorePages && !_isLoadingReferredUsers) {
        _fetchReferredUsers(page: _currentPage + 1);
      }
    }
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      _fetchReferredUsers();
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchReferredUsers({int page = 1}) async {
    setState(() {
      _isLoadingReferredUsers = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/referred-users/list?limit=10&page=$page')),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            if (page == 1) {
              _referredUsers = List<Map<String, dynamic>>.from(
                  data['data']['referred_users']);
            } else {
              _referredUsers.addAll(List<Map<String, dynamic>>.from(
                  data['data']['referred_users']));
            }
            _pagination = data['data']['pagination'];
            _summary = data['data']['summary'];
            _currentPage = page;
            _hasMorePages = _pagination['has_more_pages'] ?? false;
          });
        }
      }
    } catch (e) {
      DebugLogger.auth('Error fetching referred users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load referred users'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingReferredUsers = false;
      });
    }
  }

  Future<void> _submitReferralCode(Auth auth) async {
    final code = referralController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a referral code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is trying to refer themselves
    if (code.toLowerCase() == auth.user['username']?.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You cannot refer yourself'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmittingReferral = true);

    try {
      await auth.checkUsername(code);
      if (!auth.usernameExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid referral code'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmittingReferral = false);
        return;
      }

      await auth.changeFirstLoginStatus();
      await auth.setReferCode(code);

      // Refresh user data to update hasReferral status
      await auth.getUser();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Referral code applied successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      referralController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply referral code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmittingReferral = false);
    }
  }

  Future<void> _copyReferralCode(String username) async {
    try {
      await Clipboard.setData(ClipboardData(text: username));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Referral code copied to clipboard!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy referral code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareReferralLinkOnly(String username) async {
    try {
      final appLink = 'https://baakhapaa.com/referral/$username';

      await SharePlus.instance.share(
        ShareParams(
          text: appLink,
          sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
        ),
      );
    } catch (e) {
      DebugLogger.error('Error sharing referral link: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share referral link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareReferralLink(String username) async {
    try {
      // Create referral link
      final appLink = 'https://baakhapaa.com/referral/$username';

      final shareText = '''
🎉 Join me on Skill Sikka!

Use my referral code: $username
Or click this link: $appLink

🎁 We both get 25 bonus points when you sign up!

Download the app and start earning rewards by watching videos, playing games, and much more!
      '''
          .trim();

      // Share using the share_plus plugin
      await SharePlus.instance.share(ShareParams(
        text: shareText,
        sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
      ));

      // Show success message (optional - user will see the native share dialog)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.share, color: Colors.white),
              SizedBox(width: 8),
              Text('Share dialog opened!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      DebugLogger.error('Error sharing referral: $e');

      // Fallback to clipboard on any error
      try {
        final appLink = 'https://baakhapaa.com/referral/$username';
        final shareText = '''
🎉 Join me on Skill Sikka!

Use my referral code: $username
Or click this link: $appLink

🎁 We both get 25 bonus points when you sign up!

Download the app and start earning rewards by watching videos, playing games, and much more!

#Baakhapaa #Referral #BonusPoints
        '''
            .trim();

        await Clipboard.setData(ClipboardData(text: shareText));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.content_copy, color: Colors.white),
                SizedBox(width: 8),
                Text('Referral text copied to clipboard!'),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (clipboardError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share referral link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var auth = Provider.of<Auth>(context, listen: false);
    final String _username = auth.username!;

    return Scaffold(
      appBar: header(context: context, titleText: 'Referrals'),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh referred users data
          await _fetchReferredUsers(page: 1);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            children: [
              _buildReferralCodeCard(_username),
              _buildReferralDescriptionCard(),
              _buildApplyReferralCard(auth),
              _buildReferredUsersCard(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(String username) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
                    : Colors.blue.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Icon(Icons.share, color: Colors.blue),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Referral Code',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Share this code with friends',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.blue.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _shareReferralLink(username),
                          icon: Icon(Icons.share, color: Colors.blue.shade700),
                          tooltip: 'Share referral link',
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'share_full') {
                              _shareReferralLink(username);
                            } else if (value == 'share_link') {
                              _shareReferralLinkOnly(username);
                            } else if (value == 'copy') {
                              _copyReferralCode(username);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'share_full',
                              child: Row(
                                children: [
                                  Icon(Icons.share,
                                      color: Colors.blue.shade700),
                                  SizedBox(width: 8),
                                  Text('Share full message'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share_link',
                              child: Row(
                                children: [
                                  Icon(Icons.link, color: Colors.blue.shade700),
                                  SizedBox(width: 8),
                                  Text('Share link only'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'copy',
                              child: Row(
                                children: [
                                  Icon(Icons.copy, color: Colors.blue.shade700),
                                  SizedBox(width: 8),
                                  Text('Copy referral code'),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.more_vert,
                                color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralDescriptionCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    child: Icon(Icons.card_giftcard, color: Colors.green),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎁 Referral Benefits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Share your referral code with people who could benefit from Skill Sikka.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'For every referral both users will receive 25 points each.',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyReferralCard(Auth auth) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: auth.hasReferral
              ? Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Referral Code Already Applied',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.purple.withValues(alpha: 0.1),
                          child: Icon(Icons.person_add, color: Colors.purple),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apply Referral Code',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Have a referral code from a friend?',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Error message display
                    if (_errorMessage.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Referral form - always visible
                    TextFormField(
                      controller: referralController,
                      decoration: InputDecoration(
                        labelText: 'Enter Referral Code',
                        hintText: 'Enter your friend\'s username',
                        prefixIcon: Icon(Icons.person_add),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.purple.shade600),
                        ),
                      ),
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      onChanged: (value) {
                        if (_errorMessage.isNotEmpty) {
                          setState(() {
                            _errorMessage = '';
                          });
                        }
                      },
                    ),

                    SizedBox(height: 16),

                    // Submit button
                    Container(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmittingReferral
                            ? null
                            : () => _submitReferralCode(auth),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: _isSubmittingReferral
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(Icons.check, size: 20),
                        label: Text(
                          _isSubmittingReferral
                              ? 'Applying...'
                              : 'Apply Referral Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildReferredUsersCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    child: Icon(Icons.group, color: Colors.orange),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Referred Users',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_summary.isNotEmpty)
                          Text(
                            'Total: ${_summary['total_referrals']} referrals',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _isLoadingReferredUsers && _referredUsers.isEmpty
                  ? Container(
                      height: 200,
                      child: Center(child: Loading()),
                    )
                  : Container(
                      height: 400,
                      child: _referredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No referrals yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Start sharing your referral code!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                final user = _referredUsers[index];
                                return Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Color(0xFF2A2A2A)
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // User Avatar
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: Colors.blue.shade100,
                                        child: user['user_image_url'] != null &&
                                                user['user_image_url']
                                                    .isNotEmpty
                                            ? ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl:
                                                      user['user_image_url'],
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          ClipOval(
                                                    child: CachedNetworkImage(
                                                      imageUrl:
                                                          'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg',
                                                      width: 50,
                                                      height: 50,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context,
                                                              url) =>
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl:
                                                      'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg',
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      SizedBox(width: 16),

                                      // User Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['name'] == ''
                                                  ? 'Baakhapaa User'
                                                  : user['name'],
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '@${user['username'] ?? 'unknown'}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey[500],
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  user['joined_date_human'] ??
                                                      'Recently',
                                                  style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Reward Badge
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.card_giftcard,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '+25',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              itemCount: _referredUsers.length,
                            ),
                    ),
              if (_isLoadingReferredUsers && _referredUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

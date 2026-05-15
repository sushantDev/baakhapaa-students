// ignore_for_file: unused_import

import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/footer.dart';
import 'package:baakhapaa/widgets/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PlayerProfileScreen extends StatefulWidget {
  static const routeName = '/player-profile-screen';

  const PlayerProfileScreen({Key? key}) : super(key: key);

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  bool _isLoading = true;
  String _username = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _username = args;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      await auth.fetchPlayerProfile(_username);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final data = auth.playerProfile;

    return Scaffold(
      appBar: header(context: context, titleText: '@$_username'),
      body: _isLoading
          ? Loading()
          : data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Profile Not Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Unable to load profile for @$_username',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : data.containsKey('error')
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            data['error'] == 'rate_limit'
                                ? Icons.hourglass_empty
                                : Icons.person_off,
                            size: 64,
                            color: Colors.orange[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            data['error'] == 'rate_limit'
                                ? 'Too Many Requests'
                                : 'User Not Found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              data['message'] ?? 'Please try again later',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _fetch,
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        child: Column(
                          children: [
                            _buildPlayerProfileHeader(context, data),
                            _buildPlayerStatsCard(context, data),
                            _buildActivitySection(context, data),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildPlayerProfileHeader(
      BuildContext context, Map<String, dynamic> data) {
    String imageUrl =
        'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    try {
      final images = data['images'];
      if (images is List && images.isNotEmpty) {
        imageUrl = images[0]['thumbnail'] ?? imageUrl;
      }
    } catch (_) {}

    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue, Colors.cyan],
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data['username']?.toString() ?? _username,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        _buildRoleChip(data),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      (data['name'] ?? '').toString(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInstagramStat('Rank', (data['rank'] ?? '-').toString()),
              _buildInstagramStat(
                'Points',
                ((data['information'] is Map)
                            ? data['information']['available_coins']
                            : null)
                        ?.toString() ??
                    '0',
              ),
              _buildInstagramStat(
                  'Badges', (data['badges_count'] ?? '0').toString()),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showReportUserDialog(context, data),
                  icon:
                      Icon(Icons.flag_outlined, size: 16, color: Colors.orange),
                  label: Text('Report',
                      style: TextStyle(color: Colors.orange, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBlockUserDialog(context, data),
                  icon: Icon(Icons.block, size: 16, color: Colors.red),
                  label: Text('Block',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(Map<String, dynamic> data) {
    final role = (data['role'] ?? 'player').toString();
    if (role.isEmpty) return SizedBox.shrink();

    final isCreator = role == 'creator';
    final Color color = isCreator ? Colors.purple : Colors.blue;
    final String label = isCreator ? 'Creator' : 'Player';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInstagramStat(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerStatsCard(
      BuildContext context, Map<String, dynamic> data) {
    final info = (data['information'] is Map<String, dynamic>)
        ? data['information'] as Map<String, dynamic>
        : <String, dynamic>{};

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _buildCompactStat(
              'Matches',
              (data['matches_played'] ?? '0').toString(),
              Icons.sports_esports,
              Colors.blue),
          _buildCompactStat('Wins', (data['wins'] ?? '0').toString(),
              Icons.emoji_events, Colors.green),
          _buildCompactStat('Win Rate', (data['win_rate'] ?? '0%').toString(),
              Icons.percent, Colors.purple),
          _buildCompactStat(
              'Points',
              (info['available_coins'] ?? '0').toString(),
              Icons.savings,
              Colors.orange),
        ],
      ),
    );
  }

  Widget _buildCompactStat(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(
      BuildContext context, Map<String, dynamic> data) {
    final activities = data['recent_activity'];
    final hasActivities = activities is List && activities.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF2A2A2A)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            padding: EdgeInsets.all(12),
            child: hasActivities
                ? Column(
                    children: List.generate(
                      (activities.length).clamp(0, 10),
                      (index) {
                        final e = activities[index];
                        final title = e['title']?.toString() ?? e.toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Icon(Icons.history, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No Activity Yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This player hasn\'t recorded recent activity.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showReportUserDialog(BuildContext context, Map<String, dynamic> data) {
    final int? userId = data['id'] is int
        ? data['id'] as int
        : int.tryParse(data['id']?.toString() ?? '');
    String _selectedReason = 'Spam';
    final List<String> reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Inappropriate content',
      'Impersonation',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.flag_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Report User'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you reporting @${_username}?',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                    dense: true,
                    title: Text(r, style: TextStyle(fontSize: 13)),
                    value: r,
                    groupValue: _selectedReason,
                    onChanged: (v) =>
                        setDialogState(() => _selectedReason = v!),
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final auth = Provider.of<Auth>(context, listen: false);
                  await auth.reportContent(
                    type: 'user',
                    targetId: userId ?? 0,
                    reason: _selectedReason,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Report submitted. Thank you.'),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockUserDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.block, color: Colors.red),
          SizedBox(width: 8),
          Text('Block @$_username'),
        ]),
        content: Text(
          'Blocking @$_username will:\n\n'
          '• Remove their content from your feed immediately\n'
          '• Prevent them from seeing your profile\n'
          '• Notify our team to review this account\n\n'
          'You can unblock them later from your privacy settings.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final auth = Provider.of<Auth>(context, listen: false);
                await auth.blockUser(_username);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('@$_username has been blocked.'),
                    backgroundColor: Colors.green,
                  ));
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: Text('Block User'),
          ),
        ],
      ),
    );
  }
}

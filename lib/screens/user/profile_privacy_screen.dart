// import 'package:baakhapaa/helpers/helpers.dart';
// import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/debug_logger.dart';

class ProfilePrivacyScreen extends StatefulWidget {
  static const routeName = '/profile-privacy-screen';

  const ProfilePrivacyScreen({Key? key}) : super(key: key);

  @override
  State<ProfilePrivacyScreen> createState() => _ProfilePrivacyScreenState();
}

class _ProfilePrivacyScreenState extends State<ProfilePrivacyScreen> {
  late Map<String, bool> _visibilitySettings = {
    'likes': false,
    'view_count': false,
    'points_earned': false,
    'achievements': false,
    'challenges': false,
    'shorts': false,
    'stories': false,
    'followers': false,
  };

  bool _isSaving = false;
  // ignore: unused_field
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileVisibility();
  }

  void _fetchProfileVisibility() {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final userData = auth.user;

      if (userData.containsKey('profile_visibility') && !_isSaving) {
        final profileVisibility =
            userData['profile_visibility'] as Map<String, dynamic>;
        setState(() {
          _visibilitySettings = {
            'likes': profileVisibility['likes'] ?? false,
            'view_count': profileVisibility['view_count'] ?? false,
            'points_earned': profileVisibility['points_earned'] ?? false,
            'achievements': profileVisibility['achievements'] ?? false,
            'challenges': profileVisibility['challenges'] ?? false,
            'shorts': profileVisibility['shorts'] ?? false,
            'stories': profileVisibility['stories'] ?? false,
            'followers': profileVisibility['followers'] ?? false,
          };
          _isInitialized = true;
        });
      }
    } catch (e) {
      DebugLogger.info('Error fetching profile visibility: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final token = auth.token;

      DebugLogger.info(
          '📤 Saving profile visibility settings: $_visibilitySettings');

      // Send with profile_visibility wrapper
      final payload = {'profile_visibility': _visibilitySettings};

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/user/profile-visibility')),
        headers: Url.baakhapaaAuthHeaders(token),
        body: json.encode(payload),
      );

      DebugLogger.info('📡 Response Status: ${response.statusCode}');
      DebugLogger.info('📡 Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        DebugLogger.info('✅ Settings saved successfully');

        // Verify by fetching updated user data
        DebugLogger.info('🔄 Verifying save by fetching updated user data...');
        await auth.getUser();
        final savedData = auth.user['profile_visibility'];
        DebugLogger.info('📊 Backend returned profile_visibility: $savedData');

        // Check if backend actually saved what we sent
        bool allSaved = true;
        _visibilitySettings.forEach((key, value) {
          final backendValue = savedData[key];
          if (backendValue != value) {
            DebugLogger.info(
                '⚠️  Mismatch for $key: sent=$value, backend=$backendValue');
            allSaved = false;
          }
        });

        if (allSaved) {
          DebugLogger.info('✅ All settings verified on backend!');
        } else {
          DebugLogger.info(
              '❌ Backend did not save correctly - check API format');
        }

        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Privacy settings saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
        return;
      } else {
        DebugLogger.info('❌ API returned success: false');
        throw Exception(
            responseData['message'] ?? 'Failed to save privacy settings');
      }
    } catch (error) {
      DebugLogger.info('❌ Error saving privacy settings: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildPrivacyCard(
    String key,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: _visibilitySettings[key] ?? false,
          onChanged: (value) {
            setState(() {
              _visibilitySettings[key] = value;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(
        context: context,
        titleText: 'Profile Privacy',
      ),
      body: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Likes Visibility
                  _buildPrivacyCard(
                    'likes',
                    'Likes',
                    'Show your likes to other users',
                    Icons.favorite,
                    Colors.red,
                  ),
                  SizedBox(height: 12),

                  // Views Visibility
                  _buildPrivacyCard(
                    'view_count',
                    'Views',
                    'Show view counts on your content',
                    Icons.visibility,
                    Colors.blue,
                  ),
                  SizedBox(height: 12),

                  // Points Visibility
                  _buildPrivacyCard(
                    'points_earned',
                    'Points',
                    'Show your earned points',
                    Icons.star,
                    Colors.amber,
                  ),
                  SizedBox(height: 12),

                  // Achievements Visibility
                  _buildPrivacyCard(
                    'achievements',
                    'Achievements',
                    'Show your achievements and badges',
                    Icons.emoji_events,
                    Colors.orange,
                  ),
                  SizedBox(height: 12),

                  // Challenges Visibility
                  _buildPrivacyCard(
                    'challenges',
                    'Challenges',
                    'Show your challenge participation',
                    Icons.flag,
                    Colors.purple,
                  ),
                  SizedBox(height: 12),

                  // Shorts Visibility
                  _buildPrivacyCard(
                    'shorts',
                    'Shorts',
                    'Show your created shorts',
                    Icons.video_label,
                    Colors.green,
                  ),
                  SizedBox(height: 12),

                  // Stories Visibility
                  _buildPrivacyCard(
                    'stories',
                    'Stories',
                    'Show your created stories',
                    Icons.book,
                    Colors.indigo,
                  ),
                  SizedBox(height: 12),

                  // Followers Visibility
                  _buildPrivacyCard(
                    'followers',
                    'Followers',
                    'Show your follower count',
                    Icons.people,
                    Colors.teal,
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

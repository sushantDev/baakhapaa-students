import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

/// Handles authentication for Facebook, YouTube, and Instagram.
class SocialAuthService {
  static final SocialAuthService _instance = SocialAuthService._internal();
  factory SocialAuthService() => _instance;
  SocialAuthService._internal();

  // Facebook Auth
  // final FacebookAuth _facebookAuth = FacebookAuth.instance;

  // Google Sign-In (for YouTube)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/youtube.readonly',
      'https://www.googleapis.com/auth/youtube.force-ssl',
      'https://www.googleapis.com/auth/youtube.upload',
    ],
  );

  // Instagram Configuration - Baakhapaa-IG App
  static const String _instagramClientId = '1549951209778593';
  static const String _instagramRedirectUri =
      'https://baakhapaa.com/auth/instagram/callback';

  // Initialize service
  Future<void> initialize() async {
    // Service initialization if needed
  }

  // -----------------------------
  // 🟦 FAC+EBOOK AUTH
  // -----------------------------
//   Future<Map<String, dynamic>> loginWithFacebook() async {
//     try {
//       // Use only standard permissions that don't require app review
//       // final result =
//       //     await _facebookAuth.login(permissions: ['email', 'public_profile']);
//       // .login(permissions: ['email', 'public_profile', 'Meta oEmbed Read']);

//       // Example robust code to use after login
//       final result = await FacebookAuth.instance.login(
//         permissions: ['email', 'public_profile'],
//       );

//       debugPrint(
//           'FB login result: status=${result.status}, message=${result.message}');

//       final access = await FacebookAuth.instance.accessToken;
// // Log the whole object so you can inspect fields at runtime:
//       debugPrint(
//           'FB access object: ${access.runtimeType} ${access?.toJson() ?? access}');

// // Extract string token in a safe way (works across plugin versions)
//       String? token;
//       if (access != null) {
//         // try the common property names, then fallback to toJson map
//         token = (access as dynamic).token ?? (access as dynamic).accessToken;
//         if (token == null) {
//           try {
//             final map = (access as dynamic).toJson();
//             token = map is Map
//                 ? (map['token'] ?? map['accessToken'])?.toString()
//                 : null;
//           } catch (_) {
//             token ??= access.toString();
//           }
//         }
//       }

//       debugPrint('FB access token string: $token');

// // If token != null, fetch user data
//       if (token != null) {
//         final userData = await FacebookAuth.instance.getUserData(
//           fields: "name,email,picture.width(200)",
//         );
//         debugPrint('FB userData: $userData');
//       }

//       if (result.status == LoginStatus.success) {
//         final userData = await _facebookAuth.getUserData(
//             fields: "name,email,picture.width(200)");
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setBool('facebook_connected', true);
//         await prefs.setString('facebook_user', jsonEncode(userData));

//         log('Facebook login successful: ${userData['name']}');
//         return {
//           'success': true,
//           'user': userData,
//           'message': 'Facebook login successful'
//         };
//       } else if (result.status == LoginStatus.cancelled) {
//         return {'success': false, 'error': 'Facebook login cancelled'};
//       } else {
//         return {
//           'success': false,
//           'error': result.message ?? 'Facebook login failed'
//         };
//       }
//     } catch (e) {
//       log('Facebook login error: $e');
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   Future<void> logoutFromFacebook() async {
//     try {
//       await _facebookAuth.logOut();
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('facebook_connected');
//       await prefs.remove('facebook_user');
//       log('Facebook logout successful');
//     } catch (e) {
//       log('Facebook logout error: $e');
//     }
//   }

  Future<bool> isConnectedToFacebook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('facebook_connected') ?? false;
    } catch (e) {
      log('Error checking Facebook connection: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getFacebookUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('facebook_user');
      return data != null ? jsonDecode(data) : null;
    } catch (e) {
      log('Error getting Facebook user: $e');
      return null;
    }
  }

  // Share app invitation link on Facebook
  // Future<Map<String, dynamic>> shareAppInvitation({
  //   String? appUrl,
  //   String? message,
  // }) async {
  //   try {
  //     final bool isConnected = await isConnectedToFacebook();
  //     if (!isConnected) {
  //       return {'success': false, 'error': 'Please connect to Facebook first'};
  //     }

  //     // Default app sharing content
  //     final String defaultUrl = appUrl ??
  //         'https://play.google.com/store/apps/details?id=your.baakhapaa.app';
  //     final String defaultMessage = message ??
  //         'Join me on Skill Sikka! The amazing gaming app where you can play, compete, and win real rewards! 🎮';

  //     // Use Facebook's share dialog (no special permissions needed)
  //     final result =
  //         await _facebookAuth.login(permissions: ['email', 'public_profile']);

  //     if (result.status == LoginStatus.success) {
  //       return {
  //         'success': true,
  //         'message': 'Facebook sharing initiated',
  //         'shareUrl': defaultUrl,
  //         'shareMessage': defaultMessage,
  //       };
  //     } else {
  //       return {
  //         'success': false,
  //         'error': 'Failed to initiate Facebook sharing'
  //       };
  //     }
  //   } catch (e) {
  //     log('Facebook sharing error: $e');
  //     return {'success': false, 'error': 'Error sharing to Facebook: $e'};
  //   }
  // }

  // -----------------------------
  // 🔴 YOUTUBE AUTH (via Google)
  // -----------------------------
  Future<Map<String, dynamic>> loginWithYouTube() async {
    try {
      if (kDebugMode) {
        debugPrint('Starting YouTube/Google Sign-In...');
      }

      // Check if already signed in
      final currentUser = _googleSignIn.currentUser;
      if (currentUser != null) {
        if (kDebugMode) {
          debugPrint('User already signed in: ${currentUser.email}');
        }
        await _googleSignIn.signOut(); // Sign out to ensure fresh login
      }

      // Sign in with Google
      final account = await _googleSignIn.signIn();
      if (account == null) {
        if (kDebugMode) {
          debugPrint('YouTube login was cancelled by user');
        }
        return {'success': false, 'error': 'YouTube login was cancelled'};
      }

      if (kDebugMode) {
        debugPrint('Google Sign-In successful for: ${account.email}');
      }

      // Get authentication tokens
      final auth = await account.authentication;
      if (auth.accessToken == null) {
        if (kDebugMode) {
          debugPrint('Failed to get access token');
        }
        return {
          'success': false,
          'error': 'Failed to get authentication token'
        };
      }

      if (kDebugMode) {
        debugPrint('Authentication successful, saving user data...');
      }
      final prefs = await SharedPreferences.getInstance();

      final userData = {
        'id': account.id,
        'name': account.displayName,
        'email': account.email,
        'photoUrl': account.photoUrl,
      };

      await prefs.setBool('youtube_connected', true);
      await prefs.setString('youtube_user', jsonEncode(userData));
      await prefs.setString('youtube_token', auth.accessToken!);

      log('YouTube login successful: ${account.displayName}');
      if (kDebugMode) {
        debugPrint('YouTube login complete for: ${account.displayName}');
      }

      return {
        'success': true,
        'user': userData,
        'token': auth.accessToken,
        'message': 'YouTube login successful',
      };
    } on PlatformException catch (e) {
      final errorMessage =
          'YouTube login platform error: ${e.code} - ${e.message}';
      log(errorMessage);
      if (kDebugMode) {
        debugPrint('PlatformException during YouTube login: $e');
      }

      // Handle specific iOS errors
      if (e.code == 'sign_in_canceled') {
        return {'success': false, 'error': 'Sign-in was canceled'};
      } else if (e.code == 'network_error') {
        return {'success': false, 'error': 'Network error occurred'};
      } else if (e.code == 'sign_in_failed') {
        return {'success': false, 'error': 'Sign-in failed. Please try again.'};
      }

      return {
        'success': false,
        'error': 'YouTube login error: ${e.message}',
      };
    } catch (e) {
      final errorMessage = 'YouTube login unexpected error: $e';
      log(errorMessage);
      if (kDebugMode) {
        debugPrint('Unexpected error during YouTube login: $e');
      }
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  Future<void> logoutFromYouTube() async {
    try {
      await _googleSignIn.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('youtube_connected');
      await prefs.remove('youtube_user');
      await prefs.remove('youtube_token');
      await prefs.remove('youtube_channel');
      log('YouTube logout successful');
    } catch (e) {
      log('YouTube logout error: $e');
    }
  }

  Future<bool> isConnectedToYouTube() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('youtube_connected') ?? false;
    } catch (e) {
      log('Error checking YouTube connection: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getYouTubeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('youtube_user');
      return data != null ? jsonDecode(data) : null;
    } catch (e) {
      log('Error getting YouTube user: $e');
      return null;
    }
  }

  // YouTube channel info fetch (after login)
  Future<Map<String, dynamic>?> getYouTubeChannelInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(
            'https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&mine=true'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          final channel = data['items'][0];
          final channelInfo = {
            'id': channel['id'],
            'title': channel['snippet']['title'],
            'description': channel['snippet']['description'],
            'thumbnail': channel['snippet']['thumbnails']['default']['url'],
            'subscriberCount': channel['statistics']['subscriberCount'],
            'videoCount': channel['statistics']['videoCount'],
          };

          // Cache channel info
          await prefs.setString('youtube_channel', jsonEncode(channelInfo));
          return channelInfo;
        }
      }
    } catch (e) {
      log('Error fetching YouTube channel: $e');
    }
    return null;
  }

  // YouTube video search
  Future<List<Map<String, dynamic>>> searchYouTubeVideos(String query,
      {int maxResults = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/youtube/v3/search'
            '?part=snippet'
            '&q=${Uri.encodeComponent(query)}'
            '&type=video'
            '&maxResults=$maxResults'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['items'] != null) {
          return (data['items'] as List)
              .map<Map<String, dynamic>>((item) => {
                    'id': item['id']['videoId'],
                    'title': item['snippet']['title'],
                    'description': item['snippet']['description'],
                    'thumbnail': item['snippet']['thumbnails']['default']
                        ['url'],
                    'channelTitle': item['snippet']['channelTitle'],
                    'publishedAt': item['snippet']['publishedAt'],
                  })
              .toList();
        }
      }
    } catch (e) {
      log('Error searching YouTube videos: $e');
    }
    return [];
  }

  // YouTube playlists fetch
  Future<List<Map<String, dynamic>>> getYouTubePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/youtube/v3/playlists'
            '?part=snippet,contentDetails'
            '&mine=true'
            '&maxResults=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['items'] != null) {
          List<Map<String, dynamic>> playlists = [];

          // Add default playlists first
          playlists.addAll([
            {
              'id': 'LL', // Liked videos playlist ID
              'title': 'Liked videos',
              'itemCount': await _getLikedVideosCount(),
              'thumbnail': null,
              'isDefault': true,
              'icon': 'thumb_up',
            },
            {
              'id': 'WL', // Watch Later playlist ID
              'title': 'Watch Later',
              'itemCount': await _getWatchLaterCount(),
              'thumbnail': null,
              'isDefault': true,
              'icon': 'watch_later',
            },
          ]);

          // Add user-created playlists
          for (var item in data['items']) {
            playlists.add({
              'id': item['id'],
              'title': item['snippet']['title'],
              'description': item['snippet']['description'],
              'itemCount': item['contentDetails']['itemCount'],
              'thumbnail': item['snippet']['thumbnails']?['default']?['url'],
              'isDefault': false,
              'icon': 'queue_music',
            });
          }

          return playlists;
        }
      }
    } catch (e) {
      log('Error fetching YouTube playlists: $e');
    }
    return [];
  }

  // Get liked videos count
  Future<int> _getLikedVideosCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return 0;

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/youtube/v3/videos'
            '?part=id'
            '&myRating=like'
            '&maxResults=1'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['pageInfo']?['totalResults'] ?? 0;
      }
    } catch (e) {
      log('Error fetching liked videos count: $e');
    }
    return 0;
  }

  // Get watch later count
  Future<int> _getWatchLaterCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return 0;

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems'
            '?part=id'
            '&playlistId=WL'
            '&maxResults=1'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['pageInfo']?['totalResults'] ?? 0;
      }
    } catch (e) {
      log('Error fetching watch later count: $e');
    }
    return 0;
  }

  // Get videos from a specific playlist
  Future<List<Map<String, dynamic>>> getPlaylistVideos(String playlistId,
      {int maxResults = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return [];

      String endpoint;
      if (playlistId == 'LL') {
        // Liked videos
        endpoint = 'https://www.googleapis.com/youtube/v3/videos'
            '?part=snippet'
            '&myRating=like'
            '&maxResults=$maxResults';
      } else {
        // Regular playlist or Watch Later
        endpoint = 'https://www.googleapis.com/youtube/v3/playlistItems'
            '?part=snippet'
            '&playlistId=$playlistId'
            '&maxResults=$maxResults';
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['items'] != null) {
          return (data['items'] as List)
              .map<Map<String, dynamic>>((item) => {
                    'id': playlistId == 'LL'
                        ? item['id']
                        : item['snippet']['resourceId']['videoId'],
                    'title': item['snippet']['title'],
                    'description': item['snippet']['description'],
                    'thumbnail': item['snippet']['thumbnails']['default']
                        ['url'],
                    'channelTitle': item['snippet']['channelTitle'],
                    'publishedAt': item['snippet']['publishedAt'],
                  })
              .toList();
        }
      }
    } catch (e) {
      log('Error fetching playlist videos: $e');
    }
    return [];
  }

  // Get user's uploaded YouTube videos
  Future<List<Map<String, dynamic>>> getYouTubeVideos(
      {int maxResults = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return [];

      // First get the channel ID
      final channelResponse = await http.get(
        Uri.parse('https://www.googleapis.com/youtube/v3/channels'
            '?part=snippet,contentDetails'
            '&mine=true'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (channelResponse.statusCode == 200) {
        final channelData = jsonDecode(channelResponse.body);
        if (channelData['items'] != null && channelData['items'].isNotEmpty) {
          final uploadsPlaylistId = channelData['items'][0]['contentDetails']
              ['relatedPlaylists']['uploads'];

          // Get videos from uploads playlist
          final videosResponse = await http.get(
            Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems'
                '?part=snippet'
                '&playlistId=$uploadsPlaylistId'
                '&maxResults=$maxResults'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (videosResponse.statusCode == 200) {
            final videosData = jsonDecode(videosResponse.body);
            if (videosData['items'] != null) {
              return (videosData['items'] as List)
                  .map<Map<String, dynamic>>((item) => {
                        'videoId': item['snippet']['resourceId']['videoId'],
                        'title': item['snippet']['title'],
                        'description': item['snippet']['description'],
                        'thumbnail': item['snippet']['thumbnails']['default']
                            ['url'],
                        'channelTitle': item['snippet']['channelTitle'],
                        'publishedAt': item['snippet']['publishedAt'],
                      })
                  .toList();
            }
          }
        }
      }
    } catch (e) {
      log('Error fetching YouTube videos: $e');
    }
    return [];
  }

  // Upload video to YouTube (simplified implementation)
  // Note: Full video upload requires YouTube Data API v3 and proper multipart upload
  Future<Map<String, dynamic>?> uploadYouTubeVideo({
    required String title,
    required String description,
    String privacyStatus = 'private',
    // For now, this is a placeholder - actual video upload requires more complex implementation
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('youtube_token');
      if (token == null) return null;

      // This is a simplified version - actual implementation would need:
      // 1. File upload handling
      // 2. Multipart form data
      // 3. Progress tracking
      // 4. Proper error handling

      log('Upload functionality requires YouTube Data API v3 implementation');
      log('Title: $title, Description: $description, Privacy: $privacyStatus');

      // Return a mock success response for demonstration
      return {
        'success': true,
        'videoId': 'demo_${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'description': description,
        'privacyStatus': privacyStatus,
      };
    } catch (e) {
      log('Error uploading YouTube video: $e');
      return null;
    }
  }

  // Helper method to get YouTube token
  Future<String?> _getYouTubeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('youtube_token');
    // Try refresh by signInSilently if token missing
    if (token == null) {
      try {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          final auth = await account.authentication;
          await prefs.setString('youtube_token', auth.accessToken ?? '');
          return auth.accessToken;
        }
      } catch (e) {
        log('signInSilently error: $e');
      }
    }
    return token;
  }

  // Fetch uploaded videos (uploads playlist)
  Future<List<Map<String, dynamic>>> getYouTubeUploadedVideos(
      {int maxResults = 50}) async {
    try {
      final token = await _getYouTubeToken();
      if (token == null) return [];

      // 1) get uploads playlist id
      final chResp = await http.get(
        Uri.parse(
            'https://www.googleapis.com/youtube/v3/channels?part=contentDetails&mine=true'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (chResp.statusCode != 200) {
        log('channels fetch failed: ${chResp.statusCode} ${chResp.body}');
        return [];
      }
      final chJson = json.decode(chResp.body);
      final items = chJson['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return [];
      final uploadsId =
          items[0]['contentDetails']?['relatedPlaylists']?['uploads'];
      if (uploadsId == null) return [];

      // 2) get playlist items (uploaded videos)
      final plResp = await http.get(
        Uri.parse(
            'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=$uploadsId&maxResults=$maxResults'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (plResp.statusCode != 200) {
        log('playlistItems failed: ${plResp.statusCode} ${plResp.body}');
        return [];
      }
      final plJson = json.decode(plResp.body);
      final plItems = plJson['items'] as List<dynamic>? ?? [];

      final parsed = plItems
          .map<Map<String, dynamic>>((item) {
            final snippet = item['snippet'] ?? {};
            final contentDetails = item['contentDetails'] ?? {};
            final videoId =
                snippet['resourceId']?['videoId'] ?? contentDetails['videoId'];
            final thumbnails = snippet['thumbnails'] ?? {};
            final thumb = (thumbnails['medium'] ??
                thumbnails['default'] ??
                thumbnails['high'])?['url'];
            return {
              'videoId': videoId,
              'title': snippet['title'] ?? 'Video',
              'description': snippet['description'] ?? '',
              'thumbnail': thumb,
              'publishedAt': snippet['publishedAt'],
              'channelTitle': snippet['channelTitle'],
            };
          })
          .where((v) => v['videoId'] != null)
          .toList();

      return parsed;
    } catch (e, st) {
      log('getYouTubeUploadedVideos error: $e\n$st');
      return [];
    }
  }

  // Upload video with resumable, chunked upload (enhanced version)
  Future<Map<String, dynamic>?> uploadYouTubeVideoEnhanced({
    required File file,
    required String title,
    String description = '',
    String privacyStatus = 'private', // 'public', 'unlisted', 'private'
    void Function(double progress)? onProgress,
    int chunkSize = 256 * 1024, // 256KB default chunk size
  }) async {
    try {
      final token = await _getYouTubeToken();
      if (token == null)
        throw StateError('Missing YouTube token. Sign in first.');

      final totalBytes = await file.length();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      final metadata = {
        'snippet': {'title': title, 'description': description},
        'status': {'privacyStatus': privacyStatus},
      };

      // Initiate resumable session
      final initUri = Uri.parse(
        'https://www.googleapis.com/upload/youtube/v3/videos?part=snippet,status&uploadType=resumable',
      );

      final initResp = await http.post(
        initUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': mimeType,
          'X-Upload-Content-Length': totalBytes.toString(),
        },
        body: json.encode(metadata),
      );

      if (!(initResp.statusCode == 200 || initResp.statusCode == 201)) {
        log('upload init failed: ${initResp.statusCode} ${initResp.body}');
        return null;
      }

      final uploadUrl = initResp.headers['location'];
      if (uploadUrl == null) {
        log('upload init failed: missing Location header');
        return null;
      }

      final raf = file.openSync(mode: FileMode.read);
      int offset = 0;
      try {
        while (offset < totalBytes) {
          final end = (offset + chunkSize - 1) < (totalBytes - 1)
              ? (offset + chunkSize - 1)
              : (totalBytes - 1);
          final currentChunkSize = end - offset + 1;
          raf.setPositionSync(offset);
          final chunkBytes = raf.readSync(currentChunkSize);

          final resp = await http.put(
            Uri.parse(uploadUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': mimeType,
              'Content-Length': chunkBytes.length.toString(),
              'Content-Range': 'bytes $offset-$end/$totalBytes',
            },
            body: chunkBytes,
          );

          // If upload completed, server returns 200 or 201 with resource
          if (resp.statusCode == 200 || resp.statusCode == 201) {
            // Completed
            onProgress?.call(1.0);
            final jsonBody = json.decode(resp.body);
            return jsonBody;
          }

          // If server responds with 308 (Resume Incomplete), continue
          if (resp.statusCode == 308) {
            // Read "Range" header if present to set offset for next chunk
            final rangeHeader = resp.headers['range']; // e.g. bytes=0-524287
            if (rangeHeader != null) {
              final parts = rangeHeader.split('='); // ['bytes','0-524287']
              if (parts.length == 2) {
                final lastRange = parts[1].split('-');
                if (lastRange.length == 2) {
                  final lastReceived = int.tryParse(lastRange[1]);
                  if (lastReceived != null) {
                    offset = lastReceived + 1;
                  } else {
                    offset = end + 1;
                  }
                } else {
                  offset = end + 1;
                }
              } else {
                offset = end + 1;
              }
            } else {
              offset = end + 1;
            }
            onProgress?.call((offset / totalBytes).clamp(0.0, 1.0));
            continue;
          }

          // Some servers may respond 200 with partial, or error codes
          if (resp.statusCode >= 400) {
            log('upload chunk failed: ${resp.statusCode} ${resp.body}');
            return null;
          }

          // Otherwise advance offset
          offset = end + 1;
          onProgress?.call((offset / totalBytes).clamp(0.0, 1.0));
        }
      } finally {
        raf.closeSync();
      }
      return null;
    } catch (e, st) {
      log('uploadYouTubeVideoEnhanced error: $e\n$st');
      rethrow;
    }
  }

  // -----------------------------
  // 📸 INSTAGRAM AUTH (Demo + OAuth Skeleton)
  // -----------------------------
  Future<Map<String, dynamic>?> loginWithInstagram() async {
    try {
      // Check if already connected
      final isAlreadyConnected = await isConnectedToInstagram();
      if (isAlreadyConnected) {
        final userData = await getInstagramUser();
        return {
          'success': true,
          'user': userData,
          'message': 'Already connected to Instagram',
        };
      }

      // DEMO MODE: For development and testing
      // In production, you would:
      // 1. Launch OAuth WebView with the URL below
      // 2. Capture the authorization code from redirect
      // 3. Exchange code for access token

      final authUrl = 'https://api.instagram.com/oauth/authorize'
          '?client_id=$_instagramClientId'
          '&redirect_uri=${Uri.encodeComponent(_instagramRedirectUri)}'
          '&scope=user_profile,user_media'
          '&response_type=code';

      log('Instagram OAuth URL: $authUrl');
      log('In production, this would open a WebView for user authorization');

      // For demo purposes, create mock user data
      final mockUserData = {
        'id': 'demo_instagram_user_${DateTime.now().millisecondsSinceEpoch}',
        'username': 'baakhapaa_gamer',
        'account_type': 'PERSONAL',
        'media_count': 42,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('instagram_connected', true);
      await prefs.setString('instagram_user', jsonEncode(mockUserData));

      log('Instagram demo connection successful');
      return {
        'success': true,
        'user': mockUserData,
        'message': 'Instagram connected successfully! (Demo Mode)',
      };
    } catch (e) {
      log('Instagram login error: $e');
      return {'success': false, 'error': 'Instagram login error: $e'};
    }
  }

  // Production Instagram OAuth implementation (commented out for reference)
  /*
  Future<Map<String, dynamic>?> _productionInstagramLogin() async {
    try {
      // STEP 1: Construct Instagram OAuth URL
      final authUrl = Uri.parse(
          'https://api.instagram.com/oauth/authorize'
          '?client_id=$_instagramClientId'
          '&redirect_uri=$_instagramRedirectUri'
          '&scope=user_profile,user_media'
          '&response_type=code');

      // STEP 2: Launch OAuth in WebView (implement your WebView flow)
      final code = await _launchInstagramOAuthWebView(authUrl);
      
      // STEP 3: Exchange code for access token
      final tokenResponse = await http.post(
        Uri.parse('https://api.instagram.com/oauth/access_token'),
        body: {
          'client_id': _instagramClientId,
          'client_secret': 'YOUR_INSTAGRAM_CLIENT_SECRET',
          'grant_type': 'authorization_code',
          'redirect_uri': _instagramRedirectUri,
          'code': code,
        },
      );

      final tokenData = jsonDecode(tokenResponse.body);
      final accessToken = tokenData['access_token'];
      final userId = tokenData['user_id'];

      // STEP 4: Fetch user info
      final profileResponse = await http.get(
        Uri.parse('https://graph.instagram.com/$userId?fields=id,username,account_type&access_token=$accessToken'),
      );

      final profileData = jsonDecode(profileResponse.body);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('instagram_connected', true);
      await prefs.setString('instagram_user', jsonEncode(profileData));
      await prefs.setString('instagram_token', accessToken);

      return {'success': true, 'user': profileData};
    } catch (e) {
      log('Instagram login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  */

  Future<void> logoutFromInstagram() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('instagram_connected');
      await prefs.remove('instagram_user');
      await prefs.remove('instagram_token');
      log('Instagram logout successful');
    } catch (e) {
      log('Instagram logout error: $e');
    }
  }

  Future<bool> isConnectedToInstagram() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('instagram_connected') ?? false;
    } catch (e) {
      log('Error checking Instagram connection: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getInstagramUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('instagram_user');
      return data != null ? jsonDecode(data) : null;
    } catch (e) {
      log('Error getting Instagram user: $e');
      return null;
    }
  }

  // -----------------------------
  // 🔄 Disconnect All
  // -----------------------------
  Future<void> disconnectAllAccounts() async {
    try {
      // await logoutFromFacebook();
      await logoutFromYouTube();
      await logoutFromInstagram();
      log('All accounts disconnected successfully');
    } catch (e) {
      log('Error disconnecting accounts: $e');
    }
  }
}

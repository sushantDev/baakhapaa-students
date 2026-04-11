import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/social_auth_service.dart';
import '../utils/debug_logger.dart';

class SocialAuthProvider with ChangeNotifier {
  final SocialAuthService _socialAuthService = SocialAuthService();

  bool _isLoadingFacebook = false;
  bool _isLoadingYouTube = false;
  bool _isLoadingInstagram = false;
  bool _isConnectedToFacebook = false;
  bool _isConnectedToYouTube = false;
  bool _isConnectedToInstagram = false;
  bool _isInitialized = false; // Add initialization flag

  Map<String, dynamic>? _facebookUser;
  Map<String, dynamic>? _youTubeUser;
  Map<String, dynamic>? _instagramUser;
  Map<String, dynamic>? _youTubeChannel;
  List<Map<String, dynamic>> _youTubeSearchResults = [];
  List<Map<String, dynamic>> _youTubePlaylists = [];
  List<Map<String, dynamic>> _youTubeVideos = [];
  bool _isLoadingPlaylists = false;
  bool _isLoadingVideos = false;

  // NEW: playlist items state
  bool _isLoadingPlaylistVideos = false;
  List<Map<String, dynamic>> _currentPlaylistVideos = [];
  String? _currentPlaylistId;
  String? _currentPlaylistTitle;

  String? _error;

  // Getters
  bool get isLoadingFacebook => _isLoadingFacebook;
  bool get isLoadingYouTube => _isLoadingYouTube;
  bool get isLoadingInstagram => _isLoadingInstagram;
  bool get isConnectedToFacebook => _isConnectedToFacebook;
  bool get isConnectedToYouTube => _isConnectedToYouTube;
  bool get isConnectedToInstagram => _isConnectedToInstagram;
  bool get isInitialized => _isInitialized;
  Map<String, dynamic>? get facebookUser => _facebookUser;
  Map<String, dynamic>? get youTubeUser => _youTubeUser;
  Map<String, dynamic>? get instagramUser => _instagramUser;
  Map<String, dynamic>? get youTubeChannel => _youTubeChannel;
  List<Map<String, dynamic>> get youTubeSearchResults => _youTubeSearchResults;
  List<Map<String, dynamic>> get youTubePlaylists => _youTubePlaylists;
  List<Map<String, dynamic>> get youTubeVideos => _youTubeVideos;
  bool get isLoadingPlaylists => _isLoadingPlaylists;
  bool get isLoadingVideos => _isLoadingVideos;

  // NEW getters
  bool get isLoadingPlaylistVideos => _isLoadingPlaylistVideos;
  List<Map<String, dynamic>> get currentPlaylistVideos =>
      _currentPlaylistVideos;
  String? get currentPlaylistId => _currentPlaylistId;
  String? get currentPlaylistTitle => _currentPlaylistTitle;

  String? get error => _error;

  // Additional getters for convenience
  bool get hasAnySocialConnection =>
      _isConnectedToFacebook ||
      _isConnectedToYouTube ||
      _isConnectedToInstagram;
  bool get isFacebookLoggedIn => _isConnectedToFacebook;
  bool get isYouTubeLoggedIn => _isConnectedToYouTube;
  bool get isInstagramLoggedIn => _isConnectedToInstagram;
  bool get isFacebookLoading => _isLoadingFacebook;
  bool get isYouTubeLoading => _isLoadingYouTube;
  bool get isInstagramLoading => _isLoadingInstagram;
  String? get lastError => _error;

  // Initialize provider - check existing connections
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized) {
      if (kDebugMode) {
        DebugLogger.info('SocialAuthProvider already initialized, skipping...');
      }
      return;
    }

    if (kDebugMode) {
      DebugLogger.info('INITIALIZE called - checking stored states...');
    }

    _isConnectedToFacebook = await _socialAuthService.isConnectedToFacebook();
    _isConnectedToYouTube = await _socialAuthService.isConnectedToYouTube();
    _isConnectedToInstagram = await _socialAuthService.isConnectedToInstagram();

    if (kDebugMode) {
      DebugLogger.info('INITIALIZE results:');
      DebugLogger.info('  Facebook: $_isConnectedToFacebook');
      DebugLogger.info('  YouTube: $_isConnectedToYouTube');
      DebugLogger.info('  Instagram: $_isConnectedToInstagram');
    }

    if (_isConnectedToFacebook) {
      _facebookUser = await _socialAuthService.getFacebookUser();
    }

    if (_isConnectedToYouTube) {
      // load cached user
      _youTubeUser = await _socialAuthService.getYouTubeUser();
      // proactively load channel info if available (so screens see it immediately)
      try {
        _youTubeChannel = await _socialAuthService.getYouTubeChannelInfo();
        // Optionally prefetch playlists/videos lazily later
      } catch (e) {
        if (kDebugMode) {
          DebugLogger.info('initialize: failed to fetch channel info: $e');
        }
      }
    }

    if (_isConnectedToInstagram) {
      _instagramUser = await _socialAuthService.getInstagramUser();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Ensure YouTube metadata (channel, playlists, videos) are loaded.
  /// Safe to call multiple times; it will only fetch missing pieces.
  Future<void> ensureYouTubeDataLoaded({int videosMaxResults = 50}) async {
    if (!_isConnectedToYouTube) return;

    bool didChange = false;

    // Load channel if missing
    if (_youTubeChannel == null) {
      try {
        final ch = await _socialAuthService.getYouTubeChannelInfo();
        if (ch != null) {
          _youTubeChannel = ch;
          didChange = true;
          if (kDebugMode) {
            DebugLogger.info('ensureYouTubeDataLoaded: channel loaded');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          DebugLogger.info('ensureYouTubeDataLoaded: channel load error: $e');
        }
      }
    }

    // Load playlists if empty
    if (_youTubePlaylists.isEmpty) {
      try {
        final pl = await _socialAuthService.getYouTubePlaylists();
        _youTubePlaylists = pl;
        didChange = true;
        if (kDebugMode) {
          DebugLogger.info(
              'ensureYouTubeDataLoaded: playlists loaded (${pl.length})');
        }
      } catch (e) {
        if (kDebugMode) {
          DebugLogger.info('ensureYouTubeDataLoaded: playlists error: $e');
        }
      }
    }

    // Load uploaded videos if empty
    if (_youTubeVideos.isEmpty) {
      try {
        final vids = await _socialAuthService.getYouTubeUploadedVideos(
            maxResults: videosMaxResults);
        _youTubeVideos = vids;
        didChange = true;
        if (kDebugMode) {
          DebugLogger.info(
              'ensureYouTubeDataLoaded: videos loaded (${vids.length})');
        }
      } catch (e) {
        if (kDebugMode) {
          DebugLogger.info('ensureYouTubeDataLoaded: videos error: $e');
        }
      }
    }

    if (didChange) {
      notifyListeners();
    }
  }

  // Facebook Login
  // Future<void> loginWithFacebook() async {
  //   if (_isLoadingFacebook) {
  //     if (kDebugMode) {
  //       DebugLogger.info('Facebook login already in progress, skipping...');
  //     }
  //     return;
  //   }

  //   _isLoadingFacebook = true;
  //   _error = null;
  //   notifyListeners();

  //   // Debug: Log current state before Facebook login
  //   if (kDebugMode) {
  //     DebugLogger.info('BEFORE Facebook login:');
  //     DebugLogger.info('  Facebook connected: $_isConnectedToFacebook');
  //     DebugLogger.info('  YouTube connected: $_isConnectedToYouTube');
  //     DebugLogger.info('  Instagram connected: $_isConnectedToInstagram');
  //   }

  //   try {
  //     final result = await _socialAuthService.loginWithFacebook();

  //     if (result['success'] == true) {
  //       _isConnectedToFacebook = true;
  //       _facebookUser = result['user'];
  //       if (kDebugMode) {
  //         DebugLogger.info('Facebook login SUCCESS');
  //       }
  //     } else {
  //       _error = result['error'] ?? 'Facebook login failed';
  //       if (kDebugMode) {
  //         DebugLogger.info('Facebook login FAILED: $_error');
  //       }
  //     }
  //   } catch (e) {
  //     _error = 'Facebook login error: $e';
  //     if (kDebugMode) {
  //       DebugLogger.info('Facebook login EXCEPTION: $e');
  //     }
  //   }

  //   // Debug: Log current state after Facebook login
  //   if (kDebugMode) {
  //     DebugLogger.info('AFTER Facebook login:');
  //     DebugLogger.info('  Facebook connected: $_isConnectedToFacebook');
  //     DebugLogger.info('  YouTube connected: $_isConnectedToYouTube');
  //     DebugLogger.info('  Instagram connected: $_isConnectedToInstagram');
  //   }

  //   _isLoadingFacebook = false;
  //   notifyListeners();
  // }

  // // Facebook Logout
  // Future<void> logoutFromFacebook() async {
  //   try {
  //     await _socialAuthService.logoutFromFacebook();
  //     _isConnectedToFacebook = false;
  //     _facebookUser = null;
  //     notifyListeners();
  //   } catch (e) {
  //     _error = 'Facebook logout error: $e';
  //     notifyListeners();
  //   }
  // }

  // YouTube Login
  Future<void> loginWithYouTube() async {
    if (_isLoadingYouTube) {
      if (kDebugMode) {
        DebugLogger.info('YouTube login already in progress, skipping...');
      }
      return;
    }

    if (kDebugMode) {
      DebugLogger.info('YouTube Login Started');
    }
    _isLoadingYouTube = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _socialAuthService.loginWithYouTube();
      if (kDebugMode) {
        DebugLogger.info('YouTube Login Result: $result');
      }

      if (result['success'] == true) {
        _isConnectedToYouTube = true;
        _youTubeUser = result['user'];
        if (kDebugMode) {
          DebugLogger.info(
              'YouTube State Updated: isConnected=$_isConnectedToYouTube');
        }

        // Get channel info after successful login
        try {
          _youTubeChannel = await _socialAuthService.getYouTubeChannelInfo();
          if (kDebugMode) {
            DebugLogger.info('YouTube Channel Info loaded successfully');
          }
        } catch (e) {
          if (kDebugMode) {
            DebugLogger.info('Failed to load channel info: $e');
          }
          // Continue without channel info
        }

        // Fetch playlists
        try {
          await fetchYouTubePlaylists();
        } catch (e) {
          if (kDebugMode) {
            DebugLogger.info('Failed to load playlists: $e');
          }
          // Continue without playlists
        }
      } else {
        _error = result['error'] ?? 'YouTube login failed';
        if (kDebugMode) {
          DebugLogger.info('YouTube Login Failed: $_error');
        }
      }
    } catch (e) {
      _error = 'YouTube login error: $e';
      if (kDebugMode) {
        DebugLogger.info('YouTube Login Exception: $e');
      }
    }

    _isLoadingYouTube = false;
    if (kDebugMode) {
      DebugLogger.info(
          'YouTube Login Finished: isConnected=$_isConnectedToYouTube, isLoading=$_isLoadingYouTube');
    }
    notifyListeners();
  }

  // YouTube Logout
  Future<void> logoutFromYouTube() async {
    try {
      await _socialAuthService.logoutFromYouTube();
      _isConnectedToYouTube = false;
      _youTubeUser = null;
      _youTubeChannel = null;
      _youTubeSearchResults.clear();
      notifyListeners();
    } catch (e) {
      _error = 'YouTube logout error: $e';
      notifyListeners();
    }
  }

  // Search YouTube videos
  Future<void> searchYouTubeVideos(String query) async {
    if (!_isConnectedToYouTube) {
      _error = 'Please connect to YouTube first';
      notifyListeners();
      return;
    }

    try {
      _youTubeSearchResults =
          await _socialAuthService.searchYouTubeVideos(query);
      notifyListeners();
    } catch (e) {
      _error = 'YouTube search error: $e';
      notifyListeners();
    }
  }

  // Fetch YouTube playlists
  Future<void> fetchYouTubePlaylists() async {
    _isLoadingPlaylists = true;
    _error = null;
    notifyListeners();

    try {
      final playlists = await _socialAuthService.getYouTubePlaylists();
      _youTubePlaylists = playlists;
      if (kDebugMode) {
        DebugLogger.info('YouTube Playlists fetched: ${playlists.length}');
      }
    } catch (e) {
      _error = 'YouTube playlists error: $e';
      if (kDebugMode) {
        DebugLogger.info('YouTube Playlists error: $e');
      }
    } finally {
      _isLoadingPlaylists = false;
      notifyListeners();
    }
  }

  // Get playlist by ID
  Map<String, dynamic>? getPlaylistById(String id) {
    try {
      return _youTubePlaylists.firstWhere((playlist) => playlist['id'] == id);
    } catch (e) {
      return null;
    }
  }

  // Fetch YouTube videos
  Future<void> fetchYouTubeVideos({int maxResults = 50}) async {
    if (!_isConnectedToYouTube) {
      _error = 'Please connect to YouTube first';
      notifyListeners();
      return;
    }

    _isLoadingVideos = true;
    _error = null;
    notifyListeners();

    try {
      final videos = await _socialAuthService.getYouTubeUploadedVideos(
          maxResults: maxResults);
      _youTubeVideos = videos;
      if (kDebugMode) {
        DebugLogger.info('YouTube Videos fetched: ${videos.length}');
      }
    } catch (e) {
      _error = 'YouTube videos error: $e';
      if (kDebugMode) {
        DebugLogger.info('YouTube Videos error: $e');
      }
      _youTubeVideos = [];
    } finally {
      _isLoadingVideos = false;
      notifyListeners();
    }
  }

  // Upload YouTube video
  Future<Map<String, dynamic>?> uploadYouTubeVideo({
    required File file,
    required String title,
    String description = '',
    String privacyStatus = 'private',
    void Function(double progress)? onProgress,
  }) async {
    if (!_isConnectedToYouTube) {
      _error = 'Please connect to YouTube first';
      notifyListeners();
      return null;
    }

    _isLoadingYouTube = true;
    notifyListeners();

    try {
      final result = await _socialAuthService.uploadYouTubeVideoEnhanced(
        file: file,
        title: title,
        description: description,
        privacyStatus: privacyStatus,
        onProgress: onProgress,
      );

      // refresh list if success
      if (result != null) {
        await fetchYouTubeVideos();
        if (kDebugMode) {
          DebugLogger.info(
              'YouTube video uploaded: ${result['snippet']?['title']}');
        }
      }
      return result;
    } catch (e) {
      _error = 'YouTube upload error: $e';
      if (kDebugMode) {
        DebugLogger.info('YouTube upload error: $e');
      }
      return null;
    } finally {
      _isLoadingYouTube = false;
      notifyListeners();
    }
  }

  // Instagram Login
  Future<void> loginWithInstagram() async {
    if (_isLoadingInstagram) {
      if (kDebugMode) {
        DebugLogger.info('Instagram login already in progress, skipping...');
      }
      return;
    }

    if (kDebugMode) {
      DebugLogger.info('Instagram Login Started');
    }
    _isLoadingInstagram = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _socialAuthService.loginWithInstagram();
      if (kDebugMode) {
        DebugLogger.info('Instagram Login Result: $result');
      }

      if (result != null && result['success'] == true) {
        _isConnectedToInstagram = true;
        _instagramUser = result['user'];
        if (kDebugMode) {
          DebugLogger.info(
              'Instagram State Updated: isConnected=$_isConnectedToInstagram');
        }

        // Force UI update
        notifyListeners();
      } else {
        _error = result?['error'] ?? 'Instagram login failed';
        if (kDebugMode) {
          DebugLogger.info('Instagram Login Failed: $_error');
        }
      }
    } catch (e) {
      _error = 'Instagram login error: $e';
      if (kDebugMode) {
        DebugLogger.info('Instagram Login Exception: $e');
      }
    }

    _isLoadingInstagram = false;
    if (kDebugMode) {
      DebugLogger.info(
          'Instagram Login Finished: isConnected=$_isConnectedToInstagram, isLoading=$_isLoadingInstagram');
    }
    notifyListeners();
  }

  // Instagram Logout
  Future<void> logoutFromInstagram() async {
    try {
      await _socialAuthService.logoutFromInstagram();
      _isConnectedToInstagram = false;
      _instagramUser = null;
      notifyListeners();
    } catch (e) {
      _error = 'Instagram logout error: $e';
      notifyListeners();
    }
  }

  // Disconnect all accounts
  Future<void> disconnectAllAccounts() async {
    try {
      await _socialAuthService.disconnectAllAccounts();
      _isConnectedToFacebook = false;
      _isConnectedToYouTube = false;
      _isConnectedToInstagram = false;
      _facebookUser = null;
      _youTubeUser = null;
      _instagramUser = null;
      _youTubeChannel = null;
      _youTubeSearchResults.clear();
      notifyListeners();
    } catch (e) {
      _error = 'Error disconnecting accounts: $e';
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Additional methods for compatibility with settings screen
  // Future<bool> signInWithFacebook() async {
  //   await loginWithFacebook();
  //   return _isConnectedToFacebook;
  // }

  Future<bool> signInWithYouTube() async {
    await loginWithYouTube();
    return _isConnectedToYouTube;
  }

  // Future<void> signOutFromFacebook() async {
  //   await logoutFromFacebook();
  // }

  Future<void> signOutFromYouTube() async {
    await logoutFromYouTube();
  }

  Future<bool> signInWithInstagram() async {
    await loginWithInstagram();
    return _isConnectedToInstagram;
  }

  Future<void> signOutFromInstagram() async {
    await logoutFromInstagram();
  }

  // Share app invitation on Facebook
  // Future<Map<String, dynamic>> shareAppInvitation({
  //   String? customMessage,
  // }) async {
  //   try {
  //     if (!_isConnectedToFacebook) {
  //       return {'success': false, 'error': 'Please connect to Facebook first'};
  //     }

  //     // final result = await _socialAuthService.shareAppInvitation(
  //     //   message: customMessage,
  //     // );

  //     if (!result['success']) {
  //       _error = result['error'];
  //       notifyListeners();
  //     }

  //     return result;
  //   } catch (e) {
  //     _error = 'Sharing error: $e';
  //     notifyListeners();
  //     return {
  //       'success': false,
  //       'error': _error,
  //     };
  //   }
  // }

  // NEW: fetch videos for a playlist (wraps service)
  Future<void> fetchPlaylistVideos(String playlistId,
      {String? playlistTitle, int maxResults = 50}) async {
    if (!_isConnectedToYouTube) {
      _error = 'Please connect to YouTube first';
      notifyListeners();
      return;
    }

    _isLoadingPlaylistVideos = true;
    _error = null;
    _currentPlaylistId = playlistId;
    _currentPlaylistTitle = playlistTitle;
    notifyListeners();

    try {
      final videos = await _socialAuthService.getPlaylistVideos(playlistId,
          maxResults: maxResults);
      // Normalize items to { videoId, title, thumbnail, description, channelTitle, publishedAt }
      _currentPlaylistVideos = videos
          .map<Map<String, dynamic>>((v) {
            // Your service returns id/title/thumbnail etc. Normalize keys:
            return {
              'videoId': v['id'] ?? v['videoId'],
              'title': v['title'],
              'description': v['description'],
              'thumbnail': v['thumbnail'],
              'channelTitle': v['channelTitle'],
              'publishedAt': v['publishedAt'],
            };
          })
          .where((v) => v['videoId'] != null)
          .toList();

      if (kDebugMode) {
        DebugLogger.info(
            'Playlist videos fetched: ${_currentPlaylistVideos.length} videos for "$playlistTitle"');
      }
    } catch (e) {
      _error = 'Error fetching playlist videos: $e';
      _currentPlaylistVideos = [];
      if (kDebugMode) {
        DebugLogger.info('fetchPlaylistVideos error: $e');
      }
    } finally {
      _isLoadingPlaylistVideos = false;
      notifyListeners();
    }
  }

  // Optionally: clear current playlist cache
  void clearCurrentPlaylist() {
    _currentPlaylistVideos = [];
    _currentPlaylistId = null;
    _currentPlaylistTitle = null;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/providers/social_auth_provider.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/skeleton_loading.dart';

class YouTubeVideoSelectorScreen extends StatefulWidget {
  static const routeName = '/youtube-video-selector-screen';

  const YouTubeVideoSelectorScreen({Key? key}) : super(key: key);

  @override
  State<YouTubeVideoSelectorScreen> createState() =>
      _YouTubeVideoSelectorScreenState();
}

class _YouTubeVideoSelectorScreenState
    extends State<YouTubeVideoSelectorScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure videos are loaded using the new method
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<SocialAuthProvider>(context, listen: false);
      if (prov.isConnectedToYouTube) {
        // Use the new ensureYouTubeDataLoaded method instead of fetchYouTubeVideos
        prov.ensureYouTubeDataLoaded();
      }
    });
  }

  void _selectVideo(Map<String, dynamic> video) {
    try {
      DebugLogger.info('Video selected for shorts: ${video['title']}');

      // Return the selected video data
      Navigator.of(context).pop(video);
    } catch (e) {
      DebugLogger.error('Error selecting video: $e');
      // Fallback navigation
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Select YouTube Video'),
        backgroundColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            try {
              Navigator.of(context).pop();
            } catch (e) {
              DebugLogger.error('Error with back navigation: $e');
              // Try alternative navigation methods
              Navigator.maybePop(context);
            }
          },
        ),
      ),
      body: Consumer<SocialAuthProvider>(
        builder: (context, prov, _) {
          if (!prov.isConnectedToYouTube) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.youtube_searched_for,
                      size: 80,
                      color: Colors.red.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Connect to YouTube',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You need to connect your YouTube account to select videos for shorts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        try {
                          // Navigate back and show connect YouTube option
                          Navigator.of(context).pop();
                        } catch (e) {
                          DebugLogger.error('Error navigating back: $e');
                          // Force navigation using different method
                          Navigator.maybePop(context);
                        }
                      },
                      icon: Icon(Icons.arrow_back),
                      label: Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (prov.isLoadingVideos) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: ListSkeleton(itemCount: 4),
            );
          }

          final videos = prov.youTubeVideos;
          if (videos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 80,
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No videos found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload some videos to your YouTube channel first',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Refresh videos using the new method
                        await prov.ensureYouTubeDataLoaded();
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Use the new ensureYouTubeDataLoaded method
              await prov.ensureYouTubeDataLoaded();
            },
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: videos.length,
              itemBuilder: (context, i) {
                final v = videos[i];
                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Video thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: v['thumbnail'] != null
                              ? Image.network(
                                  v['thumbnail'],
                                  width: 120,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 120,
                                    height: 90,
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.video_library,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 120,
                                  height: 90,
                                  color: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.video_library,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    size: 32,
                                  ),
                                ),
                        ),

                        SizedBox(width: 16),

                        // Video info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v['title'] ?? 'Untitled Video',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                v['channelTitle'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 12),

                              // Select button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectVideo(v),
                                  icon: Icon(Icons.check_circle, size: 18),
                                  label: Text('Select for Shorts'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

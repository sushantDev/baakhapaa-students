import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/skeleton_loading.dart';

class CameraRecordingScreen extends StatefulWidget {
  static const routeName = '/camera-recording-screen';

  @override
  _CameraRecordingScreenState createState() => _CameraRecordingScreenState();
}

class _CameraRecordingScreenState extends State<CameraRecordingScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isRecording = false;
  bool _isFrontCamera = false;
  List<CameraDescription> cameras = [];
  int _selectedCameraIdx = 0;
  late AnimationController _recordingAnimationController;
  late AnimationController _pulseAnimationController;

  // Timer variables
  int _recordingDuration = 0;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();

    // Hide system UI for full screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _recordingAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _initializeCamera();
  }

  void _updateRecordingTime() {
    if (_isRecording && _recordingStartTime != null) {
      setState(() {
        _recordingDuration =
            DateTime.now().difference(_recordingStartTime!).inSeconds;
      });
      // Continue updating every second
      Future.delayed(Duration(seconds: 1), () {
        if (_isRecording) _updateRecordingTime();
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 5), // Limit video duration
      );

      if (pickedFile != null) {
        // Restore system UI before navigating back
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pop(pickedFile);
      }
    } catch (e) {
      DebugLogger.error('Error picking from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick video from gallery'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[_selectedCameraIdx],
      ResolutionPreset.veryHigh, // Use highest resolution for better quality
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      DebugLogger.error('Error initializing camera: $e');
    }
  }

  void _switchCamera() async {
    if (cameras.length < 2) return;

    _selectedCameraIdx = (_selectedCameraIdx + 1) % 2;
    _isFrontCamera = !_isFrontCamera;

    await _cameraController?.dispose();

    _cameraController = CameraController(
      cameras[_selectedCameraIdx],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      DebugLogger.error('Error switching camera: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      if (_isRecording) {
        final XFile video = await _cameraController!.stopVideoRecording();
        await _recordingAnimationController.reverse();
        setState(() {
          _isRecording = false;
          _recordingStartTime = null;
          _recordingDuration = 0;
        });

        // Restore system UI before navigating back
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pop(video); // Return the recorded video file
      } else {
        await _cameraController!.startVideoRecording();
        await _recordingAnimationController.forward();
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
          _recordingDuration = 0;
        });
        _updateRecordingTime(); // Start the timer
      }
    } catch (e) {
      DebugLogger.error('Error recording video: $e');
    }
  }

  @override
  void dispose() {
    // Restore system UI when leaving camera screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _recordingAnimationController.dispose();
    _pulseAnimationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              ShimmerLoading(
                child: SkeletonBox(width: 200, height: 300, borderRadius: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview (Full Screen)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // Top Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close Button
                    _buildControlButton(
                      icon: Icons.close,
                      onTap: () {
                        // Restore system UI before navigating back
                        SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.edgeToEdge);
                        Navigator.pop(context);
                      },
                    ),

                    // Recording Indicator
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _pulseAnimationController,
                        builder: (context, child) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(
                                  alpha: 0.2 +
                                      0.3 * _pulseAnimationController.value),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'REC',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    // Camera Switch Button
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onTap: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Button
                    _buildSideButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: _pickFromGallery,
                    ),

                    // Record Button (Main)
                    _buildRecordButton(),

                    // Space to maintain symmetry
                    SizedBox(width: 50),
                  ],
                ),
              ),
            ),
          ),

          // Duration Display (while recording)
          if (_isRecording)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(_recordingDuration),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: _recordingAnimationController,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
            ),
            child: Center(
              child: Container(
                width: 60 - (20 * _recordingAnimationController.value),
                height: 60 - (20 * _recordingAnimationController.value),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.white,
                  borderRadius: BorderRadius.circular(
                    _isRecording ? 8 : 30,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

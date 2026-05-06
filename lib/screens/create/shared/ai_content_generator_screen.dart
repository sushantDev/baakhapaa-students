import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../models/ai_generated_content.dart';
import '../../../providers/story_creation.dart';
import '../../../utils/debug_logger.dart';
import '../../create/story/create_episode_screen.dart';
import '../../create/story/create_season_screen.dart';
import '../../shorts/create/create_shorts_screen.dart';
import '../../subscription/subscription_screen.dart';

class AiContentGeneratorScreen extends StatefulWidget {
  static const routeName = '/ai-content-generator';

  const AiContentGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<AiContentGeneratorScreen> createState() =>
      _AiContentGeneratorScreenState();
}

class _AiContentGeneratorScreenState extends State<AiContentGeneratorScreen> {
  String _contentType = 'episode';
  Map<String, dynamic> _passthroughArgs = {};

  final _descCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descEditCtrl = TextEditingController();
  final _pointsUsersCtrl = TextEditingController(text: '100');
  final _livesCtrl = TextEditingController(text: '3');
  final _durationCtrl = TextEditingController(text: '30');

  stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isGenerating = false;
  String? _error;
  int _step = 0;

  DateTime? _publishDate;
  List<String> _genres = [];
  List<String> _maturities = [];
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final passthrough = Map<String, dynamic>.from(args);
        passthrough.remove('contentType');
        setState(() {
          _contentType = args['contentType'] as String? ?? 'episode';
          _passthroughArgs = passthrough;
        });
      }
    });
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          DebugLogger.warning('Microphone permission denied');
          return;
        }
      }

      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _isListening = status == 'listening';
          });
        },
        onError: (error) {
          DebugLogger.error('Speech error: $error');
          if (!mounted) return;
          setState(() {
            _isListening = false;
          });
        },
      );

      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (e) {
      DebugLogger.error('Speech init failed: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available.')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    await _speech.listen(
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _descCtrl.text = result.recognizedWords;
          _descCtrl.selection = TextSelection.collapsed(
            offset: _descCtrl.text.length,
          );
        });
      },
    );

    if (mounted) setState(() => _isListening = true);
  }

  Future<void> _generate() async {
    final description = _descCtrl.text.trim();
    if (description.length < 20) {
      setState(() {
        _error = 'Describe the content in a bit more detail before generating.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      final result = await storyCreation.generateFullContent(
        description: description,
        contentType: _contentType,
        questionCount: _contentType == 'season'
            ? 0
            : (_contentType == 'short' ? 4 : 7),
      );

      final content = AiGeneratedContent.fromJson(result['content']);

      setState(() {
        _titleCtrl.text = content.title;
        _descEditCtrl.text = content.description;
        _pointsUsersCtrl.text = content.pointsUsers.toString();
        _livesCtrl.text = content.lives.toString();
        _durationCtrl.text = content.duration.toString();
        _publishDate = content.publishDate;
        _genres = List<String>.from(content.genres);
        _maturities = List<String>.from(content.maturities);
        _questions = List<Map<String, dynamic>>.from(content.questions);
        _step = 1;
      });
    } on AiUsageLimitException catch (e) {
      setState(() => _error = e.message);
    } on AiInsufficientPointsException catch (e) {
      setState(() => _error = e.message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            action: SnackBarAction(
              label: 'Get Points',
              onPressed: () {
                Navigator.of(context).pushNamed(SubscriptionScreen.routeName);
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _useContent() {
    final content = AiGeneratedContent(
      title: _titleCtrl.text.trim(),
      description: _descEditCtrl.text.trim(),
      genres: List<String>.from(_genres),
      maturities: List<String>.from(_maturities),
      coins: 1,
      pointsUsers: int.tryParse(_pointsUsersCtrl.text.trim()) ?? 100,
      lives: int.tryParse(_livesCtrl.text.trim()) ?? 3,
      duration: int.tryParse(_durationCtrl.text.trim()) ?? 30,
      publishDate: _publishDate ?? DateTime.now(),
      questions: List<Map<String, dynamic>>.from(_questions),
    );

    final route = _contentType == 'season'
        ? CreateSeasonScreen.routeName
        : _contentType == 'short'
        ? CreateShortsScreen.routeName
        : CreateEpisodeScreen.routeName;

    Navigator.of(context).pushReplacementNamed(
      route,
      arguments: {..._passthroughArgs, 'aiPrefilled': content},
    );
  }

  Future<void> _pickPublishDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _publishDate = picked);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _descCtrl.dispose();
    _titleCtrl.dispose();
    _descEditCtrl.dispose();
    _pointsUsersCtrl.dispose();
    _livesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('AI Content Generator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _step == 0
            ? _buildDescribeStep(isDark)
            : _buildReviewStep(isDark),
      ),
    );
  }

  Widget _buildDescribeStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Describe your ${_contentType == 'short' ? 'short' : _contentType}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Type or speak a clear description and AI will prepare your draft content.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _descCtrl,
          maxLines: 8,
          decoration: InputDecoration(
            hintText:
                'Example: A short educational story about why eclipses happen, with simple science facts and quiz questions for students.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleListening,
                icon: Icon(_isListening ? Icons.stop : Icons.mic),
                label: Text(_isListening ? 'Stop Listening' : 'Use Voice'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGenerating ? 'Generating...' : 'Generate'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }

  Widget _buildReviewStep(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review generated content',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descEditCtrl,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pointsUsersCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Viewer Points'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _livesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Lives'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publish Date'),
            subtitle: Text(
              _publishDate != null
                  ? DateFormat('yyyy-MM-dd').format(_publishDate!)
                  : 'Select date',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickPublishDate,
          ),
          if (_genres.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Genres', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: _genres.map((g) => Chip(label: Text(g))).toList(),
            ),
          ],
          if (_maturities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Maturities', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: _maturities.map((m) => Chip(label: Text(m))).toList(),
            ),
          ],
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Generated Questions: ${_questions.length}',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _useContent,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Use This Content'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/story_creation.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/skeleton_loading.dart';
import 'create_question_screen.dart';

class ManageEpisodeQuestionsScreen extends StatefulWidget {
  static const routeName = '/manage-episode-questions';

  const ManageEpisodeQuestionsScreen({Key? key}) : super(key: key);

  @override
  State<ManageEpisodeQuestionsScreen> createState() =>
      _ManageEpisodeQuestionsScreenState();
}

class _ManageEpisodeQuestionsScreenState
    extends State<ManageEpisodeQuestionsScreen> {
  bool _isLoading = false;
  int? _episodeId;
  String _episodeTitle = '';
  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _episodeId = args['episodeId'] as int?;
        _episodeTitle = args['episodeTitle'] as String? ?? 'Questions';
        if (_episodeId != null) {
          _loadQuestions();
        }
      }
    });
  }

  Future<void> _loadQuestions() async {
    if (_episodeId == null) return;

    setState(() => _isLoading = true);

    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      final questions = await storyCreation.fetchEpisodeQuestions(_episodeId!);

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      DebugLogger.error('Error loading questions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load questions: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteQuestion(Map<String, dynamic> question) async {
    final questionId = question['id'];

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      await storyCreation.deleteQuestion(questionId);

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        _showSuccessSnackBar('Question deleted successfully');
        _loadQuestions();
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        _showErrorSnackBar('Failed to delete question: ${e.toString()}');
      }
    }
  }

  void _confirmDeleteQuestion(Map<String, dynamic> question) {
    final questionText = question['question'] ?? 'this question';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text('Are you sure you want to delete "$questionText"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteQuestion(question);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showQuestionOptions(Map<String, dynamic> question) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Question Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Question'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(
                  CreateQuestionScreen.routeName,
                  arguments: {
                    'episodeId': _episodeId,
                    'episodeTitle': _episodeTitle,
                    'mode': 'edit',
                    'question': question,
                  },
                ).then((_) => _loadQuestions());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Question'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteQuestion(question);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final questionText = question['question'] as String? ?? 'Untitled Question';
    final type = question['type'] as String? ?? 'multiple_choice';
    final time = question['time'] as int? ?? 0;
    final answers = question['answers'] as List? ?? [];
    final correctAnswer = answers.firstWhere(
      (a) => a['is_correct'] == true || a['is_correct'] == 1,
      orElse: () => null,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showQuestionOptions(question),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      questionText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${time}s',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    type.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.list, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${answers.length} answers',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (correctAnswer != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          correctAnswer['answer'] ?? '',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_episodeTitle),
            Text(
              '${_questions.length} ${_questions.length == 1 ? 'Question' : 'Questions'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: ListSkeleton(itemCount: 4),
            )
          : _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No questions yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add questions to this episode',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadQuestions,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      return _buildQuestionCard(_questions[index], index);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(
            CreateQuestionScreen.routeName,
            arguments: {
              'episodeId': _episodeId,
              'episodeTitle': _episodeTitle,
              'mode': 'create',
            },
          ).then((_) => _loadQuestions());
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
      ),
    );
  }
}

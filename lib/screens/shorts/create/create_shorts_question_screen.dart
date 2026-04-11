import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/shorts.dart';
import 'package:baakhapaa/screens/shorts/create/create_shorts_question_form_screen.dart';
import 'package:baakhapaa/screens/shorts/shorts_screen.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CreateShortsQuestionScreen extends StatefulWidget {
  static const routeName = '/create-shorts-question-screen';

  @override
  _CreateShortsQuestionScreenState createState() =>
      _CreateShortsQuestionScreenState();
}

class _CreateShortsQuestionScreenState
    extends State<CreateShortsQuestionScreen> {
  var shortsProvider;
  late List<dynamic> questions = [];
  var _isInit = false;
  bool _isLoading = true;
  int totalMcqsRequired = 0;

  // Add search functionality
  String _searchQuery = '';
  bool _isFromQuestionScreen = false;
  bool _isAddingQuestion = false;
  List<dynamic> get filteredQuestions => questions.where((question) {
        return question['question']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      }).toList();

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      shortsProvider = Provider.of<Shorts>(context, listen: false);
      totalMcqsRequired = args['totalMcqsRequired'] as int;
      _isFromQuestionScreen = args['fromQuestionScreen'] ?? false;

      shortsProvider.fetchShortsQuestions(args['shortsId'] as int).then((_) {
        setState(() {
          questions = shortsProvider.questions;
          _isLoading = false;
        });
      });
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  Future<void> _deleteQuestion(int index) async {
    if (!mounted) return; // Check if widget is still mounted

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final question = questions[index];

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Question'),
        content: Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!shouldDelete! || !mounted) return;

    try {
      // Get fresh instance of provider
      final provider = Provider.of<Shorts>(context, listen: false);

      // Remove from local state first for immediate UI update
      setState(() {
        questions.removeAt(index);
      });

      // Then delete from backend
      try {
        await provider.deleteQuestion(question['id']);

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Question deleted successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // If backend deletion fails, revert the UI change
        if (mounted) {
          setState(() {
            questions.insert(index, question);
          });
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete question: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editQuestion(Map<String, dynamic> question) async {
    if (!mounted) return;

    try {
      final shortsId = (ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>)['shortsId'];

      // Create a deep copy of the question with all required fields
      final questionCopy = {
        'id': question['id'],
        'type': question['type'],
        'question': question['question'],
        'time': question['time'],
        'shorts_id': shortsId,
        'answers': (question['answers'] as List)
            .map((answer) => Map<String, dynamic>.from({
                  'id': answer['id'],
                  'answer': answer['answer'],
                  'is_correct': answer['is_correct'],
                }))
            .toList(),
      };

      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => CreateShortsQuestionFormScreen(
            questionData: questionCopy,
          ),
        ),
      );

      if (result != null && mounted) {
        // Update question in backend
        final provider = Provider.of<Shorts>(context, listen: false);
        await provider.updateQuestion(result, question['id']);

        // Refresh questions list
        await _refreshQuestions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question updated successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to edit question: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _addQuestion(Map<String, dynamic> questionData) async {
    if (!mounted) return;

    setState(() {
      _isAddingQuestion = true;
    });

    try {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      questionData['shorts_id'] = args['shortsId'];

      // Get fresh instance of provider
      final provider = Provider.of<Shorts>(context, listen: false);
      await provider.addQuestion(questionData);

      if (mounted) {
        setState(() {
          _isAddingQuestion = false;
        });

        // Refresh the questions list instead of manually adding
        await _refreshQuestions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isAddingQuestion = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding question: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _refreshQuestions() async {
    if (!mounted) return;

    try {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      // Get fresh instance of provider
      final provider = Provider.of<Shorts>(context, listen: false);
      await provider.fetchShortsQuestions(args['shortsId'] as int);

      if (mounted) {
        setState(() {
          questions = provider.questions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh questions: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.grey.shade50,
      appBar: header(context: context, titleText: 'Manage Questions'),
      body: _isLoading
          ? _buildLoadingView(isDark)
          : Column(
              children: [
                _buildHeaderSection(isDark),
                Expanded(child: _buildQuestionsList(isDark)),
                _buildFinishButton(isDark),
              ],
            ),
    );
  }

  Widget _buildLoadingView(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color(0xFF1A1A1A),
                  Color(0xFF2A2A2A),
                  Color(0xFF1E1E1E),
                ]
              : [
                  Colors.purple.shade50,
                  Colors.blue.shade50,
                  Colors.grey.shade50,
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const ShimmerLoading(
                child: SkeletonBox(width: 56, height: 56),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Loading questions...',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isDark) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.blue.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.quiz,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Questions Manager',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${filteredQuestions.length} questions created',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: _isAddingQuestion
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              final result =
                                  await Navigator.of(context).pushNamed(
                                CreateShortsQuestionFormScreen.routeName,
                                arguments: {
                                  'shortsId': (ModalRoute.of(context)!
                                          .settings
                                          .arguments
                                      as Map<String, dynamic>)['shortsId'],
                                },
                              );

                              if (result != null &&
                                  result is Map<String, dynamic>) {
                                _addQuestion(result);
                              }
                            },
                      child: Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isAddingQuestion)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.purple.shade400),
                                ),
                              )
                            else
                              Icon(Icons.add,
                                  color: Colors.purple.shade400, size: 20),
                            SizedBox(width: 8),
                            Text(
                              _isAddingQuestion ? 'Adding...' : 'Add',
                              style: TextStyle(
                                color: Colors.purple.shade400,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(bool isDark) {
    if (filteredQuestions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredQuestions.length,
      itemBuilder: (context, index) {
        final question = filteredQuestions[index];
        return _buildQuestionCard(question, index);
      },
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF2A2A2A) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz_outlined,
              size: 60,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No questions yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start by adding your first question',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final questionText =
        question['question'] as String? ?? '${context.l10n.loading}...';
    final questionType = question['type'] as String? ?? 'Selection';
    final questionTime = question['time']?.toString() ?? '0';
    final answers = question['answers'] as List? ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ExpansionTile(
            tilePadding: EdgeInsets.all(20),
            title: Text(
              questionText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey.shade800,
              ),
            ),
            subtitle: Container(
              margin: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.category,
                    label: questionType,
                    color: Colors.blue.shade400,
                  ),
                  SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.timer,
                    label: '${questionTime}s',
                    color: Colors.orange.shade400,
                  ),
                ],
              ),
            ),
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Color(0xFF2A2A2A) : Colors.grey.shade50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Answer Options:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...List.generate(
                      answers.length,
                      (optionIndex) {
                        final answer = answers[optionIndex];
                        final isCorrect = answer['is_correct'] == 1;
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green.shade50
                                : isDark
                                    ? Color(0xFF333333)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.green.shade300
                                  : isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? Colors.green.shade400
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: isCorrect
                                    ? Icon(Icons.check,
                                        color: Colors.white, size: 14)
                                    : null,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  answer['answer'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isCorrect
                                        ? Colors.green.shade700
                                        : isDark
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade700,
                                    fontWeight: isCorrect
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildActionButton(
                          icon: Icons.edit,
                          label: 'Edit',
                          color: Colors.blue.shade400,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _editQuestion(question);
                          },
                        ),
                        SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.delete,
                          label: 'Delete',
                          color: Colors.red.shade400,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _deleteQuestion(index);
                          },
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade400,
              Colors.orange.shade500,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              HapticFeedback.mediumImpact();
              showScaffoldMessenger(
                context,
                _isFromQuestionScreen
                    ? 'Questions have been managed successfully!'
                    : 'Your shorts has been uploaded successfully!',
              );
              Navigator.of(context)
                  .pushReplacementNamed(ShortsScreen.routeName);
            },
            child: Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isFromQuestionScreen ? Icons.save : Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    _isFromQuestionScreen ? 'Save Changes' : 'Finish',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

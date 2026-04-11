import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/story_creation.dart';
import '../../../utils/debug_logger.dart';

class CreateQuestionScreen extends StatefulWidget {
  static const routeName = '/create-question';

  const CreateQuestionScreen({Key? key}) : super(key: key);

  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  int? _episodeId;
  int? _questionId;
  String _episodeTitle = '';

  final _questionController = TextEditingController();
  final _timeController = TextEditingController(text: '30');
  String _questionType = 'selection';

  final List<AnswerController> _answers = [];

  @override
  void initState() {
    super.initState();
    // Add default 4 answers for selection type
    for (int i = 0; i < 4; i++) {
      _answers.add(AnswerController());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _episodeId = args['episodeId'] as int?;
        _episodeTitle = args['episodeTitle'] as String? ?? '';
        final mode = args['mode'] as String? ?? 'create';
        _isEditMode = mode == 'edit';

        if (_isEditMode) {
          final question = args['question'] as Map<String, dynamic>?;
          if (question != null) {
            _populateQuestionData(question);
          }
        }
      }
    });
  }

  void _populateQuestionData(Map<String, dynamic> question) {
    setState(() {
      _questionId = question['id'];
      _questionController.text = question['question'] ?? '';

      // Map backend type to internal type
      final backendType = question['type'] ?? 'Selection';
      if (backendType == 'Selection') {
        _questionType = 'selection';
      } else if (backendType == 'Input') {
        _questionType = 'fill_in_blanks';
      } else {
        _questionType = 'selection';
      }

      _timeController.text = (question['time'] ?? 120).toString();

      // Clear existing answers
      _answers.clear();

      // Add answers from question data
      final answers = question['answers'] as List? ?? [];
      for (var answer in answers) {
        final controller = AnswerController();
        controller.controller.text = answer['answer'] ?? '';
        controller.isCorrect =
            answer['is_correct'] == true || answer['is_correct'] == 1;
        _answers.add(controller);
      }

      // Ensure at least 4 answers
      while (_answers.length < 4) {
        _answers.add(AnswerController());
      }
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _timeController.dispose();
    for (var answer in _answers) {
      answer.controller.dispose();
    }
    super.dispose();
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

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation
    if (_episodeId == null) {
      _showErrorSnackBar('Episode ID is missing');
      return;
    }

    // Prepare answers based on question type
    List<Map<String, dynamic>> validAnswers;

    if (_questionType == 'true_false') {
      // Auto-populate True/False answers
      final correctAnswer = _answers.firstWhere(
        (a) => a.isCorrect,
        orElse: () => _answers[0],
      );
      final isTrue =
          correctAnswer.controller.text.toLowerCase().contains('true');

      validAnswers = [
        {'answer': 'True', 'is_correct': isTrue},
        {'answer': 'False', 'is_correct': !isTrue},
      ];
    } else {
      // Check if at least one answer is marked as correct
      final hasCorrectAnswer = _answers
          .any((a) => a.isCorrect && a.controller.text.trim().isNotEmpty);
      if (!hasCorrectAnswer) {
        _showErrorSnackBar('Please mark at least one answer as correct');
        return;
      }

      // Filter out empty answers
      validAnswers = _answers
          .where((a) => a.controller.text.trim().isNotEmpty)
          .map((a) => {
                'answer': a.controller.text.trim(),
                'is_correct': a.isCorrect,
              })
          .toList();

      if (validAnswers.length < 2) {
        _showErrorSnackBar('Please provide at least 2 answers');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);

      // Map internal question type to backend expected values
      String backendType;
      if (_questionType == 'selection' || _questionType == 'true_false') {
        backendType = 'Selection';
      } else if (_questionType == 'fill_in_blanks') {
        backendType = 'Input';
      } else {
        backendType = 'Selection';
      }

      if (_isEditMode && _questionId != null) {
        await storyCreation.updateQuestion(
          questionId: _questionId!,
          type: backendType,
          time: int.parse(_timeController.text),
          question: _questionController.text.trim(),
          answers: validAnswers,
        );

        if (mounted) {
          _showSuccessSnackBar('Question updated successfully!');
          Navigator.of(context).pop();
        }
      } else {
        await storyCreation.createQuestion(
          episodeId: _episodeId!,
          type: backendType,
          time: int.parse(_timeController.text),
          question: _questionController.text.trim(),
          answers: validAnswers,
        );

        if (mounted) {
          _showSuccessSnackBar('Question created successfully!');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      DebugLogger.error('Error saving question: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save question: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addAnswer() {
    setState(() {
      _answers.add(AnswerController());
    });
  }

  void _removeAnswer(int index) {
    if (_answers.length <= 2) {
      _showErrorSnackBar('You must have at least 2 answers');
      return;
    }
    setState(() {
      _answers[index].controller.dispose();
      _answers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Question' : 'Add Question'),
        backgroundColor: isDark ? Color(0xFF1E1E1E) : null,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(isDark),
                    if (_episodeTitle.isNotEmpty) ...[
                      SizedBox(height: 16),
                      _buildEpisodeInfoCard(isDark),
                    ],
                    SizedBox(height: 16),
                    _buildQuestionTypeCard(isDark),
                    SizedBox(height: 16),
                    _buildQuestionDetailsCard(isDark),
                    SizedBox(height: 16),
                    _buildOptionsCard(isDark),
                  ],
                ),
              ),
            ),
            _buildSubmitButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isEditMode
              ? [Colors.orange.shade400, Colors.red.shade500]
              : [Colors.purple.shade400, Colors.blue.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isEditMode ? Colors.orange : Colors.purple)
                .withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEditMode ? Icons.edit : Icons.add_circle,
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
                  _isEditMode ? 'Edit Question' : 'Create New Question',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _isEditMode
                      ? 'Modify the question details below'
                      : 'Fill in the details to create your question',
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
    );
  }

  Widget _buildEpisodeInfoCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.movie, color: Colors.blue.shade700, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _episodeTitle,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: Colors.purple.shade400, size: 20),
              SizedBox(width: 8),
              Text(
                'Question Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  'selection',
                  Icons.radio_button_checked,
                  'Selection',
                  isDark,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  'fill_in_blanks',
                  Icons.edit,
                  'Fill in the Blanks',
                  isDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  'true_false',
                  Icons.check_circle,
                  'True/False',
                  isDark,
                ),
              ),
              SizedBox(width: 12),
              Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
      String type, IconData icon, String label, bool isDark) {
    final isSelected = _questionType == type;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _questionType = type;

          // Auto-populate True/False answers
          if (type == 'true_false') {
            _answers.clear();
            final trueAnswer = AnswerController();
            trueAnswer.controller.text = 'True';
            trueAnswer.isCorrect = true;
            _answers.add(trueAnswer);

            final falseAnswer = AnswerController();
            falseAnswer.controller.text = 'False';
            falseAnswer.isCorrect = false;
            _answers.add(falseAnswer);
          } else if (_answers.isEmpty || _answers.length < 2) {
            // Reset to default answers for other types
            _answers.clear();
            for (int i = 0; i < 4; i++) {
              _answers.add(AnswerController());
            }
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.purple.shade50
              : isDark
                  ? Color(0xFF2A2A2A)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.purple.shade300
                : isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.purple.shade400
                  : isDark
                      ? Colors.grey.shade300
                      : Colors.grey.shade400,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.purple.shade700
                    : isDark
                        ? Colors.grey.shade300
                        : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionDetailsCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz, color: Colors.blue.shade400, size: 20),
              SizedBox(width: 8),
              Text(
                'Question Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildCustomTextField(
            controller: _questionController,
            label: 'Question',
            hint: 'Enter your question here...',
            icon: Icons.help_outline,
            maxLines: 3,
            isDark: isDark,
            validator: (value) =>
                value!.isEmpty ? 'Please enter a question' : null,
          ),
          SizedBox(height: 16),
          _buildCustomTextField(
            controller: _timeController,
            label: 'Time Limit (seconds)',
            hint: 'e.g., 120',
            icon: Icons.timer,
            keyboardType: TextInputType.number,
            isDark: isDark,
            validator: (value) =>
                value!.isEmpty ? 'Please enter time limit' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: isDark ? Color(0xFF2A2A2A) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.purple.shade300, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list, color: Colors.green.shade400, size: 20),
              SizedBox(width: 8),
              Text(
                'Answer Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Color(0xFF1B4332) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_answers.length} options',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.green.shade300 : Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...List.generate(
            _answers.length,
            (index) => _buildAnswerField(index, isDark),
          ),
          if (_questionType != 'true_false') ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _addAnswer();
                    },
                    icon: Icon(Icons.add, size: 18),
                    label: Text('Add Option'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade600,
                      side: BorderSide(color: Colors.green.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
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
            colors: _isEditMode
                ? [Colors.orange.shade400, Colors.red.shade500]
                : [Colors.purple.shade400, Colors.blue.shade500],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (_isEditMode ? Colors.orange : Colors.purple)
                  .withValues(alpha: 0.4),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _isLoading
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _submitQuestion();
                  },
            child: Container(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditMode ? Icons.save : Icons.add_task,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          _isEditMode ? 'Update Question' : 'Save Question',
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

  Widget _buildAnswerField(int index, bool isDark) {
    final answer = _answers[index];
    final isCorrect = answer.isCorrect;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? (isDark ? Color(0xFF1B4332) : Colors.green.shade50)
            : isDark
                ? Color(0xFF2A2A2A)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? (isDark ? Colors.green.shade400 : Colors.green.shade300)
              : isDark
                  ? Colors.grey.shade600
                  : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => answer.isCorrect = !answer.isCorrect);
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green.shade400 : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: isCorrect
                  ? Icon(Icons.check, color: Colors.white, size: 16)
                  : Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: answer.controller,
              enabled: _questionType != 'true_false',
              style: TextStyle(
                color: isCorrect
                    ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                    : isDark
                        ? Colors.white
                        : Colors.grey.shade700,
                fontWeight: isCorrect ? FontWeight.w500 : FontWeight.normal,
              ),
              decoration: InputDecoration(
                hintText: 'Option ${index + 1}',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (value) {
                if (_questionType != 'true_false' &&
                    index < 2 &&
                    (value == null || value.isEmpty)) {
                  return 'Please enter option ${index + 1}';
                }
                return null;
              },
            ),
          ),
          if (_questionType != 'true_false' && _answers.length > 2)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _removeAnswer(index);
              },
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.red.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AnswerController {
  final TextEditingController controller = TextEditingController();
  bool isCorrect = false;
}

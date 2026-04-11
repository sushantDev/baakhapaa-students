import 'package:baakhapaa/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateShortsQuestionFormScreen extends StatefulWidget {
  static const routeName = '/create-shorts-question-form';
  final Map<String, dynamic>? questionData;

  CreateShortsQuestionFormScreen({this.questionData});

  @override
  _CreateShortsQuestionFormScreenState createState() =>
      _CreateShortsQuestionFormScreenState();
}

class _CreateShortsQuestionFormScreenState
    extends State<CreateShortsQuestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Selection';
  final _questionController = TextEditingController();
  final _timeController = TextEditingController(text: '10');
  List<TextEditingController> _optionControllers = [];
  int _correctAnswerIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.questionData != null) {
      _questionController.text = widget.questionData!['question'];
      _timeController.text = widget.questionData!['time'].toString();
      _selectedType = widget.questionData!['type'];

      final answers = widget.questionData!['answers'] as List;
      _optionControllers = answers.map((answer) {
        if (answer['is_correct'] == 1) {
          _correctAnswerIndex = answers.indexOf(answer);
        }
        return TextEditingController(text: answer['answer']);
      }).toList();
    } else {
      _optionControllers = List.generate(3, (_) => TextEditingController());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.questionData != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.grey.shade50,
      appBar: header(
        context: context,
        titleText: isEditing ? 'Edit Question' : 'Add Question',
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
                    _buildHeaderCard(isEditing, isDark),
                    SizedBox(height: 16),
                    _buildQuestionTypeCard(isDark),
                    SizedBox(height: 16),
                    _buildQuestionDetailsCard(isDark),
                    SizedBox(height: 16),
                    if (_selectedType == 'Selection')
                      _buildOptionsCard(isDark)
                    else
                      _buildAnswerCard(isDark),
                  ],
                ),
              ),
            ),
            _buildSubmitButton(isEditing, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isEditing, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEditing
              ? [Colors.orange.shade400, Colors.red.shade500]
              : [Colors.purple.shade400, Colors.blue.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isEditing ? Colors.orange : Colors.purple)
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
              isEditing ? Icons.edit : Icons.add_circle,
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
                  isEditing ? 'Edit Question' : 'Create New Question',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isEditing
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
                  'Selection',
                  Icons.radio_button_checked,
                  'Multiple choice question',
                  isDark,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  'Fill in the blanks',
                  Icons.edit,
                  'Text input question',
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
      String type, IconData icon, String description, bool isDark) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedType = type);
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
              type,
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
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.purple.shade600
                    : isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade500,
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
            hint: 'e.g., 10',
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
                  '${_optionControllers.length} options',
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
            _optionControllers.length,
            (index) => _buildOptionField(index, isDark),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(
                        () => _optionControllers.add(TextEditingController()));
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
      ),
    );
  }

  Widget _buildOptionField(int index, bool isDark) {
    final isCorrect = _correctAnswerIndex == index;

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
              setState(() => _correctAnswerIndex = index);
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
              controller: _optionControllers[index],
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
              validator: (value) =>
                  value!.isEmpty ? 'Please enter option ${index + 1}' : null,
            ),
          ),
          if (_optionControllers.length > 2)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _optionControllers.removeAt(index);
                  if (_correctAnswerIndex >= index) {
                    _correctAnswerIndex = _correctAnswerIndex.clamp(
                        0, _optionControllers.length - 1);
                  }
                });
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

  Widget _buildAnswerCard(bool isDark) {
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
              Icon(Icons.text_fields, color: Colors.orange.shade400, size: 20),
              SizedBox(width: 8),
              Text(
                'Correct Answer',
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
            controller: _optionControllers.isNotEmpty
                ? _optionControllers[0]
                : TextEditingController(),
            label: 'Answer',
            hint: 'Enter the correct answer...',
            icon: Icons.check_circle_outline,
            isDark: isDark,
            validator: (value) =>
                value!.isEmpty ? 'Please enter the answer' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isEditing, bool isDark) {
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
            colors: isEditing
                ? [Colors.orange.shade400, Colors.red.shade500]
                : [Colors.purple.shade400, Colors.blue.shade500],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isEditing ? Colors.orange : Colors.purple)
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
            onTap: () {
              HapticFeedback.mediumImpact();
              _submitForm();
            },
            child: Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEditing ? Icons.save : Icons.add_task,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    isEditing ? 'Update Question' : 'Save Question',
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

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      final shortsId = widget.questionData?['shorts_id'] ?? args?['shortsId'];

      final questionData = {
        'type': _selectedType,
        'question': _questionController.text,
        'time': int.parse(_timeController.text),
        'shorts_id': shortsId,
        'answers': _selectedType == 'Selection'
            ? _optionControllers.map((controller) {
                final index = _optionControllers.indexOf(controller);
                return {
                  'answer': controller.text,
                  'is_correct': index == _correctAnswerIndex ? 1 : 0,
                };
              }).toList()
            : [
                {'answer': _optionControllers[0].text, 'is_correct': 1}
              ],
      };

      // Include the id if we're editing
      if (widget.questionData != null) {
        questionData['id'] = widget.questionData!['id'];
      }

      Navigator.of(context).pop(questionData);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _timeController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

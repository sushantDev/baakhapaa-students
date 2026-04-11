import 'package:flutter/material.dart';

class TextInputWordCount extends StatefulWidget {
  final ValueChanged<int> onWordCountChanged;
  final int maxWords;
  final String hintText;
  final String labelText;
  final TextEditingController controller;

  TextInputWordCount({
    required this.onWordCountChanged,
    required this.maxWords,
    required this.hintText,
    required this.labelText,
    required this.controller,
    required String? Function(dynamic value) validator,
  });

  @override
  _TextInputWordCountState createState() => _TextInputWordCountState();
}

class _TextInputWordCountState extends State<TextInputWordCount> {
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_countWords);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_countWords);
    super.dispose();
  }

  void _countWords() {
    String text = widget.controller.text.trim();
    // ignore: deprecated_member_use
    int count = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    setState(() {
      _wordCount = count;
    });
    widget.onWordCountChanged(_wordCount);
  }

  void _handleTextInput(String text) {
    String trimmedText = text.trim();
    int wordCount =
        trimmedText.isEmpty ? 0 : trimmedText.split(RegExp(r'\s+')).length;

    if (wordCount > widget.maxWords) {
      List<String> words =
          trimmedText.split(RegExp(r'\s+')).sublist(0, widget.maxWords);
      String limitedText = words.join(' ');
      widget.controller.value = TextEditingValue(
        text: limitedText,
        selection: TextSelection.fromPosition(
          TextPosition(offset: limitedText.length),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          autofocus: true,
          minLines: 10,
          autocorrect: false,
          controller: widget.controller,
          decoration: InputDecoration(
            labelStyle: TextStyle(color: Colors.amber),
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.amber),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          maxLines: widget.maxWords,
          onChanged: _handleTextInput,
        ),
        Text('Word Count: $_wordCount / ${widget.maxWords}'),
      ],
    );
  }
}

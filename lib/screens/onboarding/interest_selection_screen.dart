import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/auth.dart';
import '../../models/url.dart';
import '../../utils/debug_logger.dart';

class InterestSelectionScreen extends StatefulWidget {
  static const routeName = '/interest-selection';
  final bool isOnboarding;

  const InterestSelectionScreen({Key? key, this.isOnboarding = false})
      : super(key: key);

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final Set<String> _selectedGenres = {};
  List<Map<String, dynamic>> _availableGenres = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final token = auth.token;

      // Fetch available genres
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/user/interests/available')),
            headers: Url.baakhapaaAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final genres = responseData['data']?['genres'] ?? [];
        _availableGenres = List<Map<String, dynamic>>.from(genres);
      }

      // Fetch existing user interests
      final existingResponse = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/user/interests')),
            headers: Url.baakhapaaAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 10));

      final existingData = json.decode(utf8.decode(existingResponse.bodyBytes));
      if (existingData['success'] == true) {
        final interests = existingData['data']?['interests'] ?? [];
        for (var interest in interests) {
          if (interest['genre'] != null) {
            _selectedGenres.add(interest['genre']);
          }
        }
      }
    } catch (e) {
      DebugLogger.error('🎯 Error loading interests: $e');
      // Fallback genres if API fails
      _availableGenres = [
        {
          'genre': 'Self-Help',
          'icon': '🌱',
          'description': 'Personal growth, habits, mindset'
        },
        {
          'genre': 'Business',
          'icon': '💼',
          'description': 'Entrepreneurship, leadership'
        },
        {
          'genre': 'Psychology',
          'icon': '🧠',
          'description': 'Human behavior, thinking'
        },
        {
          'genre': 'Finance',
          'icon': '💰',
          'description': 'Money, investing, economics'
        },
        {
          'genre': 'Science',
          'icon': '🔬',
          'description': 'Biology, physics, technology'
        },
        {
          'genre': 'Philosophy',
          'icon': '🏛️',
          'description': 'Meaning, ethics, wisdom'
        },
        {
          'genre': 'Productivity',
          'icon': '⚡',
          'description': 'Time management, focus'
        },
        {'genre': 'Health', 'icon': '🏃', 'description': 'Fitness, nutrition'},
        {
          'genre': 'Relationships',
          'icon': '💬',
          'description': 'Communication, social skills'
        },
        {
          'genre': 'History',
          'icon': '📜',
          'description': 'World events, civilizations'
        },
        {
          'genre': 'Creativity',
          'icon': '🎨',
          'description': 'Art, writing, innovation'
        },
        {
          'genre': 'Spirituality',
          'icon': '🕊️',
          'description': 'Meditation, mindfulness'
        },
      ];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveInterests() async {
    if (_selectedGenres.length < 3) return;

    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final token = auth.token;

      final response = await http
          .post(
            Uri.parse(Url.baakhapaaApi('/user/interests')),
            headers: {
              ...Url.baakhapaaAuthHeaders(token),
              'Content-Type': 'application/json',
            },
            body: json.encode({'genres': _selectedGenres.toList()}),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        if (mounted) {
          if (widget.isOnboarding) {
            Navigator.of(context).pop(true); // return success to caller
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Interests saved! 📚')),
            );
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (e) {
      DebugLogger.error('🎯 Error saving interests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save interests')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber))
            : Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (!widget.isOnboarding)
                          Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'What do you love reading?',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pick 3-5 topics to personalize your feed',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Genre grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _availableGenres.length,
                        itemBuilder: (ctx, index) {
                          final genre = _availableGenres[index];
                          final isSelected =
                              _selectedGenres.contains(genre['genre']);
                          return _buildGenreCard(genre, isSelected);
                        },
                      ),
                    ),
                  ),

                  // Bottom button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedGenres.length >= 3 && !_isSaving
                            ? _saveInterests
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              Colors.amber.withValues(alpha: 0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : Text(
                                _selectedGenres.length >= 3
                                    ? 'Continue (${_selectedGenres.length} selected)'
                                    : 'Select at least 3',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGenreCard(Map<String, dynamic> genre, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          final g = genre['genre'] as String;
          if (isSelected) {
            _selectedGenres.remove(g);
          } else if (_selectedGenres.length < 5) {
            _selectedGenres.add(g);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? Colors.amber : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              genre['icon'] ?? '📖',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              genre['genre'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.amber : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              genre['description'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white38,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class BottomWelcomeSection extends StatefulWidget {
  const BottomWelcomeSection({Key? key}) : super(key: key);

  @override
  State<BottomWelcomeSection> createState() => _BottomWelcomeSectionState();
}

class _BottomWelcomeSectionState extends State<BottomWelcomeSection> {
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    _checkIfShown();
  }

  void _checkIfShown() {
    setState(() {
      _showWelcome = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showWelcome) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0602),
        // Removed top border for connector continuity
      ),
      child: Stack(
        children: [
          // Welcome content
          Padding(
            padding: const EdgeInsets.only(
                right: 32), // Add padding to avoid overlap with close button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 4),
                Text(
                  'Welcome',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete the tasks to level up and earn rewards.\nEvery task you complete brings you closer to your next reward.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

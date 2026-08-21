import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bootcamp.dart';
import 'bootcamp_video_screen.dart';

class BootcampDetailScreen extends StatefulWidget {
  static const routeName = '/bootcamp-detail';

  final Bootcamp bootcamp;

  const BootcampDetailScreen({Key? key, required this.bootcamp})
      : super(key: key);

  @override
  State<BootcampDetailScreen> createState() => _BootcampDetailScreenState();
}

class _BootcampDetailScreenState extends State<BootcampDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF596273);

    final bootcamp = widget.bootcamp;

    return Scaffold(
      appBar: AppBar(title: Text(bootcamp.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF17191D) : const Color(0xFFF3F6F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bootcamp.durationDays} DAYS',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2E7D6B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bootcamp.title,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bootcamp.description,
                  style: TextStyle(color: mutedColor, height: 1.4),
                ),
                const SizedBox(height: 18),
                _InfoLine(
                  icon: Icons.groups_outlined,
                  label: 'Conducted by',
                  value: bootcamp.conductedBy,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose a location',
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...bootcamp.locations.map(
            (location) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isDark ? const Color(0xFF17191D) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).pushNamed(
                        BootcampVideoScreen.routeName,
                        arguments: {
                          'bootcamp': bootcamp,
                          'location': location,
                        },
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF2E7D6B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF2E7D6B)),
        const SizedBox(width: 9),
        Text('$label: ', style: TextStyle(color: mutedColor, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

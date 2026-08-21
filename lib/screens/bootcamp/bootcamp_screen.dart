import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bootcamp.dart';
import 'bootcamp_detail_screen.dart';

class BootcampScreen extends StatelessWidget {
  static const routeName = '/bootcamp';

  const BootcampScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF596273);

    return Scaffold(
      appBar: AppBar(title: const Text('Bootcamp')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Choose your learning sprint',
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore a guided course experience built around your pace.',
            style: TextStyle(color: mutedColor, height: 1.4),
          ),
          const SizedBox(height: 20),
          ...BootcampCatalog.all.map(
            (bootcamp) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BootcampCard(bootcamp: bootcamp),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootcampCard extends StatelessWidget {
  final Bootcamp bootcamp;

  const _BootcampCard({required this.bootcamp});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final accent = bootcamp.durationDays == 4
        ? const Color(0xFF2E7D6B)
        : bootcamp.durationDays == 7
            ? const Color(0xFF2864A8)
            : const Color(0xFFB56A2D);

    return Material(
      color: isDark ? const Color(0xFF17191D) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pushNamed(
          BootcampDetailScreen.routeName,
          arguments: bootcamp,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${bootcamp.durationDays}',
                    style: GoogleFonts.poppins(
                      color: accent,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bootcamp.title,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      bootcamp.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${bootcamp.location}  ·  ${bootcamp.conductedBy}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

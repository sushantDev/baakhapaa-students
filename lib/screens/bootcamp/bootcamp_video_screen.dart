import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bootcamp.dart';
import '../../widgets/simple_youtube_player.dart';
import '../../widgets/footer.dart';
import '../../widgets/comments_sheet.dart';

class BootcampVideoScreen extends StatefulWidget {
  static const routeName = '/bootcamp-video';

  final Bootcamp bootcamp;
  final String location;

  const BootcampVideoScreen({
    Key? key,
    required this.bootcamp,
    required this.location,
  }) : super(key: key);

  @override
  State<BootcampVideoScreen> createState() => _BootcampVideoScreenState();
}

class _BootcampVideoScreenState extends State<BootcampVideoScreen> {
  BootcampContent? _selectedChapter;
  int _selectedDay = 1;
  bool _showResources = false;

  @override
  void initState() {
    super.initState();
    _selectedChapter = _firstCourseForDay(_selectedDay);
  }

  BootcampContent? _firstCourseForDay(int dayNumber) {
    for (final content in widget.bootcamp.contents) {
      if (content.dayNumber == dayNumber) return content;
    }
    return null;
  }

  void _selectDay(int dayNumber) {
    setState(() {
      _selectedDay = dayNumber;
      _selectedChapter = _firstCourseForDay(dayNumber);
    });
  }

  void _selectChapter(BootcampContent content) {
    setState(() => _selectedChapter = content);
  }

  @override
  Widget build(BuildContext context) {
    final bootcamp = widget.bootcamp;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF596273);
    final pageColor =
        isDark ? const Color(0xFF111315) : const Color(0xFFF8F8F6);
    final panelColor = isDark ? const Color(0xFF202326) : Colors.white;
    final footerInset = Footer.contentBottomInset(
      context,
      routeName: BootcampVideoScreen.routeName,
    );

    final selectedDayContents = bootcamp.contents
        .where((content) => content.dayNumber == _selectedDay)
        .toList();
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(title: Text(bootcamp.title)),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 32 + footerInset),
        child: Column(
          children: [
            if (_selectedChapter != null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE5E3DC),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InlineVideoHeader(
                      chapter: _selectedChapter!,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SimpleYouTubePlayer(
                        videoId: _selectedChapter!.videoId ?? 'M7lc1UVf-VE',
                        autoPlay: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.forum_outlined, size: 18),
                      label: const Text('Discussions'),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => CommentsSheet(
                          shortsId: _selectedChapter!.seasonId,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CatalogTab(
                    label: 'Lessons',
                    selected: !_showResources,
                    isDark: isDark,
                    onTap: () => setState(() => _showResources = false),
                  ),
                ),
                Expanded(
                  child: _CatalogTab(
                    label: 'Resources',
                    selected: _showResources,
                    isDark: isDark,
                    onTap: () => setState(() => _showResources = true),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          bootcamp.durationDays,
                          (index) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _DayPill(
                              dayNumber: index + 1,
                              selected: _selectedDay == index + 1,
                              isDark: isDark,
                              onTap: () => _selectDay(index + 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DayRangeDropdown(
                    selectedDay: _selectedDay,
                    durationDays: bootcamp.durationDays,
                    isDark: isDark,
                    onChanged: _selectDay,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _showResources
                  ? _ResourcesSection(
                      bootcamp: bootcamp,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      isDark: isDark,
                      selectedDay: _selectedDay,
                    )
                  : _LessonList(
                      chapters: selectedDayContents,
                      selectedChapter: _selectedChapter,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      isDark: isDark,
                      onChapterTap: _selectChapter,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _CatalogTab({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
            color: selected
                ? const Color(0xFFE5B900)
                : (isDark ? const Color(0xFF3A3E42) : const Color(0xFFE5E5E5)),
            width: selected ? 3 : 1,
          )),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected
                  ? (isDark ? Colors.white : const Color(0xFF171717))
                  : (isDark ? Colors.white70 : const Color(0xFF596273)),
              fontWeight: FontWeight.w800,
            )),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final int dayNumber;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _DayPill({
    required this.dayNumber,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFE9B900)
          : (isDark ? const Color(0xFF2A2E32) : const Color(0xFFE8E8E8)),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text('Day $dayNumber',
              style: TextStyle(
                color: selected
                    ? const Color(0xFF171717)
                    : (isDark ? Colors.white70 : const Color(0xFF30343B)),
                fontWeight: FontWeight.w700,
              )),
        ),
      ),
    );
  }
}

class _LessonList extends StatelessWidget {
  final List<BootcampContent> chapters;
  final BootcampContent? selectedChapter;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final ValueChanged<BootcampContent> onChapterTap;

  const _LessonList(
      {required this.chapters,
      required this.selectedChapter,
      required this.textColor,
      required this.mutedColor,
      required this.isDark,
      required this.onChapterTap});

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return Text('Lessons will be available soon.',
          style: TextStyle(color: mutedColor));
    }

    return Column(
      children: chapters.asMap().entries.map((entry) {
        final chapter = entry.value;
        final selected = selectedChapter == null
            ? entry.key == 0
            : identical(chapter, selectedChapter);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected
                ? const Color(0xFFE9B900)
                : (isDark ? const Color(0xFF24282C) : const Color(0xFFE7E7E7)),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onChapterTap(chapter),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                        width: 24,
                        child: Text('${entry.key + 1}',
                            style: TextStyle(color: textColor))),
                    Expanded(
                        child: Text(chapter.title,
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600))),
                    IconButton(
                      tooltip: 'Open lesson',
                      onPressed: () => onChapterTap(chapter),
                      icon: Icon(Icons.folder_outlined, color: textColor),
                    ),
                    IconButton(
                      tooltip: 'Play lesson',
                      onPressed: () => onChapterTap(chapter),
                      icon: Icon(Icons.play_arrow_rounded, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DayRangeDropdown extends StatelessWidget {
  final int selectedDay;
  final int durationDays;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _DayRangeDropdown({
    required this.selectedDay,
    required this.durationDays,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2E32) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF42474C) : const Color(0xFFE0DED7),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedDay,
          borderRadius: BorderRadius.circular(10),
          dropdownColor: isDark ? const Color(0xFF24282C) : Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF30343B),
          ),
          onChanged: (day) => onChanged(day ?? selectedDay),
          items: List.generate(
            durationDays,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text(
                '${(index + 1).toString().padLeft(2, '0')} - ${durationDays.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF30343B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineVideoHeader extends StatelessWidget {
  final BootcampContent chapter;
  final Color textColor;
  final Color mutedColor;

  const _InlineVideoHeader({
    required this.chapter,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chapter.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          chapter.description,
          style: TextStyle(color: mutedColor, fontSize: 13),
        ),
      ],
    );
  }
}

class _ResourcesSection extends StatelessWidget {
  final Bootcamp bootcamp;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final int selectedDay;

  const _ResourcesSection({
    required this.bootcamp,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resources',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        ...List.generate(bootcamp.durationDays, (index) {
          final dayNumber = index + 1;
          final dayCourses = bootcamp.contents
              .where((content) => content.dayNumber == dayNumber)
              .toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202428) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE5E3DC),
              ),
            ),
            child: ExpansionTile(
              initiallyExpanded: dayNumber == selectedDay,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              iconColor: const Color(0xFF2E7D6B),
              collapsedIconColor: mutedColor,
              title: Text(
                'Day $dayNumber',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${dayCourses.length} ${dayCourses.length == 1 ? 'course' : 'courses'}',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
              children: dayCourses.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          'Resources will be available soon.',
                          style: TextStyle(color: mutedColor, fontSize: 13),
                        ),
                      ),
                    ]
                  : dayCourses
                      .map(
                        (course) => _CourseResources(
                          course: course,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          isDark: isDark,
                        ),
                      )
                      .toList(),
            ),
          );
        }),
      ],
    );
  }
}

class _CourseResources extends StatelessWidget {
  final BootcampContent course;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;

  const _CourseResources({
    required this.course,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.title,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...course.courseResources.map(
            (resource) => Card(
              color: isDark ? const Color(0xFF2A2E32) : const Color(0xFFF8F8F6),
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF2E7D6B),
                ),
                title: Text(
                  resource.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  resource.description,
                  style: TextStyle(color: mutedColor),
                ),
                trailing: resource.url == null
                    ? null
                    : const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: resource.url == null
                    ? null
                    : () async {
                        final uri = Uri.tryParse(resource.url!);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

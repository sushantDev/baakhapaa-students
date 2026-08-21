class BootcampResource {
  final String title;
  final String description;
  final String? url;

  const BootcampResource({
    required this.title,
    required this.description,
    this.url,
  });
}

class BootcampContent {
  final int dayNumber;
  final int seasonId;
  final String title;
  final String description;
  final String contentType;
  final String? videoId;
  final String? thumbnail;
  final List<BootcampResource> resources;

  const BootcampContent({
    required this.dayNumber,
    required this.seasonId,
    required this.title,
    required this.description,
    this.contentType = 'video',
    this.videoId = 'M7lc1UVf-VE',
    this.thumbnail,
    this.resources = const [],
  });

  List<BootcampResource> get courseResources {
    if (resources.isNotEmpty) return resources;

    return [
      BootcampResource(
        title: '$title notes',
        description: 'Downloadable notes and activities for this course.',
      ),
    ];
  }

  Map<String, dynamic> toSeasonMap() {
    return {
      'id': seasonId,
      'title': title,
      'description': description,
      'content_type': contentType,
      'video_id': videoId,
      'thumbnail': thumbnail,
      'resources': courseResources
          .map(
            (resource) => {
              'title': resource.title,
              'description': resource.description,
              'url': resource.url,
            },
          )
          .toList(),
      'is_locked': false,
      'watched': false,
      'episodes': const <dynamic>[],
    };
  }
}

class Bootcamp {
  final int durationDays;
  final String title;
  final List<String> locations;
  final String conductedBy;
  final String description;
  final List<BootcampContent> contents;

  const Bootcamp({
    required this.durationDays,
    required this.title,
    required this.locations,
    required this.conductedBy,
    required this.description,
    required this.contents,
  });

  String get location =>
      locations.isEmpty ? 'Location to be announced' : locations.first;
}

class BootcampCatalog {
  static const List<Bootcamp> all = [
    Bootcamp(
      durationDays: 4,
      title: '4-Days Bootcamp',
      locations: const [
        'Bhakti Namuna - Sundarbazaar',
        'Amar Jyoti - Palungtar',
      ],
      conductedBy: 'Baakhapaa',
      description: 'A focused start for building strong learning habits.',
      contents: [
        BootcampContent(
          dayNumber: 1,
          seasonId: 4001,
          title: 'Start With Clarity',
          description: 'Build a simple plan for your learning journey.',
          resources: const [
            BootcampResource(
              title: 'Learning plan worksheet',
              description: 'A simple worksheet for planning your week.',
            ),
          ],
        ),
        BootcampContent(
          dayNumber: 1,
          seasonId: 4011,
          title: 'Set Your Learning Goals',
          description: 'Turn a broad idea into a clear, achievable goal.',
        ),
        BootcampContent(
          dayNumber: 1,
          seasonId: 4012,
          title: 'Map Your Starting Point',
          description: 'Understand what you know before you begin.',
        ),
        BootcampContent(
          dayNumber: 1,
          seasonId: 4013,
          title: 'Build A Study Rhythm',
          description: 'Create a practical rhythm for focused learning.',
        ),
        BootcampContent(
          dayNumber: 1,
          seasonId: 4014,
          title: 'Reflect On Your Progress',
          description: 'Use a short reflection to decide your next step.',
        ),
        BootcampContent(
          dayNumber: 2,
          seasonId: 4002,
          title: 'Learn By Doing',
          description: 'Turn ideas into small, practical actions.',
        ),
        BootcampContent(
          dayNumber: 2,
          seasonId: 4021,
          title: 'Define The Product Strategy Grid',
          description: 'Organize your ideas around a useful strategy grid.',
          resources: const [
            BootcampResource(
              title: 'Strategy grid template',
              description: 'A printable template for the strategy activity.',
            ),
          ],
        ),
        BootcampContent(
          dayNumber: 2,
          seasonId: 4022,
          title: 'Understand Your Audience',
          description: 'Identify the people your idea is designed to help.',
        ),
        BootcampContent(
          dayNumber: 2,
          seasonId: 4023,
          title: 'Choose The Core Problem',
          description: 'Focus your effort on the problem that matters most.',
        ),
        BootcampContent(
          dayNumber: 2,
          seasonId: 4024,
          title: 'Test Your First Assumption',
          description: 'Plan a small test before building the full solution.',
        ),
        BootcampContent(
          dayNumber: 3,
          seasonId: 4003,
          title: 'Build Your Routine',
          description: 'Create a learning routine you can keep.',
        ),
        BootcampContent(
          dayNumber: 4,
          seasonId: 4004,
          title: 'Show Your Progress',
          description: 'Complete a small project and reflect on the result.',
        ),
      ],
    ),
    Bootcamp(
      durationDays: 7,
      title: '7-Days Bootcamp',
      locations: const [
        'Pokhara Community Center',
        'Gandaki Boarding School',
      ],
      conductedBy: 'Baakhapaa',
      description: 'A one-week path to practice, reflect, and improve.',
      contents: [
        BootcampContent(
          dayNumber: 1,
          seasonId: 7001,
          title: 'The Practice Loop',
          description: 'Create a repeatable rhythm for meaningful progress.',
        ),
        BootcampContent(
          dayNumber: 2,
          seasonId: 7002,
          title: 'Think Better',
          description: 'Use questions and feedback to sharpen your thinking.',
        ),
        BootcampContent(
          dayNumber: 3,
          seasonId: 7003,
          title: 'Share Your Work',
          description: 'Communicate what you learned with confidence.',
        ),
        BootcampContent(
          dayNumber: 4,
          seasonId: 7004,
          title: 'Solve Problems',
          description: 'Break a difficult task into useful next steps.',
        ),
        BootcampContent(
          dayNumber: 5,
          seasonId: 7005,
          title: 'Work With Feedback',
          description: 'Use feedback to improve your next attempt.',
        ),
        BootcampContent(
          dayNumber: 6,
          seasonId: 7006,
          title: 'Create With Purpose',
          description: 'Turn your learning into something useful.',
        ),
        BootcampContent(
          dayNumber: 7,
          seasonId: 7007,
          title: 'Finish Strong',
          description: 'Review your progress and plan what comes next.',
        ),
      ],
    ),
    Bootcamp(
      durationDays: 10,
      title: '10-Days Bootcamp',
      locations: const [
        'Lalitpur Learning Center',
        'Patan Academy Hall',
      ],
      conductedBy: 'Baakhapaa',
      description: 'A deeper challenge for learners ready to go further.',
      contents: [
        BootcampContent(
          dayNumber: 1,
          seasonId: 10001,
          title: 'Find Your Direction',
          description: 'Connect your interests with a practical goal.',
        ),
        BootcampContent(
          dayNumber: 2,
          seasonId: 10002,
          title: 'Build Consistency',
          description: 'Design a routine that can survive busy days.',
        ),
        BootcampContent(
          dayNumber: 3,
          seasonId: 10003,
          title: 'Make It Real',
          description: 'Complete a small project that proves your progress.',
        ),
        BootcampContent(
          dayNumber: 4,
          seasonId: 10004,
          title: 'Learn From Setbacks',
          description: 'Turn mistakes into a better plan.',
        ),
        BootcampContent(
          dayNumber: 5,
          seasonId: 10005,
          title: 'Build Momentum',
          description: 'Use small wins to keep moving forward.',
        ),
        BootcampContent(
          dayNumber: 6,
          seasonId: 10006,
          title: 'Practice Deep Work',
          description: 'Protect time for focused learning.',
        ),
        BootcampContent(
          dayNumber: 7,
          seasonId: 10007,
          title: 'Collaborate Well',
          description: 'Learn faster by working with others.',
        ),
        BootcampContent(
          dayNumber: 8,
          seasonId: 10008,
          title: 'Make Better Decisions',
          description: 'Choose the next step with clarity.',
        ),
        BootcampContent(
          dayNumber: 9,
          seasonId: 10009,
          title: 'Prepare Your Project',
          description: 'Bring your ideas together into a clear plan.',
        ),
        BootcampContent(
          dayNumber: 10,
          seasonId: 10010,
          title: 'Share The Outcome',
          description: 'Present what you built and what you learned.',
        ),
      ],
    ),
  ];
}

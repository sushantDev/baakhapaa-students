# Baakhapaa — Deepstash-Style Readable Stories + AI Auto-Generation

## Implementation Plan

**Date:** March 12, 2026  
**Scope:** Backend (Laravel 11) + Frontend (Flutter 3)  
**Status:** 🟡 Planning

---

## Overview

Transform Baakhapaa's story mode to support **readable book summaries** (Deepstash-style swipeable insight cards) alongside existing video episodes. Add an **AI content pipeline** (OpenAI GPT-4o for text + Google Gemini for images) that auto-generates 1 book summary per day via a scheduled Laravel cron command. Integrate **on-device Text-to-Speech** (`flutter_tts`) for audio narration with English + Nepali support.

### What's Being Built

| Feature                                               | Type                      | Priority |
| ----------------------------------------------------- | ------------------------- | -------- |
| Readable book summaries as swipeable cards            | Frontend + Backend        | P0       |
| AI pipeline auto-generating 1 story/day               | Backend                   | P0       |
| AI image generation (book cover + card illustrations) | Backend                   | P0       |
| Text-to-Speech for card narration                     | Frontend                  | P1       |
| Nepali content & TTS                                  | Backend + Frontend        | P1       |
| Post-reading Quiz/Crossword/Puzzle flow               | Frontend (reuse existing) | P0       |
| Reading streaks (daily habit system)                  | Backend + Frontend        | P0       |
| User book request system                              | Backend + Frontend        | P1       |
| Interest-based onboarding & personalization           | Backend + Frontend        | P1       |
| Home screen widget (Duolingo-style streak display)    | Frontend (native)         | P2       |

### Key Design Decisions

- **Content type lives on the Season level** — a season is either fully `video` or fully `readable`, no mixing
- **Horizontal swiping** for readable cards (Deepstash-style) vs vertical swiping for Shorts — distinct UX
- **OpenAI GPT-4o** for text generation (JSON structured output) + **Google Gemini** for images (cost-efficient)
- **Reuse existing quiz screens** — `QuestionScreen`, `CrosswordScreen`, `ImagePuzzleScreen` need zero changes
- **Multi-source book pipeline** — curated seeder + user requests + trending lists + AI suggestions
- **AI generates English + Nepali in a single API call** — no separate translation step
- **On-device TTS only** via `flutter_tts` — free, offline-capable; Nepali supported on most Android devices via Google TTS
- **Reading streaks extend existing daily rewards** — reuse `DailyRewardController` / `user_daily_rewards` patterns
- **Home screen widget** via `home_widget` package — proven Duolingo retention mechanic

---

## Revenue Model & Value Proposition

### How This Generates Revenue

The readable book summaries feature plugs directly into **4 existing monetization channels** already in the app:

| Revenue Channel            | How Books Drive It                                                                                                                                 | Existing Infrastructure                                                             |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Coin Economy**           | Users spend coins to unlock chapters (same as video episodes). AI generates content at ~$0.17/day but each book earns coins from hundreds of users | `UserInformation.available_coins`, `CoinLog`, episode unlock flow                   |
| **Subscriptions**          | Silver/Gold/Platinum tiers get unlimited reading. Free users get 1-2 free chapters per book, then pay coins                                        | `SubscriptionController`, `SubscriptionUser`, benefit usage tracking                |
| **Ads (AdMob)**            | Interstitial ads between chapters for free-tier users. Subscribers = ad-free                                                                       | `ad_service.dart`, existing AdMob integration                                       |
| **Engagement → Retention** | Reading streaks + quizzes increase DAU/MAU. Higher retention = higher LTV per user = better ad revenue + subscription conversion                   | `DailyRewardController`, `LevelProgressionService`, `AchievementProgressionService` |

### Free vs Paid User Experience

```
Free User:
  Chapter 1 → Free (hook them)
  Chapter 2 → Free (build habit)
  Chapter 3+ → Unlock with coins
  Quiz → Always free (engagement driver)
  TTS → Available (drives session time)
  Streak → Available (drives daily return)

Subscriber (Silver/Gold/Platinum):
  books → limited as count from backend
  No ads between chapters
  Priority access to new daily books
  Exclusive "deep dive" extended chapters
  TTS → Premium voices (future)
```

### User Value — Helping Users Perform Better

| Value               | How                                                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| **Learn faster**    | Bite-sized insight cards (Deepstash-proven format) — absorb a book's key ideas in 10-15 minutes |
| **Active recall**   | Quiz after each chapter forces retention (proven learning technique)                            |
| **Daily habit**     | Reading streaks build consistent learning habits                                                |
| **Accessibility**   | TTS lets users "read" during commute, cooking, exercise                                         |
| **Nepali market**   | First platform offering Deepstash-style book summaries in Nepali — no competition               |
| **Gamification**    | Coins, levels, achievements, streaks — makes learning addictive                                 |
| **Personalization** | Interest-based onboarding ensures users see books relevant to their goals                       |

### Projected ROI

| Metric                         | Value                                                              |
| ------------------------------ | ------------------------------------------------------------------ |
| AI content cost                | ~$5.10/month (1 book/day)                                          |
| Content library after 3 months | 90 books                                                           |
| Content library after 1 year   | 365 books                                                          |
| Break-even                     | ~10 active subscribers at lowest tier OR ~500 daily ad impressions |
| Competitive advantage          | Only Nepali-language book summary platform with gamification       |

### Book Sourcing Strategy

Books are sourced from **4 channels**, ensuring an ever-growing library:

| Source             | How                                                                                                             | When         | Volume       |
| ------------------ | --------------------------------------------------------------------------------------------------------------- | ------------ | ------------ |
| **Curated seeder** | 50 hand-picked bestsellers (Atomic Habits, Sapiens, Deep Work, etc.)                                            | Day 1 launch | 50 books     |
| **User requests**  | Users submit via "Request a Book" button (Phase 7). Admin approves → feeds into `book_topics` table             | Ongoing      | ~5-10/week   |
| **Trending lists** | Admin manually adds from Goodreads/Amazon bestseller lists monthly, or future: automated scraping               | Monthly      | ~10-20/month |
| **AI suggestion**  | After curated list is exhausted (~50 days), GPT-4o suggests next books based on user interest data + genre gaps | After day 60 | Unlimited    |

This removes single-source dependency and ensures content always matches user demand.

---

## Architecture

```
Content Pipeline
   ├── BookTopic Sources
   │     ├── Curated seeder (50 bestsellers at launch)
   │     ├── User requests (Phase 7) → admin approval → book_topics
   │     ├── Trending lists (admin adds monthly)
   │     └── AI suggestions (after curated list exhausted)
   │
   ├── Auto-generation Pipeline (daily 03:00 cron)
   │     ├── OpenAIService (GPT-4o JSON mode)
   │     │     └── season metadata, chapters[], pages[], key_points, summary, questions[], Nepali translations
   │     ├── GeminiImageService
   │     │     └── book cover + per-card illustration → upload to DigitalOcean Spaces
   │     └── ContentGenerationPipeline (DB::transaction)
   │           └── Season → Episodes → EpisodePages → Questions → AIGenerationLog
   │
   └── Personalization Layer
         ├── user_interests (onboarding Phase 8)
         └── Sorted books feed based on genre preferences

Flutter Reading Flow
   StoryScreen (Books tab — personalized by interests)
      └── EpisodeScreen (Chapter list, reading_time_minutes)
            └── ReadableEpisodeScreen (horizontal PageView)
                  ├── ReadablePageCard (gradient card, title, content, image)
                  ├── SummaryPageCard (key points, Take Quiz CTA)
                  ├── TtsControlBar (play/pause, speed, EN/NE language)
                  └── → QuestionScreen / CrosswordScreen / ImagePuzzleScreen (existing)

Engagement & Retention Loop
   ├── Reading Streaks (Phase 6) → daily reading habit + coin rewards
   ├── Home Screen Widget (Phase 9) → 🔥 streak + today's book reminder
   ├── Push Notifications → "New book today!" + streak-about-to-break alerts
   └── Interest-based Onboarding (Phase 8) → personalized book feed
```

---

## Phase 1: Backend Schema & Models

> **No dependencies — can start immediately**

### Step 1.1 — Add `content_type` to Seasons

**Migration:** `add_content_type_to_seasons_table`

```php
Schema::table('seasons', function (Blueprint $table) {
    $table->enum('content_type', ['video', 'readable'])->default('video')->after('description');
    $table->string('book_title')->nullable()->after('content_type');
    $table->string('book_author')->nullable()->after('book_title');
    $table->string('source_reference')->nullable()->after('book_author'); // attribution URL or ISBN
});
```

**Update `app/Season.php`:**

- Add `content_type`, `book_title`, `book_author`, `source_reference` to `$fillable`

**Files to touch:**

- `database/migrations/xxxx_add_content_type_to_seasons.php` _(create)_
- `app/Season.php` _(modify)_

---

### Step 1.2 — Create `episode_pages` Table & Model

**Migration:** `create_episode_pages_table`

```php
Schema::create('episode_pages', function (Blueprint $table) {
    $table->id();
    $table->foreignId('episode_id')->constrained()->cascadeOnDelete();
    $table->unsignedSmallInteger('page_number');
    $table->string('title');
    $table->text('content');
    $table->string('image_url')->nullable();
    $table->boolean('is_summary')->default(false);     // final summary card
    $table->boolean('is_key_point')->default(false);   // key insight card
    $table->string('nepali_title')->nullable();
    $table->text('nepali_content')->nullable();
    $table->timestamps();
    $table->softDeletes();
    $table->index(['episode_id', 'page_number']);
});
```

**New `app/EpisodePage.php` model:**

```php
class EpisodePage extends Model {
    use SoftDeletes;
    protected $fillable = ['episode_id', 'page_number', 'title', 'content',
        'image_url', 'is_summary', 'is_key_point', 'nepali_title', 'nepali_content'];
    public function episode() { return $this->belongsTo(Episode::class); }
}
```

**Migration:** `add_reading_time_to_episodes_table`

```php
Schema::table('episodes', function (Blueprint $table) {
    $table->unsignedSmallInteger('reading_time_minutes')->nullable()->after('duration');
});
```

**Update `app/Episode.php`:**

- Add `pages()` HasMany → EpisodePage
- Add `reading_time_minutes` to `$fillable`
- Make `video_url` nullable in validation

**Files to touch:**

- `database/migrations/xxxx_create_episode_pages_table.php` _(create)_
- `database/migrations/xxxx_add_reading_time_to_episodes.php` _(create)_
- `app/EpisodePage.php` _(create)_
- `app/Episode.php` _(modify)_

---

### Step 1.3 — API Endpoints for Readable Content

**New `app/Http/Controllers/api/EpisodePageController.php`:**

| Method | Route                                     | Action                                       |
| ------ | ----------------------------------------- | -------------------------------------------- |
| GET    | `/api/episode/{episodeId}/pages`          | `index` — all pages ordered by `page_number` |
| POST   | `/api/episode/{episodeId}/pages`          | `store` — create page(s)                     |
| PUT    | `/api/episode/{episodeId}/pages/{pageId}` | `update` — edit a page                       |
| DELETE | `/api/episode/{episodeId}/pages/{pageId}` | `destroy` — soft delete                      |

**Update `SeasonController`:**

- Accept `?content_type=readable|video` filter in `index()`
- Include `content_type`, `book_title`, `book_author` in all season responses

**Update `EpisodeController`:**

- Load `pages` relationship when parent season `content_type == 'readable'`
- Make `video_url` optional in validation rules for readable episodes
- Include `reading_time_minutes` in episode responses

**New route addition in `routes/api.php`:**

```php
Route::middleware(['auth:api'])->group(function () {
    Route::get('episode/{episodeId}/pages', [EpisodePageController::class, 'index']);
    Route::post('episode/{episodeId}/pages', [EpisodePageController::class, 'store']);
    Route::put('episode/{episodeId}/pages/{pageId}', [EpisodePageController::class, 'update']);
    Route::delete('episode/{episodeId}/pages/{pageId}', [EpisodePageController::class, 'destroy']);
});
```

**Files to touch:**

- `app/Http/Controllers/api/EpisodePageController.php` _(create)_
- `app/Http/Controllers/api/SeasonController.php` _(modify)_
- `app/Http/Controllers/api/EpisodeController.php` _(modify)_
- `routes/api.php` _(modify)_

---

### Phase 1 Verification

```bash
php artisan migrate
# Verify: episode_pages table exists with all columns

# Via Tinker
$season = Season::create(['title' => 'Test Book', 'content_type' => 'readable', 'book_author' => 'Test Author', ...]);
# Hit: GET /api/v3/seasons?content_type=readable  → should return the season
# Hit: GET /api/episode/1/pages                  → should return []
```

---

## Phase 2: AI Content Generation Pipeline

> **Depends on Phase 1 completing first**

### Step 2.1 — AI Service Layer

#### `app/Services/AI/OpenAIService.php`

Wraps the `openai-php/laravel` package. Single method: `generateBookContent(string $bookTitle, string $author): array`

Returns structured JSON (enforced via GPT-4o JSON mode):

```json
{
  "season": {
    "title": "...", "description": "...", "nepali_description": "...",
    "book_title": "...", "book_author": "...", "source_reference": "..."
  },
  "chapters": [
    {
      "title": "...", "description": "...", "nepali_title": "...", "reading_time_minutes": 3,
      "pages": [
        {
          "page_number": 1, "title": "...", "content": "...",
          "nepali_title": "...", "nepali_content": "...",
          "is_summary": false, "is_key_point": false,
          "image_prompt": "..."
        }
      ],
      "summary_page": { "title": "Key Takeaways", "content": "...", "nepali_title": "...", "nepali_content": "..." },
      "questions": [
        {
          "type": "Selection", "question": "...", "time": 30,
          "answers": [{"text": "...", "is_correct": false}, ...]
        }
      ]
    }
  ]
}
```

System prompt instructs GPT-4o to:

- Generate 3-6 chapters per book (each = 1 episode)
- 4-8 insight cards per chapter
- 1 summary card per chapter with bullet-point key takeaways
- 3 quiz questions per chapter (Selection + True/False types)
- All content in both English and Nepali
- Include `image_prompt` field per page for Gemini image generation

#### `app/Services/AI/GeminiImageService.php`

Wraps Google Gemini API (`gemini-2.0-flash-exp` or Imagen 3):

- `generateAndUpload(string $prompt, string $filename): string` — generates image, uploads to DigitalOcean Spaces, returns public URL
- Called for: book cover (1) + per-chapter header image (1 per chapter)
- Uses existing `Storage::disk('do_spaces')` for upload

#### `app/Services/AI/ContentGenerationPipeline.php`

Orchestrator service:

```
1. Pick next BookTopic where is_generated = false, ordered by priority DESC
2. Create AIGenerationLog (status: 'processing')
3. Call OpenAIService::generateBookContent() → structured JSON
4. Call GeminiImageService for book cover → get URL
5. DB::transaction():
   a. Create Season (content_type: 'readable', from JSON)
   b. Upload book cover via Imageable trait → attach to Season with slug 'cover'
   c. For each chapter in JSON:
      - Create Episode (reading_time_minutes, no video_url)
      - Call GeminiImageService for chapter header image → attach via Imageable
      - Create EpisodePages (all insight cards + summary card)
      - Create Questions + Answers
   d. Mark BookTopic.is_generated = true, generated_at = now()
   e. Update AIGenerationLog (status: 'completed', tokens_used, generation_time_seconds)
6. On any exception: rollback, update AIGenerationLog (status: 'failed', error_message)
```

**Files to touch:**

- `app/Services/AI/OpenAIService.php` _(create)_
- `app/Services/AI/GeminiImageService.php` _(create)_
- `app/Services/AI/ContentGenerationPipeline.php` _(create)_
- `composer.json` → add `openai-php/laravel` _(modify)_

```bash
composer require openai-php/laravel
```

---

### Step 2.2 — Book Topics Source

**Migration:** `create_book_topics_table`

```php
Schema::create('book_topics', function (Blueprint $table) {
    $table->id();
    $table->string('title');
    $table->string('author');
    $table->string('genre');           // self-help, business, psychology, philosophy, science
    $table->text('description')->nullable();
    $table->boolean('is_generated')->default(false);
    $table->timestamp('generated_at')->nullable();
    $table->unsignedSmallInteger('priority')->default(0); // higher = generate sooner
    $table->timestamps();
});
```

**New `app/BookTopic.php` model**

**`database/seeders/BookTopicSeeder.php`** — initial curated book list (sample):

| #   | Title                            | Author            | Genre        | Priority |
| --- | -------------------------------- | ----------------- | ------------ | -------- |
| 1   | Atomic Habits                    | James Clear       | Self-Help    | 10       |
| 2   | Think and Grow Rich              | Napoleon Hill     | Business     | 9        |
| 3   | The Psychology of Money          | Morgan Housel     | Finance      | 9        |
| 4   | Sapiens                          | Yuval Noah Harari | Science      | 8        |
| 5   | The Alchemist                    | Paulo Coelho      | Philosophy   | 8        |
| 6   | Deep Work                        | Cal Newport       | Productivity | 8        |
| 7   | Man's Search for Meaning         | Viktor Frankl     | Psychology   | 7        |
| 8   | The 7 Habits of Effective People | Stephen Covey     | Self-Help    | 7        |
| …   | _(30-50 titles total)_           |                   |              |          |

**Files to touch:**

- `database/migrations/xxxx_create_book_topics_table.php` _(create)_
- `app/BookTopic.php` _(create)_
- `database/seeders/BookTopicSeeder.php` _(create)_
- `database/seeders/DatabaseSeeder.php` _(modify — call BookTopicSeeder)_

---

### Step 2.3 — Artisan Command & Scheduling

**`app/Console/Commands/GenerateDailyStory.php`:**

```bash
# Usage
php artisan story:generate-daily              # auto-pick next topic
php artisan story:generate-daily --book="Atomic Habits" --author="James Clear"  # specific book
php artisan story:generate-daily --dry-run    # preview JSON without saving to DB
```

Behavior:

- Calls `ContentGenerationPipeline::generate()`
- Logs output to `storage/logs/ai-generation.log` (separate from main Laravel log)
- On failure: sends Slack/email notification to admin (uses existing notification pattern)
- Exit code 0 = success, 1 = failure (for cron monitoring)

**Register in `app/Console/Kernel.php`:**

```php
$schedule->command('story:generate-daily')
    ->dailyAt('03:00')
    ->withoutOverlapping()
    ->onFailure(function () { /* notify admin */ });
```

**Files to touch:**

- `app/Console/Commands/GenerateDailyStory.php` _(create)_
- `app/Console/Kernel.php` _(modify)_

---

### Step 2.4 — Environment Configuration

**Add to `.env.example`:**

```env
# AI Content Generation
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.0-flash
AI_CONTENT_GENERATION_ENABLED=true
AI_DAILY_STORY_TIME=03:00
```

**New `config/ai.php`:**

```php
return [
    'openai' => [
        'api_key' => env('OPENAI_API_KEY'),
        'model'   => env('OPENAI_MODEL', 'gpt-4o'),
    ],
    'gemini' => [
        'api_key' => env('GEMINI_API_KEY'),
        'model'   => env('GEMINI_MODEL', 'gemini-2.0-flash'),
    ],
    'generation' => [
        'enabled'    => env('AI_CONTENT_GENERATION_ENABLED', true),
        'daily_time' => env('AI_DAILY_STORY_TIME', '03:00'),
    ],
];
```

**Files to touch:**

- `.env.example` _(modify)_
- `config/ai.php` _(create)_

---

### Step 2.5 — AI Generation Logging

**Migration:** `create_ai_generation_logs_table`

```php
Schema::create('ai_generation_logs', function (Blueprint $table) {
    $table->id();
    $table->foreignId('book_topic_id')->nullable()->constrained()->nullOnDelete();
    $table->foreignId('season_id')->nullable()->constrained()->nullOnDelete();
    $table->enum('status', ['pending', 'processing', 'completed', 'failed'])->default('pending');
    $table->text('error_message')->nullable();
    $table->json('tokens_used')->nullable();   // {"openai": {"prompt": 1200, "completion": 3500}, "gemini": {...}}
    $table->unsignedSmallInteger('generation_time_seconds')->nullable();
    $table->timestamps();
});
```

**New `app/AIGenerationLog.php` model**

**Files to touch:**

- `database/migrations/xxxx_create_ai_generation_logs_table.php` _(create)_
- `app/AIGenerationLog.php` _(create)_

---

### Phase 2 Verification

```bash
# Seed book topics first
php artisan db:seed --class=BookTopicSeeder

# Dry run — inspect generated JSON without saving
php artisan story:generate-daily --dry-run

# Full run
php artisan story:generate-daily

# Verify in DB
php artisan tinker
Season::where('content_type', 'readable')->with('episodes.pages')->first()

# Verify AI log
AIGenerationLog::latest()->first()  # should show status: completed

# Verify images in DigitalOcean Spaces
# Season should have images with slug 'cover'
```

---

## Phase 3: Flutter Readable Story UI

> **Depends on Phase 1 API being deployed**

### Step 3.1 — Provider Updates

**Update `lib/providers/story.dart`:**

New state variables:

```dart
List<dynamic> _readableSeasons = [];
List<dynamic> _episodePages = [];
bool _isLoadingPages = false;
```

New methods:

```dart
// Fetch book summaries (readable seasons)
Future<void> fetchReadableSeasons(String token) async {
  // GET /api/v3/seasons?content_type=readable
  // Sets _readableSeasons, notifyListeners()
}

// Fetch pages for a readable episode (chapter)
Future<void> fetchEpisodePages(int episodeId, String token) async {
  _isLoadingPages = true; notifyListeners();
  // GET /api/episode/{episodeId}/pages
  // Sets _episodePages ordered by page_number, notifyListeners()
}

List<dynamic> get readableSeasons => [..._readableSeasons];
List<dynamic> get episodePages => [..._episodePages];
bool get isLoadingPages => _isLoadingPages;
```

**Files to touch:**

- `lib/providers/story.dart` _(modify)_

---

### Step 3.2 — Readable Episode Screen _(Core Deepstash UI)_

**New `lib/screens/story/readable_episode_screen.dart`**

Key structure:

```dart
class ReadableEpisodeScreen extends StatefulWidget {
  static const routeName = '/readable-episode-screen';
  // args: episode Map (with pages pre-loaded or fetched on init)
}

class _ReadableEpisodeScreenState extends State<ReadableEpisodeScreen> {
  PageController _pageController;
  int _currentPage = 0;
  String _language = 'en';  // 'en' or 'ne'

  // PageView.builder — horizontal
  //   items = episode pages + summary card
  //   each item = ReadablePageCard or SummaryPageCard
  //   page indicator dots (bottom center)
  //   TtsControlBar overlay (bottom, slides up/down)
  //   Language toggle (top right: EN | ने)
  //   Back button (top left)
}
```

**Card rendering logic:**

```
page.is_summary == true  →  SummaryPageCard (key points list + Take Quiz button)
page.is_key_point == true →  ReadablePageCard (highlighted accent variant)
else                     →  ReadablePageCard (standard variant)
```

**After last card (summary):**

- "Take Quiz" → `Navigator.pushNamed('/question-screen', arguments: {'episode': episode})`
- "Crossword" → `Navigator.pushNamed('/crossword-screen', arguments: {'episode': episode})`
- "Image Puzzle" → `Navigator.pushNamed('/image-puzzle-screen', arguments: {'episode': episode})`

**Reference:** `PageView.builder` pattern from `lib/screens/shorts/shorts_screen.dart` (existing horizontal swipe pattern)

**Files to touch:**

- `lib/screens/story/readable_episode_screen.dart` _(create)_

---

### Step 3.3 — Page Card Widget

**New `lib/widgets/readable_page_card.dart`**

Contains two widget classes:

**`ReadablePageCard`** — standard insight card:

```
┌─────────────────────────────┐
│ ← Back    Chapter 2    EN|ने│  (app bar — handled by screen)
├─────────────────────────────┤
│                             │
│  [Optional illustration]    │
│                             │
│  ● Page title (bold, 22sp)  │
│                             │
│  Body content text          │
│  (16sp, 1.6 line height,    │
│   readable serif/sans font) │
│                             │
│           ○ ● ○ ○ ○        │  (page dots)
└─────────────────────────────┘
Background: LinearGradient (rotating palette — 8 gradient presets, cycles by page index)
Card: rounded 16px, slight elevation shadow
```

**`SummaryPageCard`** — final summary card:

```
┌─────────────────────────────┐
│  ✦ Key Takeaways            │  (header)
├─────────────────────────────┤
│  • Point 1                  │
│  • Point 2                  │
│  • Point 3                  │
│  • Point 4                  │
├─────────────────────────────┤
│  [Take Quiz]  [Crossword]   │
│  [Image Puzzle]             │  (game mode buttons)
└─────────────────────────────┘
Background: Darker gradient variant
```

**Files to touch:**

- `lib/widgets/readable_page_card.dart` _(create)_

---

### Step 3.4 — Update Existing Screens

**`lib/screens/story/story_screen.dart`:**

- Add a "Books 📖" section/tab below or alongside existing categories (Featured, Suggested, etc.)
- Fetch readable seasons via `storyProvider.fetchReadableSeasons(token)` in `didChangeDependencies`
- Book card design differs from video season card:
  - Shows `book_author` subtitle
  - Shows `reading_time_minutes` total (sum across episodes)
  - Book-cover aspect ratio (3:4 instead of 16:9)
  - No video play icon overlay

**`lib/screens/story/episode_screen.dart`:**

- Detect `season['content_type']`
- If `readable`:
  - Label episodes as "Chapter 1", "Chapter 2" (instead of "Episode 1")
  - Show reading time `"~3 min read"` instead of video duration
  - On episode tap → `Navigator.pushNamed('/readable-episode-screen', arguments: {'episode': episode})`
- No changes needed for `video` path

**`lib/main.dart`:**

```dart
'/readable-episode-screen': (ctx) => ReadableEpisodeScreen(),
```

**Files to touch:**

- `lib/screens/story/story_screen.dart` _(modify)_
- `lib/screens/story/episode_screen.dart` _(modify)_
- `lib/main.dart` _(modify)_

---

### Step 3.5 — Post-Reading Quiz Flow

No new quiz screens needed. After reading all pages, the summary card exposes:

- **Take Quiz** → existing `QuestionScreen` (same arguments as video episodes use today)
- **Crossword** → existing `CrosswordScreen`
- **Image Puzzle** → existing `ImagePuzzleScreen`

The quiz system already queries questions by `episode_id` — readable episodes have questions too (AI-generated in Phase 2).

**Files to touch:** None (logic inside `ReadableEpisodeScreen` navigation calls only)

---

### Phase 3 Verification

```
1. Launch app → Story tab → verify "Books" section appears
2. (After Phase 2) Tap a book → chapter list shows "Chapter 1", "~3 min read"
3. Tap a chapter → ReadableEpisodeScreen opens
4. Swipe right through cards → verify gradient backgrounds cycle
5. Reach summary card → verify key points and game mode buttons show
6. Tap "Take Quiz" → existing QuestionScreen opens with correct questions
7. Tap back, toggle EN/ने → verify Nepali text renders (if populated)
```

---

## Phase 4: Text-to-Speech Integration

> **Can be developed in parallel with Phase 3**

### Step 4.1 — Add `flutter_tts` Package

**`pubspec.yaml`:**

```yaml
dependencies:
  flutter_tts: ^4.2.0
```

**New `lib/services/tts_service.dart`:**

```dart
class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  FlutterTts _tts = FlutterTts();
  bool isSpeaking = false;
  bool isPaused = false;
  double _speed = 1.0;       // 0.5, 0.75, 1.0, 1.5, 2.0
  String _language = 'en-US';

  Future<void> speak(String text) async { ... }
  Future<void> pause() async { ... }
  Future<void> resume() async { ... }
  Future<void> stop() async { ... }
  Future<void> setLanguage(String langCode) async { ... } // 'en-US' or 'ne-NP'
  Future<void> setSpeed(double speed) async { ... }
  Future<bool> isLanguageAvailable(String langCode) async { ... }
}
```

Android: Nepali supported via Google TTS engine (pre-installed on most devices).  
iOS: Nepali support varies — show prompt to switch to English if `ne-NP` unavailable.

**Files to touch:**

- `pubspec.yaml` _(modify)_
- `lib/services/tts_service.dart` _(create)_

---

### Step 4.2 — TTS Control Bar Widget

**New `lib/widgets/tts_control_bar.dart`:**

```
┌──────────────────────────────────────┐
│  🔊  ◀ 0.5x  [▶ Play]  1.5x ▶  ✕   │   (floating bottom bar)
└──────────────────────────────────────┘
```

Features:

- Play/Pause toggle (reads current card's title + content)
- Speed selector: 0.5x → 0.75x → 1x → 1.5x → 2x (tap to cycle)
- Auto-advance: completion handler calls `pageController.nextPage()` when TTS finishes
- Dismissible (X button hides bar; TTS icon on screen re-opens it)

Integrated in `ReadableEpisodeScreen`:

- On page change: `ttsService.stop()` (don't auto-play on swipe — only on explicit Press Play)
- Lang toggle (EN|ने) in app bar syncs `ttsService.setLanguage()` call

**Files to touch:**

- `lib/widgets/tts_control_bar.dart` _(create)_
- `lib/screens/story/readable_episode_screen.dart` _(modify — integrate TtsControlBar)_

---

### Phase 4 Verification

```
1. Open any readable chapter → tap TTS play → device reads card title + content aloud
2. Swipe to next card → TTS stops (does not carry over)
3. Press play on new card → reads new content
4. Tap speed button → speed cycles 1x → 1.5x → 2x → 0.5x
5. Let TTS finish → auto-advances to next card
6. Toggle EN → ने → TTS voice switches to Nepali
7. On device without Nepali TTS → verify fallback message shows
```

---

## Phase 5: Nepali Content Support

> **Mostly handled inline in Phase 1 schema + Phase 2 AI pipeline. Minimal additional work.**

### Step 5.1 — Nepali Fields at Season & Episode Level

**Migration:** `add_nepali_fields_to_seasons_and_episodes`

```php
Schema::table('seasons', function (Blueprint $table) {
    $table->text('nepali_description')->nullable()->after('description');
});

Schema::table('episodes', function (Blueprint $table) {
    $table->string('nepali_title')->nullable()->after('title');
    $table->text('nepali_description')->nullable()->after('description');
});
```

The `OpenAIService` prompt already requests Nepali translations for all content (title, description, page content) in a single GPT-4o call — no separate translation API needed.

**Files to touch:**

- `database/migrations/xxxx_add_nepali_fields_to_seasons_and_episodes.php` _(create)_
- `app/Season.php` _(modify — add to `$fillable`)_
- `app/Episode.php` _(modify — add to `$fillable`)_

---

### Step 5.2 — Frontend Language Toggle

Already built into `ReadableEpisodeScreen` (Phase 3.2). The toggle:

1. Sets `_language = 'ne'`
2. `ReadablePageCard` uses `_language == 'ne' && page['nepali_title'] != null ? page['nepali_title'] : page['title']`
3. Calls `ttsService.setLanguage('ne-NP')`
4. Persists preference: `SharedPreferences.setString('reading_language', 'ne')`

**Files to touch:** None additional (handled inside Phase 3 files)

---

### Phase 5 Verification

```
1. Tap a book chapter → reads in English by default
2. Tap "ने" toggle → Nepali text appears on cards (if populated)
3. TTS switches to Nepali voice
4. Kill and reopen app → language preference persists
5. On a card without Nepali content → falls back to English gracefully
```

---

## Phase 6: Reading Streaks (Daily Habit System)

> **Extends existing `DailyRewardController` pattern. Backend + Frontend.**

The #1 retention mechanic from Duolingo. Users build a daily reading streak by reading at least 1 chapter per day. Breaking the streak resets the counter. Longer streaks = bigger coin rewards.

### Step 6.1 — Backend: Reading Streak Model

**Migration:** `create_user_reading_streaks_table`

```php
Schema::create('user_reading_streaks', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->unsignedInteger('current_streak')->default(0);       // consecutive days
    $table->unsignedInteger('longest_streak')->default(0);       // all-time best
    $table->date('last_read_date')->nullable();                  // last day they read
    $table->unsignedInteger('total_chapters_read')->default(0);  // lifetime chapters
    $table->unsignedInteger('total_books_completed')->default(0); // lifetime books
    $table->timestamps();
    $table->unique('user_id');
});
```

**New `app/UserReadingStreak.php` model**

**New `app/Services/ReadingStreakService.php`:**

```php
class ReadingStreakService {
    // Called when user completes reading a chapter (all pages swiped)
    public function recordChapterRead(User $user, Episode $episode): array {
        $streak = UserReadingStreak::firstOrCreate(['user_id' => $user->id]);
        $today = now()->toDateString();

        if ($streak->last_read_date === $today) {
            return ['streak' => $streak, 'new_day' => false]; // already read today
        }

        $yesterday = now()->subDay()->toDateString();

        if ($streak->last_read_date === $yesterday) {
            $streak->current_streak += 1; // extend streak
        } else {
            $streak->current_streak = 1;  // reset (missed a day)
        }

        $streak->last_read_date = $today;
        $streak->longest_streak = max($streak->longest_streak, $streak->current_streak);
        $streak->total_chapters_read += 1;

        // Milestone rewards
        $reward = $this->getStreakReward($streak->current_streak);
        if ($reward > 0) {
            // Award coins via RewardBroadcastService
        }

        $streak->save();
        return ['streak' => $streak, 'new_day' => true, 'reward' => $reward];
    }

    // Streak milestones: 3 days = 5 coins, 7 = 15, 14 = 30, 30 = 100, 100 = 500
    private function getStreakReward(int $days): int { ... }
}
```

**Streak reward milestones:**

| Streak   | Reward     | Message                           |
| -------- | ---------- | --------------------------------- |
| 3 days   | 5 coins    | "3-day streak! Keep going!"       |
| 7 days   | 15 coins   | "1 week streak! 🔥"               |
| 14 days  | 30 coins   | "2 weeks strong! 💪"              |
| 30 days  | 100 coins  | "1 month! You're unstoppable! 🏆" |
| 50 days  | 200 coins  | "50 days! Legendary reader! ⭐"   |
| 100 days | 500 coins  | "100 DAYS! Master reader! 👑"     |
| 365 days | 2000 coins | "1 YEAR! Ultimate champion! 🎖️"   |

### Step 6.2 — Backend: Streak API Endpoints

**Add to `routes/api.php`:**

```php
Route::middleware(['auth:api'])->prefix('reading')->group(function () {
    Route::get('streak', [ReadingStreakController::class, 'getStreak']);
    Route::post('chapter-complete', [ReadingStreakController::class, 'recordChapterComplete']);
    Route::get('history', [ReadingStreakController::class, 'getReadingHistory']);
});
```

**New `app/Http/Controllers/api/ReadingStreakController.php`:**

- `getStreak()` → returns `current_streak`, `longest_streak`, `total_chapters_read`, `total_books_completed`, `last_read_date`, milestone progress
- `recordChapterComplete($episodeId)` → calls `ReadingStreakService`, broadcasts `RewardEarned` event if milestone hit
- `getReadingHistory()` → returns reading activity by date (for calendar heatmap like GitHub contributions)

**Add `user_reading_history` table for per-day tracking:**

```php
Schema::create('user_reading_history', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->foreignId('episode_id')->constrained()->cascadeOnDelete();
    $table->foreignId('season_id')->constrained()->cascadeOnDelete();
    $table->date('read_date');
    $table->timestamps();
    $table->index(['user_id', 'read_date']);
});
```

### Step 6.3 — Frontend: Streak UI

**Update `lib/providers/story.dart`:**

- Add `_readingStreak` state (Map with current_streak, longest_streak, etc.)
- Add `fetchReadingStreak()` and `recordChapterComplete(episodeId)` methods

**Streak display locations:**

1. **Books tab header** — "🔥 5-day streak" badge next to "Books" title
2. **ReadableEpisodeScreen** — after completing last page, show streak celebration overlay
3. **Profile screen** — streak stats card (current, longest, total chapters, total books)
4. **Home screen widget** — Phase 9

**New `lib/widgets/streak_celebration_overlay.dart`:**

- Animated fire icon 🔥 with streak count
- Shows milestone reward if hit ("7-day streak! +15 coins!")
- Confetti animation on milestone
- "Share your streak" button (share to social media)

**Files to touch:**

- `database/migrations/xxxx_create_user_reading_streaks_table.php` _(create)_
- `database/migrations/xxxx_create_user_reading_history_table.php` _(create)_
- `app/UserReadingStreak.php` _(create)_
- `app/Services/ReadingStreakService.php` _(create)_
- `app/Http/Controllers/api/ReadingStreakController.php` _(create)_
- `routes/api.php` _(modify)_
- `lib/providers/story.dart` _(modify)_
- `lib/widgets/streak_celebration_overlay.dart` _(create)_
- `lib/screens/story/readable_episode_screen.dart` _(modify — trigger recordChapterComplete)_

### Phase 6 Verification

```
1. Read 1 chapter → streak shows "🔥 1"
2. Next day, read another → streak shows "🔥 2"
3. Skip a day → streak resets to 0
4. Read again → streak shows "🔥 1" (fresh start)
5. Reach 7-day milestone → celebration overlay + 15 coins awarded
6. Check profile → streak stats visible
```

---

## Phase 7: User Book Request System

> **Lightweight feature. Backend + Frontend.**

Users can request books they want summarized. Admin approves requests → they enter the `book_topics` pipeline for AI generation.

### Step 7.1 — Backend: Book Requests

**Migration:** `create_book_requests_table`

```php
Schema::create('book_requests', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->string('title');
    $table->string('author')->nullable();
    $table->string('genre')->nullable();
    $table->text('reason')->nullable();        // "Why do you want this book?"
    $table->enum('status', ['pending', 'approved', 'rejected', 'generated'])->default('pending');
    $table->text('admin_note')->nullable();    // rejection reason or note
    $table->foreignId('book_topic_id')->nullable()->constrained()->nullOnDelete(); // linked after approval
    $table->unsignedInteger('upvotes')->default(0); // other users can upvote
    $table->timestamps();
    $table->index('status');
});
```

**Also create `book_request_upvotes` pivot table:**

```php
Schema::create('book_request_upvotes', function (Blueprint $table) {
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->foreignId('book_request_id')->constrained()->cascadeOnDelete();
    $table->primary(['user_id', 'book_request_id']);
    $table->timestamps();
});
```

**New `app/BookRequest.php` model**

**New `app/Http/Controllers/api/BookRequestController.php`:**

| Method | Route                            | Action                                                    |
| ------ | -------------------------------- | --------------------------------------------------------- |
| GET    | `/api/book-requests`             | `index` — list requests (paginated, sorted by upvotes)    |
| POST   | `/api/book-requests`             | `store` — submit new request (rate limit: 3/day per user) |
| POST   | `/api/book-requests/{id}/upvote` | `upvote` — upvote another user's request                  |
| GET    | `/api/book-requests/my`          | `myRequests` — user's own requests with status            |

**Admin-side (future admin panel, for now via Tinker/API):**

- Approve: creates `BookTopic` entry from request, sets `book_requests.status = 'approved'`, links `book_topic_id`
- Reject: sets status to `rejected` with `admin_note`
- When AI generates the book: sets status to `generated`, sends push notification to requester

### Step 7.2 — Frontend: Request a Book UI

**In `lib/screens/story/story_screen.dart` (Books tab):**

- "Request a Book" floating action button or card at the bottom of the books list
- Tapping opens a bottom sheet form:
  - Book title (required)
  - Author (optional)
  - Genre dropdown (optional)
  - Reason textarea (optional — "Why do you want this book?")
  - Submit button
- After submit: show confirmation "Your request has been submitted! 📚"

**New `lib/screens/story/book_requests_screen.dart`:**

- Browse other users' requests (sorted by upvotes)
- Upvote requests you want too (👍 button)
- "My Requests" tab showing status (Pending → Approved → Generated)
- Navigate here from Books tab header or settings

**Files to touch:**

- `database/migrations/xxxx_create_book_requests_table.php` _(create)_
- `database/migrations/xxxx_create_book_request_upvotes_table.php` _(create)_
- `app/BookRequest.php` _(create)_
- `app/Http/Controllers/api/BookRequestController.php` _(create)_
- `routes/api.php` _(modify)_
- `lib/screens/story/story_screen.dart` _(modify — add Request button)_
- `lib/screens/story/book_requests_screen.dart` _(create)_
- `lib/providers/story.dart` _(modify — add request methods)_
- `lib/main.dart` _(modify — add route)_

### Phase 7 Verification

```
1. Books tab → tap "Request a Book" → form appears
2. Submit "Rich Dad Poor Dad" → success message
3. Other user sees request in browse list → upvotes it
4. Admin approves via Tinker → BookTopic created
5. AI generates book next day → user gets push notification "Your requested book is ready!"
6. Request status updates to "Generated" in My Requests
```

---

## Phase 8: Interest-Based Onboarding & Personalization

> **Backend + Frontend. Makes the book feed feel personal from day 1.**

During onboarding (new users) or as a one-time prompt (existing users), collect reading interests. Use them to sort the Books tab — most relevant genres first.

### Step 8.1 — Backend: User Interests

**Migration:** `create_user_interests_table`

```php
Schema::create('user_interests', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->string('genre');  // matches book_topics.genre values
    $table->unsignedSmallInteger('priority')->default(0); // order user selected them
    $table->timestamps();
    $table->unique(['user_id', 'genre']);
});
```

**Available interest genres (pre-defined):**

| Genre         | Icon | Description                              |
| ------------- | ---- | ---------------------------------------- |
| Self-Help     | 🌱   | Personal growth, habits, mindset         |
| Business      | 💼   | Entrepreneurship, leadership, management |
| Psychology    | 🧠   | Human behavior, thinking, emotions       |
| Finance       | 💰   | Money, investing, economics              |
| Science       | 🔬   | Biology, physics, technology             |
| Philosophy    | 🏛️   | Meaning, ethics, ancient wisdom          |
| Productivity  | ⚡   | Time management, focus, systems          |
| Health        | 🏃   | Fitness, nutrition, mental health        |
| Relationships | 💬   | Communication, social skills, love       |
| History       | 📜   | World events, civilizations, leaders     |
| Creativity    | 🎨   | Art, writing, innovation                 |
| Spirituality  | 🕊️   | Meditation, mindfulness, inner peace     |

**New `app/Http/Controllers/api/UserInterestController.php`:**

| Method | Route                           | Action                                          |
| ------ | ------------------------------- | ----------------------------------------------- |
| GET    | `/api/user/interests`           | `index` — get user's selected interests         |
| POST   | `/api/user/interests`           | `store` — save 3-5 selected genres              |
| PUT    | `/api/user/interests`           | `update` — change interests later               |
| GET    | `/api/user/interests/available` | `available` — list all genre options with icons |

**Update `SeasonController` — personalized sorting:**

- `GET /api/v3/seasons?content_type=readable` → if user has interests, sort by matching genre first
- SQL: `ORDER BY FIELD(genre, 'user_pref_1', 'user_pref_2', ...) ASC, created_at DESC`

### Step 8.2 — Frontend: Interest Selection Screen

**New `lib/screens/onboarding/interest_selection_screen.dart`:**

```
┌─────────────────────────────┐
│  What do you love reading?  │
│  Pick 3-5 topics            │
├─────────────────────────────┤
│                             │
│  ┌──────┐  ┌──────────┐    │
│  │🌱    │  │💼        │    │
│  │Self- │  │Business  │    │
│  │Help  │  │          │    │
│  └──────┘  └──────────┘    │
│  ┌──────┐  ┌──────────┐    │
│  │🧠    │  │💰        │    │
│  │Psych │  │Finance   │    │
│  └──────┘  └──────────┘    │
│  ┌──────┐  ┌──────────┐    │
│  │🔬    │  │🏛️        │    │
│  │Science│  │Philosophy│    │
│  └──────┘  └──────────┘    │
│        ... more ...         │
│                             │
│  [Continue (3 selected)]    │
└─────────────────────────────┘
```

**When to show:**

1. **New users** — after registration, before reaching home screen (add to onboarding flow)
2. **Existing users** — one-time prompt when they first open the Books tab ("Personalize your reading? Pick topics you love")
3. **Settings** — always accessible from Profile → "Reading Interests" to update later

**Effect on Books tab:**

- Books sorted by user's interest genres first
- "For You" section at top with interest-matching books
- "Explore" section below with all other books
- If no interests set: show all books by recency (default)

**Files to touch:**

- `database/migrations/xxxx_create_user_interests_table.php` _(create)_
- `app/UserInterest.php` _(create)_
- `app/Http/Controllers/api/UserInterestController.php` _(create)_
- `app/Http/Controllers/api/SeasonController.php` _(modify — personalized sorting)_
- `routes/api.php` _(modify)_
- `lib/screens/onboarding/interest_selection_screen.dart` _(create)_
- `lib/providers/auth.dart` _(modify — add interests state + methods)_
- `lib/screens/story/story_screen.dart` _(modify — "For You" section + prompt)_
- `lib/main.dart` _(modify — add route)_

### Phase 8 Verification

```
1. New user registers → interest screen appears → picks Self-Help, Psychology, Finance
2. Books/stories tab shows "For You" with matched genres first
3. User opens Profile → "Reading Interests" → can change picks
4. After changing: Books tab re-sorts immediately
5. Existing user opens Books tab first time → one-time prompt appears
6. User skips prompt → all books shown by recency (no personalization)
```

---

## Phase 9: Home Screen Widget (Duolingo-Style)

> **Frontend only. Native Android + iOS home screen widget.**

A persistent widget on the user's phone showing their reading streak, today's book, and a tap-to-open shortcut. This is the #1 DAU driver for Duolingo — users see their streak every time they check their phone.

### Step 9.1 — Add `home_widget` Package

**`pubspec.yaml`:**

```yaml
dependencies:
  home_widget: ^0.7.0
```

**Platform setup required:**

- **Android:** Add `HomeWidgetProvider` in `android/app/src/main/kotlin/` + widget layout XML in `android/app/src/main/res/layout/`
- **iOS:** Add Widget Extension target in Xcode + SwiftUI widget view

### Step 9.2 — Widget Design

```
┌───────────────────────────┐
│  📚 Baakhapaa             │
├───────────────────────────┤
│                           │
│  🔥 12-day streak         │
│                           │
│  📖 Today's Book:         │
│  "Atomic Habits"          │
│  by James Clear           │
│                           │
│  ┌─────────────────┐      │
│  │  Read Now →      │      │  (taps open app to book)
│  └─────────────────┘      │
│                           │
│  ○ ● ○ ○ ○ ○ ○           │  (weekly dots: read days filled)
└───────────────────────────┘
```

**Widget sizes:**

- **Small (2x2):** Streak count 🔥 + "Tap to read" (minimal)
- **Medium (4x2):** Streak + today's book title + Read Now button
- **Large (4x4):** Full design above with weekly calendar dots

**Data flow:**

```
App foreground → update HomeWidget data:
  - current_streak (int)
  - todays_book_title (string)
  - todays_book_author (string)
  - weekly_activity [bool, bool, bool, ...] (7 days)
  - last_updated (timestamp)

Widget reads shared data → renders native UI
Widget tap → deep link to app → opens today's book
```

### Step 9.3 — Widget Update Triggers

Widget data refreshes when:

1. **App opens** — sync latest streak + today's book
2. **Chapter completed** — update streak count
3. **New daily book generated** — update today's book title (via FCM background handler)
4. **Background fetch** — periodic refresh every 6 hours (Android WorkManager / iOS BGAppRefreshTask)

**Create `lib/services/home_widget_service.dart`:**

```dart
class HomeWidgetService {
  static Future<void> updateWidget({
    required int currentStreak,
    required String todaysBook,
    required String todaysAuthor,
    required List<bool> weeklyActivity,
  }) async {
    await HomeWidget.saveWidgetData('streak', currentStreak);
    await HomeWidget.saveWidgetData('book_title', todaysBook);
    await HomeWidget.saveWidgetData('book_author', todaysAuthor);
    await HomeWidget.saveWidgetData('weekly', weeklyActivity.join(','));
    await HomeWidget.updateWidget(name: 'BaakhapaaWidget');
  }
}
```

### Step 9.4 — Streak-Breaking Push Notification

Complement the widget with a push notification:

- **8 PM check:** If user hasn't read today and has an active streak, send FCM: "Your 🔥12-day streak is about to break! Read 1 chapter to save it."
- Uses existing `FcmNotificationService` infrastructure
- Backend: new scheduled command `streak:check-and-notify` running at 20:00

```php
// In schedule():
$schedule->command('streak:check-and-notify')->dailyAt('20:00');
```

**Files to touch:**

- `pubspec.yaml` _(modify — add `home_widget: ^0.7.0`)_
- `android/app/src/main/kotlin/.../HomeWidgetProvider.kt` _(create)_
- `android/app/src/main/res/layout/baakhapaa_widget.xml` _(create)_
- `android/app/src/main/res/layout/baakhapaa_widget_small.xml` _(create)_
- `ios/BaakhapaaWidget/` _(create — Widget Extension)_
- `lib/services/home_widget_service.dart` _(create)_
- `lib/screens/story/readable_episode_screen.dart` _(modify — call HomeWidgetService.updateWidget)_
- `app/Console/Commands/StreakNotifyCommand.php` _(create — backend)_
- `app/Console/Kernel.php` _(modify — register streak:check-and-notify)_

### Phase 9 Verification

```
1. Install app → add Baakhapaa widget to home screen
2. Open app, read a chapter → widget updates streak count
3. Next day: widget shows "🔥 2-day streak" without opening app
4. New daily book appears → widget shows updated title
5. Tap widget → app opens directly to today's book
6. At 8 PM without reading: push notification "Your streak is about to break!"
7. Try all 3 widget sizes (small, medium, large)
```

---

## Complete File Inventory

### Backend — Files to Create

| File                                                                     | Type       | Phase |
| ------------------------------------------------------------------------ | ---------- | ----- |
| `database/migrations/xxxx_add_content_type_to_seasons.php`               | Migration  | 1.1   |
| `database/migrations/xxxx_create_episode_pages_table.php`                | Migration  | 1.2   |
| `database/migrations/xxxx_add_reading_time_to_episodes.php`              | Migration  | 1.2   |
| `app/EpisodePage.php`                                                    | Model      | 1.2   |
| `app/Http/Controllers/api/EpisodePageController.php`                     | Controller | 1.3   |
| `database/migrations/xxxx_create_book_topics_table.php`                  | Migration  | 2.2   |
| `app/BookTopic.php`                                                      | Model      | 2.2   |
| `database/seeders/BookTopicSeeder.php`                                   | Seeder     | 2.2   |
| `app/Services/AI/OpenAIService.php`                                      | Service    | 2.1   |
| `app/Services/AI/GeminiImageService.php`                                 | Service    | 2.1   |
| `app/Services/AI/ContentGenerationPipeline.php`                          | Service    | 2.1   |
| `app/Console/Commands/GenerateDailyStory.php`                            | Command    | 2.3   |
| `database/migrations/xxxx_create_ai_generation_logs_table.php`           | Migration  | 2.5   |
| `app/AIGenerationLog.php`                                                | Model      | 2.5   |
| `config/ai.php`                                                          | Config     | 2.4   |
| `database/migrations/xxxx_add_nepali_fields_to_seasons_and_episodes.php` | Migration  | 5.1   |
| `database/migrations/xxxx_create_user_reading_streaks_table.php`         | Migration  | 6.1   |
| `database/migrations/xxxx_create_user_reading_history_table.php`         | Migration  | 6.2   |
| `app/UserReadingStreak.php`                                              | Model      | 6.1   |
| `app/Services/ReadingStreakService.php`                                  | Service    | 6.1   |
| `app/Http/Controllers/api/ReadingStreakController.php`                   | Controller | 6.2   |
| `database/migrations/xxxx_create_book_requests_table.php`                | Migration  | 7.1   |
| `database/migrations/xxxx_create_book_request_upvotes_table.php`         | Migration  | 7.1   |
| `app/BookRequest.php`                                                    | Model      | 7.1   |
| `app/Http/Controllers/api/BookRequestController.php`                     | Controller | 7.1   |
| `database/migrations/xxxx_create_user_interests_table.php`               | Migration  | 8.1   |
| `app/UserInterest.php`                                                   | Model      | 8.1   |
| `app/Http/Controllers/api/UserInterestController.php`                    | Controller | 8.1   |
| `app/Console/Commands/StreakNotifyCommand.php`                           | Command    | 9.4   |

### Backend — Files to Modify

| File                                             | Change                                                    | Phase        |
| ------------------------------------------------ | --------------------------------------------------------- | ------------ |
| `app/Season.php`                                 | Add `content_type`, `book_*` fields to fillable           | 1.1, 5.1     |
| `app/Episode.php`                                | Add `pages()` HasMany, `reading_time_minutes`, `nepali_*` | 1.2, 5.1     |
| `app/Http/Controllers/api/SeasonController.php`  | `content_type` filter + personalized sort by interests    | 1.3, 8.1     |
| `app/Http/Controllers/api/EpisodeController.php` | Include pages, nullable video_url                         | 1.3          |
| `routes/api.php`                                 | Add all new routes (pages, streaks, requests, interests)  | 1.3, 6, 7, 8 |
| `app/Console/Kernel.php`                         | Register daily story + streak notify commands             | 2.3, 9.4     |
| `.env.example`                                   | Add AI API key variables                                  | 2.4          |
| `composer.json`                                  | Add `openai-php/laravel`                                  | 2.1          |
| `database/seeders/DatabaseSeeder.php`            | Call BookTopicSeeder                                      | 2.2          |

### Frontend — Files to Create

| File                                                    | Type    | Phase |
| ------------------------------------------------------- | ------- | ----- |
| `lib/screens/story/readable_episode_screen.dart`        | Screen  | 3.2   |
| `lib/widgets/readable_page_card.dart`                   | Widget  | 3.3   |
| `lib/services/tts_service.dart`                         | Service | 4.1   |
| `lib/widgets/tts_control_bar.dart`                      | Widget  | 4.2   |
| `lib/widgets/streak_celebration_overlay.dart`           | Widget  | 6.3   |
| `lib/screens/story/book_requests_screen.dart`           | Screen  | 7.2   |
| `lib/screens/onboarding/interest_selection_screen.dart` | Screen  | 8.2   |
| `lib/services/home_widget_service.dart`                 | Service | 9.3   |
| `android/app/src/main/kotlin/.../HomeWidgetProvider.kt` | Native  | 9.2   |
| `android/app/src/main/res/layout/baakhapaa_widget.xml`  | Native  | 9.2   |
| `ios/BaakhapaaWidget/` (Widget Extension)               | Native  | 9.2   |

### Frontend — Files to Modify

| File                                    | Change                                                       | Phase     |
| --------------------------------------- | ------------------------------------------------------------ | --------- |
| `lib/providers/story.dart`              | Add readable seasons, pages, streaks, requests fetch methods | 3.1, 6, 7 |
| `lib/providers/auth.dart`               | Add user interests state + methods                           | 8.2       |
| `lib/screens/story/story_screen.dart`   | Add Books section + "For You" + Request a Book button        | 3.4, 7, 8 |
| `lib/screens/story/episode_screen.dart` | Detect readable, show chapters                               | 3.4       |
| `lib/main.dart`                         | Add new routes (readable, requests, interests)               | 3.4, 7, 8 |
| `pubspec.yaml`                          | Add `flutter_tts: ^4.2.0`, `home_widget: ^0.7.0`             | 4.1, 9.1  |

### Reference Files (existing — follow their patterns)

| File                                                  | Pattern to Reuse                    |
| ----------------------------------------------------- | ----------------------------------- |
| `lib/screens/shorts/shorts_screen.dart`               | `PageView.builder` swiping          |
| `lib/screens/story/question_screen.dart`              | Post-content quiz navigation        |
| `app/Console/Commands/ChallengeRewardCommand.php`     | Artisan command structure           |
| `app/Services/LevelProgressionService.php`            | Service layer pattern               |
| `app/Services/RewardBroadcastService.php`             | DB transaction + event broadcasting |
| `app/Http/Controllers/api/DailyRewardController.php`  | Daily reward / streak claim pattern |
| `lib/widgets/rewards/redesigned_rewards_overlay.dart` | Reward celebration overlay pattern  |
| `lib/screens/user/weekly_rewards_screen.dart`         | Weekly streak display UI            |

---

## Dependency & Execution Order

```
Phase 1 (Backend schema)
    │
    ├──→ Phase 2 (AI pipeline)       [after Phase 1 migrations]
    │
    ├──→ Phase 3 (Flutter UI)        [after Phase 1 API deployed]
    │     │
    │     ├──→ Phase 5 (Nepali)      [built into Phase 3 screens]
    │     │
    │     └──→ Phase 6 (Streaks)     [after Phase 3 reading flow works]
    │           │
    │           └──→ Phase 9 (Widget) [after Phase 6 streak data exists]
    │
    ├──→ Phase 7 (Book requests)     [independent, can start with Phase 1]
    │
    └──→ Phase 8 (Onboarding)        [after Phase 2 has books to personalize]

Phase 4 (TTS)  [parallel with Phase 3 — no API dependency]
```

**Recommended execution timeline:**

| Order | Phase                        | Team     | Dependencies                     |
| ----- | ---------------------------- | -------- | -------------------------------- |
| 1     | Phase 1 (Schema + API)       | Backend  | None                             |
| 2a    | Phase 3 (Flutter reading UI) | Frontend | Phase 1 API                      |
| 2b    | Phase 2 (AI pipeline)        | Backend  | Phase 1 migrations               |
| 2c    | Phase 4 (TTS)                | Frontend | None (parallel)                  |
| 3     | Phase 6 (Reading streaks)    | Both     | Phase 3 reading flow             |
| 4a    | Phase 7 (Book requests)      | Both     | Phase 2 (book_topics table)      |
| 4b    | Phase 8 (Onboarding)         | Both     | Phase 2 (content to personalize) |
| 5     | Phase 5 (Nepali)             | Both     | Phase 2 + 3                      |
| 6     | Phase 9 (Home widget)        | Frontend | Phase 6 (streak data)            |

---

## Cost Estimates

| Item                                               | Cost per day | Cost per month (30 days) |
| -------------------------------------------------- | ------------ | ------------------------ |
| OpenAI GPT-4o (1 book, ~5K tokens)                 | ~$0.05       | ~$1.50                   |
| Google Gemini images (1 cover + 5 chapter headers) | ~$0.12       | ~$3.60                   |
| **Total (1 story/day)**                            | **~$0.17**   | **~$5.10**               |

> Scaling to 3 stories/day: ~$0.51/day → ~$15.30/month

---

## Scope Exclusions _(Future Enhancements)_

- Admin dashboard UI for AI content management, book request approval, and regeneration
- User-generated readable content (AI-pipeline-only for now)
- Offline reading / download chapters for offline access
- Social features on cards: highlights, personal notes, sharing snippets to social media
- Cloud TTS (Google Cloud / ElevenLabs) for premium voice quality
- Reader customization: font size, dark/sepia mode, reading themes
- Streak freeze (pay coins to preserve streak for 1 day, like Duolingo)
- Reading achievements (dedicated badges for reading milestones)
- Book clubs / group reading challenges
- Automated trending book list scraping (Goodreads/Amazon API integration)
- AI-powered "Ask about this book" chatbot within reading screen

---

## Open Questions / Risks

| Risk                                        | Mitigation                                                                                                           |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| GPT-4o JSON output occasionally malformed   | Validate schema + retry up to 3 times before marking log as failed                                                   |
| Gemini image generation rate limits         | Implement exponential backoff; queue image jobs separately if needed                                                 |
| Nepali TTS not available on iOS devices     | Detect `isLanguageAvailable('ne-NP')`; show "Download Nepali voice" prompt; graceful fallback to English TTS         |
| Book copyright concerns                     | Only generate _summaries and insights_, not verbatim reproduction; add `source_reference` attribution field          |
| Generated content quality                   | `--dry-run` flag lets team preview before first production run; book topics are curated by humans                    |
| Streak gaming (users swipe without reading) | Track time spent on each page; require minimum dwell time (e.g., 3 seconds per card) before marking chapter complete |
| Book request spam                           | Rate limit: 3 requests/day per user; require minimum account age; admin approval gate before generation              |
| Home widget battery drain                   | Use WorkManager (Android) / BGAppRefreshTask (iOS) with 6-hour intervals; no constant polling                        |
| Interest data cold start                    | Default to "trending/newest" sort when no interests selected; nudge users to set interests via Books tab prompt      |
| Upvote manipulation on book requests        | One upvote per user per request (enforced by `book_request_upvotes` unique constraint); no anonymous votes           |

---

## Summary: Total Scope

| #         | Phase                | What It Does                                      | Files to Create  | Files to Modify        |
| --------- | -------------------- | ------------------------------------------------- | ---------------- | ---------------------- |
| 1         | Backend Schema       | `content_type` on seasons, `episode_pages` table  | 4                | 4                      |
| 2         | AI Pipeline          | Auto-generate 1 book/day (OpenAI + Gemini)        | 8                | 4                      |
| 3         | Flutter Reading UI   | Deepstash-style card reader + Books tab           | 2                | 4                      |
| 4         | TTS                  | On-device text-to-speech for cards                | 2                | 2                      |
| 5         | Nepali               | Nepali translations + language toggle             | 1                | 2                      |
| 6         | Reading Streaks      | Daily reading habit system with coin rewards      | 5                | 3                      |
| 7         | Book Requests        | Users request + upvote books for AI generation    | 4                | 4                      |
| 8         | Onboarding Interests | Personalized book feed based on user preferences  | 4                | 5                      |
| 9         | Home Widget          | Duolingo-style streak widget + push notifications | 5                | 3                      |
| **Total** |                      |                                                   | **35 new files** | **~15 files modified** |

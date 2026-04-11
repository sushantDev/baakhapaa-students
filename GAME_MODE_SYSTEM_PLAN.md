# Plan: Episode Game Mode System (Quiz / Crossword / Image Puzzle)

## TL;DR

Add two new game modes (Crossword Puzzle, Image Jigsaw Puzzle) alongside the existing Quiz for episode completion. After the video timer completes, users see a mode selector instead of the direct "Go To Question" button. All three modes use the same lives system, grant the same rewards, and converge on WinScreen/LooseScreen. Backend tracks which mode was completed.

---

## Phase 1: Backend — Game Mode Tracking

**Goal**: Add `game_mode` column to `episode_user` pivot table so backend records which mode the user completed.

### Steps

1. **Create migration**: Add `game_mode` string column (nullable, default `'quiz'`) to `episode_user` table
   - File: `database/migrations/YYYY_MM_DD_create_game_mode_column_in_episode_user_table.php`
   - Column: `game_mode` enum-like string: `quiz`, `crossword`, `image_puzzle`

2. **Update `SeasonController@watchedEpisode`** to accept optional `game_mode` parameter
   - File: `app/Http/Controllers/api/SeasonController.php` — method `watchedEpisode()` (~line 920)
   - Accept `game_mode` from request, store in pivot when syncing: `$episode->users()->syncWithoutDetaching([Auth::id() => ['game_mode' => $request->game_mode ?? 'quiz']])`

3. **Update Episode API response** to include `game_mode` in the episode data when user has watched it
   - File: `app/Http/Controllers/api/EpisodeController.php` — `show()` method
   - Include the `game_mode` from pivot if episode is watched

---

## Phase 2: Flutter — Game Mode Selection UI

**Goal**: Replace the "Go To Question" green button with a game mode selector after timer completes.

### Steps

4. **Create `GameModeSelectionSheet`** widget — a bottom sheet or inline card that presents 3 mode options
   - File: `lib/widgets/game_mode_selector.dart` (NEW)
   - Displays 3 cards: Quiz (existing icon), Crossword (grid icon), Image Puzzle (puzzle icon)
   - Each card shows mode name, brief description
   - Crossword option: always visible (works with any number of questions)
   - Image Puzzle option: always visible (falls back to thumbnail if no video frame)
   - Returns selected mode enum: `GameMode.quiz`, `GameMode.crossword`, `GameMode.imagePuzzle`

5. **Create `GameMode` enum**
   - File: `lib/models/game_mode.dart` (NEW)
   - Values: `quiz`, `crossword`, `imagePuzzle`
   - Helper: `toApiString()` → `'quiz'`, `'crossword'`, `'image_puzzle'`

6. **Modify `VideoScreen._buildNavigationCard()`** to show mode selector when `_countdownCompleted == true`
   - File: `lib/screens/story/video_screen.dart` — `_buildNavigationCard()` (~line 3580)
   - Currently: green "Go To Question" button → calls `goToQuestionScreen()`
   - Change: green "Start Challenge" button → opens `GameModeSelectionSheet`
   - On mode selected:
     - `GameMode.quiz` → existing `goToQuestionScreen()` flow
     - `GameMode.crossword` → navigate to `CrosswordScreen`
     - `GameMode.imagePuzzle` → navigate to `ImagePuzzleScreen`
   - Store selected mode in Story provider for WinScreen to pass to backend

7. **Update Story provider** to track selected game mode
   - File: `lib/providers/story.dart`
   - Add: `GameMode _selectedGameMode = GameMode.quiz;` getter/setter
   - Add: pass `game_mode` parameter in `episodeWatched()` API call

---

## Phase 3: Crossword Puzzle Screen

**Goal**: Generate a crossword grid from episode quiz questions. Clues = question text, grid words = correct answers. Lives system: wrong word submission costs a life.

### Multi-Word Answer Strategy

Answers can be 1–4+ words long. The crossword generator handles this:

| Answer Text | Normalized Grid Entry | Strategy |
|---|---|---|
| `"Kathmandu"` | `KATHMANDU` | Direct use (single word) |
| `"New York"` | `NEWYORK` | Strip spaces — merge into single token |
| `"United States of America"` | `UNITEDSTATESOFAMERICA` | Strip spaces — merge (long but valid) |
| `"It is 42"` | `ITIS42` → filtered out (has digits) | Strip non-alpha → `ITIS` (4 chars, usable) |
| `"Yes"` | `YES` | Direct use (short but valid ≥ 2 chars) |
| `"A"` | Filtered out | Too short (< 2 chars), excluded from grid |

**Normalization pipeline** (in `crossword_generator.dart`):
```
raw answer → toUpperCase() → remove non-alphabetic chars → trim
→ if length < 2: exclude
→ if length > 20: truncate or split at natural word boundary (use first 2 words)
→ result is the grid entry
```

**Clue display** for multi-word answers shows a hint:
- Clue: `"What is the capital of Nepal?" (9 letters)`
- This tells the user the merged length, helping them fill cells

**Space-in-answer visual aid**: For answers like "NEW YORK" (grid entry `NEWYORK`), the grid cells can show a subtle dot `·` separator between word boundaries (after cell 3) so users understand where original words break. This is optional polish.

### Steps

8. **Create crossword generation algorithm**
   - File: `lib/utils/crossword_generator.dart` (NEW)
   - Input: `List<Map<String, dynamic>> questions` (from episode)
   - Processing:
     a. Extract correct answer text from each question's answers list (`answer['is_correct'] == 1`)
     b. Normalize: uppercase, strip ALL non-alphabetic characters (spaces, digits, punctuation)
     c. Filter out answers that are too short (< 2 chars)
     d. For answers > 20 chars: truncate to first 2 words (joined) to keep grid manageable
     e. Sort by length (longest first for better placement)
     f. Place first word horizontally at center of grid
     g. For each subsequent word, find best intersection with placed words (shared letter)
     h. Try horizontal if intersecting vertical word, and vice versa
     i. If no intersection found, place in nearest free space with gap
     j. Compact the grid (remove empty rows/columns from edges)
   - Output: `CrosswordPuzzle` model containing:
     - `List<List<String?>> grid` (2D grid of letters, null = black cell)
     - `List<CrosswordClue> acrossClues` (clue text, start position, answer length, direction)
     - `List<CrosswordClue> downClues`
     - `int gridWidth, int gridHeight`

9. **Create `CrosswordPuzzle` and `CrosswordClue` models**
   - File: `lib/models/crossword_puzzle.dart` (NEW)
   - `CrosswordPuzzle`: grid, clues, methods to validate answers
   - `CrosswordClue`: number, direction (across/down), question text, correct answer (normalized), original answer text, startRow, startCol, length, `List<int> wordBoundaries` (indices where original spaces were, for visual hints)
   - Method: `bool validateWord(int clueNumber, String userAnswer)` — normalizes user input same way, checks against correct answer
   - Method: `bool isComplete()` — all cells filled correctly

10. **Create `CrosswordScreen`**
    - File: `lib/screens/story/crossword_screen.dart` (NEW)
    - Route: `static const routeName = '/crossword-screen';`
    - Register in `main.dart` routes
    - **UI Layout**:
      - AppBar with episode title, lives display (hearts), timer (optional)
      - Crossword grid (scrollable/zoomable `InteractiveViewer`)
        - Each cell: `TextField` for single letter input
        - Highlighting: selected word cells highlighted, current cell focused
        - Correct cells: filled and locked (green)
        - Wrong word cells: flash red, then clear
        - Word boundary markers: subtle bottom-dot on cells at word break positions
      - Clues panel (bottom sheet or side panel):
        - "Across" section with numbered clues
        - "Down" section with numbered clues
        - Each clue shows letter count hint: `"Question text (N letters)"`
        - Tap clue → highlight corresponding cells in grid

    - **Game Logic**:
      - User taps cell or clue → focuses input on that word
      - User types letters sequentially across the word cells
      - "Submit Word" button or auto-submit when all cells of a word are filled
      - On submit: `CrosswordPuzzle.validateWord()`:
        - Correct → lock cells in green, mark clue as solved
        - Wrong → decrement life, flash cells red, clear user input for that word
      - Lives reach 0 → navigate to LooseScreen (same as quiz)
      - All words correct → navigate to WinScreen (same as quiz)

    - **State**: episode data from Story provider, lives from `episode['base_lives']`
    - **Extra lives**: same system as QuestionScreen (subscription benefit + coin purchase)

11. **Add route** for CrosswordScreen in `main.dart`
    - File: `lib/main.dart` — routes map (~line 873)

---

## Phase 4: Image Jigsaw Puzzle Screen

**Goal**: Split a video frame (or episode thumbnail) into jigsaw-shaped pieces. User drags pieces to correct positions. User-selectable difficulty (3x3, 4x4, 5x5).

### Steps

12. **Add `video_thumbnail` package**
    - File: `pubspec.yaml`
    - Package: `video_thumbnail: ^0.5.3` — extracts frames from video URLs
    - Used to capture a frame at a random timestamp from the episode video

13. **Create image puzzle logic**
    - File: `lib/utils/image_puzzle_generator.dart` (NEW)
    - `generatePuzzlePieces(Uint8List imageBytes, int rows, int cols)`:
      a. Decode image using `dart:ui` or `image` package
      b. Split into `rows x cols` rectangular tiles
      c. For jigsaw effect: apply jigsaw-shaped clip paths to each tile (tabs/blanks on edges)
      d. Return `List<PuzzlePiece>` with: piece image, correct row/col, current row/col
    - `JigsawClipper` CustomClipper: generates jigsaw tab/blank shapes on tile edges
      - Each edge can be: flat (border), tab (outward bump), blank (inward notch)
      - Edge types determined by position and neighboring pieces

14. **Create `PuzzlePiece` model**
    - File: `lib/models/puzzle_piece.dart` (NEW)
    - Fields: `int correctRow, correctCol, currentRow, currentCol`, `Widget pieceWidget`, `Offset position`, `bool isPlaced`
    - Method: `bool isCorrect()` → correctRow == currentRow && correctCol == currentCol

15. **Create `ImagePuzzleScreen`**
    - File: `lib/screens/story/image_puzzle_screen.dart` (NEW)
    - Route: `static const routeName = '/image-puzzle-screen';`
    - Register in `main.dart` routes

    - **Image Capture Flow** (in `initState`/`didChangeDependencies`):
      a. Check `episode['video_source']`:
         - If not YouTube: use `video_thumbnail` to capture frame at random timestamp from `${Url.mediaUrl}/${episode['video_url']}`
         - If YouTube or capture fails: download episode thumbnail image from `episode['thumbnail']` or episode image URL
      b. Store captured `Uint8List` image bytes
      c. Generate puzzle pieces from image

    - **Difficulty Selection** (shown before puzzle starts):
      - 3 buttons: Easy (3x3 = 9 pieces), Medium (4x4 = 16 pieces), Hard (5x5 = 25 pieces)
      - Selected difficulty determines grid dimensions

    - **UI Layout**:
      - AppBar with episode title, lives display, move counter
      - Reference image (small thumbnail in corner, toggleable)
      - Puzzle board: grid area where pieces snap into place
      - Scattered pieces: unplaced pieces shown below or around the board
      - Each piece: `Draggable` widget with jigsaw-clipped image

    - **Game Logic**:
      - Pieces start shuffled in a tray/scattered area below the board
      - User drags piece over correct grid slot → piece snaps in place (haptic feedback)
      - User drags piece to wrong slot → piece bounces back, decrement life
      - Lives reach 0 → LooseScreen
      - All pieces placed correctly → WinScreen
      - Optional: show piece count "Placed: X/Y"

    - **Lives**: same system as QuestionScreen (episode['base_lives'], extra lives purchase/benefit)

16. **Add route** for ImagePuzzleScreen in `main.dart`

---

## Phase 5: Integration & Polish

### Steps

17. **Update WinScreen** to pass `game_mode` to backend
    - File: `lib/screens/story/win_screen.dart`
    - In `episodeWatched()` call, include `game_mode` from Story provider
    - Display mode-specific congratulations text: "Crossword Completed!" / "Puzzle Solved!" / "Quiz Completed!"

18. **Update LooseScreen** retry flow to preserve selected game mode
    - File: `lib/screens/story/loose_screen.dart`
    - On "Try Again": navigate back to same game mode screen (not always VideoScreen)
    - Or navigate to VideoScreen which remembers last selected mode

19. **Update Story provider `episodeWatched()` method**
    - File: `lib/providers/story.dart`
    - Add `game_mode` parameter to API call: `GET /api/episode/{id}/watched?game_mode=crossword`

20. **Add localization keys** for new UI text
    - File: `lib/l10n/app_localizations_en.dart`, `_ne.dart`, `_zh.dart`
    - Keys: `selectGameMode`, `crosswordPuzzle`, `imagePuzzle`, `quiz`, `easyMode`, `mediumMode`, `hardMode`, `piecesPlaced`, `wordsFound`, `submitWord`, etc.

21. **Extra lives & skip integration** for new screens
    - Both CrosswordScreen and ImagePuzzleScreen should support:
      - Extra life purchase (same dialog as QuestionScreen)
      - Subscription benefit for extra lives (benefit ID 3)
    - Extract shared extra-life dialog logic into a reusable widget/mixin
    - File: `lib/widgets/extra_life_dialog.dart` (NEW) or `lib/mixins/extra_life_mixin.dart` (NEW)

---

## Phase 6: Animations, Haptics & UX Design

**Goal**: Create a polished, addictive gaming experience using the app's existing animation language (elasticOut curves, haptic patterns, sound effects) while adding game-specific micro-interactions.

### 6A. Game Mode Selector — Animations

**Entry animation** (bottom sheet slides up):
- Sheet slides up with `Curves.easeOutBack` (slight overshoot bounce), 400ms
- 3 mode cards stagger-animate in from bottom: card 1 at 0ms, card 2 at 100ms, card 3 at 200ms
- Each card uses `SlideTransition` (Y: 40px → 0) + `FadeTransition` (0 → 1)
- Background dims with `ColorTween(transparent → black54)`, 300ms

**Card hover/press states**:
- On tap-down: card scales to 0.95 with `Curves.easeOut`, 100ms — `HapticFeedback.selectionClick()`
- On tap-up: card scales back to 1.0 with `Curves.elasticOut`, 300ms
- Selected card: border glows with animated gradient (shimmer sweep left-to-right, 1.5s loop)
- Icon in card pulses gently: scale 1.0 → 1.08 → 1.0, 2s loop, `Curves.easeInOut`

**Mode selection confirmation**:
- Selected card expands slightly (scale 1.0 → 1.05) with `Curves.elasticOut`
- Other cards fade out (opacity 1 → 0, 200ms)
- `HapticFeedback.mediumImpact()`
- Card morphs/flies toward top of screen simulating "entering the game"
- 300ms delay then navigate with `PageTransitionType.fade`

### 6B. Crossword Screen — Animations & Haptics

**Screen entry**:
- `PageTransitionType.fade` transition (consistent with quiz navigation)
- Grid fades in cell-by-cell with stagger: 15ms per cell, waves from top-left to bottom-right
- Each cell does a tiny `ScaleTransition` (0.0 → 1.0) with `Curves.elasticOut`, 400ms
- Clue panel slides up from bottom after grid completes, 300ms

**Cell input interactions**:
- On cell focus: cell border animates to accent color, 200ms — `HapticFeedback.selectionClick()`
- Active word cells pulse with subtle background color animation (white → light blue → white, 1.5s loop)
- Letter typed: cell does micro-bounce (scale 1.0 → 1.1 → 1.0, 150ms, `Curves.easeOut`)
- Cursor auto-advances to next cell in word with a 50ms slide feel

**Correct word submitted**:
- All cells in word simultaneously:
  1. Flash bright green (200ms)
  2. Scale pulse 1.0 → 1.15 → 1.0 (`Curves.elasticOut`, 500ms)
  3. Lock with green background + checkmark icon fade-in
- Sound: `correct.wav` (existing asset)
- Haptic: single 150ms vibration (matches quiz correct pattern)
- Clue text: strikethrough animation (line draws left-to-right, 300ms) + opacity to 0.5
- If intersecting cells are revealed: those cells glow briefly (gold shimmer, 400ms) — free letters!
- Floating "+1" text near solved clue, flies up and fades (like coin animations)

**Wrong word submitted**:
- All cells in word simultaneously:
  1. Flash red (200ms)
  2. Horizontal shake: `sin()` wave, amplitude 8px, 3 cycles, 400ms (matches quiz wrong pattern)
  3. Letters clear with fade-out, 200ms
- Sound: `wrong.wav` (existing asset)
- Haptic: 3-burst vibration pattern — 200ms + 100ms pause × 3 (matches quiz wrong pattern)
- Heart/life indicator:
  1. Heart icon scales 1.0 → 1.3 → 1.0 with `Curves.elasticOut` (existing `_heartAnimationController` pattern)
  2. Heart blinks red (opacity toggle 1 → 0 → 1, 200ms × 2)
  3. One heart disappears with shrink + fade (300ms)
- Screen edges flash red vignette briefly (150ms)

**Last life warning**:
- Remaining heart pulses continuously (scale 1.0 → 1.15 → 1.0, 800ms loop)
- Subtle red tint overlay on grid edges
- `HapticFeedback.heavyImpact()` when entering last life

**Puzzle completion (all words correct)**:
- Grid cells do a "wave" celebration: sequential scale bounce, 30ms stagger, radiating from center
- Confetti burst from top (reuse existing confetti pattern from `redesigned_rewards_overlay.dart`):
  - Falling emoji 🎊 particles, rotating, swaying with `sin()` drift
  - Duration: 3 seconds
- Gold shimmer sweep across entire grid (left-to-right, 800ms)
- Sound: `correct.wav` played twice with 200ms gap (victory flourish)
- Haptic: long 500ms vibration (celebration)
- 1.5s celebration pause, then navigate to WinScreen with `PageTransitionType.fade`

**Clue panel interactions**:
- Tap clue: clue row highlights with slide-in color (left-to-right wipe, 200ms)
- Grid auto-scrolls/zooms to the selected word cells with `AnimatedPositioned` (300ms, `Curves.easeInOut`)
- Solved clues section: completed clues slide down into a "Solved" group with `AnimatedList`

### 6C. Image Puzzle Screen — Animations & Haptics

**Screen entry & difficulty selector**:
- Screen enters with `PageTransitionType.fade`
- Full reference image displayed in center, 1s hold
- Image "shatters" into pieces: each tile flies outward from center to random positions
  - `TweenAnimationBuilder` per piece: center position → scattered position
  - Duration: 800ms, `Curves.easeOutBack`
  - Slight rotation added to each piece (random -15° to +15°)
- Difficulty buttons fade in below: stagger 100ms each
- On difficulty select: `HapticFeedback.mediumImpact()`, button scales, pieces re-scatter to match new grid size

**Piece tray (unplaced pieces area)**:
- Pieces gently float/bob in the tray: each piece has independent `sin()` vertical oscillation
  - Amplitude: 3px, period: 2–4s (randomized per piece for organic feel)
- Subtle shadow beneath each piece (elevation effect)
- Pieces arranged in a scrollable horizontal list or 2-row wrap grid

**Drag interactions**:
- On drag start:
  - Piece scales up 1.0 → 1.1 (lifts off surface feel)
  - Shadow deepens (elevation 4 → 12)
  - `HapticFeedback.selectionClick()`
  - Other pieces in tray dim slightly (opacity 0.7)
- During drag:
  - Piece follows finger with slight 50ms lag (smooth, weighty feel via `AnimatedPositioned`)
  - When hovering over a grid slot: slot highlights with pulsing border (gold if potential match area)
  - Snap preview: when within 20px of a slot center, piece "magnetizes" — slight pull toward slot center
- On drop — **correct slot**:
  - Piece snaps to exact position with `Curves.elasticOut`, 300ms
  - Piece border flashes green (200ms)
  - Scale pulse: 1.0 → 1.08 → 1.0 (200ms)
  - Jigsaw edges "merge" with adjacent placed pieces (border between them fades out, 400ms)
  - Sound: `correct.wav`
  - Haptic: single 150ms vibration
  - Floating "✓" checkmark pops above piece and fades (300ms)
  - Piece counter updates with number roll animation
- On drop — **wrong slot**:
  - Piece bounces back to tray with `Curves.bounceOut`, 500ms
  - Piece shakes horizontally (3 cycles, 300ms) during return
  - Red flash on the attempted slot (200ms)
  - Sound: `wrong.wav`
  - Haptic: 3-burst pattern (200ms × 3 with 100ms gaps)
  - Life lost animation: heart shrink + fade (same as crossword)

**Progress indicators**:
- Piece counter: `"Placed: 7/16"` with animated number (rolls up like odometer)
- Progress bar beneath the grid fills with gradient (green shimmer sweep on each piece placed)
- At 50% completion: subtle encouraging haptic (`HapticFeedback.lightImpact()`)
- At 75% completion: remaining tray pieces glow slightly (hint: you're close!)

**Last piece placed — victory sequence**:
- Final piece drops in with dramatic slow-motion feel: 600ms instead of 300ms, `Curves.decelerate`
- All piece borders dissolve simultaneously (200ms) — image becomes whole
- Full image does a scale pulse: 1.0 → 1.05 → 1.0 with `Curves.elasticOut`
- Gold frame border draws around completed image (animated border, 800ms, clockwise draw)
- Confetti explosion from center (reuse existing pattern, 🎊 + ✨ particles)
- Gentle white flash overlay (opacity 0 → 0.3 → 0, 400ms) — "photo flash" effect
- Sound: `correct.wav` × 2 with gap
- Haptic: long 500ms celebration vibration
- 2s celebration hold, then `PageTransitionType.fade` to WinScreen

**Reference image toggle**:
- Small thumbnail in corner (60×60px)
- On tap: expands to overlay (scale 0.15 → 1.0 with `Curves.easeOutBack`, 400ms)
- Semi-transparent background dims
- Tap again or tap outside: shrinks back (reverse animation, 300ms)
- `HapticFeedback.lightImpact()` on toggle

### 6D. Lives Display — Shared Animation Component

Used across CrosswordScreen and ImagePuzzleScreen (and existing QuestionScreen):

**Hearts row in AppBar**:
- Hearts rendered as `AnimatedList` of heart icons
- Full heart: solid red, gentle pulse (scale 1.0 → 1.05, 1.5s loop, staggered per heart)
- On life lost:
  1. Target heart scales up 1.0 → 1.3 (`Curves.elasticOut`, 300ms)
  2. Heart "cracks" — color shifts red → grey
  3. Heart shrinks to 0 and fades out (200ms)
  4. Remaining hearts shift left to close gap (`AnimatedPositioned`, 200ms)
  5. Red pulse on the hearts row background (flash, 150ms)
- On extra life gained:
  1. New heart fades in from right (opacity 0 → 1, scale 0 → 1, `Curves.elasticOut`, 500ms)
  2. All hearts do a brief "happy bounce" (scale 1.0 → 1.1 → 1.0, 150ms stagger)
  3. Green flash behind hearts (100ms)
  4. `HapticFeedback.mediumImpact()`

**Extra life dialog entrance**:
- Dialog scales in from center: 0.8 → 1.0 with `Curves.elasticOut`, 400ms
- Background dims with `ColorTween`, 300ms
- "Last chance" urgency: heart icon in dialog pulses red

### 6E. Sound Design (New Assets Needed)

| Event | Sound File | Description |
|---|---|---|
| Piece snap (correct) | `correct.wav` | Reuse existing |
| Piece bounce (wrong) | `wrong.wav` | Reuse existing |
| Word correct | `correct.wav` | Reuse existing |
| Word wrong | `wrong.wav` | Reuse existing |
| Game complete | `correct.wav` × 2 | Double-play existing (no new asset needed) |
| Mode selected | `HapticFeedback.mediumImpact()` | Haptic only, no sound |
| Cell focus | `HapticFeedback.selectionClick()` | Haptic only |
| Drag start | `HapticFeedback.selectionClick()` | Haptic only |

**Note**: No new sound assets required. All audio feedback reuses existing `correct.wav` and `wrong.wav`. Haptic-only events provide tactile feedback without audio clutter.

### 6F. Animation Controllers Summary

**CrosswordScreen** requires these `AnimationController`s:
1. `_gridEntryController` — staggered grid cell appearance (800ms total)
2. `_correctWordController` — green flash + scale pulse on correct word (500ms)
3. `_wrongWordController` — red flash + shake on wrong word (400ms)
4. `_heartAnimationController` — heart scale/blink on life lost (800ms, reuse pattern from QuestionScreen)
5. `_completionController` — wave celebration + confetti (3000ms)
6. `_clueHighlightController` — clue row highlight wipe (200ms)

**ImagePuzzleScreen** requires these `AnimationController`s:
1. `_shatterController` — image breaks into pieces (800ms)
2. `_pieceFloatController` — gentle bob animation for tray pieces (continuous)
3. `_snapController` — piece snap-into-place with elastic (300ms)
4. `_bounceBackController` — wrong drop bounce back (500ms)
5. `_heartAnimationController` — heart animations (800ms, same pattern)
6. `_completionController` — victory sequence (2000ms)
7. `_borderDrawController` — gold frame draw around completed image (800ms)
8. `_referenceToggleController` — thumbnail expand/collapse (400ms)

**GameModeSelector** requires:
1. `_sheetEntryController` — bottom sheet slide + card stagger (600ms total)
2. `_cardPressController` — tap feedback scale (100ms)
3. `_selectionController` — selected card expand + others fade (300ms)

**Mixin for consistency**: `GameAnimationMixin` extracts shared patterns (heart animation, confetti, correct/wrong feedback) so both game screens use identical timing and curves.

### 6G. Color Palette & Theme

Consistent colors across both game modes:

| Element | Light Mode | Dark Mode |
|---|---|---|
| Active cell/slot border | `Color(0xFF2196F3)` Blue | `Color(0xFF64B5F6)` Light Blue |
| Correct flash | `Color(0xFF4CAF50)` Green | `Color(0xFF66BB6A)` Light Green |
| Correct locked cell bg | `Color(0xFFE8F5E9)` Green 50 | `Color(0xFF1B5E20)` Green 900 |
| Wrong flash | `Color(0xFFF44336)` Red | `Color(0xFFEF5350)` Light Red |
| Selected word highlight | `Color(0xFFE3F2FD)` Blue 50 | `Color(0xFF0D47A1)` Blue 900 |
| Puzzle board bg | `Color(0xFFFAFAFA)` Grey 50 | `Color(0xFF212121)` Grey 900 |
| Piece tray bg | `Color(0xFFECEFF1)` Blue Grey 50 | `Color(0xFF263238)` Blue Grey 900 |
| Gold frame/shimmer | `Color(0xFFFFD700)` Gold | `Color(0xFFFFD700)` Gold |
| Hearts | `Colors.red` | `Colors.redAccent` |

### 6H. Transition Flow Diagram

```
VideoScreen (timer complete)
    │
    ▼ [green button tap]
GameModeSelectionSheet (bottom sheet, 3 cards)
    │
    ├── Quiz selected ──────→ QuestionScreen (existing flow unchanged)
    │                              │
    ├── Crossword selected ─→ CrosswordScreen (new)
    │                              │
    └── Image Puzzle selected → DifficultySelector → ImagePuzzleScreen (new)
                                   │
                                   ▼
                        ┌── All correct ──→ WinScreen (+ game_mode)
                        │                      │
                        └── Lives = 0 ───→ LooseScreen
                                               │
                                               ▼ [Try Again]
                                          VideoScreen (same episode)
```

---

## Relevant Files

### Flutter (Modify)
- `lib/screens/story/video_screen.dart` — Change "Go To Question" button to game mode selector
- `lib/screens/story/win_screen.dart` — Pass game_mode, mode-specific text
- `lib/screens/story/loose_screen.dart` — Retry flow preserves game mode
- `lib/providers/story.dart` — Add selectedGameMode state, pass game_mode to API
- `lib/main.dart` — Register new routes (CrosswordScreen, ImagePuzzleScreen)
- `pubspec.yaml` — Add `video_thumbnail` dependency
- `lib/l10n/app_localizations_*.dart` — New localization keys

### Flutter (Create)
- `lib/models/game_mode.dart` — GameMode enum
- `lib/models/crossword_puzzle.dart` — CrosswordPuzzle, CrosswordClue models
- `lib/models/puzzle_piece.dart` — PuzzlePiece model
- `lib/utils/crossword_generator.dart` — Crossword grid generation algorithm
- `lib/utils/image_puzzle_generator.dart` — Image splitting + jigsaw clip paths
- `lib/widgets/game_mode_selector.dart` — Game mode selection bottom sheet
- `lib/widgets/extra_life_dialog.dart` — Shared extra life dialog (extracted from QuestionScreen)
- `lib/screens/story/crossword_screen.dart` — Crossword puzzle game screen
- `lib/screens/story/image_puzzle_screen.dart` — Image jigsaw puzzle game screen
- `lib/mixins/game_animation_mixin.dart` — Shared animation patterns (hearts, confetti, feedback)

### Backend (Modify)
- `app/Http/Controllers/api/SeasonController.php` — Accept `game_mode` in `watchedEpisode()`
- `app/Http/Controllers/api/EpisodeController.php` — Include `game_mode` in response

### Backend (Create)
- `database/migrations/xxxx_add_game_mode_to_episode_user_table.php` — Migration

---

## Verification

1. **Backend**: Run `php artisan migrate` — confirm `game_mode` column added to `episode_user` table
2. **Backend**: Test `GET /api/episode/{id}/watched?game_mode=crossword` — verify column populated
3. **Crossword**: Create an episode with 3+ questions, play crossword mode, verify:
   - Grid generates correctly with intersecting words
   - Multi-word answers (e.g., "New York") render as merged cells `NEWYORK` with word boundary hint
   - Wrong word flashes red + shakes + costs a life
   - Correct word locks green + strikethrough on clue
   - All words correct → confetti + WinScreen with correct rewards
   - 0 lives → LooseScreen
4. **Image Puzzle**: Play image puzzle mode on a non-YouTube episode, verify:
   - Video frame captured and image "shatters" into jigsaw pieces
   - Pieces bob gently in tray
   - Drag feedback: piece lifts, snaps magnetically near correct slot
   - Correct placement: snap + green flash + haptic
   - Wrong placement: bounce back + shake + wrong sound + life lost
   - All placed → border draw + confetti + WinScreen
5. **Image Puzzle Fallback**: Play on a YouTube episode → verify thumbnail used instead of video frame
6. **Game Mode Tracking**: After completing each mode, check `episode_user.game_mode` in database
7. **Extra Lives**: Test extra life purchase and subscription benefit in both new modes
8. **Haptics**: Test on physical device — verify vibration patterns match quiz screen
9. **Sound**: Verify `correct.wav` / `wrong.wav` play at appropriate moments
10. **Dark mode**: Both screens render correctly in dark and light themes
11. **Flutter build**: `flutter build apk --debug` succeeds without errors
12. **Localization**: Switch language (NE, ZH) → verify new strings appear

---

## Decisions

- **Game mode selection**: Inline in VideoScreen after timer completes (bottom sheet), not a separate screen
- **Jigsaw style**: Drag-and-drop with jigsaw-shaped clip paths (not sliding puzzle)
- **Jigsaw difficulty**: User-selectable (3x3, 4x4, 5x5) shown before puzzle starts
- **Image source**: Video frame preferred, episode thumbnail as fallback
- **Crossword minimum**: No minimum question count; works with even 1-2 questions (simpler grid)
- **Crossword lives**: Life lost per wrong word submission (not per wrong letter)
- **Multi-word answers**: Stripped of spaces/special chars and merged into single grid tokens; word boundary dots shown as hints
- **Long answers (>20 chars)**: Truncated to first 2 words joined, keeping grid manageable
- **Backend tracking**: `game_mode` column added to `episode_user` pivot table
- **Same rewards**: All 3 modes grant identical coins via existing `episodeWatched()` flow
- **Sound assets**: No new sounds needed — reuse `correct.wav` and `wrong.wav`
- **Animation consistency**: All timing, curves, and haptic patterns match existing QuestionScreen patterns
- **Shared mixin**: `GameAnimationMixin` extracts common animation code for DRY implementation
- **Excluded**: No new backend quiz validation — all game validation remains client-side (same as current quiz)
- **Excluded**: No AI-generated crossword clues — uses existing question text directly

## Further Considerations

1. **Crossword with single-word answers**: If correct answers contain multiple words (e.g., "New York"), the generator strips spaces and merges ("NEWYORK"). Word boundary dots in cells hint at original word breaks. Clue shows `(7 letters)` to help the user.
2. **Very long answers (4+ words)**: Answers like "United States of America" become `UNITEDSTATESOFAMERICA` (21 chars). The plan truncates to first 2 words (`UNITEDSTATES`, 12 chars) when >20 chars to keep the grid playable. The clue still shows the full question.
3. **Offline image puzzle**: Video frame capture requires network. Consider caching a frame during video playback so the puzzle works even if network drops before mode selection.
4. **Replayability**: On retry, crossword re-randomizes word placement order and image puzzle re-shuffles pieces to provide variety.
5. **Performance**: Jigsaw clip paths with `CustomClipper` are GPU-accelerated. For 5×5 (25 pieces), each piece has 4 edges with bezier curves — test on low-end devices. Consider `RepaintBoundary` per piece.
6. **Accessibility**: All haptic events should have visual equivalents. Color-blind users: don't rely solely on red/green — also use icons (✓/✗) and shape changes.

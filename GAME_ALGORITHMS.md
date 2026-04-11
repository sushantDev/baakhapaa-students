# Game Algorithms – Crossword & Image Puzzle

Technical documentation for the crossword puzzle and image puzzle game modes in the Baakhapaa Flutter app.

---

## Table of Contents

1. [Crossword Puzzle](#crossword-puzzle)
   - [Generation Algorithm](#crossword-generation-algorithm)
   - [Progressive Difficulty](#crossword-progressive-difficulty)
   - [Hint System](#crossword-hint-system)
2. [Image Puzzle](#image-puzzle)
   - [Generation Algorithm](#image-puzzle-generation-algorithm)
   - [Auto-Difficulty](#image-puzzle-auto-difficulty)
   - [Hint System](#image-puzzle-hint-system)
3. [File Reference](#file-reference)

---

## Crossword Puzzle

### Crossword Generation Algorithm

**File:** `lib/utils/crossword_generator.dart`

The crossword is generated from episode questions using a **greedy word-placement algorithm** with intersection scoring.

#### Step 1: Extract Words from Questions

Each question has multiple answers. The generator finds the correct answer (`is_correct == 1`) and normalizes it:

- Convert to uppercase
- Strip all non-alphabetic characters (`[^A-Z]`)
- Skip answers shorter than 2 characters
- Truncate answers longer than 20 characters to the first 2 words
- Record word boundaries (where spaces were) for display purposes

#### Step 2: Select Words by Difficulty

Words are sorted by answer length (shortest first) to establish a natural easy→hard ordering. Based on the `difficulty` parameter (0.0–1.0):

- **Word count**: `max(3, entries.length × (0.5 + difficulty × 0.5))` — at easiest difficulty, roughly half the questions are included; at hardest, all are used.
- Selected words are then re-sorted **longest-first** for optimal grid placement (longer words create more intersection opportunities).

#### Step 3: Place Words on Grid (Greedy Placement)

Uses a 30×30 working grid:

1. **First word**: Placed horizontally at the grid center.
2. **Subsequent words**: For each remaining word, the algorithm tries to find the best placement by:
   - Scanning all already-placed letters in the grid
   - For each letter that matches a letter in the new word, testing both horizontal and vertical placement at that intersection
   - Scoring each valid placement by the **number of intersections** (shared letters with existing words)
   - Selecting the placement with the highest intersection score

**Placement validation (`_canPlace`):**

- Word must fit within grid bounds (0 to 29)
- Each cell in the word's path must be either empty or contain the same letter (intersection)
- Adjacent cells (perpendicular to the word direction) must not have unrelated letters — this prevents words from running alongside each other without proper crossword structure

**If no valid placement exists** for a word, it is skipped.

#### Step 4: Compact and Build

After all words are placed:

1. Find the bounding box of all non-null cells in the 30×30 grid
2. Create a compact grid with exact dimensions
3. Assign **clue numbers** sequentially, processing cells top-to-bottom, left-to-right — a cell gets a number if it starts an across word or a down word
4. Build `CrosswordClue` objects with question text, correct answer, position, direction, length, and word boundaries
5. Return a `CrosswordPuzzle` with the compact grid and clue lists

#### Algorithm Classification

This is a variant of a **greedy constructive heuristic** for crossword layout. It prioritizes:

- Intersection density (more shared letters = better)
- Longer words first (more placement options for shorter words later)

It does **not** use backtracking or constraint propagation (unlike professional crossword compilers like Crossword Compiler or ECW), making it O(n² × m) where n is the number of words and m is the grid size — fast enough for real-time generation.

---

### Crossword Progressive Difficulty

**File:** `lib/screens/story/crossword_screen.dart` → `didChangeDependencies()`

Difficulty scales based on the number of episodes the user has completed in the current season:

| Completed Episodes | Difficulty   | Word Count        | Hint Percentage |
| ------------------ | ------------ | ----------------- | --------------- |
| 0–2                | 0.2 (Easy)   | ~60% of questions | ~42% of letters |
| 3–5                | 0.5 (Med)    | ~75% of questions | ~30% of letters |
| 6–8                | 0.75 (Hard)  | ~88% of questions | ~20% of letters |
| 9+                 | 1.0 (Expert) | 100% of questions | ~10% of letters |

**Hint percentage formula:** `0.5 − (difficulty × 0.4)`

Pre-filled hints are distributed randomly across each word, with at least 1 hint per word guaranteed. Intersecting cells that are already hinted by another word are not double-counted.

---

### Crossword Hint System

**Files:** `lib/screens/story/crossword_screen.dart`

- **Cost:** 5 coins per hint
- **Action:** Reveals one random unrevealed letter across all unsolved clues
- **Flow:**
  1. User taps the lightbulb icon in the AppBar
  2. Confirmation dialog shows the cost and current coin balance
  3. On confirm: a random unrevealed cell is selected, its correct letter is filled in and marked as a hint cell (non-editable)
  4. Coins are deducted locally via `Auth.deductCoinsLocally()` for instant UI feedback
  5. A `POST /coin-transaction` is fired in the background to log the spend on the server
  6. If the revealed letter completes all cells in any word, that word is auto-validated

---

## Image Puzzle

### Image Puzzle Generation Algorithm

**File:** `lib/utils/image_puzzle_generator.dart`

The image puzzle uses a **grid-based image splitting** approach.

#### Step 1: Decode Image

The source image (video thumbnail, YouTube thumbnail, or episode/season image) is loaded as raw bytes (`Uint8List`) and decoded into a `dart:ui Image` using `instantiateImageCodec`.

Image source priority:

1. **Video frame**: Extract a random frame (10%–80% of duration) from the episode video using `video_thumbnail` package (JPEG, max 512px height, 15s timeout)
2. **YouTube thumbnail**: If YouTube video, try `maxresdefault` → `sddefault` → `hqdefault`
3. **Episode/season images**: Fall back to any available thumbnail or image URL

#### Step 2: Split into Pieces

Given a grid size (rows × cols), the image is divided into equal rectangular regions:

```
pieceWidth  = image.width  / cols
pieceHeight = image.height / rows
```

For each grid position (row, col):

1. Create a `PictureRecorder` and `Canvas`
2. Use `canvas.drawImageRect` to extract the sub-region:
   - Source rect: `(col × pieceWidth, row × pieceHeight, pieceWidth, pieceHeight)`
   - Destination rect: `(0, 0, pieceWidth, pieceHeight)`
3. Convert to a `ui.Image` via `picture.toImage()`
4. Wrap in a `PuzzlePiece` object with `correctRow`, `correctCol`, and a unique key

#### Step 3: Shuffle

The list of `PuzzlePiece` objects is shuffled randomly. Each piece retains its `correctRow`/`correctCol` so the game can validate placement.

#### Rendering

Each piece is rendered using:

- `PuzzlePiecePainter` (CustomPainter): Draws the piece's image scaled to the display slot size
- `JigsawClipper` (CustomClipper): Clips the piece with jigsaw-edge shapes using cubic Bézier curves, based on the piece's position in the grid (edge pieces have flat sides, interior pieces have tabs/blanks)

#### Algorithm Classification

This is a straightforward **spatial decomposition** — the image is partitioned into an N×M grid of tiles, shuffled, and the user must reconstruct the original arrangement via drag-and-drop. The computational complexity is O(rows × cols) for generation.

---

### Image Puzzle Auto-Difficulty

**File:** `lib/screens/story/image_puzzle_screen.dart` → `_autoSelectDifficulty()`

Grid size scales with the user's season progress:

| Completed Episodes | Grid Size | Total Pieces |
| ------------------ | --------- | ------------ |
| 0–3                | 3×3       | 9            |
| 4–7                | 4×4       | 16           |
| 8+                 | 5×5       | 25           |

The difficulty selector UI is **bypassed** — the appropriate grid is chosen automatically based on progress (though manual selection remains available as fallback if auto-detection fails).

---

### Image Puzzle Hint System

**Files:** `lib/screens/story/image_puzzle_screen.dart`

- **Cost:** 10 coins per hint
- **Action:** Auto-places one random unplaced puzzle piece in its correct grid slot
- **Flow:**
  1. User taps the lightbulb icon in the AppBar
  2. Confirmation dialog shows the cost and current coin balance
  3. On confirm: a random unplaced piece is selected and placed in its `(correctRow, correctCol)` position via the existing `_onCorrectPlacement()` method
  4. Coins are deducted locally via `Auth.deductCoinsLocally()` for instant UI feedback
  5. A `POST /coin-transaction` is fired in the background to log the spend on the server
  6. If this was the last piece, the game completion flow triggers automatically

---

## File Reference

| File                                         | Purpose                                                         |
| -------------------------------------------- | --------------------------------------------------------------- |
| `lib/utils/crossword_generator.dart`         | Crossword grid generation algorithm                             |
| `lib/models/crossword_puzzle.dart`           | CrosswordPuzzle and CrosswordClue data models                   |
| `lib/screens/story/crossword_screen.dart`    | Crossword game UI, input handling, hints, difficulty            |
| `lib/utils/image_puzzle_generator.dart`      | Image splitting and PuzzlePiece generation                      |
| `lib/models/puzzle_piece.dart`               | PuzzlePiece data model                                          |
| `lib/screens/story/image_puzzle_screen.dart` | Image puzzle game UI, drag-drop, hints, auto-difficulty         |
| `lib/screens/story/win_screen.dart`          | Shared victory screen (marks episode as watched)                |
| `lib/screens/story/loose_screen.dart`        | Shared game-over screen                                         |
| `lib/providers/auth.dart`                    | User coins balance (`userAvailableCoins`, `deductCoinsLocally`) |
| `lib/providers/story.dart`                   | Episode data, `episodeWatched()` API, game mode tracking        |

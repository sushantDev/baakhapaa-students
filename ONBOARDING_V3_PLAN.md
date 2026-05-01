# Onboarding V3 — Whiteboard Implementation Plan

**Date:** April 22, 2026  
**Scope:** Full narrative onboarding redesign — dialogue-driven, puzzle-interactive, quest-based post-login flow  
**Replaces:** `ONBOARDING_REDESIGN_PLAN.md` (V2 — 15-slide passive flow)

---

## Overview

The whiteboard defines two interconnected arcs:

| Arc                     | When                                                    | Key Mechanic                                        |
| ----------------------- | ------------------------------------------------------- | --------------------------------------------------- |
| **STORY of PUPPET.DEV** | Pre-login (first launch only, non-skippable for Player) | Dialogue narrative + Picture Puzzle + Yes/No branch |
| **STORY OF PLAYER**     | Post-login (quest-based, progressive)                   | Quests → Level up → Map → Challenge system          |

---

## Arc 1 — STORY of PUPPET.DEV (Pre-Login)

### Narrative Summary

A person who spends too much time (20+ hrs) consuming content gets trapped — becomes a puppet controlled by technology. The puppet needs help escaping. The Player (unnamed at this stage) is chosen to help. If Player agrees, they get benefits in return.

> **Style:** All explanations are done in **dialogue mode** — session-based, lip-sync type conversation bubbles (NOT slide cards). Think interactive comic/chat.

### Screen-by-Screen Flow

```
[S1] Hook Screen
     "A person spending maximum time (20+ hrs) consuming content..."
     → Animated: person silhouette → transforms into puppet
     → Auto-advance or tap to continue

[S2] Trapped Screen
     "Gets trapped by technologies and engaging contents"
     → Puppet in chains / locked in digital world visual
     → Dialogue: "Needs help to get out. Asks for help..."
     → Lip-sync puppet dialogue bubble

[S3] The Challenge — Picture Puzzle
     "A challenge to the Player"
     → Interactive picture puzzle: 1 missing piece
     → Player must tap/drag the correct piece into place
     → On completion: puzzle pieces snap together → forms the END SCREEN image
     → This reveals: Puppet.dev's face / identity

[S4] Puppet.dev Introduces Itself (Dialogue sequence)
     → Puppet speaks (lip sync dialogue bubbles):
       • "I used to be an observer — watching, commenting, sharing, building community"
       • "I was researching how to get benefits through engagement"
       • "But I got trapped in the loop. I turned into a puppet."
       • "You are a chosen one — I need your help to get benefits of engagement."
       • "Help me change the world. In return, I'll give YOU benefits."

[S5] Decision Point — Yes or No
     → Big prompt: "Puppet lets you decide"
     → Two options:
       [YES] → continue onboarding as Player
       [NO]  → out / explore as Guest (skip to app in read-only guest mode)

     ── YES BRANCH ────────────────────────────────────────────────────────
     [S6] Benefits Reveal
          → Show: list of benefits acquired
          → Gift section CTA / "think again" option
          → Puppet explains how to GET these benefits as a Player

     [S7] Secret Ingredient
          → "Shows its discovery — the secret ingredient:"
          → Storytelling & Trust → explain how storytelling builds trust
          → Puppet gives a short story for the user to understand

     [S8] Loyalty Points Introduction
          → Puppet gives loyalty points for listening
          → Puppet explains how to USE the points to redeem benefits
          → "Login for rewards" suggestion (CTA)

     [S9] Login / Register Screen
          → Login button → LoginScreen
          → Register button → RegistrationScreen
          → (40 pre-login onboarding coins stored in SharedPrefs for claim on login)

     ── NO BRANCH ─────────────────────────────────────────────────────────
     [S-Guest] Guest Mode Entry
          → Exit to app as guest (read-only browsing, no rewards)
          → Persistent "Join for benefits" banner in app
```

### Key Technical Requirements — Arc 1

| Feature                    | Details                                                                                                                                                                                                     |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Dialogue/Lip-Sync UI**   | Chat-bubble style widget with puppet avatar, animated typing dots, timed auto-reveal of each line. Puppet image mouth animation (simple 2-frame swap) or wiggle animation synced to text appearance timing. |
| **Picture Puzzle Widget**  | Grid with 1 blank slot. Tiles are draggable or tap-to-place. On correct placement: scale + confetti animation. Final assembled image = reveal screen (puppet identity).                                     |
| **Yes/No Branching**       | `OnboardingProvider` tracks `playerDecision` (yes/no/guest). Navigation forks at this point.                                                                                                                |
| **Guest Mode**             | SharedPrefs flag `'guest_mode': true`. App detects this and shows limited UI. Login prompt replaces gated actions.                                                                                          |
| **Pre-login Coin Staging** | On completing YES branch → store `'staged_onboarding_coins': 40` in SharedPrefs. Claimed on first login via existing `claimOnboardingReward()`.                                                             |
| **Non-skippable (Player)** | No skip button in Arc 1 for the Player path. Only back navigation between dialogue steps.                                                                                                                   |

---

## Arc 2 — STORY OF PLAYER (Post-Login)

This arc begins immediately after the Player logs in for the **first time**. It is a guided quest flow shown once, tied to their first session.

### Trigger

```
OnLogin → isFirstLogin == true → enter PlayerOnboarding quest flow
```

Flag stored: `SharedPrefs['player_story_completed'] = false` initially, `true` after all quests shown.

### Quest Flow

```
[LOGIN EVENT]
     ↓
[P1] Welcome + 40 Points Award
     → "After logging in, Puppet.dev gives 40 login Points for loyalty"
     → Animated coins flying into wallet
     → "These points will help guide you to get benefits"
     → Level increase animation (on-screen celebration)

[P2] Quest 1 — Short Storytelling Video
     → Puppet.dev presents: "Watch how storytelling builds trust and gives benefits"
     → Short video (≤ 2 mins) on storytelling value
     → On complete: level increase animation (Level 1 → 2)
     → Reward: loyalty points

[P3] Username Setup
     → "What do I call you?"
     → Input field: set display name / username
     → Saved to profile via PATCH /api/user/profile
     → Confirm → continue

[P4] Quest 2 — Long Storytelling Video
     → "Watch the long video — storytelling is the secret element to getting benefits"
     → Longer deep-dive video on storytelling
     → On complete: Level up (→ Level 2)
     → Triggers: Map Concept + Shop Section unlock

[P5] Map Concept / Shop Unlock Screen
     → "Claim more points and help Puppet's quest for return on engagement"
     → Visual: map/quest board showing unlocked areas
     → CTA: "Explore Shop" and "View your Story feed"

[P6] Challenge Introduction
     → "Become a better person — use engagement as your benefit"
     → Device challenge reveal: Phone / Laptop / Monitor
     → "Earn loyalty points to enter challenges"
     → CTA: "Enter your first challenge"

[P7] Content Overview — "For You"
     → What's unlocked for the Player:
       • Stories (episodes/seasons)
       • Short Stories (shorts)
       • Shop (products/affiliate)
       • Free Challenge participation
     → "Completion results in level upgrade"
```

### Level Progression Tiers (from whiteboard)

| Level Range | Unlock Type                   | Content                                                             |
| ----------- | ----------------------------- | ------------------------------------------------------------------- |
| Level 1–10  | **Point-based quests**        | Complete content, quizzes, challenges → earn points → level up      |
| Level 15–20 | **Loyalty-based information** | Premium educational content unlocked by loyalty standing            |
| Level 20+   | **Payment or loyalty badges** | Badges unlockable via shop purchase OR social media promotion tasks |

### Key Technical Requirements — Arc 2

| Feature                    | Details                                                                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **40 Login Points**        | POST `/api/loyalty/award` with type `'first_login'` (idempotent — backend guards duplicate awards). Animate with existing coin-fly animation.          |
| **Quest Tracking**         | New `PlayerQuestProvider` (or extend `RewardsProvider`) with state: `questStep` (0–7), `questCompleted`. Persisted via SharedPrefs + backend.          |
| **Level-Up Animation**     | Reuse/extend existing level-up overlay (Pusher event `level_upgraded`). Trigger locally during quest flow without Pusher if needed.                    |
| **Username Screen**        | Simple `TextField` screen. PATCH to `/api/user/profile` with `{ "username": "..." }`. Validation: 3–20 chars, alphanumeric + underscore.               |
| **Video Player**           | Use existing `FlickVideoPlayer` (stories) or `MediaKit` (shorts) for quest videos. Videos hosted on CDN.                                               |
| **Map/Quest Board**        | New visual component: grid of unlocked zones. Each zone = a feature area (Stories, Shop, Challenges). Locked zones shown as greyed out with lock icon. |
| **Challenge Entry**        | Links to existing Challenge system. First challenge is free. `ChallengeProvider.enterChallenge()` flow.                                                |
| **Guest → Player Upgrade** | When guest clicks any gated action → show mini-onboarding CTA → register → immediately enter Arc 2 quest flow.                                         |

---

## Creator Path (##CREATOR — Whiteboard Note)

The whiteboard marks `## CREATOR` on the top right. Details were not written, but the architecture must support a separate onboarding path for Creator role.

**Placeholder scope (to be designed in next whiteboard session):**

- Creator onboarding skips the "trapped puppet" narrative (different tone)
- Focuses on: content creation tools → first upload wizard → audience building → monetization
- Separate quest flow post-login for creators

---

## Architecture Changes Required

### Files to Create

| File                                                 | Purpose                                   |
| ---------------------------------------------------- | ----------------------------------------- |
| `lib/screens/onboarding/dialogue_screen.dart`        | Lip-sync dialogue bubble system for Arc 1 |
| `lib/screens/onboarding/picture_puzzle_screen.dart`  | Interactive puzzle widget                 |
| `lib/screens/onboarding/decision_screen.dart`        | Yes/No branching screen                   |
| `lib/screens/onboarding/benefits_screen.dart`        | Post-yes benefits reveal                  |
| `lib/screens/onboarding/guest_entry_screen.dart`     | Guest mode confirmation                   |
| `lib/screens/onboarding/player_quest_screen.dart`    | Post-login Arc 2 quest wrapper            |
| `lib/screens/onboarding/quest_video_screen.dart`     | Quest 1 & 2 video player                  |
| `lib/screens/onboarding/username_setup_screen.dart`  | "What do I call you?" screen              |
| `lib/screens/onboarding/map_concept_screen.dart`     | Map/quest board visual                    |
| `lib/screens/onboarding/challenge_intro_screen.dart` | Challenge system intro                    |
| `lib/providers/player_quest_provider.dart`           | Quest state management                    |
| `lib/widgets/dialogue_bubble.dart`                   | Reusable lip-sync bubble widget           |
| `lib/widgets/picture_puzzle.dart`                    | Puzzle tile widget                        |

### Files to Modify

| File                                      | Change                                                                |
| ----------------------------------------- | --------------------------------------------------------------------- |
| `lib/screens/auth/onboarding_screen.dart` | Replace 15-slide `PageView` with dialogue-driven navigator            |
| `lib/providers/onboarding_provider.dart`  | Add `playerDecision`, `guestMode`, `dialogueStep` state               |
| `lib/screens/auth/login_screen.dart`      | After first login, route to `PlayerQuestScreen` instead of HomeScreen |
| `lib/screens/auth/splash_screen.dart`     | Add guest mode routing                                                |
| `lib/main.dart`                           | Register new routes + `PlayerQuestProvider`                           |

### New SharedPrefs Keys

| Key                      | Type                              | Purpose                          |
| ------------------------ | --------------------------------- | -------------------------------- |
| `player_decision`        | String (`'yes'`/`'no'`/`'guest'`) | Arc 1 decision outcome           |
| `guest_mode`             | bool                              | Whether user is in guest mode    |
| `player_story_completed` | bool                              | Whether Arc 2 quest flow is done |
| `player_quest_step`      | int                               | Last completed quest step (0–7)  |
| `username_set`           | bool                              | Whether username has been set    |

---

## Implementation Phases

### Phase 1 — Dialogue System + Puzzle (Arc 1 Screens S1–S3)

**Goal:** Replace current slide-based onboarding with dialogue-bubble narrative.

- Build `DialogueBubble` widget (avatar + text + typing animation)
- Build `DialogueScreen` that plays through a list of dialogue lines sequentially
- Build `PicturePuzzleScreen` with drag-and-drop/tap-to-place tiles
- Hook up S1 (hook), S2 (trapped), S3 (puzzle) in new onboarding flow

**Verify:**

- [ ] Dialogue bubbles animate in one line at a time
- [ ] Puppet mouth/wiggle animation synced to text reveal
- [ ] Picture puzzle: correct piece snaps, wrong piece returns
- [ ] Puzzle completion triggers reveal animation

### Phase 2 — Puppet Introduction + Decision Branch (Arc 1 Screens S4–S9)

**Goal:** Complete Arc 1 with branching YES/NO logic.

- Build `DecisionScreen` with animated Yes/No cards
- Build `BenefitsScreen` (gift reveal + think again)
- Build `SecretIngredientScreen` (storytelling + loyalty points intro)
- Implement guest mode (NO branch → `GuestEntryScreen` → limited HomeScreen)
- Wire login CTA at end of YES branch

**Verify:**

- [ ] YES → benefits → storytelling → login CTA
- [ ] NO → guest mode entry, SharedPrefs `guest_mode: true`
- [ ] Guest sees "Join for benefits" banner in app
- [ ] Pre-login staged coins saved to SharedPrefs

### Phase 3 — Post-Login Quest Flow (Arc 2 Screens P1–P3)

**Goal:** First-login quest flow through P1 (90 pts), P2 (Quest 1 video), P3 (username).

- Build `PlayerQuestProvider` with step tracking
- Build `WelcomeQuestScreen` (90 points + level animation)
- Build `QuestVideoScreen` (short video + completion reward)
- Build `UsernameSetupScreen` ("What do I call you?")
- Wire post-login routing: `isFirstLogin` → `PlayerQuestScreen`

**Verify:**

- [ ] 90 coins awarded once on first login (idempotent)
- [ ] Level increase animation plays after Quest 1 video
- [ ] Username saved to backend
- [ ] Quest step persisted in SharedPrefs

### Phase 4 — Map, Shop, Challenge Intro (Arc 2 Screens P4–P7)

**Goal:** Complete Arc 2 with level-up, map concept, and challenge intro.

- Build `MapConceptScreen` (quest board, locked/unlocked zones)
- Build `ChallengeIntroScreen` (device challenge types + entry CTA)
- Build `ContentOverviewScreen` ("For You" summary)
- Level progression tier display (point vs loyalty vs badge)

**Verify:**

- [ ] Quest 2 video completes → Level up to Level 2
- [ ] Map shows correct locked/unlocked state
- [ ] Challenge intro links to existing challenge system
- [ ] Content overview screen exits to HomeScreen
- [ ] `player_story_completed` set to true after P7

### Phase 5 — Creator Path Placeholder + Polish

**Goal:** Stub Creator onboarding path + end-to-end testing.

- Route Creator role selection → Creator placeholder screen
- Full regression test of both branches (YES / Guest)
- Performance check: puzzle animation, dialogue timing
- Asset creation list for design team (puzzle images, dialogue frames)

---

## Assets Required (Design Team)

| Asset                        | Type            | Usage                                             |
| ---------------------------- | --------------- | ------------------------------------------------- |
| `puppet_trapped.gif`         | GIF             | S1/S2 — person becoming puppet, trapped in chains |
| `puzzle_pieces_*.png`        | PNG (6–9 tiles) | S3 — Picture Puzzle tiles                         |
| `puzzle_reveal.png`          | PNG             | S3 — completed puzzle = puppet identity reveal    |
| `puppet_dialogue_open.png`   | PNG             | Puppet mouth-open frame (lip sync)                |
| `puppet_dialogue_closed.png` | PNG             | Puppet mouth-closed frame (lip sync)              |
| `benefits_gift.gif`          | GIF             | S6 — benefits/gift reveal animation               |
| `storytelling_secret.png`    | PNG             | S7 — secret ingredient visual                     |
| `map_concept.png`            | PNG             | P5 — quest board / map overview                   |
| `device_challenge.png`       | PNG             | P6 — phone/laptop/monitor challenge visual        |
| `90_points_award.gif`        | GIF             | P1 — coin fly animation for 90 pts                |

---

## Open Questions (Clarify Before Phase 1)

1. **Lip-sync style** — Is the puppet mouth animation a real 2-frame swap, or just a wiggle/bounce on the avatar while text appears?
2. **Picture puzzle size** — How many pieces? (3×3 = 9 tiles recommended for mobile)
3. **Puzzle image** — What does the completed puzzle reveal? (Puppet.dev logo? Puppet face?)
4. **Quest videos** — Are the short/long storytelling videos already produced, or does the design team need to create them?
5. **90 points backend endpoint** — Does `/api/loyalty/award` accept a `'first_login'` type, or does a new endpoint need to be created?
6. **Creator onboarding** — When will the Creator whiteboard session happen to detail that path?
7. **Guest mode depth** — What features are accessible as a guest? (View-only stories? All public content?)

---

## Summary of What Changes from V2

| V2 (Current)                 | V3 (This Plan)                                   |
| ---------------------------- | ------------------------------------------------ |
| 15 passive slides            | Dialogue-driven narrative with lip sync          |
| Single quiz question         | Interactive picture puzzle                       |
| No branching                 | YES/NO decision with guest path                  |
| 40 coin reward               | 40 pre-login staged + 90 post-login = 130 total  |
| Onboarding ends at login CTA | Post-login quest arc (P1–P7) continues           |
| No quest system              | Structured quests with level-up animations       |
| No username setup            | "What do I call you?" screen post-login          |
| No map/shop intro            | Map concept + Shop unlock in quest flow          |
| Static level display         | Live level-up animations at each quest milestone |

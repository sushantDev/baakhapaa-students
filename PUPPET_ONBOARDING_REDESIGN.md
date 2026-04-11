# Puppet-Driven Onboarding Redesign — Business Analysis & Implementation Strategy

> **Status**: Planning  
> **Last Updated**: March 17, 2026  
> **Scope**: Full onboarding redesign with role-based paths, puppet narrative, and interest selection integration  
> **Related**: `Frame-by-Frame Onboarding Documentation.pdf`, `lib/screens/onboarding/interest_selection_screen.dart`

## TL;DR

Redesign the onboarding flow from the current static 4-page carousel into a **26-frame puppet-guided narrative experience** with role-based paths (Player/Creator/Vendor), integrated interest selection, and gamified progression. The puppet character transforms from a metaphorical concept into the app's interactive guide, combining storytelling + quizzes + reward psychology to drive retention from the first minute.

---

## Part 1: Business Analysis

### 1.1 Current State Assessment

| Component                                                                             | Status             | Issue                                                                                                                                                          |
| ------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **OnboardingScreen** (`lib/screens/auth/onboarding_screen.dart`)                      | Active             | 4-page image carousel (Play, Learn, Earn, Join) → minimal engagement, passive experience                                                                       |
| **WelcomeScreen** (`lib/screens/auth/welcome_screen.dart`)                            | Active             | Advertisement video + Login/Register buttons — no personalization                                                                                              |
| **InterestSelectionScreen** (`lib/screens/onboarding/interest_selection_screen.dart`) | Built but orphaned | Exists with full API integration but NOT wired into onboarding flow                                                                                            |
| **Puppet System**                                                                     | Fully built infra  | Backend + frontend complete (PuppetInteractionMixin, 150+ screen mappings, progress tracking) but NOT introduced during onboarding. Users discover it randomly |
| **Role Selection**                                                                    | Missing            | No UI exists. All users default to `'player'` role at registration                                                                                             |

### 1.2 Why Puppet-Driven Onboarding Is More Effective

The current flow is passive: watch images → tap next → register. The puppet narrative turns this into **active participation**:

| Current Carousel                                 | Puppet Onboarding                                                            |
| ------------------------------------------------ | ---------------------------------------------------------------------------- |
| 4 static images                                  | 26 interactive frames with animations, quizzes, and rewards                  |
| No engagement hook                               | "Not knowing makes you a puppet" creates emotional investment                |
| Users discover puppet randomly post-registration | Users meet puppet from minute-one, increasing lifetime dialog engagement     |
| No pre-registration reward                       | Users earn coins pre-signup → sunk-cost motivation to complete registration  |
| 0% quiz exposure before app entry                | Users learn quiz mechanics during onboarding → lower first-session confusion |

**Psychological flow**: Curiosity → Story engagement → Problem awareness → User participation → Reward feedback → Personalization

**Key effectiveness drivers**:

1. **Narrative hook** — "Not knowing makes you a puppet" metaphor creates emotional investment before signup
2. **Behavioral priming** — Users learn quiz mechanics BEFORE entering the app, reducing confusion and first-session drop-off
3. **Reward conditioning** — Earning coins pre-registration creates sunk-cost motivation to complete signup
4. **Self-select bias** — Asking engagement questions (Frame 2) filters passive downloaders from active users early
5. **Puppet introduction** — Users understand the assistant character from minute-one, increasing puppet dialog engagement throughout app lifetime

### 1.3 Existing Video Content — Redundancy Assessment

The current carousel already shows brand videos. The puppet onboarding **replaces** these with higher-engagement content:

- Static images → **Interactive animations** (puppet silhouette, wire-breaking, vice symbols)
- Passive watching → **Active participation** (quizzes, tapping interactions)
- Generic brand video → **Personalized narrative** (user helps puppet escape → earns coins → claims rewards)

**Recommendation**: Phase out the current 4-page carousel entirely. Repurpose the WelcomeScreen video as a "skip to login" fallback for returning users only.

### 1.4 Missing: Role-Based Onboarding Paths

The Frame-by-Frame documentation focuses exclusively on the **Player path**. Three distinct paths are needed:

| Role           | Value Proposition                                  | Onboarding Focus                                                                       |
| -------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Player** 🎮  | Learn through quizzes, earn coins, level up        | Current PDF flow: puppet narrative → quiz → rewards → interest selection               |
| **Creator** 🎬 | Build content, grow audience, earn from engagement | Content creation tools intro → first season/short upload wizard → monetization preview |
| **Vendor** 🛍️  | Sell products, affiliate partnerships, reach users | Shop setup → product listing → affiliate system intro → creator partnership options    |

### 1.5 Interest Selection Integration Point

`InterestSelectionScreen` maps to **Frame 25-26** (Reward Preference + Reward Interest Input) in the documentation:

- **Frame 25 replacement**: Instead of generic "reward interests," show genre-based interest selection (Self-Help, Business, Psychology, Finance, Science, Philosophy, Productivity, Health, Relationships, History, Creativity, Spirituality)
- **Personalization anchor**: Selected interests immediately affect the Story feed ordering (already wired in backend `SeasonController` lines 357-369)
- **Post-registration step**: After Frame 18 (Registration), before Frame 22 (Story Page), insert interest selection
- **Existing API endpoints**:
  - `GET /api/user/interests/available` — Fetch genre options
  - `GET /api/user/interests` — Fetch user's existing selections
  - `POST /api/user/interests` — Save 3-5 selected genres

---

## Part 2: Frame-by-Frame Breakdown (Player Path)

### Pre-Onboarding: Role Selection Gate

| Frame | Purpose                                     | UI Elements                                                              | Interaction   |
| ----- | ------------------------------------------- | ------------------------------------------------------------------------ | ------------- |
| **0** | Self-identify as Player, Creator, or Vendor | Three cards with value propositions, "Not sure? Start as Player" default | Tap role card |

### Act 1: Introduction & Curiosity (Frames 1-3)

| Frame   | Purpose                  | UI Elements                                     | Interaction                       |
| ------- | ------------------------ | ----------------------------------------------- | --------------------------------- |
| **1**   | Welcome — Brand identity | App logo with fade-in animation                 | Auto-transitions (no interaction) |
| **1.2** | Entry point options      | Referral codes, vendor entry etc.               | Optional tap                      |
| **2**   | Trigger curiosity        | Thought-provoking question + interaction button | Tap response                      |
| **3**   | Value proposition        | Point icon illustration + short value statement | Auto-transitions                  |

### Act 2: Puppet Narrative (Frames 4-9)

| Frame   | Purpose                      | UI Elements                                                                        | Interaction                  |
| ------- | ---------------------------- | ---------------------------------------------------------------------------------- | ---------------------------- |
| **4**   | Introduce puppet metaphor    | "Not knowing makes you a puppet" visual — silhouette of person turning into puppet | Auto-transitions after delay |
| **5**   | Puppet character intro       | Puppet silhouette animation + Next button                                          | Tap Next                     |
| **5.2** | "Get out of the puppet zone" | Escape concept visual                                                              | Interaction TBD              |
| **6**   | Puppet trapped by wires      | Cinematic wire-binding animation                                                   | Auto-transitions to quiz     |
| **7**   | Quiz button discovery        | Quiz icon + puppet asking for help + "Click here" guide                            | Tap Quiz button              |
| **8**   | First quiz question          | Question + single answer option + progress bar intro                               | Select correct answer        |
| **9**   | Puppet freedom               | Wire-breaking animation — puppet regains control                                   | Auto-transitions             |

### Act 3: Rewards & Education (Frames 10-16)

| Frame    | Purpose                  | UI Elements                                                                                                                                                                        | Interaction                   |
| -------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| **10**   | Progress reward feedback | Progress bar increase + puppet info + unlocked shackles background                                                                                                                 | Auto-transitions              |
| **11**   | Puppet explains concepts | Puppet dialogue + Continue button                                                                                                                                                  | Tap Continue                  |
| **12**   | Eight Vices introduction | Animation video (15-30s) showing 8 vice symbols: Greed, Ego, Anger, Fear, Attachment, Jealousy, Lust, Laziness. User selects vice to interact with → category/swipe → video → quiz | Vice selection + watch + quiz |
| **13**   | Second quiz prompt       | Quiz icon/button                                                                                                                                                                   | Tap Quiz                      |
| **14**   | Second quiz question     | Question + answer choices + reward animation                                                                                                                                       | Select correct answer         |
| **14.2** | Vice-to-point conversion | Animation showing vice symbol transforming into point                                                                                                                              | Auto-transitions              |
| **15**   | Achievement feedback     | Full progress bar + coin reward animation + info text                                                                                                                              | Auto-transitions              |
| **16**   | Puppet congratulations   | Puppet comes to foreground from standard placement + dialogue                                                                                                                      | Auto-transitions              |
| **16.2** | Gift reveal              | Progress bar completes, reveals gift → goes to its place                                                                                                                           | Auto-transitions              |

### Act 4: Registration & Personalization (Frames 17-26)

| Frame  | Purpose                    | UI Elements                                                            | Interaction    |
| ------ | -------------------------- | ---------------------------------------------------------------------- | -------------- |
| **17** | Login prompt               | "Click login to claim your reward" + Login button                      | Tap Login      |
| **18** | Registration               | Name, email, credentials, Register button, social login                | Complete form  |
| **19** | Landing/Profile page       | User profile entry to app                                              | View profile   |
| **20** | Puppet reward info         | Puppet informs about earned points + Next button                       | Tap Next       |
| **21** | Username personalization   | Input field + Confirm button                                           | Type username  |
| **22** | Story page intro           | Story interface, cards or feed                                         | Browse stories |
| **23** | Level system intro         | Puppet explains levels + welcome message                               | Tap Next       |
| **24** | Level upgrade info         | How leveling up works + Continue interactions                          | Continue       |
| **25** | Interest/reward preference | Puppet asks about interests → **InterestSelectionScreen** (3-5 genres) | Select genres  |
| **26** | Reward interest input      | Text input for reward motivation (100 words)                           | Write + submit |

---

## Part 3: Implementation Plan

### Phase 1 — Role Selection Gate (Pre-Onboarding)

**Purpose**: Let users self-identify before entering role-specific onboarding.

**Steps**:

1. **Create `RoleSelectionScreen`** at `lib/screens/onboarding/role_selection_screen.dart`
   - Three cards: Player (🎮), Creator (🎬), Vendor (🛍️) with value propositions
   - Each card shows 2-3 bullet benefits + illustration
   - "Not sure yet? Start as Player" default option
   - Route: `/role-selection`

2. **Add route** in `lib/main.dart` routes map (~line 909 area)

3. **Insert between** Frame 1 (Welcome/Logo) and Frame 2 (Engagement Question)
   - Player → Full puppet narrative flow (Frames 2-26)
   - Creator → Creator-specific onboarding (Phase 4)
   - Vendor → Vendor-specific onboarding (Phase 4)

4. **Store selection** in SharedPreferences and pass to registration API
   - Backend `AuthController.php` line 81 already accepts `role` in request body

**Key files**:

- `lib/screens/auth/onboarding_screen.dart` — Replace with new orchestrated flow
- `lib/screens/auth/register_screen.dart` — Pass role from selection (line 183, register call)
- `lib/main.dart` — Add route
- Backend: `app/Http/Controllers/api/AuthController.php` — Already accepts `role`

### Phase 2 — Puppet Narrative Engine (Player Path, Frames 1-16)

**Purpose**: Build the interactive puppet-guided onboarding as described in the Frame-by-Frame documentation.

**Steps**:

5. **Create `PuppetOnboardingController`** at `lib/screens/onboarding/puppet_onboarding_controller.dart`
   - Manages frame progression state (current frame, animations, quiz answers)
   - Tracks progress bar (fills across frames 1→16)
   - Handles coin rewards earned during onboarding (stored locally until registration)

6. **Create individual frame widgets** in `lib/screens/onboarding/frames/`:
   - `welcome_frame.dart` — Frame 1: Logo animation + auto-transition
   - `engagement_question_frame.dart` — Frame 2: Curiosity question + tap interaction
   - `value_proposition_frame.dart` — Frame 3: Point icon + value statement
   - `puppet_metaphor_frame.dart` — Frame 4-5: "Not knowing makes you a puppet" + silhouette animation
   - `puppet_trapped_frame.dart` — Frame 6: Wire-binding cinematic animation
   - `quiz_interaction_frame.dart` — Frame 7-8: Quiz button discovery + first quiz question
   - `puppet_freedom_frame.dart` — Frame 9: Wire-breaking animation
   - `progress_reward_frame.dart` — Frame 10: Progress bar + reward feedback
   - `puppet_dialogue_frame.dart` — Frame 11: Puppet explains concepts
   - `vices_frame.dart` — Frame 12: Eight vices animation/selection
   - `final_quiz_frame.dart` — Frame 13-14: Second quiz + reward animation
   - `puppet_congrats_frame.dart` — Frame 15-16: Full progress + gift reveal

7. **Wire Lottie/Rive animations** for puppet character (silhouette, trapped, freedom, congratulations)
   - Store animation assets in `assets/animations/onboarding/`

8. **Integrate with backend puppet system**:
   - Use existing `GET /api/puppets/screen/onboarding_frame_{N}/suggestions` for quiz content
   - Track progress via `POST /api/puppets/interaction/{id}/track`

**Key files to reuse**:

- `lib/widgets/puppet_dialog.dart` — Reuse dialog rendering pattern (scale animation, avatar, actions)
- `lib/services/puppet_interaction_service.dart` — API integration for fetching frame content
- `lib/providers/puppet_interaction_provider.dart` — State management pattern to follow
- Backend: `app/Http/Controllers/api/PuppetInteractionController.php` — Add onboarding-specific interactions

### Phase 3 — Registration + Interest Selection Integration (Frames 17-26)

**Purpose**: Convert onboarding engagement into registered user with personalized feed.

**Steps**:

9. **Create `OnboardingLoginPromptFrame`** — Frame 17: "Login to claim your earned coins" CTA
   - Show accumulated coins from quiz answers
   - "Login" and "Register" buttons (reuse WelcomeScreen pattern)

10. **Modify `RegisterScreen`** to accept pre-earned coins and selected role
    - After registration, credit onboarding coins via `POST /api/onboarding/complete`
    - Pass `role` from RoleSelectionScreen to registration body

11. **Integrate `InterestSelectionScreen`** as post-registration step
    - Set `isOnboarding = true` (already supported in current implementation)
    - Insert between registration (Frame 18) and story page (Frame 22)
    - Maps to Frame 25-26 conceptually

12. **Create `OnboardingCompleteFrame`** — Puppet welcome message + level info (Frames 23-24)
    - Puppet explains level system
    - Shows first-login reward
    - Navigates to StoryScreen

**Key files**:

- `lib/screens/onboarding/interest_selection_screen.dart` — Already built, wire into flow
- `lib/screens/auth/register_screen.dart` — Modify to accept role + pre-earned coins
- `lib/providers/auth.dart` — `isFirstLogin` getter (line 251), `changeFirstLoginStatus()` method
- Backend: `app/User.php` — `is_first_login` field already exists

### Phase 4 — Creator & Vendor Onboarding Paths (Future)

**Purpose**: Role-specific guidance for non-player users.

**Steps**:

13. **Design Creator onboarding frames** (separate document needed):
    - Puppet introduces content creation tools
    - Demo: Create a short or season
    - Monetization preview (coin earnings, audience growth)
    - Interest selection scoped to creator topics

14. **Design Vendor onboarding frames** (separate document needed):
    - Puppet introduces shop/affiliate system
    - Demo: List a product
    - Partnership/affiliate program overview
    - Interest selection scoped to vendor categories

15. **Both paths converge** at interest selection + story page entry

**Key files to reference**:

- `lib/screens/create/story/` — Creator content creation screens
- `lib/screens/shop/` — Vendor shop screens
- Backend: `app/Http/Controllers/UserController.php` lines 246, 264 — Role assignment endpoints

### Phase 5 — Backend Support

**Steps**:

16. **Seed puppet interactions** for onboarding:
    - Populate `puppet_interactions` table with frames 1-26 content
    - Screen names: `onboarding_frame_1` through `onboarding_frame_26`
    - Include quiz questions, dialogue text, animation references

17. **Add onboarding coin crediting endpoint**:
    - `POST /api/onboarding/complete` — Credits pre-earned coins after registration
    - Validates coins earned match expected quiz answers
    - Creates `CoinLog` entries with status `'earned'` and source `'onboarding'`

18. **Add `onboarding_completed_at` timestamp** to `users` table:
    - Migration: `add_onboarding_completed_at_to_users_table`
    - Tracks whether user completed full onboarding vs skipped

19. **Align `UserInterest` genres** with `Genre` model:
    - Currently hardcoded genre names in `UserInterestController`
    - Should reference `genres` table for data consistency

**Key files**:

- Backend: `app/Http/Controllers/api/PuppetInteractionController.php` — Add onboarding frame queries
- Backend: `app/Http/Controllers/api/UserInterestController.php` — Genre alignment
- Backend: `database/seeders/` — New seeder for onboarding puppet interactions
- Backend: `app/UserPuppetProgress.php` — Track onboarding frame completion

---

## Part 4: Complete User Flow Diagram

# Baakhapaa for Students — Technical Plan

## Overview

Fork both the Laravel backend and Flutter app into separate repos per school. Configure branding, API URLs, Firebase, and storage per school. Seed academic pseudo-content (subjects, chapters, quizzes, challenges, gifts). Design the process as a repeatable template so adding future schools is a checklist operation, not a development project.

**Deployment model:** Separate repo clone per school (not shared DB multi-tenant)
**Branding:** White-label APK/IPA per school (new name, logo, colors)
**Content:** Mix — central Baakhapaa admin seeds library, teacher/creators curate
**Teacher role:** Reuse existing `creator` role
**Coin economy:** Full (earn/spend, shop, gifts)
**Payments:** Institutional subscription (school pays, students free)
**Flutter:** Fork into new repo per school (e.g., `baakhapaa_students_pilot`)
**Backend:** Two infrastructure options documented — pick per school budget

---

## Phase 0 — Preparation & Repo Setup

1. Fork `baakhapaa_backend` → `baakhapaa_students_[school]_backend` (private Git repo)
2. Fork `baakhapaa_flutter_v3` → `baakhapaa_students_[school]` (private Git repo)
3. Create `SCHOOL_DEPLOYMENT_GUIDE.md` in each fork — master checklist of every file to change per new school _(this is the scalability artifact)_

---

## Phase 1 — Backend: Configure & Infrastructure

### Files to change per fork

| File                                         | What Changes                                                                                             |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `.env`                                       | `APP_NAME`, `APP_URL`, `DB_DATABASE`, `DB_PASSWORD`, `PUSHER_APP_*`, `STRIPE_*` (or disable), `KHALTI_*` |
| `database/seeders/SettingsTableSeeder.php`   | `site_name`, `site_logo`, `currency_*` → school's identity                                               |
| `database/seeders/UsersTableSeeder.php`      | School admin email/password                                                                              |
| `baakhapaa-flutter-firebase-adminsdk-*.json` | Replace with school's Firebase Admin SDK JSON                                                            |
| `config/filesystems.php`                     | New DigitalOcean Spaces bucket/endpoint for school                                                       |

### Infrastructure options (pick per school budget)

- **Option A — Same server, new DB:** New subdomain `school1.app.baakhapaa.com`, new MySQL DB `baakhapaa_school1`, new Nginx vhost, shared Redis/queue pool. Lower cost.
- **Option B — Separate VPS:** New DigitalOcean Droplet, own DB, own SSL, fully isolated. Higher cost, zero blast radius.

### New migrations

1. `add_school_to_users_table` — adds `school` (nullable string) to `users` table — lets you filter/display which school a user belongs to. Update `User::$fillable` and `UserController` profile response.
2. `create_school_subscriptions_table` — columns: `school_name`, `admin_email`, `plan`, `status`, `expires_at`, `seats`

### Institutional subscription setup

- New `SchoolSubscriptionSeeder` — seeds pilot school record
- Manual Stripe invoice to school admin for now; webhook automation in Phase 2+
- New `SchoolController` or extend `SettingController` — endpoint to verify subscription validity

Run: `php artisan migrate:fresh --seed`

---

## Phase 2 — Backend: Pseudo Content Seeding

### Content mapping (academic + general knowledge mix)

| Baakhapaa Concept    | Student Context                                   |
| -------------------- | ------------------------------------------------- |
| Season               | Subject (e.g., "Grade 8 Mathematics")             |
| Episode              | Chapter video (e.g., "Chapter 1: Algebra Basics") |
| Questions            | Chapter MCQ quiz (5 per episode)                  |
| Shorts               | Fun fact clips, knowledge shorts per subject      |
| Challenge            | Subject competition (Season-type + Shorts-type)   |
| Gift (`type='gift'`) | School merchandise, certificates, vouchers        |
| Product              | Study materials, stationery                       |
| Achievement          | Milestones ("Watch 10 Episodes", "Score 100%")    |

### Seeders to create in `database/seeders/student/`

- `StudentContentSeeder` — 3–4 Seasons, 3 Episodes each, 5 MCQ Questions each (placeholder DO Spaces / YouTube URLs)
- `StudentChallengeSeeder` — 2 challenges (one Season-type, one Shorts-type), 30-day deadline
- `StudentProductGiftSeeder` — 3 gifts (`type='gift'`), 2 products (stationery)
- `StudentShortsSeeder` — 5 short knowledge clips
- `StudentAchievementSeeder` — 5 starter achievements

All seeder records use the seeded teacher (creator role) account as `user_id`.

---

## Phase 3 — Flutter: Fork & Rebrand

### Mandatory file changes per school fork

| File                                                    | Change                                                    |
| ------------------------------------------------------- | --------------------------------------------------------- |
| `pubspec.yaml`                                          | `name`, `description`, `version`                          |
| `lib/models/url.dart`                                   | `rootUrl` → new backend subdomain                         |
| `lib/config/pusher_config.dart`                         | New Pusher app key + `authEndpoint`                       |
| `lib/config/app_credentials.dart`                       | Stub Khalti/Stripe (no student payments)                  |
| `lib/theme/app_colors.dart`                             | School primary + accent colors                            |
| `assets/images/onboarding/logo_baakhapaa.png`           | School logo                                               |
| `android/app/build.gradle`                              | `applicationId` (e.g., `com.school1.baakhapaa`)           |
| `android/app/src/main/AndroidManifest.xml`              | `android:label`                                           |
| `ios/Runner/Info.plist`                                 | `CFBundleName`, `CFBundleIdentifier`                      |
| `ios/Runner.xcodeproj/project.pbxproj`                  | Bundle ID                                                 |
| `google-services.json` + `ios/GoogleService-Info.plist` | School Firebase project                                   |
| `firebase_options.dart`                                 | Regenerate via `flutterfire configure`                    |
| `lib/l10n/app_en.arb`                                   | `appTitle` → school app name                              |
| `lib/providers/onboarding_provider.dart`                | Update `OnboardingSlide` list — school-specific messaging |
| `lib/screens/auth/onboarding_screen.dart`               | Update slide content/imagery for school context           |

### Routes to disable in `main.dart` (student fork)

- `/affiliate-dashboard` — affiliate dashboard
- Creator role request screen
- Vendor product creation screens
- Stripe merchant payment flows

### Keep fully intact

Coin economy, challenges, gifts, shop (school gifts only), shorts, season/episode learning flow, leaderboard, achievements, Pusher real-time rewards overlay.

---

## Phase 4 — Flutter: Student UX Adjustment

1. `SplashScreen` default route: change post-login home to `StoryScreen` (subjects) instead of `ShortsScreen`
2. `InterestSelectionScreen`: pre-filter interests to academic genres seeded in backend
3. `UserScreen` / profile: display `school` field returned from backend
4. `OnboardingProvider`: replace generic platform slides with school-branded content (school name, subjects available, how coins work for students)

---

## Phase 5 — Multi-School Scalability Template

Create `SCHOOL_DEPLOYMENT_GUIDE.md` documenting:

1. Backend fork checklist with every env var and file
2. Flutter fork checklist with every file from Phase 3
3. Infrastructure decision tree (Option A vs. Option B)
4. Content seeder how-to for adding new grades/subjects
5. APK/IPA build and signing guide per school
6. _(Future, deferred)_ If shared-DB model is ever desired: add `school_id` FK to `seasons`, `shorts`, `challenges`, `products` — documented but not needed while using separate DBs

---

## Relevant Files

### Backend

- `database/seeders/` — add `student/` subfolder for new seeders
- `database/migrations/` — 2 new migrations (`add_school_to_users`, `create_school_subscriptions`)
- `database/seeders/SettingsTableSeeder.php` — branding config
- `database/seeders/UsersTableSeeder.php` — admin account
- `app/Http/Controllers/api/SettingController.php` — extend for subscription verification
- `app/User.php` — add `school` to `$fillable`

### Flutter

- `lib/models/url.dart` — API URL
- `lib/config/pusher_config.dart` — Pusher credentials
- `lib/theme/app_colors.dart` — color theme
- `lib/providers/onboarding_provider.dart` — onboarding slides
- `lib/main.dart` — routes to disable

---

## Verification Checklist

1. `php artisan migrate:fresh --seed` on new school DB — no errors
2. `POST /api/login` with seeded admin → `200` + token
3. `GET /api/story` → 3–4 seeded seasons returned
4. `GET /api/v2/shorts` → 5 seeded shorts
5. `GET /api/challenges` → 2 challenges
6. `GET /api/products` → mixed gifts/products
7. Flutter: `flutter run` → app loads with school branding, school logo visible
8. Full onboarding → home screen lands on Seasons (subjects)
9. End-to-end: student login → watch episode → answer quiz → coins earned
10. End-to-end: student joins challenge → wins → reward shown via Pusher overlay

---

## Key Decisions

- Separate repo per school = natural DB isolation, zero multi-tenancy complexity in Phase 1
- Teachers reuse `creator` role — no new role/permissions engineering needed
- `school` column on `users` = lightweight label, not full FK scoping
- Institutional subscription is manual invoice at pilot stage, automate later
- No Stripe on student side v1 (school pays institutionally, students are free)
- Affiliate + vendor creation screens disabled in student fork
- Shared-DB / multi-tenant path is documented but deferred to a future phase

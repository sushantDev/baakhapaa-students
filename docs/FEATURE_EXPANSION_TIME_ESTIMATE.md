# Baakhapaa Platform Expansion — Time Estimate & Backend Assessment

**Date:** 2026-08-18
**Scope:** Full UI/UX redesign (Figma) + multi-role dashboards + events-nearby module + one-way broadcast messaging + AI integrations + district/municipality signup + direct premium course purchase.

**Assumptions used for this estimate** (confirmed with stakeholder):

- Team: **1–2 Flutter developers + 1 backend (Laravel) developer** (small team). _Update: the actual team is now known to be larger (1 CTO doing full-stack Laravel+Flutter, 1 Flutter dev, 1 Laravel dev, 4 interns) — see [STAKEHOLDER_4_MONTH_ROADMAP.md](STAKEHOLDER_4_MONTH_ROADMAP.md) for the revised 4-month plan built on the real team. The §3 full-scope figures below still reflect the original small-team assumption and are the reference point for "how long without more people."_
- Municipality / Ministry / Baakhapaa-Admin dashboards: **separate web admin panel**, not inside the mobile app.
- AI scope: LLM chatbot tutor + AI-assisted content creation + personalized/adaptive learning recommendations.
- Backend team & repo access: **available** (this session only has the Flutter repo — the Laravel backend repo, `baakhapaa_backend`, is not accessible here; assessment below is inferred from API contract docs in `docs/` and should be confirmed against the real codebase before locking the plan).
- Rollout: **phased**, incremental feature launches rather than one big-bang release.
- Payments: **Khalti + Stripe + eSewa** for direct course purchases.

---

## 1. Executive Summary

The mobile app does **not** need to be rebuilt from scratch, and the backend does **not** need to be rebuilt from scratch either — but this is a large expansion, not a small one. With the stated small team (2 Flutter + 1 backend dev), realistic full delivery of everything requested is **~11–15 months**, phased into independently shippable increments. The single biggest risk is not the mobile app — it's that **one backend developer is being asked to also build and maintain a brand-new multi-tenant government web dashboard**, on top of APIs, AI services, geolocation, messaging, and 3 payment gateways. That is the part most likely to blow the timeline (see §6).

**Bottom line on backend:** Keep the existing Laravel backend. Extend it — don't replace it. Add a Laravel Filament (or Nova) admin panel in the same codebase for the web dashboards rather than standing up a separate JS SPA; this reuses the existing backend team's skills and is the only realistic way a single backend developer covers 5 dashboard consumers.

---

## 2. Current State — What Already Exists (verified in this repo)

| Capability           | Status                                                                                                                                    | Evidence                                                                                                                                                       |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Backend stack        | Laravel, REST API, `{success, data}` response pattern                                                                                     | [docs/BaakhapaaStudents_Technical_Plan.md](../docs/BaakhapaaStudents_Technical_Plan.md), [docs/API_REQUIREMENTS.md](../docs/API_REQUIREMENTS.md)               |
| Roles                | `guest`, `player`, `creator`, `vendor`, `admin` — no `student`/`teacher`/`municipality`/`ministry` distinction yet                        | [lib/providers/auth.dart](../lib/providers/auth.dart)                                                                                                          |
| Institution concept  | "School" exists as a first-class entity (subscription, teacher-approval flows) — a usable pattern to extend to municipality/district      | [docs/BaakhapaaStudents_Technical_Plan.md](../docs/BaakhapaaStudents_Technical_Plan.md)                                                                        |
| Payments             | Khalti (coins only) + Stripe (physical products/shipping) fully wired; **no course-purchase/entitlement model yet**; eSewa not integrated | [lib/services/khalti_service.dart](../lib/services/khalti_service.dart), [docs/STRIPE_PAYMENT_INTEGRATION_PLAN.md](../docs/STRIPE_PAYMENT_INTEGRATION_PLAN.md) |
| Real-time / push     | Pusher (`reward_earned`, `level_upgraded`, `gift_available`) + FCM fully working                                                          | [lib/services/pusher_service.dart](../lib/services/pusher_service.dart)                                                                                        |
| Geolocation          | **None.** `geolocator`/`geocoding` packages present but commented out in `pubspec.yaml`, unused                                           | `pubspec.yaml`                                                                                                                                                 |
| Dashboards/analytics | Creator analytics screen exists (points, followers, achievements, seasons) — good template for student/teacher dashboards                 | [lib/screens/analytics/analytics_screen.dart](../lib/screens/analytics/analytics_screen.dart)                                                                  |
| AI                   | Hardcoded Q&A chatbot (no LLM) + speech-to-text for content input. **No LLM/OpenAI/Gemini integration at all.**                           | [lib/providers/chatbot_provider.dart](../lib/providers/chatbot_provider.dart)                                                                                  |
| Signup               | Email/password, Google/Apple social login, referral codes — **no district/municipality/location fields**                                  | [lib/screens/auth/register_screen.dart](../lib/screens/auth/register_screen.dart)                                                                              |

**Verdict:** Solid foundation to extend. Nothing here forces a rewrite. The gaps (roles, geolocation, AI, course entitlements, admin dashboards) are all additive.

---

## 3. Feature-by-Feature Breakdown & Estimates

Estimates are elapsed calendar time for the stated team, assuming phased/parallel work where the team size allows.

| #   | Workstream                                                                                                                                                                                                                         | Backend work                                                                                                               | Flutter/web work                                                          | Estimate                                                                                                                                                                                                                                        |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0   | **Foundation**: role model rework (student/teacher/municipality/ministry/baakhapaa-admin), Nepal administrative-division seed data (7 provinces / 77 districts / 753 local levels), dev environment, design-token setup from Figma | Migration + role/permission rework                                                                                         | Design token/theme setup                                                  | 2–3 wks                                                                                                                                                                                                                                         |
| 1   | **UI/UX redesign** (Figma → app), core navigation + component library first, screen-by-screen retrofit after                                                                                                                       | —                                                                                                                          | Full re-skin, ~all screens                                                | 8–12 wks (core), continues incrementally alongside other phases                                                                                                                                                                                 |
| 2   | **District/Municipality signup** — local government body account type, verification/approval workflow                                                                                                                              | New tables + admin-approval endpoint                                                                                       | Signup flow + role-specific fields                                        | 3–4 wks                                                                                                                                                                                                                                         |
| 3   | **Multi-role dashboards** (student, teacher — in-app; local level/palika, ministry, baakhapaa-admin — web) — see §3.1 for the detailed analytics spec that replaces the original placeholder estimate                              | Shared metric layer + aggregation/reporting API, nightly-rollup jobs, drill-down hierarchy (ward→palika→district→province) | Student/teacher screens (Flutter) + Filament panels (web), 5 panels total | **MVP descriptive scope (see §8): 16–17 wks. Full descriptive breadth (all groups, all 5 panels): 20–26 wks. Predictive rows: not estimated — blocked by the spec's own Data Gate (§6 of the analytics spec) until a full term of data exists** |
| 4   | **Events Nearby** (lat/lng discovery + notifications)                                                                                                                                                                              | Events CRUD, radius query (Haversine/PostGIS), Pusher/FCM trigger                                                          | Map UI, permission flow (iOS/Android review implications)                 | 4–6 wks                                                                                                                                                                                                                                         |
| 5   | **One-way broadcast messaging** (admin/ministry/local-gov → users)                                                                                                                                                                 | Announcement model, role-gated sender, targeting by district/municipality/school                                           | Inbox/notification UI                                                     | 3–4 wks                                                                                                                                                                                                                                         |
| 6   | **AI integrations**: LLM chatbot tutor, AI content-creation upgrade, adaptive/personalized recommendations (v1 heuristic, not full ML)                                                                                             | Server-side LLM proxy (keep API keys off-device), content-safety filtering, usage logging/cost caps                        | Chat UI, content-gen UI upgrade                                           | 13–19 wks                                                                                                                                                                                                                                       |
| 7   | **Direct premium course purchase** (Khalti + Stripe + eSewa)                                                                                                                                                                       | Course/entitlement model, purchase records, 3-gateway verification, refund handling                                        | Purchase flow, unlock UI                                                  | 5–7 wks                                                                                                                                                                                                                                         |

**Total (mostly sequential, some backend/frontend parallelism): ~54–70 weeks ≈ 12–16 months** for the full scope as specified (using the Phase 3 MVP-descriptive figure; add 4–9 weeks more if full descriptive breadth on all 5 panels is required before v1.1), with the small team, delivered as phased releases (each workstream ships independently rather than waiting for everything).

With a **medium team** (3–4 Flutter + 2 backend + 1 designer, the option not chosen), this compresses to roughly **6–8 months** because dashboards, AI, and payments can run in parallel instead of queuing behind one backend developer.

### 3.1 Dashboards & Analytics — Detailed Requirements

The stakeholder has since supplied a detailed analytics inventory for all 5 panels (student, teacher/creator, local level/palika, ministry, super admin), saved in full at [docs/SKILLSIKKA_DASHBOARD_ANALYTICS_SPEC.md](SKILLSIKKA_DASHBOARD_ANALYTICS_SPEC.md). It replaces the generic "dashboards" assumption used above with:

- **A shared metric layer requirement** — every metric computed once, server-side, and rendered five ways. This is new backend infrastructure, not just five separate screens; it's the single biggest technical dependency in Phase 3 and must be built before any panel ships real numbers.
- **~120 distinct metrics across 5 panels**, including genuinely hard analytics (item discrimination, distractor confusion index — psychometric-style item-response statistics; cohort retention curves; matched-comparison-group impact analysis).
- **A drill-down hierarchy** (ward → palika → district → province) that depends on Phase 2's district/municipality seed data.
- **A hard access-control rule**: learners see only their own data, teachers see named learners only within their own class, and palika/ministry/admin panels never receive learner names — counts and aggregates only. This must be enforced in the metric layer itself, not per-screen.
- **Predictive analytics is explicitly Phase-3-gated by the spec's own rules** (§6 of the spec): it cannot ship before one full completed school term, ≥5,000 learners with 8+ weeks of activity, and ≥500 outcome events exist — independent of team size or budget. This is treated as **out of scope for any near-term delivery plan**, including the 4-month plan in §8.

---

## 4. Backend: Extend, Don't Rebuild

Concrete additive changes needed in the existing Laravel app:

- **New tables**: `districts`, `municipalities` (or a seeded reference table of Nepal's official administrative divisions), `events` (with lat/lng + spatial index), `announcements` (+ targeting rules), `course_purchases`/`entitlements`, `ai_conversations`/`ai_usage_log`.
- **Role/permission rework**: current 5 roles don't map to student/teacher/municipality/ministry/baakhapaa-admin — needs a permissions layer (e.g. `spatie/laravel-permission`) rather than a single `role` string.
- **New services**: LLM proxy service (never call OpenAI/Gemini directly from the Flutter app — keys must stay server-side), geo "nearby" query service, broadcast messaging service, eSewa gateway client, a reporting/aggregation service (likely queued nightly jobs — real-time dashboard aggregation across thousands of students will not scale on ad-hoc queries).
- **Recommended**: add **Laravel Filament** as an admin panel inside the same Laravel app for the municipality/ministry/admin web dashboards, instead of a separate JS SPA. It reuses the backend team's existing skillset and is the only realistic way one backend developer supports 3 new web-facing dashboard consumers on this timeline.

No framework migration, no backend rewrite — this is incremental extension of an already-working system.

---

## 5. Security & Compliance Flags (do not skip)

- **Minors' location data**: students are very likely minors. Storing/broadcasting their geolocation and sharing engagement data with government bodies (municipality/ministry) requires explicit parental consent, data minimization (e.g. don't expose exact home location, use school/municipality-level granularity instead of live GPS), and a clear data-retention policy. This needs a short compliance review before Phase 4/Phase 3 government dashboards ship.
- **Role-gated broadcast messaging**: must be enforced server-side (not just hidden in UI) so only admin/ministry/local-gov accounts can send one-way broadcasts — an unauthenticated or under-authorized sender is a direct authorization vulnerability (OWASP A01).
- **LLM chatbot for children**: needs content-safety filtering and logging/monitoring given the student audience; do not proxy raw model output without a moderation layer.
- **Payment gateways**: all 3 (Khalti/Stripe/eSewa) verification must happen server-side against each provider's API — never trust a client-reported "payment success" to unlock course content (the current empty `backend/khalti_verify.php` in this repo is a red flag to check for in the real backend: confirm server-side amount/status verification exists, not just client-side checkout completion).

---

## 6. Risks That Could Change the Estimate

1. **Single backend developer bottleneck** — building APIs + web admin dashboards + AI proxy + geolocation + messaging + 3 payment gateways is realistically 2 backend developers' worth of scope. This is the top risk to the 11–15 month estimate; recommend at least a temporary second backend/full-stack hire for the dashboard + AI phases.
2. **Figma readiness** — "ready" designs still need to be checked for dev-handoff completeness (states, spacing/redlines, component variants). If they're concept mockups rather than dev-ready specs, add 2–4 weeks for design-to-spec work.
3. **App store review risk** — background location (Events Nearby) and a full UI overhaul both increase store review scrutiny/rejection risk; build in review buffer per release.
4. **Backend repo not reviewed** — this assessment is based on this Flutter repo's API-contract docs, not the actual Laravel codebase. Recommend a half-day backend audit before finalizing the plan to confirm the role/permission system, and whether `khalti_verify.php` reflects real server-side verification or is dead code.
5. **AI recurring cost** — LLM API usage is an ongoing operating cost, not a one-time build cost; budget for it separately from dev time.

---

## 8. 4-Month Delivery Plan — Dashboards & Analytics Workstream Only

**Scope boundary:** this plan covers only the dashboards/analytics feature (item 2 of the original 7-item request), using the detailed spec in §3.1. It does **not** include the other 6 workstreams (full UI/UX redesign, events nearby, messaging, AI, district/municipality signup, direct course purchase) — those remain on the 12–16 month track in §3 unless resourced separately.

**Feasibility verdict:** full descriptive breadth across all 5 panels in 4 months (~17 weeks) with only 1 backend developer is not credible if that developer is also expected to work on any of the other 6 workstreams concurrently. It **is** achievable if (a) the backend developer is dedicated solely to this workstream for the 4 months, and (b) the per-panel metric set is narrowed to an MVP subset now, with the remainder shipped as v1.1 in month 5–6. Predictive analytics is not part of this plan at all — it's blocked by the spec's own Data Gate regardless of effort (§3.1).

### MVP scope per panel (ships in month 4) vs. deferred to v1.1

| Panel                | Ships in 4 months                                                                                                     | Deferred to v1.1                                                                                                                       |
| -------------------- | --------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Student              | Performance (mastery score, objective status map, quiz history), Progress/habit (mastery trend, time on task, streak) | Attempts-to-mastery detail, retention-check scoring, challenge/reward league                                                           |
| Teacher/creator      | Reach, Course performance (enrolment funnel, completion rate, drop-off curve)                                         | Question/confusion analytics (item discrimination, distractor index — needs real psychometric calculation), audience segmentation      |
| Local level (palika) | Reach, Participation, core Learning outcomes (proficiency bands, average mastery)                                     | Equity analysis, Impact/before-after comparison                                                                                        |
| Ministry             | National reach, core Outcomes (proficiency index, band distribution)                                                  | Equity, System/supply, Impact analysis                                                                                                 |
| Super admin          | Platform health, Growth, Finance, basic Trust & Safety queue                                                          | Full Data quality panel, Governance (model registry/drift — moot until predictive ships anyway), deep Trust & Safety anomaly detection |

### Month-by-month plan

1. **Month 1** — Shared metric layer foundation (objective/mastery data model, single source-of-truth calculation service) + Student dashboard MVP (Flutter, in-app).
2. **Month 2** — Teacher/creator dashboard MVP (reach + course performance funnel) + admin web panel shell (Filament: auth, roles, navigation) started in parallel.
3. **Month 3** — Local level (palika) and Ministry dashboard MVPs (web), both descriptive-core only, built on Phase 2's district/municipality drill-down hierarchy.
4. **Month 4** — Super admin dashboard MVP (platform health, growth, finance, basic safety queue) + cross-panel QA (verify the shared metric layer produces identical numbers on every panel) + access-control security review (learner-name boundary, audit logging for "who viewed learner data").

### Resourcing caveat (restated plainly)

This 4-month plan only holds if the backend developer works on dashboards **exclusively** during this window. If events/messaging/AI/payments are also expected to progress in parallel on the same 1 backend developer, pick one: extend the dashboards timeline, or add a second backend developer for these 4 months. There is no version of this plan where one backend developer delivers dashboards _and_ keeps the other 6 workstreams moving in the same 4 months.

---

## 9. Recommended Next Step

Confirm the backend-team bottleneck risk (§6.1) and the resourcing caveat (§8) before committing to either timeline — either accept the ~12–16 month range for full scope with the stated small team, or the 4-month MVP-dashboards-only plan with the backend developer dedicated exclusively to it. Once resourcing is settled, this document can be handed to `writing-plans` to produce a phase-by-phase implementation plan starting with Phase 0 (foundation) and Phase 2 (district/municipality signup), which unblock everything else.

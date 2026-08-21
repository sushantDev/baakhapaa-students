# 4-Month Delivery Roadmap — Stakeholder Version

**Date:** 2026-08-18
**Purpose:** A stakeholder-facing breakdown of what this team can realistically deliver in 4 months, and why 4 months is the right number — not an arbitrary one.
**Backing detail:** [FEATURE_EXPANSION_TIME_ESTIMATE.md](FEATURE_EXPANSION_TIME_ESTIMATE.md) (technical estimate) and [SKILLSIKKA_DASHBOARD_ANALYTICS_SPEC.md](SKILLSIKKA_DASHBOARD_ANALYTICS_SPEC.md) (dashboard analytics detail).

## The team, honestly assessed

| Person                           | Role                                                        | Real contribution in Month 1                                                                                                                                                                            | Real contribution by Month 3–4                                                                                                                                                                                                                |
| -------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CTO                              | Lead dev, Laravel + Flutter, architecture & security review | High — but ~20–30% of time goes to mentoring 4 interns and reviewing their code, not writing features                                                                                                   | High, plus final sign-off on every security-sensitive piece (payments, roles, AI safety)                                                                                                                                                      |
| Flutter Dev                      | Mobile UI/UX                                                | Full productivity from day 1                                                                                                                                                                            | Full productivity                                                                                                                                                                                                                             |
| Laravel Dev                      | Backend/API                                                 | Full productivity from day 1                                                                                                                                                                            | Full productivity                                                                                                                                                                                                                             |
| Intern (knows Laravel + Flutter) | Supervised full-stack                                       | ~50% of a junior dev's output — still needs review on everything merged                                                                                                                                 | ~70–80%, works more independently                                                                                                                                                                                                             |
| 3 Interns (know neither stack)   | Learning + narrow supervised tasks                          | **Near-zero feature output.** Month 1 is a genuine onboarding month: Flutter/Laravel fundamentals, codebase walkthrough, shadowing, small non-critical tasks (content updates, manual QA, test-writing) | 20–40% of a junior dev's output each, on **narrow, well-defined, low-risk tasks** (following an established pattern, e.g. a Filament CRUD screen or a redesigned static screen) — always reviewed by CTO/Flutter dev/Laravel dev before merge |

**On "with the use of AI":** AI coding assistants (Copilot-style tools) are used throughout by every developer, including the interns. Realistically this gives a **15–25% speed-up on repetitive, pattern-following work** — boilerplate CRUD endpoints, redesigned screens that follow an existing template, test scaffolding, seed-data scripts. It does **not** turn an intern who doesn't know Flutter into a Flutter developer overnight, and it does **not** reduce the review time senior developers must spend on security-sensitive work (payments, role/permission logic, anything touching a minor's data). The estimates below already assume this AI boost — it is not a separate multiplier layered on top.

**Net effective capacity:** roughly **4–5 experienced-developer-equivalents** once interns are past onboarding (from Month 2 onward), not 7 people at face value. This is the number the plan below is built on.

## Why 4 months — not 2, not 12

- **Some things are strictly sequential.** The role/permission model (student/teacher/municipality/ministry/admin) must exist before district/municipality signup, dashboards, or messaging can be built on top of it. The shared metric layer must exist before any of the 5 dashboards can show a real number. You cannot compress these dependencies by adding more people to them.
- **3 of the 7 people are not productive on day 1.** A team that looks like 7 heads is really ~3 productive heads in Month 1, ramping toward ~5 by Month 3–4. Any plan that assumes interns are at full output from week one is not credible.
- **Some work should not be rushed regardless of headcount:** payment gateway correctness (real money, 3 gateways), the learner-data access boundary (a minor's data reaching a government official's screen), and AI content-safety for a child audience. Cutting corners here is a security/compliance risk, not a scheduling one.
- **Given all of that, the full original 7-item scope realistically needs ~6–9 months even with this team and AI assistance** (see [FEATURE_EXPANSION_TIME_ESTIMATE.md](FEATURE_EXPANSION_TIME_ESTIMATE.md) §3 for the full-scope math). This document defines the **largest, most defensible slice of that scope this team can deliver in 4 months** — not a promise to finish everything in 4 months, because that promise would not be true.

---

## What ships by the end of Month 4

| Workstream                                                                                                                                                                                                                                             | Status at Month 4                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Role model (student/teacher/municipality/ministry/baakhapaa-admin)                                                                                                                                                                                     | ✅ Live                                                                                                                                                                |
| District/Municipality signup for local government bodies                                                                                                                                                                                               | ✅ Live                                                                                                                                                                |
| Core UI/UX redesign (Figma)                                                                                                                                                                                                                            | ✅ Rolled out on highest-traffic screens (home, auth, course browse, quiz play, profile, settings); a tail of lower-traffic legacy screens carries into Phase 2        |
| Student dashboard (in-app)                                                                                                                                                                                                                             | ✅ Live — MVP metrics (performance, progress/habit)                                                                                                                    |
| Teacher dashboard (in-app)                                                                                                                                                                                                                             | ✅ Live — MVP metrics (reach, course performance funnel)                                                                                                               |
| Local level / Ministry / Super-admin dashboards (web, Filament)                                                                                                                                                                                        | ✅ Live — descriptive-core metrics only (see MVP table in [FEATURE_EXPANSION_TIME_ESTIMATE.md](FEATURE_EXPANSION_TIME_ESTIMATE.md) §8)                                 |
| One-way broadcast messaging (admin/ministry/local-gov → users)                                                                                                                                                                                         | ✅ Live                                                                                                                                                                |
| Events Nearby — **simplified**: events are uploaded/curated from the backend (Filament), no user-generated events or map UI; app shows a list filtered by distance from the user's location, with a push notification when a new event is added nearby | ✅ Live (v1)                                                                                                                                                           |
| Direct premium course purchase — **Khalti only** (already integrated for coins, extended to course entitlements)                                                                                                                                       | ✅ Live (v1)                                                                                                                                                           |
| Direct premium course purchase — Stripe and eSewa gateways                                                                                                                                                                                             | ❌ Phase 2 — added once Khalti-only flow is proven in production; multiplying payment gateways multiplies verification/refund edge cases, worth doing one at a time    |
| AI chatbot tutor (LLM-powered) and all other AI integrations (content-creation upgrade, personalized/adaptive recommendations)                                                                                                                         | ❌ Removed from this 4-month plan at your request — freed capacity was redirected to Events Nearby and course purchase above. Revisit in Phase 2                       |
| Predictive analytics (all 5 panels)                                                                                                                                                                                                                    | ❌ Not planned at all until the SkillSikka spec's own Data Gate is met (one full school term, ≥5,000 learners, ≥500 outcome events) — this is independent of team size |
| Remaining dashboard depth (equity analysis, question/confusion psychometrics, impact analysis, governance/data-quality panels)                                                                                                                         | ❌ Phase 2                                                                                                                                                             |

---

## Month-by-month breakdown (who does what)

### Month 1 — Foundation & Onboarding

| Person               | Focus                                                                                                                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CTO                  | Role/permission model design (`spatie/laravel-permission`), Nepal admin-division seed schema, security review plan, kicks off Figma design-token extraction                                                         |
| Laravel Dev          | Role/permission migration, districts/municipalities seed tables + read API                                                                                                                                          |
| Flutter Dev          | Design-token/theme system integration, navigation shell redesign                                                                                                                                                    |
| Intern (both stacks) | Supervised: seed-data scripts + API tests                                                                                                                                                                           |
| 3 Interns            | Onboarding: Flutter/Laravel fundamentals, codebase walkthrough, shadowing; low-risk tasks only (content/copy updates, manual QA catalog of screens needing redesign, writing test cases for the existing auth flow) |

**End of month:** role model live in staging, admin-division data seeded, design tokens integrated, interns past onboarding.

### Month 2 — Signup + Redesign Rollout + Metric Layer

| Person               | Focus                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------------- |
| CTO                  | Shared metric-layer schema design, security boundary review, code reviews                                        |
| Laravel Dev          | District/municipality signup backend (local-gov account type + admin approval), shared metric-layer core service |
| Flutter Dev          | District/municipality signup UI, redesign rollout on top 8–10 screens                                            |
| Intern (both stacks) | Student dashboard UI (Flutter), wired to metric layer as it comes online                                         |
| Intern 1             | Redesigned static screens (settings, about, help) — reviewed by Flutter Dev                                      |
| Intern 2             | Widget/component tests for redesigned screens                                                                    |
| Intern 3             | Simple CRUD endpoints (districts/municipalities admin list) — reviewed by Laravel Dev                            |

**End of month:** district/municipality signup live, redesign visible on core screens, metric layer processing real events, Student dashboard in internal testing.

### Month 3 — Dashboards Expansion + Messaging + Events Nearby

| Person               | Focus                                                                                                                                                                                                                    |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CTO                  | Broadcast-messaging authorization review, course-purchase entitlement model design (started early so Month 4 isn't a scramble), review of location-data handling for minors (school/ward-level granularity, not raw GPS) |
| Laravel Dev          | Teacher dashboard API, broadcast messaging backend, Events backend (admin-curated event CRUD in Filament + "nearby" query endpoint by lat/long radius)                                                                   |
| Flutter Dev          | Teacher dashboard UI, announcements inbox UI, Events Nearby UI (list view, `geolocator` permission + distance filter, push notification handling for new nearby events)                                                  |
| Intern (both stacks) | Filament admin panel shell (auth, roles, navigation) for the 3 web dashboards, including the events-upload screen                                                                                                        |
| Intern 1             | Continues redesign rollout on remaining medium-traffic screens                                                                                                                                                           |
| Intern 2             | QA (manual + automated) on messaging + dashboard + events features                                                                                                                                                       |
| Intern 3             | Basic Filament list/detail screens, supervised                                                                                                                                                                           |

**End of month:** teacher dashboard live, broadcast messaging live, Events Nearby in beta.

### Month 4 — Web Dashboards + Hardening + Demo Prep

| Person                           | Focus                                                                                                                                                                                                                |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CTO                              | Cross-panel QA (shared metric layer consistency), access-control/audit-log review, course-purchase security review (server-side Khalti verification, never trust a client-reported "success"), stakeholder demo prep |
| Laravel Dev                      | Local level (palika) + Ministry + Super-admin dashboard APIs (descriptive-core), course-purchase backend (entitlement model, Khalti verification, content unlock)                                                    |
| Flutter Dev                      | Finish redesign rollout on remaining screens (best effort), course-purchase UI (buy button, receipt confirmation, unlock flow), Events Nearby polish                                                                 |
| Intern (both stacks) + 3 Interns | Filament screens for the 3 web dashboards under Laravel Dev's direction, bug-fixing, documentation, full regression QA                                                                                               |

**End of month:** everything in the "ships by Month 4" table above, demo-ready for stakeholders.

---

## Bottom line for stakeholders

4 months buys: the new role system, government-body signup, a visibly redesigned app on its most-used screens, working dashboards for students, teachers, local government, the ministry and Baakhapaa admin (core metrics), one-way government-to-user messaging, a simplified backend-curated Events Nearby feature, and direct premium course purchase via Khalti. It does **not** buy an AI chatbot or any other AI integration (dropped from this plan to make room for the above), Stripe/eSewa course payments, the deeper analytics (confusion/psychometrics, equity, predictive), or a 100%-repainted app — those are Phase 2, roughly Months 5–9, and are called out here explicitly so nothing is assumed silently.

**Why this swap fits:** dropping the AI chatbot freed roughly the same amount of backend effort that the simplified Events Nearby (no map UI, no user-generated content — just backend-curated events with a distance filter) and a single-gateway (Khalti-only) course purchase flow need. Adding Stripe and eSewa on top of Khalti in the same 4 months would not have fit without cutting something else — each extra gateway adds its own verification, refund, and failure-mode edge cases worth doing one at a time rather than rushed.

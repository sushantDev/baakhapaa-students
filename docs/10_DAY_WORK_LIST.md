# Baakhapaa — 10-Day Delivery Plan

| Field       | Detail                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------- |
| Document    | 10-day delivery plan: performance, course payments, ICT & AI Bootcamp, automated challenges |
| Prepared by | Baakhapaa engineering team                                                                  |
| Date        | 19 August 2026                                                                              |
| Period      | 10 working days (2 calendar weeks)                                                          |
| Team        | CTO (Laravel + Flutter lead), 1 Flutter Developer, 1 Laravel Developer, 4 Interns           |

---

## 1. Executive Summary

This plan delivers four items over 10 working days: app performance improvements for slow-network conditions, direct course purchases via Khalti (previously points-only), a new ICT & AI Bootcamp experience with 4/7/10-day options, and flexible challenge submissions (video, website files, or GitHub links, instead of video only).

Three of the four items build on existing systems and are on track for full delivery in this window. The **ICT & AI Bootcamp** is an entirely new feature with no prior groundwork, and is the item most likely to need a scope adjustment if timelines tighten. The recommended fallback, if needed, is to launch with the **10-day bootcamp option only** in this window and add the 4-day and 7-day options immediately after — the underlying design supports all three from day one, so this would be a phasing decision, not rework.

**Ownership:** the Frontend Developer owns items 1 (Performance) and 3 (ICT & AI Bootcamp). Sushant (CTO) is personally delivering items 2 (Course purchase) and 4 (Automated Challenges) end-to-end, backend and frontend, given his full-stack background.

A small number of product decisions need confirmation before or during day one (§5) to avoid rework mid-sprint.

---

## 2. Scope

| #   | Item                 | Current State                                                                                       | What Changes                                                                                                     | Owner                                                                  |
| --- | -------------------- | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 1   | Performance          | Meaningful optimization work already in place (efficient rendering, batched loading, image caching) | Defer non-critical content until needed, add loading placeholders, and adapt content quality to connection speed | Frontend Developer                                                     |
| 2   | Course purchase      | Users can currently unlock courses using points only                                                | Add a "Buy with Khalti" option alongside the existing points option                                              | Sushant (CTO)                                                          |
| 3   | ICT & AI Bootcamp    | Does not exist yet                                                                                  | New bootcamp section with 4/7/10-day options, each containing daily slides and videos                            | Frontend Developer (backend data model supported by Backend Developer) |
| 4   | Automated Challenges | Current submissions are video-only                                                                  | Submission method adapts to the challenge type — video upload, website files (HTML/ZIP), or a GitHub link        | Sushant (CTO)                                                          |

---

## 3. 10-Day Delivery Schedule

| Day | Sushant (CTO) — Items 2 & 4                                                                                                                                          | Backend Developer — Bootcamp backend                                                            | Frontend Developer — Items 1 & 3                                                 | Interns                                                                |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 1   | Confirm current challenge submission flow; design challenge submission-type model; plan Khalti course-purchase design                                                | Design Bootcamp data model (duration → day → slides + video) and admin content management setup | Performance audit: identify which home-screen sections can load on demand        | Baseline testing of current app startup time and slow-network behavior |
| 2   | Build Khalti course-purchase backend endpoint                                                                                                                        | Bootcamp content delivery API (list/detail by duration + day)                                   | Defer non-critical sections; add loading placeholders to key screens             | Enable file-upload capability for later challenge work                 |
| 3   | Build challenge submission-type rules and validation (video / website files / GitHub link)                                                                           | Continue Bootcamp API; begin admin CRUD polish                                                  | Bootcamp section entry point + 4/7/10-day selection screen                       | Write tests for the new deferred-loading behavior                      |
| 4   | Add "Buy with Khalti" option to the course purchase screen (frontend + backend wiring); begin challenge submission backend (file handling, link validation, storage) | Bootcamp API refinement; support content admin uploads                                          | Bootcamp day-by-day screen (slides + video playback)                             | Manual testing of the Khalti course-purchase flow                      |
| 5   | Mid-sprint checkpoint on items 2 & 4; wire submission type to determine which uploader UI the app shows                                                              | Continue Bootcamp backend, prep for QA                                                          | Continue Bootcamp UI; checkpoint on whether 4/7-day variants need to be phased   | Continue bootcamp testing; log remaining slow-network issues           |
| 6   | Build adaptive challenge upload UI (video / file / link, based on challenge type); security review of file validation and Khalti verification                        | Support content admin, minor backend polish                                                     | Bootcamp polish; connection-aware content quality for bootcamp and course videos | Testing of bootcamp playback across device types                       |
| 7   | Fixes and refinements on items 2 & 4                                                                                                                                 | Fixes and API polish                                                                            | Bootcamp bug fixes; polish deferred-loading behavior                             | Regression testing of course purchase and challenge submissions        |
| 8   | Cross-feature review of items 2 & 4; confirm any scope decision from Day 5                                                                                           | Fixes                                                                                           | Bootcamp polish (loading and empty states)                                       | Full regression testing across all four items                          |
| 9   | Final sign-off on payment and file-submission security                                                                                                               | Fixes from testing                                                                              | Fixes from testing                                                               | Documentation and release notes                                        |
| 10  | Demo preparation, staging verification                                                                                                                               | Staging verification                                                                            | Staging verification                                                             | Final testing and issue triage                                         |

---

## 4. Risk & Feasibility

This schedule is achievable if scope holds as defined above. Two risks worth flagging with this ownership split:

- **ICT & AI Bootcamp** carries the most schedule risk since it is being built from nothing. A checkpoint is built in at Day 5 to decide early — not at the end — whether the bootcamp's 4-day and 7-day options should be phased to a follow-up delivery, keeping the 10-day option as the guaranteed launch deliverable.
- **Concentration risk on Sushant.** Items 2 and 4 both include security-sensitive work (payment verification, file-upload validation) and are now owned end-to-end by one person rather than split across a backend and frontend developer. This reduces available review bandwidth and has no built-in backup if Sushant is blocked or unavailable on a given day — worth keeping in mind if either item's timeline slips.

---

## 5. Items Requiring Confirmation

1. **Bootcamp slide format** — confirm whether slides will be delivered as images or as documents (e.g. PDF); this affects build time.
2. **"Premium courses" definition** — confirm this refers to the existing course/season structure, rather than a separate course entity.
3. **GitHub link verification depth** — confirm whether a submitted GitHub link only needs to be a valid URL, or must be verified as an accessible/public repository.
4. **Current challenge submission flow location** — confirm where the existing video-only submission currently lives in the product, so day one work targets the right area.

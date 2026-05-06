# Baakhapaa for Students — Non-Technical Plan

## What Are We Building?

A branded version of the Baakhapaa learning app, customized for a specific school under the name **"[School Name] Learning App"** (or similar). Students log in, watch educational video lessons organized by subject, answer quizzes, earn coins, compete in subject challenges, and redeem rewards (school merchandise, certificates). Teachers manage content. The school pays an institutional subscription; students access it completely free.

---

## Who Is This For?

| Person                       | What They Do                                                                          |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| **Students**                 | Watch lessons, answer quizzes, earn coins, join challenges, redeem gifts              |
| **Teachers**                 | Upload video lessons, create quiz questions, run subject challenges                   |
| **School Admin / Principal** | Manages the subscription, approves teacher accounts, monitors engagement              |
| **Baakhapaa Team**           | Sets up the platform for each school, provides support, supplies demo content library |

---

## What Students Will Experience at Launch

**Learning Subjects:** 3–4 subjects available at launch (e.g., Mathematics, Science, English, General Knowledge). Each subject has 3 video chapters with quizzes.

**Short Knowledge Clips:** 5 fun fact short videos per subject — bite-sized, TikTok-style clips that make learning entertaining.

**Challenges:** 2 school-wide competitions active at launch — e.g., "Grade 8 Science Challenge" and "General Knowledge Shorts Battle."

**Gifts & Rewards:** Students redeem earned coins for school-branded prizes (stationery pack, merit certificate) or digital rewards.

**Achievements:** Milestone badges — e.g., "Watched 10 Lessons", "Perfect Quiz Score", "Challenge Winner."

---

## How Schools Are Added (Repeatability)

Adding a new school is a **configuration exercise, not a development project.** The Baakhapaa team follows a standard checklist:

1. **School provides:** Logo, brand colors, preferred app name, school admin's email address
2. **Baakhapaa team does:** Creates a backend instance, customizes the app with school's logo and colors, builds and delivers the APK (Android) and IPA (iOS)
3. **School admin does:** Distributes the app to students, creates teacher accounts, reviews demo content and adds their own
4. **Go-live:** School admin shares the installer link or QR code with students

**Estimated time per new school:** ~1 week (after pilot templates are ready, 2–3 days for subsequent schools)

---

## Pilot Plan — School 1

| Step                                        | Who                | When      |
| ------------------------------------------- | ------------------ | --------- |
| Select pilot school partner                 | Baakhapaa team     | Week 1    |
| Gather school branding (logo, colors, name) | School admin       | Week 1    |
| Backend setup + demo content seeded         | Technical team     | Weeks 1–2 |
| Flutter app rebranded, APK built and tested | Technical team     | Week 2    |
| Teacher training (how to upload content)    | Baakhapaa team     | Week 3    |
| Student beta launch (small group of 20–30)  | School + Baakhapaa | Weeks 3–4 |
| Feedback collection + fixes                 | Both               | Weeks 4–5 |
| Full school launch                          | School admin       | Week 6    |

---

## Pricing Model (Institutional Subscription)

| Plan         | What's Included                                                              | Suggested Price   |
| ------------ | ---------------------------------------------------------------------------- | ----------------- |
| Pilot (free) | Up to 100 students, demo content, email support                              | Free for 3 months |
| Basic        | Up to 300 students, teacher content uploads, email support                   | ₹X / month        |
| Pro          | Unlimited students, analytics dashboard, priority support, custom challenges | ₹Y / month        |

_School pays. Students never pay._

---

## What's Deliberately Excluded at Launch

To keep the launch focused and manageable, the following features from the main Baakhapaa app are intentionally left out:

- Student-to-student messaging
- Parent dashboard / parent login
- Payment flows for students
- Affiliate / vendor marketplace
- YouTube and Facebook social account linking
- Content creation by students (teachers and admin only)

These can be added in later phases based on school feedback.

---

## How It Grows to More Schools

Each new school gets its own branded app. As more schools join:

- **Content library grows** — schools benefit from a shared academic content base seeded by Baakhapaa
- **Cross-school competition** becomes possible (future phase: inter-school leaderboards, national challenges)
- **Baakhapaa evolves** into a **school network platform** — schools have their own identity and community while competing on a shared stage

The pilot school's feedback directly shapes the template used for every school that follows.

---

## Success Metrics for Pilot

| Metric                    | Target (End of Month 1)                |
| ------------------------- | -------------------------------------- |
| Student registrations     | 50+ active students                    |
| Daily active users (DAU)  | 20+ students/day                       |
| Lessons watched           | 200+ episode views                     |
| Quiz completion rate      | 60%+ of started quizzes completed      |
| Challenge participation   | 30+ students in at least one challenge |
| Teacher content uploads   | At least 1 teacher uploads new content |
| Coin redemptions          | At least 10 gift redemptions           |
| School admin satisfaction | Positive feedback on setup experience  |

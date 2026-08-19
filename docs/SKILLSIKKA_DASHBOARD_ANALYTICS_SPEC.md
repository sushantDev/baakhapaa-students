# SkillSikka Dashboard & Analytics Specification (v0.1, draft for review)

**Prepared by:** Baakhapaa product and data team
**Date:** 18 August 2026
**Source:** Pasted stakeholder spec, incorporated verbatim (structure preserved) for engineering/curriculum sign-off before any screen is drawn.

## How to read this document

This lists what appears on each of the five dashboards. Each row names an analytics group and the figures inside it, so engineering and curriculum can agree on the list before any screen is drawn.

Two rules apply across all five panels:

1. Every metric is calculated **once in a shared metric layer** and rendered five ways — no two panels can ever disagree about the same number.
2. Predictions reach government users as **counts, regions and objectives**, never as a named list of children.

---

## 1. Student dashboard

The learner is a child — analytics answer two questions only: _what should I do next_ and _am I getting better_. Diagnosis is present but framed as action.

**Performance**

- Mastery score per subject and per learning objective (0–100)
- Objective status map: mastered, developing, not started, needs revision
- First attempt accuracy vs. retry accuracy
- Quiz score history and points earned per attempt
- Mistakes grouped by objective (not by question order)
- Strongest and weakest subject ranking
- Attempts needed before an objective reaches mastery

**Progress and habit**

- Mastery trend over the last 8 weeks
- Time on task per week
- Streak length and weekly goal completion
- Course and episode completion percentage
- Learning velocity: objectives mastered per active week
- Retention check score: accuracy on the same objective 14–30 days later

**Challenge and reward**

- Challenge submission status, views and pass rate
- Certificates earned with verification link
- Points, badges, and an opt-in class/ward league (shown only where the group has 10+ active learners)

**Predictive** _(Phase 3 — gated, see §6)_

- Spaced revision queue: objectives about to be forgotten
- Readiness score for an upcoming test, per subject
- Suggested next lesson based on the weakest unmastered objective

> A learner never sees a dropout risk score, a predicted grade, or a public rank against named classmates. Where a prediction exists, the screen shows the action it implies instead of the label.

---

## 2. Teacher and creator dashboard

Three questions: does the course work, where do learners get lost, what does it earn. Confusion analytics is the differentiated part.

**Reach**

- Courses published and in draft
- Total enrolments and active learners this week
- Followers with 30-day change
- Watch minutes, total and per course
- Revenue for paid courses: gross, platform fee, tax withheld, net payable, payout status

**Course performance**

- Enrolment funnel: view → enrol → first lesson → halfway → complete → challenge → certificate
- Completion rate vs. platform benchmark for the same grade/course length
- Episode drop-off curve with the timestamp where abandonment spikes
- Rewatch heat across the episode timeline
- Watch-through rate per episode

**Question and confusion**

- Item difficulty: share of learners answering correctly
- Item discrimination: whether the question separates strong from weak learners
- Distractor distribution and confusion index: which wrong option most learners choose
- Average time to answer
- Ranked list of objectives causing the most confusion
- A verdict on every question: keep, rewrite or replace

**Audience**

- Learner segments as counts: struggling, on track, ahead
- Geographic spread of learners at palika level
- Grade mix, device class and connectivity class
- Doubt rate per 100 completions, reports and takedowns

**Predictive** _(Phase 3 — gated)_

- Forecast completions and revenue for the current month
- Expected drop-off for a newly published episode, from length/pacing
- Content health score with trend, weights published in-app

> A creator sees counts and segments. A school teacher assigned to a class sees named learners in that class only — that is the relationship in which a name is useful and accountable.

---

## 3. Local level dashboard (palika)

Users: education section chief, education officers, ward representatives. Every figure carries a comparison against the previous term and the district average (has to survive being quoted in a council meeting).

**Reach**

- Coverage rate: active learners vs. school-age population, per ward
- Registered and active learners by ward, grade, gender, school
- Trend since baseline
- Count of learners inactive for 30 days

**Participation**

- Weekly active learners
- Enrolments, completions, and drop-off stage
- Median weekly learning minutes
- Challenge participation and certificates issued

**Learning outcomes**

- Proficiency band distribution by subject/grade: below basic, basic, proficient, advanced
- Average mastery per subject, per ward, per school
- Marks and score distribution per course
- The ten weakest objectives with learner counts
- Ward vs. palika average, palika vs. district average

**Equity**

- Gender gap in mastery (percentage points, direction of travel)
- Ward-to-ward gap
- Connectivity and device gap
- Urban/rural difference inside the palika

**Impact**

- Before/after figures for any programme the palika ran
- Comparison against similar wards that did not receive the programme
- Cost per completion and cost per objective mastered

**Predictive** _(Phase 3 — gated)_

- Projected count of at-risk learners per ward (counts only)
- Weak objectives projected for next term
- Enrolment and demand forecast for the coming term
- Need-index ranking of wards
- Simulated effect of a proposed intervention, reported with a range

> A named at-risk list handed to a local official carries safeguarding risk and very little upside. The correct output of a prediction here is a ward, a subject and a suggested programme.

---

## 4. Ministry of Education dashboard

Output is a programme, a budget line, or a briefing note. Every figure shown with its sample base.

**National reach**

- Coverage rate nationally and by province/district/palika
- Active learners and growth trend, with sample base beside every figure
- Registered schools and onboarding status

**Outcomes**

- National proficiency index by grade and subject
- Proficiency band distribution nationally and by province
- Objective-level weakness map, drilled province → district → palika → ward
- Term-on-term trend
- Curriculum coverage: which objectives are widely taught vs. barely touched

**Equity**

- Gaps by gender, province, urban/rural, language of instruction, disability (where recorded)
- Gap trend rather than gap level
- Coverage inequality between palikas

**System and supply**

- Content supply vs. demand: objectives with thin or no content
- Teacher/creator activity by region
- Connectivity and device profile by district
- Platform cost per completion

**Impact**

- Every federal programme with pre/post figures
- Difference against a matched comparison group, with confidence range
- Whether the equity gap narrowed or widened
- Cost per unit of learning gain, ranked across programmes

**Predictive** _(Phase 3 — gated)_

- Projected proficiency at term end by province/subject
- Projected dropout volume by region
- Weak objective forecast for next term, nationally and by province
- Need-index ranking of all palikas, with contributing factors
- Demand forecast for bandwidth, devices, content commissioning
- Intervention simulator: expected lift if a programme runs in a given region

---

## 5. Baakhapaa super admin dashboard

The only place the raw picture exists — tightest access control in the product. Trust & safety sits at the top of the default view regardless of which team logs in.

**Platform health**

- Uptime, API latency (p95), error rate
- Crash-free session rate and app version spread
- Video start failure rate and buffering ratio by district
- Offline sync queue backlog

**Growth**

- Installs, activation rate, funnel by acquisition source
- Cohort retention curves at week 1, 4, 12
- DAU/WAU/MAU and stickiness
- Geography of new signups

**Content operations**

- Courses by state, moderation queue age, review throughput
- Takedown time vs. target
- Most reported content

**Trust and safety**

- Child safety queue (shown first)
- Video review backlog vs. SLA target
- Age flag reviews and suspected account sharing
- Assessment gaming anomalies: impossible answer speeds, matching response patterns, one device with many accounts

**Finance**

- Gross sales, platform revenue, payouts due/paid
- Failed payments, refunds, chargebacks
- Cost per active learner, cost per completion, video cost trend

**Data quality**

- Event loss rate
- Questions published without a learning objective code
- Schools missing geographic codes
- Snapshots past their freshness target

**Governance**

- Who viewed learner-level data this week, by role and stated reason
- Model registry: version, training window, fairness test result, drift status
- Running experiments and their results
- Feature flag state

**Predictive** _(Phase 3 — gated)_

- Infrastructure and cost forecast
- Churn forecast by segment
- Fraud and abuse risk scoring
- Model drift alerts

---

## 6. Rules for predictive analytics (Phase 3 gate)

Predictive rows above ship only after one full school term of data exists, under five conditions:

| Rule                 | Detail                                                                                                      |
| -------------------- | ----------------------------------------------------------------------------------------------------------- |
| Data gate            | One complete term of history, ≥5,000 learners with 8+ weeks of activity, ≥500 recorded outcome events       |
| Beat the simple rule | Model must beat the plain rule it replaces by a stated margin, else ship the plain rule labeled as such     |
| Fairness test        | No group (gender, province, connectivity class) may carry a false-positive rate >20% above the overall rate |
| Aggregation          | Government panels receive counts, wards, subjects, objectives — never a named list of learners              |
| No punitive action   | A model output never blocks access, withholds a certificate, or changes a grade — it routes attention only  |
| Visible model card   | Training window, features, known limits, review date — one tap away, in Nepali and English                  |

Before the gate is cleared, ship rule-based flags with the words "rule based" shown in the interface.

**Access boundary (carried into every dashboard's implementation):** a learner sees only their own data; a teacher sees named learners only within their own class; palika/ministry/admin panels never receive learner names — counts and aggregates only.

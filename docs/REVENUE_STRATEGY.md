# Baakhapaa Revenue Strategy — From ₹0 to ₹1 Lakh and Beyond

## Current Situation Analysis

| Metric                     | Value                                                               |
| -------------------------- | ------------------------------------------------------------------- |
| Monthly Active Users       | < 1,000                                                             |
| Play Store Downloads       | 10,000+                                                             |
| Play Store Rating          | 3.4                                                                 |
| AdMob Revenue (last month) | $0.11 (~NPR 15)                                                     |
| Active Creators            | 5                                                                   |
| Team                       | 8 people (3 dev, 1 design, 1 HR, 1 CEO, 2 interns)                  |
| Marketing Budget           | < NPR 10,000                                                        |
| Revenue to date            | ~NPR 0                                                              |
| Target                     | NPR 1,00,000 by end March 2026                                      |
| Platforms                  | Android (Play Store) + iOS (App Store)                              |
| Content                    | Entertainment, anime, Nepal beauty, repurposed social media content |

---

## The Core Problem

**Your app has a broken economic model.** Users perceive Baakhapaa as "a way to earn money" — not as entertainment or education they'd pay for. This creates a **negative unit economics loop**:

1. You spend money on promotion → users come
2. Users earn free coins by watching/quizzing → expect to withdraw real money
3. You can't pay them out profitably → users leave disappointed
4. You've spent money acquiring users who generated zero revenue

**You built an extensive monetization infrastructure** (subscriptions, shop, donations, affiliates, ads, coin purchases) — but none of it works because the user's mental model is "I'm here to take money out, not put money in."

### Existing Monetization Infrastructure (Built but Underutilized)

| Feature                                     | Status                   | Revenue Generated                |
| ------------------------------------------- | ------------------------ | -------------------------------- |
| Khalti coin purchases                       | Built, inactive          | NPR 0                            |
| 3-tier subscriptions (Silver/Gold/Platinum) | Built, inactive          | NPR 0                            |
| AdMob rewarded ads                          | Active in 2 screens only | $0.11/month                      |
| Shop/Product purchases                      | Built, inactive          | NPR 0                            |
| Affiliate product system                    | Built, inactive          | NPR 0                            |
| Donation system (creator tips)              | Built, inactive          | NPR 0                            |
| Coin withdrawal system                      | Blocked (badge locked)   | NPR -15,000 (historical outflow) |
| Referral system                             | Built, minimal usage     | NPR 0                            |
| Daily rewards                               | Active                   | NPR 0 (cost center)              |
| Achievement/Level system                    | Active                   | NPR 0                            |

**Key insight:** AdMob ads exist only on crossword hint and image puzzle reference screens — two optional, deeply buried interactions. With <1K MAU and ~60 ad impressions/month, this generates almost nothing.

---

## PHASE 1: Emergency Revenue (March 11–31, 2026) — Target: NPR 20,000–50,000

You have 20 days and almost no budget. These are **zero-cost or near-zero-cost actions** using existing infrastructure.

### 1.1 — Flip the Ad Strategy (NPR 5,000–15,000 potential)

**Current problem:** AdMob is only in 2 game screens (crossword hint + image puzzle reference). With <1K MAU and ads only triggering on optional hint purchases, you get ~60 impressions/month. That's nothing.

**Actions:**

- **Add interstitial ads between every episode completion** — this is where users are most engaged and will tolerate a 5-second ad
- **Add banner ads on the home feed, shorts feed, and season listing screens** — these are high-traffic surfaces
- **Add rewarded ads as an option for EVERY coin-costing action** — not just hints. "Watch ad to unlock this episode free" / "Watch ad for 5 extra coins" / "Watch ad to get extra life"
- **Add an interstitial ad after every 3rd short viewed** — shorts are your TikTok equivalent, this is standard industry practice (TikTok, Instagram, YouTube Shorts all do this)
- **Add a rewarded ad button on the daily rewards screen** — "Watch ad to double today's reward"

**Why this works:** Even with 500 MAU, if each user sees 5-10 ads/day (industry average for free gaming apps), you'd generate 75K-150K impressions/month. At Nepal eCPM of $0.50-$1.50, that's $37-$225/month (NPR 5,000-30,000). This is your most reliable short-term revenue.

**Files to modify:**

- `lib/screens/story/crossword_screen.dart` — already has ad logic, extend pattern
- `lib/screens/story/image_puzzle_screen.dart` — same
- Home screen, shorts feed, episode completion screen — add interstitial/banner placements
- Create a reusable `AdService` or extend existing ad loading pattern from game screens

### 1.2 — Reactivate Dormant Users (NPR 0 cost, high impact)

You have 10,000+ installs but <1,000 MAU. That means 9,000+ users who installed and left.

**Actions:**

- **Send a Firebase push notification campaign to ALL registered users** — "Baakhapaa Special: Play quizzes and win real prizes this week!" (tie to whatever Nepali event is upcoming)
- **Create a 7-day comeback challenge** — "Return for 7 days straight, earn 500 bonus coins + entry to prize draw"
- **Use FCM topic-based notifications** — already built in your `FcmNotificationService`. Send daily at 7 PM Nepal time (peak mobile usage)

### 1.3 — Nepali Creator Partnership Revenue Share (NPR 10,000–30,000 potential)

**Your ShreeGo partnership brought users but generated NPR 0 because there was no monetization trigger during the campaign.**

**Actions:**

- Approach 3-5 mid-tier Nepali TikTok/YouTube creators (10K-100K followers) with this pitch: **"Create exclusive quiz content on Baakhapaa. We split ad revenue 50/50. Your fans will play quizzes about YOUR content."**
- The creator promotes their Baakhapaa quiz to their followers → you get new users who watch ads → you share ad revenue
- **Key insight**: The creator's content is the attraction, ads are the monetization. The creator doesn't need to understand your coin system — they just need to drive traffic and get paid

### 1.4 — College Event Model (NPR 5,000–20,000 potential)

**You already proved this works** — you got users and engagement during college events.

**Actions:**

- Partner with 3-5 Nepal colleges/universities for "Baakhapaa Quiz Championship" events
- **Charge an entry fee**: NPR 50-100 per participant (standard for college quiz competitions)
- Prize pool: NPR 5,000 (from entry fees) → you keep the rest as revenue + ad revenue during the event
- 200 participants × NPR 100 = NPR 20,000 entry fees. Give NPR 5,000 as prizes, keep NPR 15,000

---

## PHASE 2: Sustainable Revenue Engine (April–June 2026) — Target: NPR 50,000+/month

### 2.1 — Restructure the Coin Economy (Critical)

**The single most important change.** Your current model is a money-losing machine:

- Users earn coins for free → expect to cash out → you pay real money → net loss

**New model — "Entertainment-First Economy":**

| Change            | Current                                  | New                                                                                                   |
| ----------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Free coin earning | Generous (daily rewards, quiz, referral) | Reduced by 70%. Free coins only for basic engagement                                                  |
| Coin withdrawal   | Blocked (badge locked)                   | **Permanently removed** for free coins. Only purchased coins or creator-earned coins are withdrawable |
| Coin purpose      | "Earn real money"                        | "Unlock premium content, buy hints, customize profile"                                                |
| Real money in     | Almost none                              | Coin purchase packs, subscriptions, event entry fees                                                  |
| Messaging         | "Earn money playing games"               | "Nepal's most fun quiz app — learn, play, compete"                                                    |

**Implementation details:**

- Remove all "earn money" messaging from app store listing, onboarding, and marketing
- Rename "coins" to "gems" or "stars" to psychologically break the real-money association
- Keep the coin/gem system for in-app engagement but disconnect it from cash withdrawal
- Creators can still earn through donation system (viewers spend purchased coins)

### 2.2 — Premium Subscription Launch (NPR 15,000–40,000/month potential)

You already have the subscription infrastructure built. Simplify and launch it:

**Two tiers only:**

| Tier               | Price         | Benefits                                                                                        |
| ------------------ | ------------- | ----------------------------------------------------------------------------------------------- |
| **Baakhapaa Plus** | NPR 99/month  | Ad-free experience, 2x daily rewards, exclusive badge, early access to new seasons              |
| **Baakhapaa Pro**  | NPR 299/month | Everything in Plus + unlimited hints, unlimited lives, profile customization, creator analytics |

**Why NPR 99 works:** It's cheaper than a plate of momo. The key value proposition is **ad-free**. Once you implement aggressive ad placement (Phase 1.1), users will feel the pain and some will pay to remove ads. Industry conversion rate: 2-5% of active users.

- 500 MAU × 3% conversion × NPR 99 = NPR 1,485/month (starting)
- As MAU grows to 5,000: NPR 14,850/month
- Pro tier adds another NPR 5,000-10,000/month

**Payment integration:** Already have Khalti. Add eSewa (Nepal's most popular payment) — this is critical as many Nepali users prefer eSewa over Khalti.

### 2.3 — Coin Purchase Packs (NPR 10,000–25,000/month potential)

For users who won't subscribe but want specific benefits:

| Pack       | Price   | Gems                   |
| ---------- | ------- | ---------------------- |
| Starter    | NPR 49  | 100 gems               |
| Popular    | NPR 149 | 350 gems (17% bonus)   |
| Best Value | NPR 499 | 1,500 gems (50% bonus) |
| Mega       | NPR 999 | 3,500 gems (75% bonus) |

**Key:** Make gems necessary for meaningful progress. Lock premium episodes, advanced game hints, profile badges, and leaderboard placement behind gem spending.

### 2.4 — Aggressive Ad Monetization (NPR 20,000–60,000/month at 5K MAU)

**Full ad placement strategy:**

| Placement           | Type         | Frequency           | Expected eCPM |
| ------------------- | ------------ | ------------------- | ------------- |
| Between shorts      | Interstitial | Every 3rd short     | $1.00-2.00    |
| Episode completion  | Interstitial | After every episode | $1.00-2.00    |
| Home feed           | Banner       | Persistent          | $0.30-0.50    |
| Season listing      | Native       | Every 5th item      | $0.50-1.00    |
| Game hints          | Rewarded     | On demand           | $2.00-5.00    |
| Daily bonus doubler | Rewarded     | 1x daily            | $2.00-5.00    |
| Extra lives         | Rewarded     | On demand           | $2.00-5.00    |

**With 5,000 MAU × 8 ads/user/day × 30 days = 1.2M impressions/month**

At blended eCPM of $1.00 = $1,200/month = **NPR 160,000/month** (this alone exceeds your 1 lakh target)

### 2.5 — Sponsored Content & Brand Deals (NPR 10,000–50,000 per deal)

**The Nepali market approach:**

- Approach Nepali brands (Wai Wai, Goldstar, Ncell, NTC, local restaurants) for sponsored quiz seasons
- "Wai Wai Food Quiz" — a season of quiz episodes about food, sponsored by Wai Wai
- Brand pays NPR 10,000-50,000 for a sponsored season featuring their branding
- Users play for free → brand gets impressions → you get paid
- This is essentially a native advertising model

---

## PHASE 3: Scale (July 2026+) — Target: NPR 2,00,000+/month

### 3.1 — "Baakhapaa for Schools" B2B Model

**The highest-value pivot for education-focused positioning:**

- White-label the quiz platform for Nepali schools/colleges
- Schools pay NPR 5,000-15,000/year for a school-branded quiz portal
- Teachers create quizzes from curriculum → students play at home
- **Nepal has 35,000+ schools** — even 0.1% adoption = 35 schools × NPR 10,000 = NPR 3,50,000/year

### 3.2 — International Scaling with Localization

- Nepali diaspora market first (Qatar, UAE, Malaysia, USA, Australia — large Nepali populations)
- Quizzes about Nepal, Nepali culture, Nepali language learning
- **Language learning angle**: "Learn Nepali through quizzes" for second-generation diaspora
- This opens AdMob to high-eCPM markets ($5-15 eCPM in US/Australia vs $0.50-1.50 in Nepal)

### 3.3 — Creator Fund & Revenue Sharing

- Once ad revenue reaches NPR 1,00,000+/month, allocate 20% as creator fund
- Pay creators based on engagement metrics (views, quiz completions)
- This attracts better creators → better content → more users → more ad revenue
- Flywheel effect similar to YouTube's partner program

### 3.4 — Live Quiz Events (Monetization through events)

- Weekly live quiz event with real-time competition
- Entry fee: NPR 20-50 (via purchased gems)
- Prize pool: 50% of entry fees, you keep 50%
- 500 participants × NPR 30 = NPR 15,000 per event × 4 events/month = NPR 60,000/month
- Build FOMO and appointment-based engagement

---

## Revenue Projection Summary

| Timeline            | Revenue Source                  | Monthly Estimate (NPR) |
| ------------------- | ------------------------------- | ---------------------- |
| **March 2026**      | Ads (expanded placement)        | 5,000–15,000           |
|                     | College events (1-2)            | 10,000–20,000          |
|                     | Creator partnership campaigns   | 5,000–15,000           |
| **April–June 2026** | Ads (5K MAU target)             | 40,000–160,000         |
|                     | Subscriptions (2-3% conversion) | 10,000–40,000          |
|                     | Coin/Gem purchases              | 10,000–25,000          |
|                     | Sponsored content (1-2 deals)   | 10,000–50,000          |
| **July 2026+**      | Ads (10K+ MAU)                  | 100,000–300,000        |
|                     | Subscriptions                   | 30,000–80,000          |
|                     | B2B (Schools)                   | 50,000–150,000         |
|                     | Events                          | 30,000–60,000          |
|                     | Coin/Gem purchases              | 20,000–50,000          |

---

## Immediate Action Items (This Week, March 11–17)

Priority-ordered list your team can start executing today:

1. **[Dev - 2 days]** Add interstitial ads between shorts (every 3rd) and after episode completion — reuse the `RewardedAd` pattern from game screens but use `InterstitialAd`
2. **[Dev - 1 day]** Add banner ads to home screen and season listing
3. **[Dev - 1 day]** Add "Watch ad to double daily reward" rewarded ad on daily rewards screen
4. **[Dev - 1 day]** Add rewarded ad option for episode/shorts unlock ("Watch ad OR spend coins")
5. **[Marketing - 1 day]** Draft and send FCM push notification to all registered users — "Come back for the Baakhapaa Spring Challenge"
6. **[CEO - 3 days]** Contact 3 colleges in Kathmandu for quiz championship events in March
7. **[CEO - 3 days]** Contact 2-3 TikTok creators (10K+ followers) for content partnership
8. **[Content - ongoing]** Create a "Nepal GK Quiz" season — general knowledge about Nepal that any Nepali person would find interesting and want to share
9. **[All - 1 day]** Update Play Store listing — remove any "earn money" language, position as "Nepal's #1 Quiz & Entertainment App"
10. **[Dev - 2 days]** Add eSewa payment gateway alongside Khalti for coin purchases and subscriptions

---

## The Most Important Mindset Shift

**Stop being an "earn money" app. Start being an entertainment app that happens to have rewards.**

Apps that promise users money attract the wrong audience — people looking for easy income, not engaged users. Every successful app in this space (Duolingo, Kahoot, HQ Trivia) makes money FROM users through:

- Ads (free tier exposure)
- Subscriptions (ad removal + perks)
- B2B licensing (schools/businesses)

None of them let users withdraw real money for playing. The rewards are cosmetic (badges, levels, leaderboard rank) and feel-good (learning progress, achievement unlocks).

**Your game infrastructure is excellent.** The crossword generator, image puzzles, quiz modes, level progression, achievements — this is genuinely good gamification. The problem was never the product; it's the positioning and business model.

**Reposition Baakhapaa as:**

> "Nepal ko sabai bhanda ramro quiz app — sikha, khela, jita!"
> (Nepal's best quiz app — learn, play, win!)

Where "win" means badges, leaderboard rank, and bragging rights — not cash.

---

## Global Best Practices Applied

| Strategy                  | Proven By                | Your Implementation              |
| ------------------------- | ------------------------ | -------------------------------- |
| Freemium + Ads            | Duolingo ($531M revenue) | Free with ads, paid ad-free tier |
| Rewarded Ads              | Every mobile game        | Watch ad for in-game benefit     |
| Interstitial Ads          | TikTok, Instagram        | Between content pieces           |
| Subscription tiers        | YouTube, Spotify         | NPR 99 / NPR 299 monthly         |
| Sponsored quizzes         | Kahoot for Business      | Brand-sponsored seasons          |
| College events            | HQ Trivia model          | Live competitive quizzes         |
| B2B education             | Kahoot ($100B valuation) | Schools subscription             |
| Creator revenue share     | YouTube Partner Program  | 20% of ad revenue to creators    |
| Virtual currency purchase | Roblox, Fortnite         | Gem packs for real money         |

---

## Risk Mitigation

| Risk                           | Mitigation                                                                                              |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Users leave when earning stops | Already happening. The pivot to entertainment-first loses low-value users but attracts sustainable ones |
| Play Store rating drops        | Add a "Rate us" prompt after positive experiences (win screen). Current 3.4 already isn't great         |
| Low eCPM in Nepal              | Rewarded ads have 3-5x higher eCPM than banners. Also target diaspora in high-eCPM countries            |
| Creators leave without pay     | Creator fund from ad revenue (Phase 3). Short-term: offer them the partnership model                    |
| Limited marketing budget       | Focus on viral loops — challenge friends, share quiz results on social media, referral bonuses          |

---

## Technical Implementation Priority

### Ad Service Architecture (New file: `lib/services/ad_service.dart`)

A centralized ad management service that handles:

- Preloading interstitial and rewarded ads
- Tracking ad frequency caps (don't show more than X ads per session)
- Checking subscription status (skip ads for Plus/Pro users)
- Logging ad impressions for analytics/creator revenue share

### Subscription Gate Logic

- Check `user.subscription_tier` before showing ads
- Gate premium content behind subscription or gem purchase
- Show upgrade prompts at natural friction points (ad shown → "Remove ads for NPR 99/month")

### eSewa Integration

- Add `esewa_flutter_sdk` to pubspec.yaml
- Mirror the Khalti payment flow in a new `EsewaService`
- Backend: Add eSewa verification endpoint alongside existing Khalti verification

---

_Document created: March 11, 2026_
_For: Baakhapaa Team_
_Next review: March 18, 2026 (after implementing Phase 1 quick wins)_

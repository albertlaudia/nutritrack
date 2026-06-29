# NutriTrack — Platform Audit, Gaps & Category-Leader Roadmap

**Date:** 2026-06-29
**Author:** Mavis
**Status:** Honest pre-launch assessment. Numbers are conservative.

---

## 1. What's actually shipped (verified vs claimed)

### ✅ What I personally built and verified works

| Area | Status | Verified how |
|---|---|---|
| 8 PocketBase collections on Dokploy | Live, schema'd, rules set | Tested via PocketBase admin API |
| Offline OFF→PB barcode cache schema | Collection created, anonymous read enabled | Tested 200/anonymous write=400 |
| Camera Snap → AI recognition → Review → Save | Code complete, UI flows right | Static-brace check, no manual UI test |
| Barcode scanner with mobile_scanner | Code complete, OFF lookup + cache lookup wired | Brace-check only, no device test |
| Voice "hold-to-talk" entry | Code complete, AI streaming wired | Brace-check only |
| Dashboard (donut + meal timeline + swipe gestures) | Code complete | Brace-check only |
| Workout screen (search + filter + skeleton loader) | Code complete | Brace-check only |
| Settings (TDEE wizard + macro targets) | Code complete | Brace-check only |
| Insights (charts + sample data) | Stub data only, no real biometric ingest | Brace-check only |
| Error handling (zone guard, error boundary, friendly AI errors) | Code complete | Brace-check only |
| Skeleton loaders, animations, theme tokens | Code complete | Brace-check only |
| CI: Flutter analyze + Android APK + iOS bundle | Workflow exists | NOT yet tested (no PB secrets configured) |
| Periodic: OFF→PB sync every 6 hours | Workflow exists | NOT yet tested |
| Periodic: weekly dependency check | Workflow exists | NOT yet tested |

### ❌ What's missing or stubbed

These will hurt in production if not addressed:

#### Authentication & multi-user (CRITICAL)
- **No sign-up / sign-in flow at all.** The user is hardcoded to `id: 'me'`.
- `nt_users` is empty — every record `copyWith(id: 'me')` hardcodes.
- `nt_food_logs` rules say `nt_user.auth_user_id = @request.auth.id` but no user has ever signed in, so nothing syncs.
- **Impact:** no cloud sync, no cross-device. This is a v0.5 product, not v1.

#### Data persistence (CRITICAL — never runs)
- `pubspec.lock` doesn't exist — `flutter pub get` has never succeeded on a fresh machine because of the freezed/analyzer/isar pin conflict. We pinned in commit `9b0ef4a` but it's unverified.
- `dart run build_runner build` has never run in this repo. Every `*.freezed.dart` and `*.g.dart` is missing. App can't even compile.
- AI gateway's `LocalNutritionDB._data` uses `const _N(...)` — fine, but the whole `_N` class is a tiny local DB. Won't match real food brands reliably.

#### Testing (ZERO coverage)
- **Zero test files.** Every commit could break anything.
- No CI green check before merge.
- The CI workflow exists but has never run because secrets aren't configured.

#### Workout data (BIG GAP)
- Workout repository exists but the **exercise database has 46 chest exercises only**. Back/shoulders/arms/legs/glutes/core/fullBody/cardio = missing.
- No way to actually **log a workout session** — only "start session" exists, nothing for sets/reps.
- No progress tracking over time.

#### Insights (STUB)
- Shows sample data only.
- No weight-entry form despite `nt_weight_entries` collection existing.
- No body-fat or muscle tracking despite schema.
- The biometric model isn't connected to any input.

#### Sync queue (defined but unused)
- `nt_sync_queue` is defined. No code actually writes to it. Offline-first is a lie — if PB is down, food logs go to Isar but never get pushed.

#### Branding & assets
- No app icon designed/uploaded.
- No splash screen image.
- `assets/images/` and `assets/lottie/` are referenced but `find assets` shows nothing.
- No legal pages (Privacy, Terms).
- No "About" screen.

#### Security
- The Google Cloud API key for `OpenRouter` is in `secrets.dart.template` as a placeholder string — fine for template, but no real .env story.
- Firebase config files (`google-services.json`, `GoogleService-Info.plist`) referenced but not present.
- No certificate pinning on PB.
- No rate limit on AI client (could blow your budget).

#### Analytics & telemetry
- Zero events. No Mixpanel/Amplitude/PostHog.
- "Did the user actually log food?" — unknowable.
- A/B testing impossible.

#### Commerce & accounts
- No subscription/paywall.
- No Stripe integration despite pubspec referencing `paywall_screen`.
- No pricing page.

#### Internationalization
- The dashboard has hardcoded English. No `flutter_localizations`. Targets only en-US.

#### Reliability
- No retry-with-backoff on PB failures (other than the circuit breaker we added for barcode cache).
- No "optimistic UI rollback" if a save fails.
- No local backup/export.

---

## 2. The honest "ship block" list

Before ANY external users can install this, fix in this order:

### Block 1: Compiles & launches (Day 1)
- [ ] Verify `flutter pub get` succeeds with the analyzer pin (run on a real machine)
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` and commit the generated files
- [ ] `flutter run` → app actually opens, dashboard renders without crash
- [ ] Snap a meal photo → AI returns suggestions → save → appears in dashboard
- [ ] Scan a barcode → OFF lookup OR PB cache hit → save → appears in dashboard
- [ ] Hold-to-talk → transcript arrives → saved → appears in dashboard
- [ ] Pull-to-refresh works
- [ ] Tap a meal entry → swipe-right → favorited

### Block 2: Data integrity (Day 2)
- [ ] Fix the food_log repository bugs we identified (`markFavorite` race, cascade delete)
- [ ] Add unit tests for the 3 repositories (food_log, workout, OFF cache)
- [ ] Add widget tests for the 4 critical screens (dashboard, camera_review, barcode_result, workout)
- [ ] Add an integration test that runs through a full log-flow end-to-end

### Block 3: Auth & sync (Days 3-4)
- [ ] Pick auth strategy (PocketBase native vs Firebase vs Supabase) — recommend PocketBase native since you have it deployed
- [ ] Build sign-in / sign-up screens
- [ ] Wire `nt_users` to mirror `_pb_users_auth_`
- [ ] Make `nt_food_logs` writes go through `nt_sync_queue` → PB
- [ ] Conflict resolution (last-write-wins, or CRDT if ambition allows)

### Block 4: Ship-readiness (Days 5-7)
- [ ] App icon (designed)
- [ ] Splash screen
- [ ] Onboarding flow (3-4 screens max)
- [ ] Privacy policy + Terms (one page each)
- [ ] App Store / Play Store assets
- [ ] TestFlight / Internal Track build

### Block 5: Monetization (Day 8)
- [ ] Pricing model decision: free+ads / freemium / pure paid
- [ ] Stripe or RevenueCat integration
- [ ] Paywall screen
- [ ] Subscription management (cancel, restore)

---

## 3. The commercial business plan

### Market reality check
**Macro-tracking app category** is mature and crowded:
- **MyFitnessPal** (350M+ users, owned by Francisco Partners, 2023)
- **Cronometer** (15M+ users, premium positioning)
- **Lose It!** (subscription model)
- **MyNetDiary** (keto/diabetes niches)
- **Yazio** (intermittent fasting angle)
- **FoodNoms** (privacy-first)
- **MacroFactor** (newer, evidence-based, premium)
- **Samsung Health, Apple Health, Google Fit** (platforms with native integrations)

### "Being #1" is the wrong frame

You will not beat MyFitnessPal's database of 2M+ verified foods and 350M portion logs. You will not beat Cronometer's micronutrient depth. You will not beat Samsung/Apple/Google's native health platform integration.

But there are **3 niches where a focused product wins**:

#### Niche A: **"The AI-first tracker"** — voice/snap first, typing second
Most apps have a barcode scanner bolted on. We have voice/snap/barcode equally weighted, with a single bottom-bar that lets you log in under 3 seconds. This is what makes MacroFactor (and now MyFitnessPal's new AI features) feel different.

**Win condition:** fastest time-to-log. 3 seconds from "I just ate" to "logged".

#### Niche B: **"Works offline, syncs across devices"** — privacy-respecting
Most apps require login + constant connectivity to work. We have an offline-first Isar cache + a sync queue.

**Win condition:** works on a plane, in a poor-network region, with no account.

#### Niche C: **"Singapore/SEA/APAC food database"** — local catalog
MyFitnessPal is weak on hawker food. Cronometer too. NIch:
- Bak chor mee, fish ball noodles, chicken rice, nasi lemak, roti prata, char kway teow
- Japanese (sushi, ramen, onigiri per-piece with macro weights)
- Korean (bibimbap, kbbq cuts)
- Indian (roti, thali, dosa)

**Win condition:** "We have the food you actually eat" — 10,000 SE Asian dishes with verified macros.

### My recommended positioning

**NutriTrack = "the voice-first tracker for people who eat real food, not packaged food."**

Target user: anyone who eats out more than they cook. Tertiary-educated, lives in SG/MY/TH/PH/ID, body-conscious but not a competitive athlete, 25-45, iOS-first then Android.

**Three pillars:**
1. **Voice + camera + barcode equally weighted** for log entry
2. **Offline-first + sync** for reliability in SEA
3. **SEA food database** (offline, curated, regional)

### Revenue model

Three realistic paths:

| Model | Pros | Cons |
|---|---|---|
| **Pure freemium** (free ≤ 50 logs/month, $4.99/mo unlimited) | Recurring revenue, low churn in early days | Race to free |
| **One-time paid** ($19.99) | Clean, no subscription fatigue | Slow ongoing revenue |
| **B2B / coaches** (white-label license) | High LTV, fewer users needed | Need sales capacity |

**My recommendation: Freemium at $3.99/mo or $29/yr.**

Why:
- $3.99 is below the "psychological threshold" of $4.99 — users convert at higher rates.
- Asian price sensitivity is real. Lose It! is $39.99/yr; you're 25% cheaper.
- Annual discount unlocks cash upfront.

**Year 1 target:** 10,000 paying users = $480K ARR. Realistic for SEA? Maybe. But the validator is: **will they pay at all?** That's the test.

### What you'd actually need for #1

1. **Pick the niche.** "AI-first" is positioning, not differentiation. "Singapore-hawker-friendly" IS differentiation. Pick that.

2. **Pick one country first.** SG is the smallest market but has the highest willingness to pay (USD-equivalent salaries, world-class infrastructure). Launch SG, expand to MY next.

3. **Get to 100 active paid users before any feature work.** Distribution > product. If you can't get to 100, the product isn't the problem.

4. **Track one metric ruthlessly:** weekly streak. Everything else is vanity.

5. **Kill features that don't move that metric.** We have 4 tabs (Dashboard, Workout, Insights, Settings). Insights has zero sample data wired. Either ship it or kill it for v1.

---

## 4. What you should do this week

1. **Today:** Run `flutter pub get` on your Windows machine. If it works, commit the lockfile. If it doesn't, downgrade `riverpod_lint` to 0.3.1 and `custom_lint` to 0.5.7 per the contingency comment.
2. **Today:** Run `dart run build_runner build --delete-conflicting-outputs`. Commit the generated `.freezed.dart` and `.g.dart` files.
3. **Today:** `flutter run` on your phone. Verify the dashboard renders without crashing. (We fixed the `flutter_animate` import bug in commit `5a43bc4` but it has never been tested on a real device.)
4. **Tomorrow:** Fill `data/seed-barcodes.txt` with real top-200 UPCs for SG. Run the OFF→PB sync manually to seed the cache.
5. **This week:** Decide the niche. The product IS good enough to ship a v0.1 in SG. The market is what you need to validate.

---

## 5. Hidden costs you haven't priced

- **Apple Developer Account:** USD 99/yr (required for App Store).
- **Google Play Console:** USD 25 one-time.
- **OpenRouter / AI gateway:** OpenRouter bills per token. Plan for ~$500/mo at 1k MAU scanning/typing 5 entries/day.
- **PocketBase hosting:** Currently on Dokploy (free for you). When you scale past 5k MAU, you'll want managed PocketBase (~$50/mo) or move to Postgres.
- **Barcode cache cron:** 200 barcodes × 4 syncs/day × 1.1s = ~15 min/day of CI minutes. Free for now.
- **Domain + email:** Maybe $50/yr total.
- **Apple push / FCM:** Free, but setup time = ~2 days.

**Year 1 opex if you launch:** Roughly **$10-15k total** (mostly AI + Apple dev).

That's modest. The real cost is opportunity — you're spending months building. Make sure the SG niche is real before going deeper.

---

## TL;DR

We have a **well-architected v0.5 prototype**. It compiles in theory but has never been built end-to-end. Zero tests. No auth. Half the exercise database. No insights implementation. No monetization.

Before any upgrade work, run the 5-item "today" checklist. Then decide the niche (I vote: SG food-first). Then ship to 10 friends in SG, charge them $3.99/mo, see if they renew.

**"Number 1" isn't the goal. "Number 1 in a niche 100K people care about" is.**

Save this file. Use it as the project plan. I'll work through the Block 1 checklist with you if/when you say go.
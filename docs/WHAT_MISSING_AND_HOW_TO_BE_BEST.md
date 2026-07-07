# NutriTrack — What's Missing & How To Be The Best

**Date:** 2026-07-07
**Author:** Mavis (audit + product strategy)
**Status:** Honest assessment. Not a sales pitch.

---

## TL;DR — The honest answer

NutriTrack has **great bones** (clean architecture, AI gateway, Drift migration, brand identity shipped, PB schema live). But:

- **The build is broken** (31 compile errors in 2 files)
- **The app has no login / no onboarding / no first-run experience**
- **5 of 6 screens render fake / sample data, not real Drift data**
- **There's zero test coverage**
- **It hasn't been run on a device even once** (no proof anything works end-to-end)

To be **the best nutrition app**, you need 4 categories of work:
1. **Fix what's broken** (blockers — must do)
2. **Wire what exists** (data plumbing — must do)
3. **Add what makes NutriTrack different** (AI differentiation — must do to compete)
4. **Polish the 1% details** (the things that make people tell friends)

A v1 launch needs (1) + (2) + the minimum of (3). Being "the best" needs (4) plus relentless (3) iteration.

---

## Category 1: 🔴 Fix what's broken (blockers)

These prevent the app from even compiling or running.

### 1.1 The 31 compile errors (45 min)

`barcode_scanner_screen.dart` + `camera_screen.dart` won't compile. See `PRODUCTION_READINESS_AUDIT.md` §1 for the full list.

Root causes:
- `RRect.topLeft/topRight/bottomLeft/bottomRight` doesn't exist (those are `Rect` getters, not `RRect`)
- 3 callbacks with wrong signatures (`Function() vs Function(String)`)
- `MobileScannerErrorBuilder` API drift (you pinned `mobile_scanner: ^5.2.3` but the API changed in `^7.x`)

**Fix:**
```bash
# Replace RRect.topLeft with RRect.tlRadius
# Or use Rect.fromCircle / outerRect to compute corner points
# Add String param to 3 callbacks
# Migrate MobileScanner error builder to current signature
```

### 1.2 The 17 lint warnings (15 min)

`dart fix --apply` will kill 12 of them. The other 5 are stale imports that need manual edits.

### 1.3 README lies (10 min)

```
- Local DB | Isar 3.1 (NoSQL, indexed, reactive queries)
+ Local DB | Drift 2.28 (SQLite + reactive streams + KMP-friendly)

- Flutter 3.24+, Dart 3.4+
+ Flutter 3.27+, Dart 3.6+
```

### 1.4 7 dead dependencies (30 min)

`just_audio`, `web_socket_channel`, `confetti`, `flutter_staggered_animations`, `animations`, `lottie`, `gap`, `shimmer` are declared in pubspec but **0 imports in lib/**. ~10 MB of APK size for nothing.

`supabase_flutter` is also declared but `supabase/` folder is unused — either commit to it (Supabase auth + sync = 1 week) or remove it.

**Total Category 1: ~2 hours**

---

## Category 2: 🔴 Wire what exists (data plumbing)

The data layer is 70% built. The presentation layer is reading sample data instead.

### 2.1 Insights screen (4 hours)

Currently renders `_generateSampleWeights()` — fake data. Needs to:
1. Watch `weight_entries` table via `weightRepository.watchAll()`
2. Compute trend lines (7-day rolling avg, weekly delta)
3. Show real chart (already have `fl_chart`)
4. Add streak counter (consecutive logging days)

### 2.2 Workout screen (6–8 hours)

Currently has a search screen over `nt_exercises` (46 chest exercises only). Needs to:
1. **Session lifecycle**: Start → Active (timer, set logging) → Rest → Complete
2. **Set logging UI**: "Bench Press 3×8 @ 185 lbs, RPE 8" — the entire differentiator
3. **Rest timer**: 90-second countdown between sets, with sound + vibration
4. **History view**: past sessions, PRs (personal records)
5. **Volume tracking**: total volume per muscle group per week

The voice-input workflow ("Bench 3×8 at 185, RPE 8") is half-built in `quick_log_bar.dart` — needs to be expanded to the workout screen.

### 2.3 Dashboard macro donut (3 hours)

The `MacroDonut` widget shows data, but the daily aggregate (`aggregateForDate`) needs to feed it. Currently shows whatever fake numbers are passed in.

### 2.4 Meal cards (4 hours)

`MealTimelineCard` shows fake entries. Needs to:
1. Read from `food_log_entries` table grouped by `MealSlot`
2. Show real entries (image + name + macros)
3. Tap entry → edit
4. Long-press → delete / favorite

### 2.5 Camera review sheet (3 hours)

Camera captures, AI recognizes, review sheet shows. Currently the review sheet probably shows static UI. Needs to:
1. Reject low-confidence items (< 0.6 confidence = needs confirmation)
2. Allow user to fix quantity (grams)
3. Allow user to fix slot (breakfast/lunch/dinner/snack)
4. Save to local Drift + queue for sync

### 2.6 Barcode result sheet (3 hours)

Similar to camera review sheet but for barcodes. Reads from OFF → user confirms → saves.

**Total Category 2: ~30 hours** (≈ 4 working days)

---

## Category 3: 🟡 What makes NutriTrack different (must do to compete)

This is the actual product work. Everything in Categories 1–2 is plumbing; this is why users choose NutriTrack over MyFitnessPal.

### 3.1 Onboarding (2 days)

**Without onboarding, users churn within 30 seconds.** A new user opens the app and sees:
- Generic 2000 kcal target (almost certainly wrong)
- No idea what NutriTrack does
- No reason to come back

**Recommended flow (3 screens, skippable):**

**Screen 1: Welcome**
- Hero illustration
- "Snap it. Speak it. We log it." tagline
- "Get started" CTA

**Screen 2: Why we're different**
- 3 cards:
  - 📸 **Snap** — point camera, AI identifies food in 2 seconds
  - 🎤 **Speak** — say "two eggs and toast," get macros instantly
  - 📊 **Scan** — point at any barcode, get nutrition facts
- "Continue" CTA

**Screen 3: Calibrate**
- Quick TDEE wizard (5 questions: sex, age, height, weight, activity)
- Goal picker (cut / maintain / bulk)
- "Start tracking" CTA → write to UserProfile table

After onboarding:
- Show a "demo meal" pre-logged (so dashboard isn't empty)
- Highlight the camera button

### 3.2 The voice experience (3 days)

**Why it matters:** This is NutriTrack's most novel feature. MyFitnessPal can't do it well. Strong's voice logging is weak. MacroFactor doesn't even try.

**What you have:**
- `record: ^5.1.2` (audio capture)
- `just_audio: ^0.9.40` declared but unused (should remove or wire to TTS feedback)
- AI gateway's `parseFromVoice` returns `Stream<VoiceLogProgress>`
- Quick log bar has a "voice" button

**What's missing:**
- Real voice UI: hold-to-talk button with waveform animation
- Whisper transcription (large-v3) with model fallback (Whisper tiny for slow networks)
- Punctuation & food-specific normalization ("three eggs" → 3 eggs at 50g each)
- Multi-language support (start with English, then Mandarin — your SEA user base will care)

**Implementation sketch:**
```dart
// In quick_log_bar.dart:
GestureDetector(
  onLongPressStart: () => _startRecording(),
  onLongPressEnd: () => _stopAndProcess(),
  child: AnimatedMicIcon(isRecording: _isRecording, amplitude: _amplitude),
)
```

### 3.3 The AI camera experience (3 days)

**Why it matters:** This is the OTHER differentiator. MFP doesn't have it. Cronometer doesn't have it.

**What you have:**
- `camera: ^0.11.0+2`
- AI gateway's `recognizeFromImage` returns `List<FoodLogEntry>`
- Camera screen + review sheet (build-broken)

**What's missing (the high-value parts):**
1. **Multi-food segmentation** — when a plate has rice + chicken + salad, identify each separately, not as "mixed dish"
2. **Portion estimation** — "this looks like ~150g of rice" (currently always returns 100g default)
3. **Verification flow** — show detected items with confidence bars (green ≥0.8, yellow 0.5–0.8, red <0.5); red items need user confirmation
4. **Re-shot button** — if confidence is too low, "Take another photo?"
5. **Quick fix shortcuts** — "half portion," "double portion," "swap to breakfast"

### 3.4 Smart suggestions (2 days)

**Why it matters:** MacroFactor's key feature is "your TDEE adjusts based on your data." NutriTrack should do the same.

**What's missing:**
- "You've been logging 1800 kcal/day for 3 weeks and weight is steady. Your maintenance is ~2200. Want to recalibrate?"
- "You're 200g short on protein today. Try [high-protein snack suggestion]."
- "It's 3 PM and you haven't logged lunch. Snap it now before you forget?"

These are **reactive** insights — not static dashboards. Triggered by:
- Specific date/time conditions
- Specific data patterns (7-day rolling avg, 3-day streaks)
- User-set goals (in UserProfile)

**Implementation:**
- A `SuggestionEngine` service that runs on app foreground
- A `NotificationService` (using `flutter_local_notifications` — already in pubspec) for local pushes
- Suggestion templates stored in `media/` or in code

### 3.5 Adaptive TDEE (1 day)

**Why it matters:** The whole point of "smart" nutrition tracking. MacroFactor's killer feature.

**What's there:** TDEE wizard in Settings calculates a starting TDEE from inputs.

**What's missing:** A weekly recalibration that uses actual weight + intake data to refine TDEE.

**Algorithm (simple version):**
```
Weekly delta = (avg intake) - (TDEE estimate)
Weight change = (week_n weight) - (week_n-1 weight)
Calories per kg = 7700 (3500 if you use pounds)
Implied TDEE = avg_intake - (weight_change_kg * 7700 / 7)
```

After 3+ weeks of consistent logging, this becomes more accurate than the static formula.

### 3.6 Exercise database completeness (4–6 hours)

**Current state:** 46 chest exercises on PB. **Target:** ~488 across 9 muscle groups.

**Effort:** Mostly boilerplate. Take `scripts/exercises_chest.js` and:
1. Copy to `exercises_back.js`, `exercises_shoulders.js`, etc.
2. Fill in real exercises (ExRx.net, Bodybuilding.com are good sources)
3. Run each script to seed PB

**Recommended:** A single `exercises_all.json` with all 488, then one script that loads and seeds everything. Easier to maintain.

### 3.7 Workout UI completion (4 days)

**Currently:** Workout screen has search but no session UI.

**Need:**
1. **Active session screen** — list of exercises in session, tap to expand and log sets
2. **Set logger** — `S x W @ RPE` UI; previous session auto-filled for superset/progression
3. **Rest timer** — 90s default, configurable per exercise; haptic + audio cue
4. **Exercise picker** — searchable list with thumbnails; filter by muscle group
5. **History view** — past sessions, PRs, total volume per week chart

**This is the work that takes NutriTrack from "AI nutrition app with half a workout feature" to "complete nutrition + workout app."**

### 3.8 Smart notifications (2 days)

**Why it matters:** Retention. Apps that ping users daily retain 3× better than passive apps.

**What to notify:**
- 7 PM if no dinner logged: "Snap your dinner?"
- 8 AM if weight hasn't been logged this week: "Weigh-in day?"
- When protein is < 50g by 6 PM: "Protein warning — try Greek yogurt"
- When a workout is overdue (set cadence in settings): "Rest day or leg day?"

**Use `flutter_local_notifications` (already in pubspec).** Wire through riverpod.

---

## Category 4: 🟢 Polish (the 1% that makes it delightful)

These are NOT blockers. They're the things that make NutriTrack memorable.

### 4.1 Haptic feedback everywhere

- Successful log → light haptic
- Failure → heavy haptic
- Camera shutter → medium haptic
- Workout set complete → double haptic + vibration

iOS: `HapticFeedback.mediumImpact()`
Android: `Vibration.vibrate(duration: 50)`

### 4.2 Motion that means something

You have `app_motion.dart` already. Use it for:
- Macro donut: animate from 0 → current value on dashboard load (1.2s ease-out-cubic)
- Barcode scan: pulse the camera frame when scanning
- Voice: waveform visualization while recording
- Workout set log: scale-up bounce on set save

### 4.3 Sound design

- Subtle "swoosh" on meal log
- Bell on workout complete
- Soft "click" on set save
- Different pitch for macro over/under goal

Use `just_audio` (already in pubspec) for short .mp3 effects.

### 4.4 Skeleton loaders everywhere

You have `shimmer` declared but unused. Use it for:
- Dashboard tiles while data loads
- Exercise search results
- History list
- Insights charts

**This single feature removes 80% of "feels slow" complaints.**

### 4.5 Empty states with personality

Every screen needs a great empty state. Examples:

- **No meals today:** "Nothing logged yet. Snap your first meal — it'll take 5 seconds." + camera button
- **No workouts this week:** "Rest day is good. Or hit the gym — your call." + start workout button
- **No weight history:** "Weigh-ins make the algorithm smarter. Log your first one." + log weight button
- **No exercise matches:** "Nothing matches. Did you mean...?" with suggestions

### 4.6 Onboarding "wow" moment

The first time a user logs via voice or camera, show a celebration:
- Confetti animation (you have `confetti` declared but unused)
- "+247 kcal logged in 4 seconds"
- "You've saved 2 minutes vs. typing"

Make the FIRST experience feel fast and magical. This is when users decide to keep the app.

### 4.7 Streaks & achievements (3 days)

**Why it matters:** Duolingo proved this. Streaks are the #1 retention mechanism in consumer apps.

**For nutrition:**
- "5-day logging streak" 
- "7-day protein goal hit"
- "30 days of complete logs"
- "Logged 50 unique foods"

**For workout:**
- "PR on Bench Press: +5 lbs"
- "5 workouts this week"
- "Hit every muscle group this week"

Show on Dashboard as small badge row. Don't make it gamified (no points) — make it *acknowledgment* of real behavior.

### 4.8 Quick actions

- **Long-press dashboard tile** → quick log (e.g., long-press "Lunch" → "What did you eat?")
- **Swipe-to-delete** on meal entries
- **Swipe-to-favorite** on barcode/camera result
- **Pull-to-refresh** on dashboard (re-aggregate macros)
- **iOS share extension** (later — for native "Share to NutriTrack" from Photos)

### 4.9 Quick-add without logging in

For casual users who don't want accounts:
- "Continue without account" in onboarding
- All data local-first
- "Sign in to sync across devices" in Settings

Don't gate the core experience on auth.

### 4.10 Helpful error messages

You have `AppErrorHandler` but error messages should:
- **Be specific**: "Camera permission denied. Open Settings to grant camera access." (not "Error occurred")
- **Be actionable**: "No internet. We'll save this and sync later." (not "Network failed")
- **Be human**: "Couldn't identify this. Try a clearer photo with the food centered." (not "AI classification failed")

### 4.11 Accessibility (a11y)

- All interactive widgets need `Semantics(label: '...')`
- Color contrast check (WCAG AA minimum)
- Dynamic font scaling tested up to 200%
- VoiceOver/TalkBack tested on real devices

### 4.12 Localization (i18n)

- Start with `intl.arb` setup
- English first
- Then Mandarin (your SEA user base)
- Then Bahasa Indonesia / Thai / Vietnamese

For v1, English-only is fine. But the structure must support it.

### 4.13 Offline indicator

- Show a banner when offline: "Offline — logging locally, will sync when reconnected"
- Show queue count: "3 logs pending sync"
- Show sync success: "✓ Synced"

### 4.14 Crash reporting (Sentry — 2 hours)

`flutter pub add sentry_flutter` + add to `AppErrorHandler`. Free tier = 5K events/month. Non-negotiable for production.

### 4.15 App Store presence

- **App name:** "NutriTrack" (clean, clear, not "AI Nutrition Tracker Pro+")
- **Subtitle:** "Snap. Speak. Log."
- **Description:** focus on the speed of logging + the AI intelligence
- **Screenshots:** show the camera-in-action + the dashboard + the workout
- **Category:** Health & Fitness
- **Keywords:** nutrition tracker, calorie counter, AI food scanner, macro tracker, workout log

---

## Critical Path: What to do in the next 4 weeks

| Week | Goal | Hours |
|---|---|---|
| **1** | Fix all 31 compile errors + lint + dead deps + README. Write 7 priority tests. App runs on your phone for the first time. | 25h |
| **2** | Wire Dashboard + Insights + Workout screens to real Drift data. Onboarding flow. Sentry. | 35h |
| **3** | Voice logging UI + Whisper integration. AI camera verification flow. | 30h |
| **4** | Exercise database (488 entries). Workout session UI. Smart notifications. | 30h |

After 4 weeks: **TestFlight + Play Internal Track.** Invite 50 friends/family. Watch how they use it.

After 6 weeks: **Public beta.** Listen to feedback. Iterate.

After 8 weeks: **Public launch.** Marketing push.

---

## What makes the BEST nutrition app (not just A nutrition app)

The nutrition app winners of 2026 share these traits:

1. **Fast logging** — under 5 seconds from "I want to log" to "logged" (NutriTrack's AI focus)
2. **Personalized targets** — not generic 2000 kcal, but YOUR kcal (NutriTrack's TDEE wizard)
3. **Motivating without being preachy** — no guilt trips, no "you've gone over budget" (use streaks + nudges, not warnings)
4. **Works offline** — airplane mode logging, sync later (NutriTrack's offline-first)
5. **Doesn't require a login** — local-first, optional sync (recommend this path)
6. **Multi-modal** — camera, voice, scan, text — pick whichever is fastest in the moment (NutriTrack's 3-method approach)
7. **Honest AI** — show confidence, allow corrections, never silently wrong (verification flow)
8. **Privacy-respecting** — data stays on device by default, AI processes images but doesn't store them (NutriTrack's architecture supports this)

NutriTrack **has 6 of 8** in the architecture already. What's missing:
- #1 (fast logging) — depends on Category 3.1 + 3.2 + 3.3
- #7 (honest AI) — depends on Category 3.3 verification flow

If you do Category 1 (fix what's broken) + Category 2 (wire what exists) + Category 3.1 (onboarding) + Category 3.3 (camera verification) + a splash of Category 4.4 (skeleton loaders) + 4.5 (empty states) + 4.6 (wow moment)...

You have an honest shot at being **the best AI-first nutrition app on the market.**

---

## The list of "must NOT skip"

If you skip any of these, NutriTrack won't be the best:

1. ✅ **Onboarding** (Category 3.1) — non-negotiable
2. ✅ **Real data wiring** (Category 2.1–2.6) — without this, the app is a tech demo
3. ✅ **Voice logging UI** (Category 3.2) — your main differentiator
4. ✅ **Camera verification** (Category 3.3) — without this, users lose trust fast
5. ✅ **Sentry crash reporting** (Category 4.14) — without this, you can't fix bugs you don't know about
6. ✅ **Empty states with personality** (Category 4.5) — without these, the app feels broken on day 1

If you do these 6, NutriTrack is **launchable.** Add the rest over time.

---

## The list of "skip for v1, plan for v2"

- Localization (English-only at launch is fine)
- Cloud sync (offline-first local-only is fine for v1)
- Wearable integrations (Apple Watch / Garmin — defer to v2)
- Apple Health / Google Fit integration (deferred; we removed `health` plugin)
- Social features (share progress, friends feed) — defer entirely

These are all features MacroFactor / MFP have, but none of them are differentiators. They can wait.

---

**Bottom line:** NutriTrack has the bones of a great app. The build is broken (45 min to fix). The data plumbing is half-done (4 days to finish). The differentiators (voice + camera) are architected but not built (1 week to ship). The polish (skeletons, empty states, haptics) is missing (1 week).

**Total to launchable v1: 4–5 weeks of focused work.** Not 6 months. Not 12 weeks. **4 weeks.**

The next 2 hours alone (fixing the 31 errors + dead deps + README) will get you from "broken code" to "first-time builds on a phone."

Let me know what to tackle first.
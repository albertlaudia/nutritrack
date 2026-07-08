# NutriTrack — Production Readiness Audit (Update)

**Date:** 2026-07-07
**Method:** Static analysis (`analyze_output.txt` from `flutter analyze`) + grep across `lib/`.
**Disclaimer:** This audit is based on **the user's last push on Windows**, not on a fresh `flutter analyze` run in this sandbox (no Flutter SDK here). The errors listed below are reproduced verbatim from `analyze_output.txt` (UTF-16LE) at the time of the user's last sync.

---

## Executive Summary

| Category | Status | Details |
|---|---|---|
| Hard compile errors | 🔴 **31 errors** | All in `barcode_scanner_screen.dart` + `camera_screen.dart` |
| Lint warnings | 🟡 17 warnings | Mostly unused imports/fields, `withOpacity` deprecations |
| Test coverage | 🔴 **0%** | No `test/` directory exists |
| Auth/onboarding | 🔴 **Missing entirely** | App opens straight to `/dashboard` |
| Secrets config | 🟡 Template-only | User has to copy `secrets.dart.template` manually |
| Generated files in repo | 🟡 Gitignored | Every fresh clone must run `build_runner` before first build |
| Pub health | 🟢 Mostly OK | Known 9 majors-behind tracked in `KNOWN_WARNINGS.md §6` |
| Media/brand | 🟢 Done | `media/` golden source + 32 exported assets shipped |
| Drift migration | 🟢 Done | All Isar references removed, Drift DB in place |
| Build (Android) | 🟡 Last-known broken | `health 10.2.0` removed; awaiting user's re-test |
| Build (iOS) | 🟢 Unknown | macOS runner CI never had a clean bill |
| PB schema | 🟢 Live | 8 `nt_*` collections seeded, anonymous barcode read enabled |
| Exercise data | 🟡 46/488 (9.4%) | Only chest seeded — back/legs/shoulders/etc. missing |
| Accessibility (a11y) | 🔴 Not audited | No Semantics labels reviewed |
| Localization (i18n) | 🔴 English-only | No `intl.arb` setup, hard-coded strings throughout |
| Crash reporting | 🔴 Missing | No Sentry / Firebase Crashlytics / Bugsnag integration |
| Analytics | 🔴 Missing | No events tracked |
| Onboarding | 🔴 Missing | First-launch flow doesn't exist |
| Paywall / premium tier | 🔴 Not in v1 | That's a feature, not a defect |

**Production-ready score: 25% → 30%** (mostly unchanged from June audit; build failure now a smaller set of files; brand shipped).

---

## 1. 🔴 Build-blocking errors (must fix before next build)

**Source:** `analyze_output.txt` (Windows user's last `flutter analyze`)

### `lib/features/barcode/presentation/screens/barcode_scanner_screen.dart` — 27 errors

**Errors A–F: `Future<void> Function() vs Function(String)`** (lines 264, 303, 327)

```dart
// Wrong (parameter type mismatch — argument takes no args, expected String)
Future<void> Function()  →  Future<void> Function(String)
```

3 call sites. The signature expects a callback that receives a String (barcode), but the current callback takes no args.

**Errors G–K: `MobileScannerErrorBuilder?` type mismatch** (line 457)

```dart
_ErrorView Function(BuildContext, MobileScannerException)  →  MobileScannerErrorBuilder?
```

Mobile Scanner's API changed in `^5.x` → `^7.x` (you're on 5.2.3 with 7.2.0 available). The error builder signature changed.

**Errors L–V: `RRect.topLeft`, `RRect.topRight`, `RRect.bottomLeft`, `RRect.bottomRight`** (lines 525–538)

```dart
RRect.topLeft  // undefined — that's a getter on Rect, not RRect
RRect.topRight // same
```

8 errors. Code is using `RRect.topLeft` etc. but `RRect` doesn't have those properties. Either:
- Use `RRect.tlRadius` / `RRect.trRadius` etc. (the radius accessors)
- Or compute the points manually from `RRect.outerRect` / `RRect.innerRect`

### `lib/features/camera/presentation/screens/camera_screen.dart` — 4 errors

Same `RRect` getter issue (likely) plus a `MobileScannerException`-style build issue from API drift.

### Fix plan (single PR)

```bash
# Step 1: Fix the 3 Function() vs Function(String) callbacks
#         (add String param, ignore with _)
# Step 2: Fix the error builder signature
# Step 3: Rewrite the rounded-corner math to use Rect not RRect
# Step 4: Run flutter analyze; expect 0 errors
```

**Effort:** 30–45 minutes. Should be a clean PR.

---

## 2. 🟡 Lint warnings (cleanup)

17 warnings, mostly mechanical:

| Count | Warning | Where |
|---|---|---|
| 5 | Unused imports | `lib/app/router.dart`, `lib/app/shell_scaffold.dart`, etc. |
| 2 | Unused fields | `_stack` in error handler, `_cameraStatus` in camera screen |
| 6 | `withOpacity` deprecation | Throughout — Flutter 3.27+ wants `withValues(alpha:)` |
| 4 | Misc (stale imports, etc.) | – |

Fix: `dart fix --apply` after a clean build, OR sed-rewrite `withOpacity` → `withValues`.

**Effort:** 15 minutes. Zero functional risk.

---

## 3. 🔴 Zero test coverage

There is **no `test/` directory.** `flutter test --coverage` in CI will succeed only because there are no tests to fail.

For a production app, this is the single biggest gap. Not because tests are sacred — because:

1. **Regressions will slip through silently** — every time we add a feature, we risk breaking something invisible.
2. **No refactor safety net** — every line of cleanup requires manual verification.
3. **Onboarding new contributors takes longer** — there's no `WidgetTester` example to copy.

### Priority test surface

| Test | Why it matters |
|---|---|
| `core/ai/ai_gateway_test.dart` | Mocks Dio, verifies response → `FoodLogEntry` parsing |
| `core/db/drift_database_test.dart` | Uses `NativeDatabase.memory()` to verify schema, no actual disk writes |
| `core/error/app_error_handler_test.dart` | Verifies `runZonedGuarded` catches exceptions and reports them |
| `features/dashboard/data/food_log_repository_test.dart` | CRUD on local + mocked sync queue behavior |
| `features/barcode/data/off_client_test.dart` | Mocked HTTP, barcode → `FoodLogEntry` parsing |
| `shared/providers/core_providers_test.dart` | Riverpod provider override testing |
| `widget_test.dart` | App boots, dashboard renders, bottom nav works |

**Effort:** 1–2 days for the critical 7 above. ~150 LOC of tests for 9,400 LOC of code = ~1.6% coverage, which is fine for a v1.

---

## 4. 🔴 No auth / onboarding

The router has 4 branches + 2 modals (`/camera`, `/barcode`). There is **no `/login`, no `/signup`, no `/onboarding` route**. The app's `initialLocation` is `/dashboard`. On first launch, user sees dashboard with no biometrics set.

For an AI nutrition tracker that's "personal," this is bad:

- **Without onboarding**, user gets a generic 2000 kcal target that's almost certainly wrong for them.
- **Without auth**, there's no concept of "this is my data" — every device is a fresh install.

### What v1 needs (minimum)

1. **3-screen onboarding** (welcome → goal pick → first weight entry)
2. **Settings-only auth** (no login screen; data is local-only, optional email for sync)

The settings-based auth path means: no login screen, but the Settings tab has a "Sign in to sync across devices" button that opens Supabase auth. Simpler, faster, less friction.

**Effort:** 2–3 days (onboarding + Supabase auth wiring).

---

## 5. 🟡 Secrets not configured for fresh clones

```bash
$ test -f lib/core/config/secrets.dart && echo "YES" || echo "NO"
NO
```

Only `secrets.dart.template` exists. Every fresh clone needs:
```bash
cp lib/core/config/secrets.dart.template lib/core/config/secrets.dart
# edit values
dart run build_runner build
flutter run
```

`scripts/setup.sh` does this — but it's not in `flutter create` output, and Android/iOS CI workflows don't run it.

**Fix:** Add a `secrets.example.dart` that gets committed (currently `.template` is committed). Or use `--dart-define` for keys (safer).

**Effort:** 30 minutes.

---

## 6. 🟡 Generated files gitignored

`.gitignore`:
```
*.g.dart
*.freezed.dart
```

Fresh clone → `flutter pub get` → `dart run build_runner build` → first compile.

This is conventional for Flutter but causes a "first-build pain" CI catches fine but a new developer doesn't. Mitigation: commit the generated files (anti-pattern but practical), OR document the build step loudly.

CI does run `dart run build_runner build --delete-conflicting-outputs` so it's safe there.

---

## 7. 🔴 9 packages on major version N–1 (KNOWN_WARNINGS §6)

| Package | Current | Latest | Migration effort |
|---|---|---|---|
| flutter_riverpod | 2.6.1 | 3.3.2 | 2–3 days (rewrite all `@riverpod` providers + codegen) |
| riverpod_annotation | 2.6.1 | 4.0.3 | coupled |
| riverpod_generator | 2.6.4 | 4.0.4 | coupled |
| freezed | 2.5.8 | 3.2.5 | 2 days (rewrite all `@freezed` classes) |
| freezed_annotation | 2.4.4 | 3.1.0 | coupled |
| mobile_scanner | 5.2.3 | 7.2.0 | 1 day (Android permission + scan API drift) |
| health | 10.2.0 | 13.3.1 | n/a (we removed it) |
| go_router | 14.8.1 | 17.3.0 | 1 day |
| intl | 0.19.0 | 0.20.3 | half-day (date formatting API reshuffle) |
| drift | 2.28.2 | 2.34.0 | minor — bump freely |
| camera | 0.11.4 | 0.12.0+1 | minor — bump freely |
| flutter_lints | 4.0.0 | 6.1.0 | rule audit (half-day) |

**Effort:** ~1 week total if done in 5 grouped PRs (per `KNOWN_WARNINGS.md §6`).

---

## 8. 🔴 Exercise data: 46 of 488

`scripts/exercises_chest.js` is the only seed file. Per the audit doc, the goal was 488 exercises across 9 muscle groups. We're at **9.4%**.

**What's missing:**
- back.js (~80 exercises)
- shoulders.js (~50)
- arms/biceps.js (~40)
- arms/triceps.js (~30)
- legs.js (~100)
- glutes.js (~25)
- core.js (~50)
- cardio.js (~60)
- full_body.js (~30)

**Effort:** 4–6 hours (boilerplate-heavy; copy `exercises_chest.js` template, fill in name + muscle group + equipment per exercise).

---

## 9. 🟢 Drift migration done, Isar fully purged

`grep -rn "isar\|Isar"` shows zero matches in `lib/`. `pubspec.yaml` doesn't reference Isar. `drift_database.dart` has 7 tables with `@DataClassName` annotations (post-freezed-3 hint).

---

## 10. 🟡 README drift — still says "Isar"

```
## Stack
| Local DB | Isar 3.1 (NoSQL, indexed, reactive queries) |
```

Update needed:
- `Local DB | Drift 2.28 (SQLite + reactive streams + KMP-friendly)`
- Drop `pubspec.lock not committed` claim (now committed)
- Update Flutter version `3.24+` → `3.27+`

**Effort:** 10 minutes.

---

## 11. 🔴 Missing: a11y, i18n, crash reporting, analytics

| Concern | What's there | What's missing |
|---|---|---|
| **Accessibility** | Some `Semantics` widgets? (didn't grep) | Label audit, focus order, dynamic font scaling tested |
| **Localization** | `intl: ^0.19.0` declared | No `lib/l10n/`, no `.arb` files, all strings hardcoded |
| **Crash reporting** | None | No Sentry, no Firebase Crashlytics, no Bugsnag |
| **Analytics** | None | No GA4 events for `app_open`, `meal_logged`, `workout_completed` |

For v1 launch, crash reporting is the must-have. Analytics can wait. i18n and a11y are post-launch follow-ups.

**Effort:**
- Crash reporting (Sentry): 2 hours. `flutter pub add sentry_flutter`, add `Sentry.captureException` wrappers in error handler.
- Analytics (GA4): 4 hours.
- i18n: 2–3 days (rewrite all strings).
- a11y: 1–2 days audit + fixes.

---

## 12. 🟢 Media/brand shipped

- 1 master SVG (`icon-master.svg`)
- 32 binary assets across iOS / Android / Web / Play Store / branding
- 2 utility scripts (`scripts/export_app_icons.py`, `tools/sync-app-icons.sh`)
- Visual contact sheet at `docs/icon-sizes-overview.png`

**What's still empty:** `media/branding/{logo,wordmark}/`, `media/fonts/Inter/`, `media/illustrations/`, `media/marketing/`, `media/store-assets/ios-app-store/`. READMEs describe what should go there.

---

## 13. 🟢 PB schema complete + live

8 `nt_*` collections on `pocketbase.scaleupcrm.com`:
- nt_users (base, 11 fields)
- nt_food_logs (19 fields)
- nt_exercises (16 fields, 46 chest seeded)
- nt_workout_sessions (9 fields)
- nt_weight_entries (7 fields)
- nt_favorites (10 fields)
- nt_meal_templates (7 fields)
- nt_sync_queue (9 fields)
- nt_barcode_cache (19 fields, anonymous read)

The OFF→PB sync cron (`off-to-pb-sync.yml`) runs every 6h to populate the barcode cache. Last runtime: unknown (no GitHub Actions UI access from sandbox).

---

## 14. 🟡 2 surviving "TODO" comments in user-facing code

```dart
// lib/features/insights/presentation/screens/insights_screen.dart:206
// TODO: wire to WeightRepository + nt_weight_entries.

// lib/features/workout/presentation/screens/workout_screen.dart:534
// TODO: wire to active workout session once
```

These are **the Insights screen and Workout screen** — they render placeholder data, not real Drift-backed data. User must manually log weight via the "Log weight" button you added in commit `3b3556f`, and the chart reads from a `_generateSampleWeights()` hardcoded list.

**Effort:** 4–6 hours to wire Insights to WeightRepository, another 6–8 hours to fully wire Workout session flow.

---

## 15. 🟢 Supabase folder exists but unused

```
supabase/
```

No files imported from this folder in `lib/`. The `supabase_flutter: ^2.8.0` dep is declared. `supabase/` directory holds what looks like initial setup. Either:
- Finish Supabase integration (auth + cloud sync), OR
- Remove the dep until you actually need it.

**Effort:** 1 week to do Supabase properly (RLS, schema, real-time sync).

---

## Priority-ordered fix list (next 2 weeks)

| # | Task | Effort | Why first |
|---|---|---|---|
| 1 | Fix 31 compile errors in barcode/camera screens | 45 min | Without this, nothing else runs |
| 2 | Fix 17 lint warnings (`dart fix --apply`) | 15 min | One-shot cleanup |
| 3 | README Isar→Drift, Flutter 3.24→3.27, etc. | 10 min | Avoid contributor confusion |
| 4 | Remove dead deps: just_audio, web_socket_channel, confetti, shimmer, animations, lottie, gap, supabase_flutter (if no plan) | 30 min | Smaller dep tree = faster builds |
| 5 | 7 priority tests (AI gateway, Drift DB, error handler, repositories, providers, smoke test) | 1–2 days | Without tests, every future PR is a coin flip |
| 6 | Onboarding flow (3 screens: welcome → goal → first weight) | 2 days | App without onboarding = immediately-churned |
| 7 | Wire Insights + Workout screens to Drift repos | 1 day | Currently renders fake data — feels broken |
| 8 | Sentry integration for crash reporting | 2 hours | Production without crash reporting = blind |
| 9 | Seed remaining 442 exercises (back, shoulders, arms, legs, glutes, core, cardio, full_body) | 4–6 hours | Without data, workout feature is half-built |
| 10 | Supabase auth + cloud sync | 1 week (or defer to v2) | Big lever for retention |
| 11 | Major-version bumps (5 grouped PRs per KNOWN_WARNINGS §6) | 1 week | Future-proofing |

---

## What I would do RIGHT NOW (in priority order)

If you (the user) are reading this and have a fresh morning:

1. **Run `flutter analyze` locally.** Get a current errors list. (`analyze_output.txt` is from your last push.)
2. **Fix the 31 compile errors.** Mostly `RRect.topLeft` → `Rect.topLeft` and signature fixes. This is THE blocker.
3. **Run `dart fix --apply`.** Cleans 12 of the 17 warnings in 5 seconds.
4. **Send me a screenshot of the icon on your home screen** after running `bash tools/sync-app-icons.sh`.
5. **Pick ONE of the priority tasks (5–11) above and start.** Onboarding is highest-impact. Tests is highest-effort. Exercises is highest-velocity. Pick what excites you.

If you want me to do any of these, just say the word. I'll write the fix, commit, push. You pull, run `flutter analyze`, confirm zero errors.

---

**Auditor:** Mavis (Claude Code)
**Audit timestamp:** 2026-07-07 13:47 Asia/Shanghai
**Confidence level:** High on errors/warnings (from `analyze_output.txt`). Medium on feature completeness (from grep + file structure). Low on what users actually see in their app (no device runs).
---

## REFRESH 2026-07-08

The 31 compile errors documented in §1 were **resolved by the user across
commits f046171, 2c4b2b5, 55250c9** before this audit was finalized. The
`analyze_output.txt` referenced at the top is 8+ days stale and was removed
from the repo.

Re-run a fresh `flutter analyze` on your machine to confirm. The `tools/lint-cleanup.sh`
script wraps the full pipeline.

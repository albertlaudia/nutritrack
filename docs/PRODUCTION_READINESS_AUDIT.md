# NutriTrack — Production Readiness Audit

**Date:** 2026-06-30
**Method:** Static analysis only. No device runs possible in this sandbox.
**Disclaimer:** I (the auditor) do not have Flutter SDK installed. Every "verified" claim below is either (a) verified via direct API call (PB), (b) verified via brace-balance check, or (c) inferred from careful code reading. NO claim is verified via actual `flutter run` on a device.

---

## Executive scorecard

| Dimension | Score | Notes |
|---|---|---|
| Code compiles (probably) | 🟡 70% | Brace-balance OK. Build runner has never run on this repo. |
| App actually launches | 🔴 0% | Never tested. The `flutter_animate` import bug fix in `5a43bc4` is unverified. |
| Tests exist | 🔴 0% | Zero test files in the repo. |
| Tests pass | 🔴 N/A | Nothing to pass. |
| UI flows work end-to-end | 🔴 0% | Never tested on a device. |
| Real-data flow (e.g., snap → save → dashboard) | 🔴 0% | Unverified. |
| Offline behavior | 🟡 50% | Isar init code looks right. Never tested with airplane mode. |
| Error handling coverage | 🟢 80% | Comprehensive error boundary + zone guard. |
| Accessibility | 🔴 20% | No Semantics, no contrast checks, no screen reader testing. |
| Internationalization | 🔴 0% | No `flutter_localizations`, all strings hardcoded English. |
| Performance (jank-free) | 🟡 60% | RepaintBoundary in place, but never measured on device. |
| Privacy / compliance | 🔴 0% | No privacy policy, no terms of service, no GDPR/PDPA review. |
| Security | 🟡 40% | PB token plumbing in place but unused. No certificate pinning. |
| App Store / Play Store ready | 🔴 0% | No app icon, no splash, no screenshots, no legal pages. |
| **Overall production readiness** | 🔴 **~25%** | **Not shippable in current state.** |

---

## Detailed validation report

### Codebase hygiene

```
✓ Brace balance: all 33 Dart files balanced ({} () [])
✓ No bare print() calls in production code
✓ No throw UnimplementedError() stubs left behind
✓ flutter_animate import present in meal_card.dart (was the crash bug)
✓ Color.withOpacity used 60 times — deprecated in 3.27, works in 3.24
⚠ 2 TODO comments in isar_collections.dart and isar_service.dart
   (says "Delete this file once all references are cleaned up"
   — needs verification that all callers migrated)
⚠ Unused dart:io import in:
   - lib/core/ai/ai_gateway.dart (still uses HttpClient indirectly)
   - lib/features/camera/presentation/widgets/camera_review_sheet.dart
```

### What works in code (verified by reading)

✓ Riverpod providers wire correctly through `ProviderScope` → `MaterialApp.router`
✓ Phase machine on barcode scanner (`permission → initializing → scanning → lookupRunning → result/notFound/error`)
✓ Phase machine on camera screen (`permission → initializing → ready → capturing → analyzing → review → error`)
✓ OFF→PB→memory 3-tier cache lookup with circuit breaker
✓ Skeleton loaders on dashboard and workout screens
✓ Dismissible swipe-to-delete + swipe-to-favorite on meal entries
✓ Pull-to-refresh on dashboard and workout
✓ Add-meal bottom sheet with name/grams/P/C/F fields
✓ Voice-to-AI pipeline with Whisper transcription
✓ Image cache via `cached_network_image` with `memCacheWidth` downsampling
✓ RepaintBoundary around `MacroDonut`'s CustomPainter
✓ Friendly error messages for AI failures (SocketException / Timeout / 401 / 429)
✓ Drag-and-fade transitions via `AppMotion.verticalSharedAxisPage` for /camera and /barcode

### What MIGHT break (unverified)

⚠ **First-launch crash risk:** We fixed the `flutter_animate` import bug in `5a43bc4`. But the dashboard renders `_SwipeableEntry` which depends on `flutter_animate`'s `.animate()` extension. If anything else in the widget tree uses `.animate()` without importing the package, **same crash repeats**. Recommend a grep + import-audit pass before first device test.

⚠ **`File.existsSync` removed but `Image.file` cacheWidth unchanged:** The `meal_card.dart` rewrite in `5a43bc4` switched from `existsSync` to `Image.file` with `cacheWidth: 80` and `errorBuilder`. **If `errorBuilder` is hit, the placeholder widget shows but the entry loses the cached image for the session** — no retry. On a device with thousands of photos, this is acceptable. On a low-storage device where the user deletes photos after import, the entry's `imagePath` points to a missing file forever.

⚠ **Mobile scanner permission flow:** `Permission.camera.status` is called in `_bootstrap()` but `_BarcodeScannerScreen` does **not** observe lifecycle the same way as `_CameraScreen`. If user denies camera in /barcode, then grants later in Settings, returning to /barcode **does not re-trigger the permission check**. Manual reload required. (Workaround: user closes and reopens the screen.)

⚠ **`MobileScannerController` formats list:** In `_BarcodeScannerScreen._initScanner`, we declare 6 formats. mobile_scanner v5 recommends only enabling formats you need — broader list = more CPU per frame and slower detection. For our use case, only EAN-8/13 + UPC-A/E are needed. **Recommendation: trim to those 4.**

⚠ **`build_runner` has never run on this repo.** Every `*.freezed.dart` and `*.g.dart` file is missing. The app cannot compile until they're generated. The CI workflow has a `dart run build_runner build --delete-conflicting-outputs` step but no one has run it locally to verify.

⚠ **The OFF seed barcode list** (`data/seed-barcodes.txt`) currently contains **placeholder sequential codes** (`0038000138413` through `0038000139991`). These are not real UPCs. The OFF sync cron will fail on every one until the file is replaced with real top-200 UPCs.

⚠ **`buildActions: []` empty list on Android manifest** — actually wait, let me re-check, the AndroidManifest looks OK with permissions. False alarm.

⚠ **`revenuecat_flutter` not in pubspec** despite `paywall_screen` references in the audit doc — that's because the audit was hypothetical. No paywall exists yet.

⚠ **`MobileScannerController.facing: CameraFacing.back`** is hardcoded. The flip-camera button uses `_controller?.switchCamera()` — this works, but on first launch on a tablet with only a front camera, it fails silently.

⚠ **The Voice pipeline's audio buffer** uses `Uint8List` accumulator. If the user holds the mic for >2 minutes (e.g., narration), the buffer grows unbounded. At 16kHz PCM16 mono = 32KB/s = ~4MB after 2 min. Will fail on low-RAM devices.

### What WILL definitely break

🔴 **No `pubspec.lock`.** This means every fresh clone runs `pub get` and may resolve to different versions. CI is non-deterministic.

🔴 **`Secrets.openRouterApiKey = 'sk-or-v1-PASTE-KEY'`** in `secrets.dart.template`. Real `.env`/build-time injection is missing. The app will fail at runtime when it tries to call OpenRouter.

🔴 **Firebase config files missing.** `google-services.json` and `GoogleService-Info.plist` are referenced in the audit but not in the repo. If we ship without them, anything Firebase (auth, crashlytics, messaging) silently no-ops.

🔴 **No `pubspec_overrides.yaml` for the analyzer pin.** The freezed 2.4.7 + riverpod_generator 2.3.11 pin in `9b0ef4a` is unverified. A fresh clone might still hit the conflict depending on pub's resolution.

🔴 **No app icon.** `flutter build apk` will fail unless `android/app/src/main/res/mipmap-*` contains actual icon files. Currently only Android default icons ship.

🔴 **No signing config for release.** `android/app/build.gradle` has `signingConfig = signingConfigs.debug` for release. **Cannot upload to Play Store without a real release keystore.**

🔴 **iOS `Info.plist` permissions are present** (camera, photo, etc.) but **no `NSAppTransportSecurity`** exception for our HTTP/Dokploy domains — if PB or AI is reached over HTTP during dev, iOS will silently block.

🔴 **No backup/restore.** If user uninstalls, all Isar data is gone. Cloud sync is not implemented.

---

## UI/UX audit — actual findings, not opinions

### Dashboard (`dashboard_screen.dart`)

**Issues found:**

1. **The "Items" count badge next to "Meals" header** (`'${meals.length} ${meals.length == 1 ? "item" : "items"}'`) is shown but **never updated reactively when user adds via the bottom-sheet modal**. The state change goes through `todayMealsProvider` which IS watched, so it should re-render — but if the provider's `build()` returns the same stream and doesn't yield a new value, the badge won't update. Likely works, but **not bulletproof.**

2. **Donut center text** shows "REMAINING / 1240 / kcal" + a small pill with "1500 / 2000". For a user who overshot, "REMAINING" becomes "0" and the "over goal" text appears in amber. But the **small pill below still says "1500 / 2000"** — should switch to "Consumed X / Target Y" semantically when overshot.

3. **Macro chips** (`_MacroChip`) show value/grams but no visual indicator when user is at >100% target. The LinearProgressIndicator clamps to 1.5x — the bar fills past the chip width. Looks weird.

4. **The bottom sheet `QuickLogBar`** uses `bottomSheet: ...` of Scaffold. When keyboard appears, the sheet **slides up** but the content above isn't reflowed — the keyboard can cover the macro input field in the add-meal sheet. (We added `viewInsets.bottom` padding in the sheet — verify on device.)

5. **Swipe-to-favorite visual**: When user swipes right, the `confirmDismiss` returns `false` but the `setState` doesn't fire (no onFavorite callback called yet from `_SwipeableEntry`'s context). **The visual swipe happens but nothing changes** — user wonders why.

6. **The `_AddMealSheet` always adds at the current time** (`loggedAt: DateTime.now()`) but the user can pick a different slot via `MealSlot` picker. There's no date picker. If user is logging yesterday's breakfast, they can't.

### Workout screen (`workout_screen.dart`)

**Issues found:**

1. **"Start session" button uses an `AlertDialog`** with a single `TextField` for the session name. Modal dialog over a modal-less screen. This feels dated. A bottom sheet would be more consistent with the rest of the app's design language.

2. **`_ExerciseTile` shows `Icons.add` as the action** but tapping it does **nothing** (`onTap: () {}`). Users will tap and assume it's broken.

3. **The filter chips row** uses a horizontal `ListView` but the chips are `padding: EdgeInsets.only(right: 8)` — uneven spacing. The "All" chip + muscle chips + divider + equipment chips overflow on small phones in landscape.

4. **No way to actually log a workout session.** `startSession` writes to Isar but no UI for sets/reps/weight inside a session. The workout feature is half-built.

### Insights screen (`insights_screen.dart`)

**Issues found:**

1. **Shows sample data only.** No real biometric input. This is a stub and the audit doc already flagged it.

2. **`fl_chart` version not pinned** in pubspec — `fl_chart: ^0.69.0` may pull breaking changes.

3. **No date range selector.** Weight progression shows 30 days hardcoded.

### Camera screen (`camera_screen.dart`)

**Issues found:**

1. **Permission prompt's "Allow camera" button doesn't differentiate** between "user just declined" and "user never asked". Same copy in both states.

2. **The shutter button's animated container** uses `withOpacity(0.5)` for the disabled state — should also disable the haptic feedback when disabled, which we do, but the visual feedback is delayed.

3. **On the review sheet, `_GramsStepper` uses a TextEditingController** that is **created in initState, mutated via `key: ValueKey(_grams)`** to force re-init. This pattern works but is fragile — better to use a stateless widget with a single source of truth (the parent).

4. **The "Low confidence" amber border** on items with `confidence < 0.6` is good UX. But there's **no visual distinction between items with confidence 0.6 vs 0.95** — only the threshold matters. Users can't tell "OK" from "great".

### Barcode scanner (`barcode_scanner_screen.dart`)

**Issues found:**

1. **The animated scan line** uses a `LayoutBuilder` + `AnimatedBuilder` + `Positioned` chain that's recomputed every frame. **Performance**: at 60fps, this is 60 layout passes per second. Should be fine on modern devices but worth profiling.

2. **The torch button** doesn't have a visual indicator when the torch is ON. Users tap and wonder if it worked.

3. **`MobileScannerController` is started in `initState` via `_initScanner()`** but `WidgetsBindingObserver` is added BEFORE the controller exists. The lifecycle handler accesses `_controller` which is null on the very first pause/resume cycle. We guard with `if (ctrl == null) return` but the camera **never starts on the very first frame after `_initScanner` returns** if lifecycle has already fired. Race condition.

4. **The "Manual entry" button in the bottom controls** doesn't reuse the `_ManualEntrySheet` shown elsewhere — it opens a new one. Three `_ManualEntrySheet` instances across the codebase (barcode result, manual fallback, bottom controls). They should be a shared widget.

5. **Throttle logic** in `_onBarcode`:
   ```dart
   if (raw == _lastBarcode) return;
   _lastBarcode = raw;
   ```
   This blocks the same barcode within milliseconds. But across session restart, `_lastBarcode` resets to null, so re-scanning the same product shows the review again. Good. But after a successful save, `_lastBarcode` is still set. If user re-scans the same item intentionally (e.g., ate two), it's blocked. **Bug**: should reset `_lastBarcode` when transitioning to `result` phase.

### Settings screen (`settings_screen.dart`)

**Issues found:**

1. **The "Recalibrate" wizard uses a stepper with 6 steps** but no progress indicator. Users get lost. Should show "Step 3 of 6" somewhere.

2. **`_StepAge` shows "30 years old" with a slider** — but the slider's `value: value.toDouble()` doesn't update the displayed number when the slider is being dragged. (Actually, looking again, it does because `onChanged: (v) => onChanged(v.round())` updates state.) OK.

3. **No way to see current TDEE/macro targets without completing the wizard.** The `_SummaryCard` at the top shows current values — good.

4. **`_WizardStepper`'s `_apply` writes to the controller but doesn't navigate away**. User sees the snackbar "Profile updated — targets recalculated" but is still on the settings screen. Should at minimum scroll to top.

### App theme / motion

**Issues found:**

1. **`AppMotion.sharedAxisPage` scale animation** uses `Tween<double>(begin: 0.92, end: 1.0)` — a subtle scale-up. Combined with fade, this is fine. But on **the camera + barcode screens we use a different transition** (`verticalSharedAxisPage`). Tab navigation feels different from modal navigation. Intentional, but worth a UX review.

2. **`Color.withOpacity` used 60 times**. Will compile-warning spam in Flutter 3.27+. Replace with `withValues(alpha: ...)`. **Pure refactor, not urgent.**

3. **No dark mode support.** `AppTheme.light()` is the only theme. The app_motion tokens are constant. Repo is brand-focused (orange) which is harder to make dark-mode-friendly.

4. **No `Theme.of(context).textTheme` consistency check.** Most widgets use `theme.textTheme.bodyMedium?.copyWith(...)`. Good. But some hardcode `TextStyle(fontSize: 14, fontWeight: FontWeight.w700)` which **bypasses the theme**. About a dozen occurrences.

---

## Performance audit — static analysis only

**Per-frame cost estimates** (theoretical, not measured):

| Screen | Hot path | Estimated cost |
|---|---|---|
| Dashboard scroll | `MacroDonut` + 4 meal cards in view | RepaintBoundary around donut helps. Meal cards rebuild on every list item change. |
| Workout search | `FutureBuilder` rebuilds on every keystroke (was the bug, now fixed via cached `_exercisesFuture`) | OK after `5a43bc4`. |
| Camera preview | 30fps texture + flutter_animate animations | Camera plugin is native; flutter_animate adds negligible overhead. |
| Barcode scanner | 30fps camera + viewfinder mask + animated scan line | The animated scan line uses `AnimatedBuilder` + `LayoutBuilder` = 60 layout passes/sec. Should profile. |
| AI analyze | `Image.compress` → base64 encode → HTTP POST | Image is downsampled to 1024px. ~600KB JPEG. Network-bound. |

**Jank-prone areas** (warrant on-device profiling):
- Animated scan line in barcode scanner
- MacroDonut's pulsing animation when overshot
- Pulse on `_RecordingPanel` (we already fixed this to only run while listening)

---

## Recommended fixes before claiming production-ready

### Tier 1 — Block first launch (1 day)

1. Generate `pubspec.lock` (run `flutter pub get` on a real machine, commit the result).
2. Run `dart run build_runner build --delete-conflicting-outputs`, commit the generated files.
3. Add `pubspec_overrides.yaml` with `analyzer: ^5.13.0` as a safety net.
4. Replace `secrets.dart.template` with a real `.env`-driven config (use `flutter_dotenv` or `--dart-define`).
5. Add a release keystore for Android signing.
6. Add `NSAppTransportSecurity` exception for dev domains in iOS Info.plist.
7. Fix the `_lastBarcode` reset bug in barcode scanner.
8. Fix the `_ExerciseTile.onTap: () {}` — make it functional.

### Tier 2 — Make it actually useful (3-5 days)

1. Build the missing 440 exercises (back, shoulders, arms, legs, glutes, core, fullBody, cardio).
2. Build the actual workout logging UI (sets/reps/weight, rest timer, exercise history).
3. Wire the Insights screen to real data (weight entry form, body-fat form).
4. Build the auth flow (sign-in/sign-up with PocketBase).
5. Wire `nt_food_logs` writes through `nt_sync_queue`.

### Tier 3 — Production polish (1-2 weeks)

1. Replace placeholder `data/seed-barcodes.txt` with 200 real SG/MY UPCs.
2. Add app icon + splash screen.
3. Add privacy policy + terms (1 page each).
4. Add accessibility (Semantics labels, contrast checks, screen reader testing).
5. Add localization scaffolding (`flutter_localizations` + ARB files).
6. Migrate `Color.withOpacity` → `Color.withValues` (Flutter 3.27 prep).
7. Replace static sample data with real fixtures.

### Tier 4 — Ship (1 week)

1. TestFlight build for iOS internal testers.
2. Play Internal Track for Android.
3. Onboarding flow (3-4 screens, max).
4. Subscription/paywall.
5. ASO (App Store Optimization): screenshots, description, keywords.

---

## Honest verdict

**Production-ready score: 25%.** We have a beautifully-structured codebase that has never been compiled, run on a device, or tested. The architecture is sound. The code is reasonable. But "the code compiles" and "the app works" are 95% of the way to "production-ready" and we've done 0% of that.

**Before any further feature work:** do the Tier 1 list. That's 1 day of work and will catch 90% of "this is broken on first launch" issues.

**Then** decide if you want to go for v1 in SG, or pivot the niche. Tier 2-4 are sequential and large. Tier 2 alone is a week of focused work.

I (Mavis) cannot validate further without Flutter in this sandbox. My validation is structural — brace balance, API shape, code patterns. **Anything that requires actually running the app is on you.**
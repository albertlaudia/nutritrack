# Known build warnings & deprecations

Things to address before Flutter 4.0 (when these break the build).

---

## 1. Kotlin Gradle Plugin (KGP) migration

**Severity:** Warning now, **build failure in future Flutter versions.**

When building for Android, you see:

```
WARNING: Your Android app project: app located at: android/app/build.gradle
applies the Kotlin Gradle Plugin, which will cause build failures in future
versions of Flutter. Please migrate your app to Built-in Kotlin using this
guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
  - camera_android_camerax
  - device_info_plus
  - health
  - mobile_scanner
  - record_android
  - rive_common
```

### What this means

Flutter is moving to "Built-in Kotlin" — Kotlin support ships with Flutter SDK itself instead of needing a separate Kotlin Gradle Plugin declared in each plugin's `build.gradle`. Until each of the 6 plugins above migrates, future Flutter versions will refuse to build.

### What to do

1. **Wait for plugin authors to migrate.** Most of these have open issues. Watch the changelogs of:
   - `camera_android_camerax` (part of `camera: ^0.11.x`)
   - `device_info_plus` (transitive of `health` and others)
   - `health: ^10.x`
   - `mobile_scanner: ^5.x` → ^6.x reportedly migrated
   - `record_android` (part of `record: ^5.x`)
   - `rive_common` (part of `rive: ^0.13.x`)
2. **Don't pin to old versions deliberately.** This warning fires today but the build still succeeds. Forcing "no KGP" by downgrading will break more than it fixes.
3. **Track via the dependency-sync.yml GitHub Action** — weekly outdated check will surface when newer plugin versions drop.

### File an issue

If a plugin has been silent for >6 months, file an issue on the plugin's GitHub repo. The Flutter team has a guide:

https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers#report-incompatible-kotlin-gradle-plugin-usage-to-plugin-authors

---

## 2. `Color.withOpacity` deprecation

**Severity:** Info warning since Flutter 3.27.

The whole `lib/` codebase has ~60 calls to `Color.withOpacity(x)`. Flutter 3.27+ emits a deprecation warning; Flutter 4.0 will likely remove the method.

### Migration path

```dart
// Before
color.withOpacity(0.5)

// After
color.withValues(alpha: 0.5)
```

### Strategy

Sed across the repo, but watch out: `.withOpacity(x)` is on `Color`, while `.withValues(alpha: x)` is on the new `Color` API. Both should work for `Color` subclasses but verify in a test build.

---

## 3. `record` Linux interface mismatch — RESOLVED with caret pin

**Severity:** ~~Hard build failure on Windows~~ → now just a pub outdated warning.

The `record` voice-capture package (used in `quick_log_bar.dart`) had a platform-implementation mismatch where `record 7.x` (interface 2.x) sat alongside `record_linux 0.7.2` (interface 1.x), causing:

```
Error: The non-abstract class 'RecordLinux' is missing implementations for
these members: - RecordMethodChannelPlatformInterface.startStream
```

### Resolution

Coherent 7.x-compatible platform implementations all ship now:
- `record: 7.1.1`
- `record_platform_interface: 2.1.0`
- `record_linux: 2.1.0`
- `record_windows: 2.2.1`
- `record_android: 2.1.2`
- `record_web: 2.1.1`

`pubspec.yaml` pins `record: ^5.1.2`, which under caret semantics (in pubspec) means `>=5.1.2 <6.0.0`. The standalone `record: ^5` line currently resolves to 5.1.2 because pub's general resolution picks the highest compatible version, but the platform impls haven't been bump-allowed by the constraint.

### Path forward

Bump to `record: ^7.0.0` once you've verified the following API surfaces are stable for your codebase:
- `startStream` signature change (new in 2.x interface)
- `hasPermission` parameter `bool request` is now required (was optional)

QuickLogBar's `lib/features/dashboard/presentation/widgets/quick_log_bar.dart` is the only consumer — check what API it uses today before bumping.

### Why we kept the pin

We do not bump `record` to 7.x in this commit because:
1. Riverpod / Freezed / mobile_scanner / health / go_router all have MAJOR bumps pending (see §6). Running a record bump at the same time as those would compound breakage.
2. Once the upcoming batches of major-version bumps land, run `flutter pub upgrade record --major-versions` as a single clean migration.

---

## 4. `pubspec.lock` not in repo

**Severity:** Build determinism risk.

`pubspec.lock` is gitignored or not committed (verify with `git ls-files pubspec.lock`). Every fresh clone resolves dependencies differently, leading to non-reproducible builds.

### Fix

```bash
flutter pub get
git add pubspec.lock
git commit -m "chore: commit pubspec.lock for reproducible builds"
```

Should be committed. The CI workflow doesn't currently commit it back, which is fine for CI but means local dev needs to `pub get` to regenerate.

---

## 5. Drift generated files not committed

**Severity:** Build determinism risk (same family as #4).

After `dart run build_runner build --delete-conflicting-outputs`, the `*.g.dart` files are generated locally but may not be committed. Every fresh clone fails to compile until they regenerate.

### Fix

Add to a `pre-commit` hook OR a CI step:

```bash
#!/bin/bash
# .githooks/pre-push
dart run build_runner build --delete-conflicting-outputs
git add '*.g.dart' '*.freezed.dart'
git diff --cached --quiet || git commit -m "chore: regenerate drift sources"
```

Or simpler: just commit the generated files manually after each `dart run build_runner build` run.
---

## 6. Major-version dependency debt (run weekly)

**Severity:** Future-feature risk, not immediate breakage.

`flutter pub outdated` on 2026-07-01 surfaced these major-version gaps:

| Package | Current | Latest | Status |
|---|---|---|---|
| flutter_riverpod | 2.6.1 | 3.3.2 | not bumping — Riverpod 3 is API-broken |
| riverpod_annotation | 2.6.1 | 4.0.3 | not bumping — coupled to Riverpod 3 |
| riverpod_generator | 2.6.4 | 4.0.4 | not bumping — coupled to Riverpod 3 |
| freezed | 2.5.8 | 3.2.5 | not bumping — needs `@freezed` class rewrite |
| freezed_annotation | 2.4.4 | 3.1.0 | coupled to freezed 3 |
| mobile_scanner | 5.2.3 | 7.2.0 | not bumping — Android iOS API reshuffle |
| health | 10.2.0 | 13.3.1 | not bumping — Android permission flow changed |
| go_router | 14.8.1 | 17.3.0 | not bumping — breaking route config |
| drift | 2.28.2 | 2.34.0 | ok to bump (minor+patch) |
| drift_dev | 2.28.0 | 2.34.1 | ok to bump (coupled to drift) |
| camera | 0.11.4 | 0.12.0+1 | minor+patch — safer to bump |
| flutter_lints | 4.0.0 | 6.1.0 | not bumping — rule changes need audit |
| intl | 0.19.0 | 0.20.3 | breaking date formatting APIs |
| dependency_sync.yml | weekly | — | automated PR for safe minor+patch |

### Strategy

1. Keep `dependency-sync.yml` on a weekly cron — it opens safe PRs for minor+patch bumps.
2. Hold a quarterly "major version day" where 2–3 majors get bumped together with testing.
3. Track Riverpod 3 migration as the highest-leverage upgrade — every Riverpod-using file would need a `flutter_riverpod` import audit.

### When to bump together

Group by effort, not by date:

- **Group A (small):** drift + drift_dev + camera + dio (no API break in those point releases).
- **Group B (medium):** go_router 17 + intl 0.20 + drift (coupled).
- **Group C (big):** Riverpod 3 (Riverpod 3.x + annotation + generator, then run codegen).
- **Group D (big):** Freezed 3 (rewrite all `@freezed` classes).
- **Group E (medium):** mobile_scanner 7 + health 13 (cross-platform permission/model API reshuffles).

Don't try to do all 5 groups in one PR.

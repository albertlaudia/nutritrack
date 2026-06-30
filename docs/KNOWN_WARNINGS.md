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

## 3. `record` Linux interface mismatch

**Severity:** **Hard build failure on Windows.**

The `record` voice-capture package (used in `quick_log_bar.dart`) has platform-specific implementations. Pub can resolve `record 7.x` (interface 2.x) on one platform but pull `record_linux 0.7.2` (interface 1.x) on another, causing:

```
Error: The non-abstract class 'RecordLinux' is missing implementations for
these members: - RecordMethodChannelPlatformInterface.startStream
```

### Fix in this repo

`pubspec.yaml` pins `record: 5.1.2` + `record_platform_interface: 1.4.0` via `dependency_overrides`. This keeps every platform implementation on interface 1.x where the implementations are complete.

### When to remove the override

When ALL of the following ship a coherent 7.x set:
- `record: ^7.x` (the core package)
- `record_linux: ^1.0.0` (Linux impl, currently stuck at 0.7.x)
- `record_platform_interface: ^2.0.0` (new interface)

Until then, keep the override.

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
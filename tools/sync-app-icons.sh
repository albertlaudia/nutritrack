#!/bin/bash
#
# Wire media/app-icons/ → Flutter project's android/ and ios/ asset folders.
#
# This makes the master SVG → PNG exports actually USED in the build.
# Until you run this, the Flutter app uses the default Flutter logo
# (or whatever was previously copied to those folders).
#
# Usage:  bash tools/sync-app-icons.sh
#
# Run after:
#   python3 scripts/export_app_icons.py
#
# Safe to re-run any time. Symlinks where possible, copies where symlinks
# aren't reliable (Windows-checkouts).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MEDIA="$ROOT/media/app-icons"
FLUTTER="$ROOT/../"  # Flutter project root = this repo root

cd "$ROOT"

# ── Android ──────────────────────────────────────────────────────────────
ANDROID_RES="$ROOT/android/app/src/main/res"

echo "→ Android legacy icons → android/app/src/main/res/mipmap-{density}/ic_launcher.png"
for D in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$ANDROID_RES/mipmap-$D"
  cp -v "$MEDIA/android/$D/ic_launcher.png" "$ANDROID_RES/mipmap-$D/"
done

echo "→ Android adaptive (v26+) → mipmap-anydpi-v26/"
mkdir -p "$ANDROID_RES/mipmap-anydpi-v26"
cp -v "$MEDIA/android/mipmap-anydpi-v26/"*.xml "$ANDROID_RES/mipmap-anydpi-v26/"
cp -v "$MEDIA/android/foreground.png"  "$ANDROID_RES/mipmap-anydpi-v26/ic_launcher_foreground.png"
cp -v "$MEDIA/android/background.png"  "$ANDROID_RES/mipmap-anydpi-v26/ic_launcher_background.png"
cp -v "$MEDIA/android/monochrome.png"  "$ANDROID_RES/mipmap-anydpi-v26/ic_launcher_monochrome.png"

# ── iOS ─────────────────────────────────────────────────────────────────
IOS_ASSETS="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$IOS_ASSETS"
cp -v "$MEDIA/ios/AppIcon.appiconset/"*.png "$IOS_ASSETS/"
cp -v "$MEDIA/ios/AppIcon.appiconset/Contents.json" "$IOS_ASSETS/"

# ── Web (if/when marketing site is added) ───────────────────────────────
echo
echo "Note: web favicons go in any future web/ folder. For now Flutter web"
echo "      will need them manually placed in web/ during flutter create."

echo
echo "Done. App icons wired to Flutter project."
echo "Run:  flutter clean && flutter run"

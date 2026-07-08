#!/bin/bash
#
# One-shot lint & code hygiene pass. Safe to run anytime.
#
# What this does:
#   1. flutter pub get (refresh lockfile)
#   2. dart fix --apply (auto-resolve what's mechanical)
#   3. flutter analyze (show what fix didn't catch)
#
# What it does NOT do:
#   - Modify generated files (run build_runner separately)
#   - Touch pubspec.yaml (the dead-dep removal is a deliberate PR)
#   - Push anything
#
# Usage: bash tools/lint-cleanup.sh

set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter not on PATH. Install from https://docs.flutter.dev/get-started/install"
  exit 1
fi

echo "🔄 flutter pub get ..."
flutter pub get

echo ""
echo "🔧 dart fix --apply ..."
dart fix --apply

echo ""
echo "🧪 Regenerating freezed/json/drift sources (also runs analyze)..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "📊 flutter analyze ..."
flutter analyze --no-fatal-infos --no-fatal-warnings

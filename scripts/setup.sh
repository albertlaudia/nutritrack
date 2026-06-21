#!/bin/bash
set -e

echo "🥗 NutriTrack setup"
echo "===================="

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter not found. Install from https://docs.flutter.dev/get-started/install"
  exit 1
fi

echo "✅ Flutter $(flutter --version | head -1)"

echo ""
echo "📦 Installing dependencies..."
flutter pub get

if [ ! -f lib/core/config/secrets.dart ]; then
  echo ""
  echo "🔑 Setting up secrets..."
  cp lib/core/config/secrets.dart.template lib/core/config/secrets.dart
  echo "   Created lib/core/config/secrets.dart"
  echo "   ⚠️  Edit it with:"
  echo "      - OpenRouter API key (https://openrouter.ai/keys)"
  echo "      - Supabase URL + anon key (optional, for cloud sync)"
fi

echo ""
echo "🔨 Generating code (freezed, json_serializable, isar, riverpod)..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit lib/core/config/secrets.dart with your keys"
echo "  2. flutter run"
echo "  3. flutter build apk --release"
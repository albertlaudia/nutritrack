# NutriTrack

**MyFitnessPal meets AI.** Offline-first nutrition + workout tracker for iOS and Android.

Snap your meal. Speak your lunch. Get instant macro breakdowns with adaptive targets that learn from your progress.

## Why it's different

| Old way | NutriTrack |
|---|---|
| Type "1 cup rice" in search | Snap photo, AI identifies rice + chicken + greens separately |
| Log workout sets in 5 separate screens | Voice: "Bench 3x8 at 185, RPE 8" — done |
| Manual macro targets | TDEE wizard that recalibrates with your goal + activity |
| Lose your log if you don't log in | Offline-first Isar DB; cloud sync is optional |

## Architecture

Domain-Driven Architecture (DDA) with **clear boundaries** between layers:

```
lib/
├── core/                    # Framework-level concerns
│   ├── ai/                 # Pluggable AI gateway (vision + voice)
│   ├── db/                 # Isar collections + service
│   ├── theme/              # Design system
│   ├── animation/          # Motion tokens
│   ├── network/            # Dio config
│   └── config/             # Secrets (compile-time env)
│
├── features/                # Vertical features, each self-contained
│   ├── dashboard/
│   │   ├── domain/         # FoodLogEntry, MacroNutrients (pure)
│   │   ├── data/           # FoodLogRepository (Isar)
│   │   └── presentation/   # DashboardScreen + widgets
│   ├── workout/
│   ├── insights/
│   ├── settings/
│   └── ...
│
├── shared/                  # Cross-feature concerns
│   ├── providers/          # Riverpod providers (@riverpod codegen)
│   ├── widgets/            # Reusable widgets
│   └── extensions/
│
└── app/                    # App entry: theme, router, shell
    ├── app.dart
    ├── router.dart         # GoRouter with StatefulShellRoute
    └── shell_scaffold.dart # 4-tab bottom nav
```

## Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.24+, Dart 3.4+ |
| State | Riverpod 2.5 with `@riverpod` codegen |
| Routing | go_router 14 with `StatefulShellRoute.indexedStack` |
| Local DB | Isar 3.1 (NoSQL, indexed, reactive queries) |
| AI | OpenRouter → MiniMax M3 + Gemini Flash + GPT-4o-mini fallback |
| Audio | record 5.x → Whisper large-v3 |
| Voice parse | M3 text → structured JSON |
| Health | health 10.x (Apple Health + Health Connect + Google Fit) |
| Charts | fl_chart 0.69 (weight graph, moving average) |
| Cloud sync | supabase_flutter (ready, off by default) |
| Models | freezed + json_serializable + Isar annotations |

## 4-tab UX

### Tab 1: Fuel & Energy (Dashboard)
- **Multi-layer nutrition donut** — outer calories, middle macros (P/C/F arcs), inner readout
- **Macro chips** with progress bars
- **AI Quick-Log bar** floating bottom — tap = snap, hold = voice
- **Meal timeline** — Breakfast → Lunch → Dinner → Snacks, each with sparkline macro bars

### Tab 2: Smart Workout Builder
- **Exercise DB** — Isar-indexed, 1000+ exercises (seeded once)
- **Filters** — muscle group, equipment, difficulty
- **Session runner** — sets × reps × weight × RPE
- **Biometric hooks** — read active energy from Apple Health / Google Fit

### Tab 3: AI Insights & Forecasting
- **Weight progression graph** — daily weight + 7-day moving average
- **Adherence correlator** — rule-based insights from your logs
  - "When protein < 20% by noon, evening cravings ↑ 40%"
  - "30g+ fiber 5 days → better sleep scores"

### Tab 4: Biomarker Settings
- **TDEE wizard** — Mifflin-St Jeor BMR × activity multiplier
- **Goal presets** — aggressive cut / moderate cut / recomposition / lean bulk / aggressive bulk / maintain
- **Auto macro targets** — protein g/kg, fat % of kcal, carbs as remainder

## Quick start

```bash
# 1. Install Flutter
# https://docs.flutter.dev/get-started/install

# 2. Clone
git clone https://github.com/albertlaudia/nutritrack.git
cd nutritrack

# 3. One-shot setup
bash scripts/setup.sh
# - flutter pub get
# - copies secrets template
# - runs build_runner

# 4. Edit secrets with your OpenRouter key
#    (and Supabase URL/anon if you want cloud sync)
# lib/core/config/secrets.dart

# 5. Run
flutter run
```

## AI gateway — pluggable

```dart
abstract class AIGateway {
  Future<List<FoodLogEntry>> recognizeFromImage({...});
  Stream<VoiceLogProgress> parseFromVoice({...});
  Future<List<FoodLogEntry>> parseTextLog(String transcript);
}
```

Default implementation: **OpenRouterAIGateway** that:
1. Resizes image to 1024px, compresses to ~78% JPEG
2. POSTs to OpenRouter with MiniMax M3 (primary)
3. Falls back to Gemini Flash, then GPT-4o-mini on error
4. Parses structured JSON → typed `FoodLogEntry` list

Swap in your own `AIGateway` (direct OpenAI, on-device TFLite, etc.) by providing an alternate implementation in `core_providers.dart`.

## Production checklist

- [ ] Add real release signing keys (Android `release.keystore`, iOS Apple Developer team)
- [ ] Seed exercise database with 1000+ exercises (`workout_repository.seedExercisesIfEmpty`)
- [ ] Wire `supabase_flutter` for cloud sync (offline-first still primary)
- [ ] Add Health platform native config (HealthKit entitlements, Health Connect declaration)
- [ ] Localize UI strings to ES / ZH / ID for SG/MY/ID launch wedge
- [ ] App icon + splash assets (currently placeholder emoji)

## License

MIT — see [LICENSE](LICENSE).
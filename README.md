# NutriTrack

**MyFitnessPal meets AI.** Offline-first nutrition + workout tracker for iOS and Android.

Snap your meal. Speak your lunch. Get instant macro breakdowns with adaptive targets that learn from your progress.

## Why it's different

| Old way | NutriTrack |
|---|---|
| Type "1 cup rice" in search | Snap photo, AI identifies rice + chicken + greens separately |
| Log workout sets in 5 separate screens | Voice: "Bench 3x8 at 185, RPE 8" — done |
| Manual macro targets | TDEE wizard that recalibrates with your goal + activity |
| Lose your log if you don't log in | Offline-first Drift DB; cloud sync is optional |

## Architecture

Domain-Driven Design (DDD) with **clear boundaries** between layers:

```
lib/
├── core/                    # Framework-level concerns
│   ├── ai/                 # Pluggable AI gateway (vision + voice)
│   ├── db/                 # Drift DB + service
│   ├── sync/               # PocketBase REST client
│   ├── error/              # Global error handler + error boundary widget
│   ├── theme/              # Design system (colors, motion, theme)
│   └── config/             # Secrets (compile-time env)
│
├── features/                # Vertical features, each self-contained
│   ├── dashboard/
│   │   ├── domain/         # FoodLogEntry, MacroNutrients (freezed)
│   │   ├── data/           # FoodLogRepository (Drift)
│   │   └── presentation/   # DashboardScreen + widgets
│   ├── workout/
│   ├── insights/
│   ├── settings/
│   ├── camera/             # Snap → AI → review → save
│   └── barcode/            # Scan → OFF lookup → review → save
│
├── shared/                  # Cross-feature concerns
│   └── providers/          # Riverpod providers (@riverpod codegen)
│
└── app/                    # App entry: theme, router, shell
    ├── app.dart
    ├── router.dart         # GoRouter with StatefulShellRoute
    └── shell_scaffold.dart # 4-tab bottom nav
```

## Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.27+, Dart 3.6+ |
| State | Riverpod 2.6 with `@riverpod` codegen |
| Routing | go_router 14 with `StatefulShellRoute.indexedStack` |
| Local DB | Drift 2.28 (SQLite, reactive streams) |
| AI | OpenRouter → MiniMax M3 + Gemini Flash + GPT-4o-mini fallback |
| Voice capture | record 5.1.2 → Whisper large-v3 |
| Voice parse | M3 text → structured JSON |
| Barcode | mobile_scanner 5.2.3 → Open Food Facts |
| Charts | fl_chart 0.69 (weight graph, moving average) |
| Backend | PocketBase (REST, scheduled OFF → PB sync via GitHub Actions) |
| Models | freezed + json_serializable |

## 4-tab UX

### Tab 1: Fuel & Energy (Dashboard)
- **Multi-layer nutrition donut** — outer calories, middle macros (P/C/F arcs), inner readout
- **Macro chips** with progress bars
- **AI Quick-Log bar** floating bottom — tap = snap, hold = voice
- **Meal timeline** — Breakfast → Lunch → Dinner → Snacks, each with sparkline macro bars

### Tab 2: Smart Workout Builder
- **Exercise DB** — PocketBase-backed, seeded with chest exercises (488 target across 9 muscle groups)
- **Filters** — muscle group, equipment, difficulty
- **Session runner** — sets × reps × weight × RPE
- **Biometric hooks** — local WeightRepository entries

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
# 1. Install Flutter 3.27+ from https://docs.flutter.dev/get-started/install

# 2. Clone
git clone https://github.com/albertlaudia/nutritrack.git
cd nutritrack

# 3. One-shot setup
bash scripts/setup.sh
# - flutter pub get
# - copies secrets template to lib/core/config/secrets.dart
# - runs build_runner (freezed, json_serializable, drift, riverpod)

# 4. Edit secrets with your OpenRouter key
# lib/core/config/secrets.dart

# 5. Run
flutter run
```

**First build on a fresh clone takes ~3 minutes** (downloads Gradle, runs build_runner, runs pub get). Subsequent builds are ~10 seconds.

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

## Production readiness

See `docs/PRODUCTION_READINESS_AUDIT.md` for the full audit (16-point problem list with effort estimates) and `docs/WHAT_MISSING_AND_HOW_TO_BE_BEST.md` for the product strategy.

Top open items:
- **Build must complete on a real device** (currently ~30 lint warnings remaining, all minor)
- **First-run onboarding** — currently goes straight to `/dashboard`
- **Insights screen real data** — currently renders sample data
- **Tests** — 0% coverage; plan for ~7 priority tests
- **Crash reporting** — no Sentry integration yet

## Brand

The NutriTrack mark is a brand-orange rounded square containing a cream "plate" circle with one quadrant cleanly cut out (top-right), three horizontal data lines on the cream area (representing parsed meal data), and one solid orange dot below center (representing "logged").

- Master SVG: `media/app-icons/source/icon-master.svg`
- Per-platform exports: `media/app-icons/{ios,android,web,store-assets}/`
- Regenerate after any change: `python3 scripts/export_app_icons.py && bash tools/sync-app-icons.sh`
- Design tokens: `media/templates/figma-tokens.json`

## License

MIT — see [LICENSE](LICENSE).

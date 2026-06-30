# `illustrations/` — Empty states, onboarding, hero scenes

Vector-first illustrations used inside the Flutter app and on the marketing site.

## Style guide

- **Line over fill.** Stroke-heavy illustrations with selective flat color fills
- **Warm, slightly playful.** Not corporate; not childish
- **Brand palette only.** No colors outside `media/SOURCE.md` color table
- **Avoid:** stock photo style, photographs of food, gradients inside illustrations
- **Include:** contextual objects (phone, plate, scale) to reinforce the action

## Empty states (in the app)

| File | Where it appears |
|---|---|
| `empty-dashboard.svg` | Dashboard tab when no meals logged today |
| `empty-meals.svg` | Specific meal slot (breakfast, lunch, dinner, snack) when empty |
| `empty-workouts.svg` | Workout tab when no sessions started |
| `empty-insights.svg` | Insights tab when no biometric data yet |
| `empty-search.svg` | Search results when nothing matches |

Each should:
- Be 320×320 viewBox minimum (so it scales cleanly on phones and tablets)
- Have a single hero illustration + space below for the headline + CTA

## Onboarding (3-4 screens)

| File | Screen |
|---|---|
| `onboarding-1-hero.svg` | Welcome / "We get out of your way" |
| `onboarding-2-hero.svg` | Voice/camera/snap — the three log methods |
| `onboarding-3-hero.svg` | Offline-first / privacy |
| `onboarding-4-hero.svg` | (optional) Goal-setting step |

Each ~360×480 viewBox to match a phone screen minus nav bar.

## Hero illustrations

Larger illustrations for marketing site, blog posts, social. ~1200×800 viewBox.

## Format

- **SVG** is the master format. Always.
- Export PNG fallbacks at 1×, 2×, 3× device pixel ratios into a sibling `exports/` folder if the consuming platform can't render SVG (some email clients, some in-app views on older Android)
- Don't bake text into illustrations — it gets blurry at small sizes and creates i18n headaches

## Flutter consumption

```dart
// In a Flutter widget:
SvgPicture.asset(
  'assets/illustrations/empty-meals.svg',
  width: 200,
  height: 200,
)
```

Requires `flutter_svg` (already in pubspec). Assets go in `assets/illustrations/` of the Flutter project, which should be a symlink or copy of this folder.
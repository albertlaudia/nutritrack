# NutriTrack — Brand source

> **Single source for brand rules. When in doubt, refer here. Update this file when the brand changes.**

## Voice & positioning

**One-liner:** *The voice-first tracker for people who eat real food.*

**Tone:** Calm, smart, non-judgmental. We help you log; we don't lecture you about your choices.

**Three things we never sound like:**
- ❌ Gym-bro motivation ("CRUSH YOUR GOALS")
- ❌ Diet-culture shame ("you shouldn't have eaten that")
- ❌ Corporate wellness ("maximize your human capital")

**Three things we do sound like:**
- ✅ A friend who tracks their own food
- ✅ A nutritionist who respects your life
- ✅ Tech that gets out of your way

---

## Colors

Primary brand color is orange (food, warmth, energy — not corporate blue or diet green).

| Token | Hex | RGB | Where to use |
|---|---|---|---|
| `brand` | `#FF6B35` | 255, 107, 53 | Primary CTAs, highlights, brand surfaces |
| `brand-dark` | `#E85A2C` | 232, 90, 44 | Hover/pressed states |
| `brand-light` | `#FF8A5C` | 255, 138, 92 | Hover on light surfaces |
| `brand-soft` | `#FFF1EB` | 255, 241, 235 | Tinted backgrounds, "filled chip" UI |
| `mint` | `#00C896` | 0, 200, 150 | Success, positive streaks |
| `amber` | `#FFB627` | 255, 182, 39 | Warning, attention without alarm |
| `sky` | `#4FC3F7` | 79, 195, 247 | Informational accents |
| `lavender` | `#8B7FFF` | 139, 127, 255 | Secondary accents |
| `rose` | `#FF6B9D` | 255, 107, 157 | Tertiary accents |
| `error` | `#E53935` | 229, 57, 53 | Destructive actions, errors only |

**Neutrals:**
| Token | Hex | Where |
|---|---|---|
| `background` | `#FAFAFA` | App background (light mode) |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surface-muted` | `#F5F5F7` | Inset surfaces, skeletons |
| `divider` | `#EAEAEA` | Hairlines, borders |
| `text-primary` | `#1A1A1A` | Body text |
| `text-secondary` | `#6B6B6B` | Captions, secondary info |
| `text-tertiary` | `#A0A0A0` | Disabled, hints |

These exact hex values live in code at `lib/core/theme/app_colors.dart`. The mobile project MUST stay in sync with this file — treat the Dart file as a copy of this doc, not the other way around.

---

## Typography

**Display + Headlines:** Inter, weights 600–800
**Body:** Inter, weight 400–500
**Mono (numbers, macros):** JetBrains Mono, weight 400

Inter is licensed under the SIL Open Font License 1.1 (free for commercial use). The actual font files live in two places:

- **`media/fonts/Inter/`** — golden source, includes LICENSE + README
- **`assets/fonts/`** — Flutter-side copy referenced by `pubspec.yaml`'s `flutter.fonts:` section

These should be byte-identical. If you update Inter, update both. (Could be a symlink if cross-platform — GitHub symlinks are flaky on Windows clones.)

### Type scale (in code)

```
displayLarge  56 / 800 / -1.5     # Hero numbers (e.g. remaining kcal)
displayMedium 44 / 800 / -1.2
displaySmall  34 / 700 / -0.8
headlineLarge 28 / 700 / -0.5    # Screen titles
headlineMedium 22 / 700 / -0.3
headlineSmall 18 / 600 / -0.2
titleLarge    18 / 600
titleMedium   16 / 600
titleSmall    14 / 600
bodyLarge     16 / 400 / 1.5
bodyMedium    14 / 400 / 1.45
bodySmall     12 / 400 / 1.4
```

Source: `lib/core/theme/app_theme.dart`. Update both files together when scale changes.

---

## Logo

The NutriTrack logo is the brand mark used in:
- App icon (simplified version)
- Splash screen
- Web footer
- Social cards
- Store listings

Logo variants:

| File | Purpose |
|---|---|
| `branding/logo/logo-primary.svg` | Master — orange wordmark on transparent |
| `branding/logo/logo-mono-dark.svg` | White on dark backgrounds |
| `branding/logo/logo-mono-light.svg` | Dark on light backgrounds |
| `branding/logo/logo-wordmark.svg` | Wordmark only (no icon) for tight horizontal spaces |

Exports (PNG): `branding/exports/logo-{1024,512,256,128}.png`

**Clear space rule:** minimum padding around logo = 1× the height of the wordmark. No text or graphics inside this padding.

**Minimum size:** 24px height (digital), 12mm height (print).

---

## Iconography

The Flutter app uses Material icons (`Icons.*`) for in-app UI. For the **app icon** and any branded illustrations, use:

- **Master:** `media/app-icons/source/icon-master.svg` (1024x1024 vector)
- **Exports:** see `media/app-icons/{ios,android,web}/`

The app icon should be **simple, recognizable at 16px, and recognizably NutriTrack**. Avoid photographic content — Apple's HIG and Material guidelines both reject it.

**Design constraints for the app icon:**
- Single solid background color (the brand orange or white)
- Foreground silhouette visible at 16×16 px
- No text (app icons don't render text reliably at small sizes)
- No gradients in the icon itself (gradients render inconsistently across launchers)
- Border-radius: iOS rounds the icon for you; Android adaptive icons handle this — design for the inner 66% safe area

---

## Photography & imagery

**For illustrations (empty states, onboarding, marketing):**
- Line illustrations over flat color fills, brand palette
- Avoid: stock photos, photos of food (off-brand for a tracker focused on real food)
- Style: warm, slightly playful, minimal detail
- Recommended: commission a single illustrator and stick with their style

**For marketing screenshots (App Store + Play Store):**
- Always on the brand-orange gradient background
- Real UI screenshots, not mocked (use `flutter test --update-goldens` to regenerate)
- Show 1-2 key features per screenshot, with a one-line caption overlay

---

## Do / don't

✅ **Do:**
- Use the orange brand color for primary CTAs
- Use Inter for all text
- Use vector (SVG) for any new graphic
- Use the mint color for positive feedback only
- Respect minimum sizes

❌ **Don't:**
- Use blue, green (non-mint), or purple as primary accents
- Use Comic Sans, Papyrus, or any "playful" font for branding
- Use stock photos of food
- Add a gradient to the app icon
- Mix the rose / lavender / sky colors as primary — they're for variation only

---

## Change log

| Date | Change | Author |
|---|---|---|
| 2026-06-30 | Initial draft (orange brand, Inter typeface) | Mavis |

Update this table when the brand changes. Bump the version in `templates/figma-tokens.json` (semver).
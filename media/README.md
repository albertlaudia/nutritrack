# `media/` — Golden source for all brand & product assets

> **Rule: this folder is the single source of truth. Never duplicate. Always link from here.**

Every image, icon, illustration, screenshot, social card, font, and store listing asset for NutriTrack lives here. Platform-specific projects (Flutter mobile, Next.js web, future Figma libraries) reference these files via symlinks, build-time copy, or direct import — but the **canonical files live here**.

---

## Folder layout

| Folder | What's in it | Used by |
|---|---|---|
| `branding/` | Logo, wordmark, exports of the brand mark | Everywhere |
| `app-icons/` | App icon source + per-platform sized exports | iOS / Android / Web / PWA |
| `store-assets/` | App Store + Play Store marketing screenshots and listings | Store submission flows |
| `illustrations/` | Empty-state art, onboarding scenes, hero illustrations | Flutter mobile, web marketing |
| `marketing/` | Social cards, web hero, blog post images, OG cards | Web, social media, blog |
| `fonts/` | Brand font files (Inter, JetBrains Mono) with licenses | Flutter `pubspec.yaml`, web fonts |
| `templates/` | Source design tokens (Figma JSON, brand colors) | Designers, AI tools, regenerations |

---

## File naming convention

- **Lowercase, kebab-case**: `empty-dashboard.svg`, not `Empty Dashboard.svg`
- **One purpose per file**: don't cram multiple sizes into one file
- **Vector source always SVG**: every PNG has an SVG ancestor
- **Exports include size in name when ambiguous**: `logo-1024.png`, `hero-light-1920w.png`
- **No spaces, no underscores** in filenames. Dash only.

---

## Source vs export rule

Every asset has two forms:

1. **Source** (master, in `source/` or `branding/logo/`): the editable, scalable file
2. **Export** (in `exports/`, `ios/`, `android/`, `web/`): pre-rendered at the platform's required sizes

**Never edit an export.** If you need to change an icon, edit the source, then re-export all sizes. There should be a generator script (or a Figma plugin) that does this; see `templates/README.md`.

---

## Versioning

When a brand asset changes:

1. Update the source
2. Re-export all derived sizes
3. Commit source + exports together in one commit titled `brand: <change>`
4. Update `SOURCE.md` if the change affects brand rules (color, typography, voice)
5. Bump the `version` field in `templates/figma-tokens.json` (semver)

When a marketing asset changes:

1. Same as above but title the commit `marketing: <change>`

---

## Where assets get used

| Asset | Flutter | Web | App Store | Play Store |
|---|---|---|---|---|
| `branding/exports/logo-256.png` | ✅ Splash | ✅ Footer | ❌ | ❌ |
| `app-icons/ios/AppIcon.appiconset/*.png` | ✅ Xcode asset catalog | ❌ | ✅ Listing thumbnail | ❌ |
| `app-icons/android/{m,h,x,xx,xxx}hdpi/*.png` | ✅ res/drawable | ❌ | ❌ | ✅ Listing thumbnail |
| `store-assets/ios-app-store/screenshots/*.png` | ❌ | ❌ | ✅ Required | ❌ |
| `store-assets/google-play/feature-graphic.png` | ❌ | ❌ | ❌ | ✅ Required |
| `marketing/social/og-image-1200x630.png` | ❌ | ✅ Open Graph | ❌ | ❌ |
| `illustrations/empty-meals.svg` | ✅ Empty states | ❌ | ❌ | ❌ |

---

## How to add a new asset

1. Drop the source file (SVG preferred) into the right subfolder
2. Export all required sizes — use a script if the size list is non-trivial
3. Add a one-line entry to that folder's `README.md` describing what it is
4. If it's referenced from code, update the consuming project to point at it
5. Commit

---

## Read these next

- `SOURCE.md` — brand rules, colors, typography, voice
- `templates/README.md` — design tokens, Figma export instructions
- The folder-specific READMEs (e.g. `app-icons/ios/README.md`)
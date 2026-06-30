# `templates/` — Source design tokens + tooling

Source files and tokens for regenerating brand assets.

## What's here

| File | Purpose |
|---|---|
| `figma-tokens.json` | Design tokens — colors, spacing, radii, type. Source of truth for Figma Variables and code-side `app_colors.dart`. |
| `brand-colors.png` | Quick-reference card showing all brand colors. Use in design reviews. |
| `og-card-template.svg` | Template for blog/social share cards. Auto-generate via script. |

## `figma-tokens.json` (canonical design tokens)

This file is the **bridge between design and code**. It defines:

- Colors (with hex, RGB, HSL)
- Spacing scale (4px base, in 4/8/12/16/24/32/48/64)
- Border radii (sm/md/lg/full)
- Typography (font family, weights, sizes, line heights, letter spacing)
- Shadow definitions
- Z-index scale

Sync directions:
- **Figma Variables** ← this file (designers import)
- `lib/core/theme/app_colors.dart` ← this file (engineers copy)
- `lib/core/theme/app_theme.dart` ← `figma-tokens.json` (type styles)
- Web Tailwind config ← `figma-tokens.json` (web theme)

When you update this file:
1. Bump the `version` field (semver)
2. Add an entry to the change log at the bottom
3. Regenerate any consumer that needs it

## Regenerating PNG exports from SVGs

A small Node script (`scripts/export-png.js`) lives in this folder (or in `tools/` at the repo root — move as preferred). It walks `branding/`, `app-icons/`, `illustrations/`, `marketing/` and re-renders all required PNG sizes.

Pseudocode:

```js
const SIZES = {
  logo: [1024, 512, 256, 128],
  favicon: [16, 32, 192, 512],
  android: { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 },
};
// walk svgs, rasterize, output to the right export folder
```

Run with `node scripts/export-png.js` after editing any SVG.

## Open Graph card auto-generation

`og-card-template.svg` is a placeholder template. To generate a real share card from a blog post:

1. Pull post title + author + featured image
2. Open the template, fill in the title text and the image
3. Render to PNG at 1200×630
4. Save to `marketing/social/og-image-1200x630.png`

Implement in `scripts/build-og-card.js` using `sharp` + SVG manipulation.

## Adding a new asset type

When you introduce a new kind of asset (e.g., a new social platform, a new screen size):

1. Update this README
2. Add the size list to `export-png.js`
3. Add a new sub-folder under the relevant `media/<category>/`
4. Add a per-folder README explaining what's there and when to use it
5. Update `media/README.md`'s "Where assets get used" table
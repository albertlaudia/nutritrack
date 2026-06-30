# `branding/` — Logo and wordmark

Master vector files for the NutriTrack brand mark.

## Files

### Logos (master SVGs)

| File | Use |
|---|---|
| `logo/logo-primary.svg` | Primary brand mark — full color, transparent background. Use this on white/light surfaces. |
| `logo/logo-mono-dark.svg` | White version. Use on dark/brand surfaces. |
| `logo/logo-mono-light.svg` | Dark version. Use on light surfaces when you want a single-color mark. |
| `logo/logo-wordmark.svg` | Wordmark only (text "NutriTrack") for tight horizontal spaces where the icon is already shown. |

### Wordmarks (horizontal + stacked)

| File | Use |
|---|---|
| `wordmark/wordmark-horizontal.svg` | Logo icon + wordmark side by side. Default for headers. |
| `wordmark/wordmark-stacked.svg` | Logo icon above wordmark. Use for square containers. |

### Pre-rendered exports (PNG)

`exports/logo-{1024,512,256,128}.png` — raster fallbacks for places that can't read SVG (e.g., App Store Connect upload form, some social media uploaders).

## Usage rules

- **Always use SVG** when the consuming platform supports it. SVG is the source.
- **PNG exports are fallback only.** If you find yourself editing a PNG, edit the SVG and re-export.
- The PNG filenames include their width (`logo-256.png` = 256px wide). Don't add PNGs without the size in the name.
- Maintain aspect ratio. The master is 1024×1024 (icon + wordmark centered).

## How to re-export PNGs from SVG

Use any of:

```bash
# rsvg-convert (best quality, single command)
rsvg-convert -w 256 branding/logo/logo-primary.svg -o exports/logo-256.png

# ImageMagick (works everywhere)
convert -density 300 -background none \
  branding/logo/logo-primary.svg -resize 256x256 \
  exports/logo-256.png

# Inkscape CLI
inkscape branding/logo/logo-primary.svg \
  --export-png=exports/logo-256.png -w 256
```

For batch export of all sizes, see `templates/README.md`.
# `marketing/` — Web, social, blog assets

Everything for the marketing site, social media, blog posts, and email.

## Sub-folders

- `social/` — Open Graph cards, Twitter cards, share images
- `web-hero/` — Hero images for the marketing site

## Social card standards

| File | Size | Platform |
|---|---|---|
| `og-image-1200x630.png` | 1200×630 | Facebook Open Graph (default for most platforms) |
| `twitter-card-1200x675.png` | 1200×675 | Twitter / X summary_large_image |
| `linkedin-1200x627.png` | 1200×627 | LinkedIn shares |
| `instagram-square-1080.png` | 1080×1080 | Instagram feed posts |
| `instagram-story-1080x1920.png` | 1080×1920 | Instagram / TikTok stories |

## Web hero standards

| File | Size | Use |
|---|---|---|
| `hero-light-1920w.png` | 1920×1080 | Marketing site hero, light mode |
| `hero-dark-1920w.png` | 1920×1080 | Marketing site hero, dark mode |
| `hero-mobile-750w.png` | 750×1334 | Mobile viewport hero (rare) |

## Format guidance

- PNG, not JPG (sharp text/edges)
- sRGB color space
- 72dpi (these are screen-only)
- Maximum file size 200 KB (large social cards fail to load on slow connections)
- Use brand palette only
- Include the NutriTrack wordmark on all hero images (it's the only way to build brand recognition)

## Branding on social cards

Every share image must include:
1. NutriTrack wordmark (bottom-right or top-left)
2. One-line value prop or feature title
3. Brand-orange accent color

Avoid:
- Putting more than 7 words of text on a card
- Using fonts other than Inter
- Using photos (stick to illustrations or UI mockups)

## Web consumption

The marketing site (Next.js or similar) reads these from `media/marketing/web-hero/` directly via build-time copy or symlink.

## Social media auto-generation

For blog post share cards, use a template (see `templates/og-card-template.svg`) that takes:
- Post title (1 line)
- Author name
- Featured image (optional)
- Outputs: a PNG at 1200×630 with consistent branding

Don't hand-design every share card — automate.
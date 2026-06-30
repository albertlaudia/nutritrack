# Web App Icons

For the marketing site and any future PWA.

## Required files

| File | Size (px) | Purpose |
|---|---|---|
| `favicon-16.png` | 16×16 | Browser tab (standard DPI) |
| `favicon-32.png` | 32×32 | Browser tab (high DPI) |
| `favicon-192.png` | 192×192 | PWA manifest, Android home screen |
| `favicon-512.png` | 512×512 | PWA splash screen |
| `favicon.ico` | 16/32/48 multi-size | Legacy browser fallback |

## Where they're used

- **HTML head** (`<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">`)
- **Web manifest** (`"icons": [{ "src": "/favicon-192.png", "sizes": "192x192" }]`)
- **Apple touch icon** (`<link rel="apple-touch-icon" href="/favicon-192.png">`)
- **Open Graph default image** for social shares (`marketing/social/og-image-1200x630.png`)

## Web consumption

The web project (Next.js, etc.) should reference these directly. Copy or symlink as needed.

## Generating a `.ico` from PNGs

```bash
# ImageMagick: combine multiple sizes into one .ico
convert favicon-16.png favicon-32.png favicon-48.png favicon.ico

# RealFaviconGenerator or icoconvert.com for higher-quality ICO
```
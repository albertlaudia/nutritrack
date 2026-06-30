# `app-icons/` — App icon source + per-platform exports

The app icon is the single most-seen piece of branding for a mobile app — every notification, every home-screen glance, every App Store / Play Store search result. Get this right.

## Workflow

1. Edit `source/icon-master.svg` (1024×1024 vector)
2. Re-export to all per-platform sizes (see scripts in `templates/`)
3. Place the exports in the right platform folder:
   - iOS: `ios/AppIcon.appiconset/` (Xcode asset catalog)
   - Android: `android/{m,h,x,xx,xxx}hdpi/` (resource buckets)
   - Web: `web/` (favicons + PWA manifest)
4. Commit

The Flutter mobile project at `android/app/src/main/res/` and `ios/Runner/Assets.xcassets/` should be **symlinks or copies** of these folders. Keep them in sync.

## Per-platform sizes

### iOS (`ios/AppIcon.appiconset/`)

Xcode asset catalog requires specific filenames inside `AppIcon.appiconset/`:

| Filename | Size | Scale |
|---|---|---|
| `icon-20@2x.png` | 40×40 | iPhone notification 2x |
| `icon-20@3x.png` | 60×60 | iPhone notification 3x |
| `icon-29@2x.png` | 58×58 | iPad settings 2x |
| `icon-29@3x.png` | 87×87 | iPad settings 3x |
| `icon-40@2x.png` | 80×80 | iPhone spotlight 2x |
| `icon-40@3x.png` | 120×120 | iPhone spotlight 3x |
| `icon-60@2x.png` | 120×120 | iPhone app 2x |
| `icon-60@3x.png` | 180×180 | iPhone app 3x |
| `icon-1024.png` | 1024×1024 | App Store (no transparency allowed) |

A `Contents.json` is also required — see `ios/README.md` for the canonical version.

### Android (`android/{density}/`)

Android adaptive icons use foreground + background layers, but for the legacy direct icon approach (still supported by older devices):

| Folder | Size | Density |
|---|---|---|
| `mdpi/` | 48×48 | 160dpi baseline |
| `hdpi/` | 72×72 | 240dpi |
| `xhdpi/` | 96×96 | 320dpi |
| `xxhdpi/` | 144×144 | 480dpi |
| `xxxhdpi/` | 192×192 | 640dpi |

For Android 8+ adaptive icons (recommended), also produce `foreground.png` (432×432, safe zone 264×264) and `background.png` (432×432) — store in `android/` directly, not in density folders. The Flutter Android project places these in `android/app/src/main/res/mipmap-anydpi-v26/`.

### Web (`web/`)

| File | Size | Use |
|---|---|---|
| `favicon-16.png` | 16×16 | Browser tab |
| `favicon-32.png` | 32×32 | Browser tab (high-DPI) |
| `favicon-192.png` | 192×192 | PWA manifest, Android home screen |
| `favicon-512.png` | 512×512 | PWA splash, share image |

The web project uses these directly from `web/index.html` and `web/manifest.json`.

## Design rules

- **No transparency** on iOS 1024×1024 (App Store rejects it)
- **No rounded corners** — iOS and Android apply their own mask
- **Safe area** = inner 66% of the canvas. Anything outside may be cropped on Android adaptive.
- **Foreground / background contrast** — your icon needs to be legible on both light AND dark home screens. Test on both.
- **Don't include text.** App icons render at 16×16 px in notification badges; text becomes illegible.
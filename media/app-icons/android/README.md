# Android App Icons

Two formats to ship:

1. **Legacy icons** (one PNG per density): place in `mipmap-{m,h,x,xx,xxx}hdpi/`
2. **Adaptive icons** (Android 8+, recommended): separate foreground + background layers

## Legacy icons

| Folder | Size (px) | DPI |
|---|---|---|
| `mdpi/` | 48×48 | 160 |
| `hdpi/` | 72×72 | 240 |
| `xhdpi/` | 96×96 | 320 |
| `xxhdpi/` | 144×144 | 480 |
| `xxxhdpi/` | 192×192 | 640 |

Each file should be named `ic_launcher.png`.

## Adaptive icons (Android 8+)

Place in `android/` (not in density folders):

- `foreground.png` — 432×432 px. Visible portion: inner 264×264 safe area.
- `background.png` — 432×432 px. Solid color or full-bleed image.
- `monochrome.png` (optional, Android 13+) — for themed icons. 432×432 px, single color.

The Flutter Android project places these in `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@mipmap/ic_launcher_background"/>
  <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
  <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
```

## Android consumption

The Flutter Android project should reference these via Gradle's `resConfigs` or a pre-build script. Easiest: copy `mipmap-{density}/ic_launcher.png` into `android/app/src/main/res/mipmap-{density}/` during the build.

## Play Store rules

- App icon is uploaded separately in Play Console, NOT from the APK
- Use `store-assets/google-play/icon-512.png` for the Play Console listing
- The 512×512 must be opaque, no transparency
- Adaptive icons are device-rendered; the legacy icon is the fallback for older devices
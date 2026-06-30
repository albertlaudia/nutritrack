# `store-assets/` — App Store + Play Store marketing

All the artwork required to publish the app on the two major stores.

## Sub-folders

- `ios-app-store/` — what you upload to App Store Connect
- `google-play/` — what you upload to Play Console

These folders are **versioned per release**. When you ship v0.5, copy the relevant files into `ios-app-store/v0.5/` and `google-play/v0.5/`. This lets you regenerate assets without losing the ones a previous store submission used.

```
store-assets/
├── ios-app-store/
│   ├── screenshots/        # Latest screenshots (in per-version subfolders)
│   │   ├── 6.7-inch/       # iPhone 14 Pro Max size (1290x2796)
│   │   ├── 6.5-inch/       # iPhone 11 Pro Max (1242x2688)
│   │   └── 12.9-inch/      # iPad Pro 12.9" 3rd gen (2048x2732)
│   └── latest/             # Symlink-like reference to current version
└── google-play/
    ├── screenshots/        # Phone + tablet screenshots
    ├── feature-graphic.png # 1024x500 — required
    └── promo-graphic.png   # 1800x1200 — optional
```

## Required per platform

### iOS App Store

- App icon: 1024×1024 (also lives in `media/app-icons/ios/AppIcon.appiconset/`)
- Screenshots: minimum 3 per device class (iPhone 6.7", 6.5", 5.5" if supporting old devices, iPad 12.9")
- Optional: app preview video (15–30 seconds, H.264, .m4v or .mov)

### Google Play

- App icon: 512×512 (also in `media/app-icons/android/`)
- Feature graphic: 1024×500 (**required**)
- Phone screenshots: minimum 2, recommend 4–8
- Tablet screenshots: minimum 1 (if supporting tablets)
- Short description (80 chars), full description (4000 chars), what's new
- Optional: promo graphic 1800×1200

## How to capture screenshots

For Flutter, the recommended path is **`flutter test --update-goldens`** + a screenshot test. But for store screenshots you usually want a real device or simulator with seeded data, not a goldens file.

Practical workflow:
1. Build a release-mode build (`flutter build apk --release` or iOS equivalent)
2. Install on a phone with the right resolution
3. Navigate through key flows
4. Screenshot each (Cmd+S on iOS Simulator, Power+VolDown on real device)
5. Drop into the right `screenshots/<device-class>/` folder

Frame your screenshots with:
- Brand-orange gradient background (NOT plain)
- 1–2 key features per screenshot
- One-line caption overlay ("Snap it. AI identifies it.")
- Device bezel visible (looks more professional in the store)

## Versioning

When shipping a new release:
1. Create a folder `ios-app-store/v0.X/` and `google-play/v0.X/`
2. Drop new screenshots there
3. Update `latest/` symlink (or copy)
4. Update `CHANGELOG.md` at repo root with the store submission date + assets used
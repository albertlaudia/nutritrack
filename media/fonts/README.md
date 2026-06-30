# `fonts/` — Brand font files

The single source for brand fonts. The Flutter project at `assets/fonts/` should mirror these.

## Currently shipping

- **Inter** — display, headlines, body
- **JetBrains Mono** — numbers (macros, weight logs)

Both are licensed under the SIL Open Font License 1.1 — free for commercial use, no royalties.

## Files

```
fonts/
├── Inter/
│   ├── Inter-Regular.ttf      (400)
│   ├── Inter-Medium.ttf       (500)
│   ├── Inter-SemiBold.ttf     (600)
│   ├── Inter-Bold.ttf         (700)
│   ├── Inter-ExtraBold.ttf    (800)
│   ├── LICENSE.md              (OFL 1.1 — bundled with the font)
│   └── README.md               (Inter font credit + version)
├── JetBrainsMono/
│   ├── JetBrainsMono-Regular.ttf (400)
│   ├── LICENSE.md
│   └── README.md
└── README.md                  (this file)
```

## Flutter consumption

The Flutter project's `assets/fonts/` should mirror these files. `pubspec.yaml` declares them via:

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter/Inter-Regular.ttf
        - asset: assets/fonts/Inter/Inter-Medium.ttf
          weight: 500
        # ... etc
```

## When to update

1. New version of Inter released (every few months on rsms.me/inter)
2. Major redesign of the app that uses new weights

To update:
1. Download the new `.ttf` files from rsms.me/inter (Inter) and jetbrains.com/mono (JetBrains Mono)
2. Drop into `Inter/` or `JetBrainsMono/` here
3. Copy to Flutter project's `assets/fonts/` (or symlink)
4. Update version in this README and in `templates/figma-tokens.json`
5. Bump the font version in any app that hard-codes it

## Web consumption

The marketing site loads fonts via `@font-face` from `media/fonts/Inter/` (or a CDN). Don't bundle font files into the web build — load from this folder at runtime for consistency.

## Licensing reminder

Inter is **OFL 1.1** — you can use, modify, and redistribute freely. **Don't** sell the font itself. Always keep the LICENSE.md file with the font when distributing.

JetBrains Mono is **OFL 1.1** — same terms.

Both licenses require keeping the copyright notice intact. Don't strip them.
# iOS App Icons

Xcode asset catalog format.

## Required files

Place inside `AppIcon.appiconset/`:

| Filename | Size (px) | Purpose |
|---|---|---|
| `icon-20@2x.png` | 40×40 | iPhone notification 2x |
| `icon-20@3x.png` | 60×60 | iPhone notification 3x |
| `icon-29@2x.png` | 58×58 | iPad settings 2x |
| `icon-29@3x.png` | 87×87 | iPad settings 3x |
| `icon-40@2x.png` | 80×80 | iPhone spotlight 2x |
| `icon-40@3x.png` | 120×120 | iPhone spotlight 3x |
| `icon-60@2x.png` | 120×120 | iPhone home screen 2x |
| `icon-60@3x.png` | 180×180 | iPhone home screen 3x |
| `icon-1024.png` | 1024×1024 | App Store submission (MUST be opaque) |
| `Contents.json` | — | Xcode asset catalog manifest |

## Contents.json template

```json
{
  "images": [
    { "filename": "icon-20@2x.png", "idiom": "iphone", "scale": "2x", "size": "20x20" },
    { "filename": "icon-20@3x.png", "idiom": "iphone", "scale": "3x", "size": "20x20" },
    { "filename": "icon-29@2x.png", "idiom": "ipad", "scale": "2x", "size": "29x29" },
    { "filename": "icon-29@3x.png", "idiom": "ipad", "scale": "3x", "size": "29x29" },
    { "filename": "icon-40@2x.png", "idiom": "iphone", "scale": "2x", "size": "40x40" },
    { "filename": "icon-40@3x.png", "idiom": "iphone", "scale": "3x", "size": "40x40" },
    { "filename": "icon-60@2x.png", "idiom": "iphone", "scale": "2x", "size": "60x60" },
    { "filename": "icon-60@3x.png", "idiom": "iphone", "scale": "3x", "size": "60x60" },
    { "filename": "icon-1024.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024" }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

## iOS consumption

The Flutter iOS project at `ios/Runner/Assets.xcassets/AppIcon.appiconset/` should mirror this folder. Two options:

1. **Symlink:** `ln -s ../../media/app-icons/ios/AppIcon.appiconset ios/Runner/Assets.xcassets/AppIcon.appiconset`
2. **Build-time copy:** a Makefile/script that copies the files pre-build

I recommend symlink for single-source-of-truth, but Windows-clone friction means a copy is more reliable for teams. Document your choice in the iOS README.

## App Store rules (often forgotten)

- `icon-1024.png` must NOT have an alpha channel (App Store rejects with a cryptic error)
- All sizes must match `Contents.json` declarations exactly — wrong dimensions = rejected
- Don't include the same image at multiple sizes with different visual designs (auto-detected as deceptive)
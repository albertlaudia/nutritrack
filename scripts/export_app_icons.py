#!/usr/bin/env python3
"""
Export NutriTrack's master app-icon SVG to all platform-specific sizes.

Run from the repo root:
  python3 scripts/export_app_icons.py

Output:
  - media/app-icons/ios/AppIcon.appiconset/         (iOS asset catalog)
  - media/app-icons/android/{m,h,x,xx,xxx}hdpi/     (legacy density buckets)
  - media/app-icons/android/{foreground,background,monochrome}.png (adaptive)
  - media/app-icons/web/                            (favicons)
  - media/store-assets/google-play/icon-512.png     (Play Store submission)
  - media/branding/exports/logo-icon-1024.png       (canonical PNG)

The master SVG is media/app-icons/source/icon-master.svg — render with cairosvg.
"""
import os
import cairosvg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'media/app-icons/source/icon-master.svg')

# iOS App Icon set
IOS_DIR = os.path.join(ROOT, 'media/app-icons/ios/AppIcon.appiconset')
ios_targets = [
    ('icon-20@2x.png',        40),
    ('icon-20@3x.png',        60),
    ('icon-29@2x.png',        58),
    ('icon-29@3x.png',        87),
    ('icon-40@2x.png',        80),
    ('icon-40@3x.png',       120),
    ('icon-60@2x.png',       120),
    ('icon-60@3x.png',       180),
    ('icon-1024.png',       1024),
]

# Android legacy
ANDROID_DIR = os.path.join(ROOT, 'media/app-icons/android')
android_density_targets = [
    ('mdpi',     48),
    ('hdpi',     72),
    ('xhdpi',    96),
    ('xxhdpi',  144),
    ('xxxhdpi', 192),
]

# Android adaptive: foreground/background/monochrome are 432x432, fg has safe area in inner 264
ANDROID_ADAPTIVE_DIR = os.path.join(ROOT, 'media/app-icons/android')
android_adaptive_targets = [
    ('foreground.png',   432),
    ('background.png',   432),
    ('monochrome.png',   432),
]

# Web
WEB_DIR = os.path.join(ROOT, 'media/app-icons/web')
web_targets = [
    ('favicon-16.png',  16),
    ('favicon-32.png',  32),
    ('favicon-192.png', 192),
    ('favicon-512.png', 512),
]

# Play Store
STORE_DIR = os.path.join(ROOT, 'media/store-assets/google-play')
store_google_play_targets = [
    ('icon-512.png', 512),   # Play Store submission (opaque, no alpha)
]

# Branding exports (canonical flat PNG)
BRAND_DIR = os.path.join(ROOT, 'media/branding/exports')
brand_targets = [
    ('logo-icon-1024.png', 1024),
    ('logo-icon-512.png',   512),
    ('logo-icon-256.png',   256),
    ('logo-icon-128.png',   128),
]


def render(size: int, dst: str) -> None:
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cairosvg.svg2png(url=SRC, write_to=dst, output_width=size, output_height=size)
    print(f"  {os.path.relpath(dst, ROOT)}  ({size}x{size})")


def main() -> None:
    print(f"Master source: {os.path.relpath(SRC, ROOT)}")
    print()

    print("→ iOS AppIcon.appiconset/")
    for name, size in ios_targets:
        render(size, os.path.join(IOS_DIR, name))

    print()
    print("→ Android legacy (mipmap densities)")
    for density, size in android_density_targets:
        render(size, os.path.join(ANDROID_DIR, f'{density}/ic_launcher.png'))

    print()
    print("→ Android adaptive (foreground/background/monochrome)")
    for name, size in android_adaptive_targets:
        render(size, os.path.join(ANDROID_ADAPTIVE_DIR, name))

    print()
    print("→ Web (favicons)")
    for name, size in web_targets:
        render(size, os.path.join(WEB_DIR, name))

    print()
    print("→ Google Play (opaque 512x512)")
    for name, size in store_google_play_targets:
        render(size, os.path.join(STORE_DIR, name))

    print()
    print("→ Branding exports (canonical PNGs)")
    for name, size in brand_targets:
        render(size, os.path.join(BRAND_DIR, name))

    print()
    print("Done.  All platforms covered.")


if __name__ == '__main__':
    main()

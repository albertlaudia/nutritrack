# GitHub Actions workflows

Three workflows run on this repo:

## `ci.yml` — Build + analyze + test

Triggers: push to `main`/`develop`, pull requests to `main`.

Runs the standard Flutter CI: `flutter pub get`, `build_runner`, `flutter analyze --fatal-infos`, `flutter test --coverage`, then builds both Android APK and iOS `.app` bundle (no-codesign). All artifacts uploaded.

Caches `~/.pub-cache` and `.dart_tool` keyed on `pubspec.lock` hash so subsequent runs are fast.

## `off-to-pb-sync.yml` — Periodic OFF → PocketBase cache refresh

Triggers: every 6 hours (`0 */6 * * *`), or manual via `workflow_dispatch`.

Runs `scripts/off_to_pb_sync.js` to fetch Open Food Facts products for the barcodes in `data/seed-barcodes.txt` and upsert them into the `nt_barcode_cache` PocketBase collection. Without this, the cache only grows when users scan new barcodes, and OFF data goes stale.

**Required secrets** (configure at Settings → Secrets and variables → Actions):

| Secret | Description |
|---|---|
| `PB_URL` | e.g. `https://pocketbase.scaleupcrm.com` |
| `PB_ADMIN_EMAIL` | PocketBase superuser email |
| `PB_ADMIN_PASSWORD` | PocketBase superuser password |

Schedule runs do a dry-run first (logs what would happen) then the real run. Manual runs skip the dry-run if you want them to, and let you specify a custom barcode file or limit.

After the run, posts a `:notice::` line in the GitHub Actions log with the current record count in `nt_barcode_cache`, so you can verify growth over time.

**Caveat — OFF's published rate limit**: 1 product query per second per IP. The script sleeps 1100ms between requests. With 200 barcodes this takes ~3.7 minutes per run. If you expand the seed list significantly, consider scaling back to twice daily or pre-filtering by region.

## `dependency-sync.yml` — Weekly outdated + security advisory check

Triggers: Mondays at 09:00 UTC, or manual.

Runs `flutter pub outdated` and `osv-scanner` against `pubspec.lock`. If anything is outdated, opens (or updates) a PR titled `deps: weekly pub outdated check` with the full report. The PR is informational only — you decide whether to merge.

Posts a weekly summary to the GitHub Actions step summary and uploads the raw `runtime-outdated.txt`, `all-outdated.txt`, and `osv-report.md` as artifacts (30-day retention).

The PR-creation step uses `GH_TOKEN` from the workflow's auto-provided secret. It needs `contents: write` and `pull-requests: write` permissions, which are declared at the workflow level.

**Why a weekly PR instead of Dependabot auto-merge**: Dependabot aggressively opens dozens of PRs and doesn't understand your analyzer-5 vs analyzer-6 pin conflicts. This gives you the same signal (one place to look, weekly) without the noise.

## Required secrets summary

```
PB_URL             # used by off-to-pb-sync.yml
PB_ADMIN_EMAIL     # used by off-to-pb-sync.yml
PB_ADMIN_PASSWORD  # used by off-to-pb-sync.yml
```

No secrets are required for `ci.yml` or `dependency-sync.yml` (they only read public repo data).